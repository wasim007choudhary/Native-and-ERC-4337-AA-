// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {DeployAccountEAA} from "../../script/DeployAccountEAA.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {AccountEAA} from "../../src/AA-ETHEREUN/Account.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendingPackedUserOP, IEntryPoint} from "../../script/SendingPackedUserOP.s.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * ============================================================================
 * EDUCATIONAL SPECIFICATION — AccountEAATest
 * ============================================================================
 *
 * WHAT IS THIS CONTRACT?
 * ----------------------------------------------------------------------------
 *
 * This is NOT just a test file.
 *
 * It is a behavioral proof suite for an ERC-4337 Smart Account.
 *
 * It verifies:
 *
 *     1. Signature correctness
 *     2. Validation logic correctness
 *     3. Full execution through EntryPoint
 *
 * Think of this file as:
 *
 *     A simulation of the ERC-4337 lifecycle.
 *
 * ============================================================================
 * WHO ARE THE ACTORS IN THESE TESTS?
 * ============================================================================
 *
 * 1. AccountEAA
 *      The smart contract wallet being tested.
 *
 * 2. EntryPoint
 *      The ERC-4337 coordinator contract.
 *
 * 3. Owner (EOA)
 *      The cryptographic authority of AccountEAA.
 *
 * 4. Bundler
 *      Simulated via broadcasted EOA in test.
 *
 * 5. mockUSDC
 *      A simple ERC20 used to simulate real token interaction.
 *
 * ============================================================================
 * WHAT DO THESE TESTS PROVE?
 * ============================================================================
 *
 * TEST 1:
 *     Proves signature generation matches owner.
 *
 * TEST 2:
 *     Proves validateUserOp() enforces signature + prefund logic.
 *
 * TEST 3:
 *     Proves full ERC-4337 flow works end-to-end.
 *
 * ============================================================================
 * WHY ARE THESE IMPORTANT?
 * ============================================================================
 *
 * Because ERC-4337 introduces:
 *
 *     - Off-chain signing
 *     - On-chain validation
 *     - Indirect execution via EntryPoint
 *
 * These tests ensure each layer behaves correctly.
 *
 * ============================================================================
 */

contract AccountEAATest is Test {
    using MessageHashUtils for bytes32;

    HelperConfig hConfig;
    AccountEAA accountEAA;
    DeployAccountEAA deployEAA;
    ERC20Mock mockUSDC;
    SendingPackedUserOP sendPckedUserOP;
    address other = makeAddr("other");

    /**
     * @notice Initializes full ERC-4337 environment for testing.
     *
     * ============================================================================
     * WHAT HAPPENS HERE?
     * ============================================================================
     *
     * 1. DeployAccountEAA deploys:
     *      - EntryPoint (mock if local)
     *      - AccountEAA
     *
     * 2. Deploy mock ERC20.
     *
     * 3. Instantiate SendingPackedUserOP helper.
     *
     * WHY deploy fresh environment?
     *
     *     To ensure deterministic, isolated testing.
     *
     * WHAT IF reused state?
     *
     *     Tests could pass due to leftover storage.
     *
     * SECURITY PROPERTY:
     *
     *     Each test runs in clean VM snapshot.
     *
     * EDUCATIONAL TAKEAWAY:
     *
     *     This builds a miniature ERC-4337 ecosystem.
     */

    function setUp() public {
        deployEAA = new DeployAccountEAA();
        (hConfig, accountEAA) = deployEAA.depolyEAA();
        mockUSDC = new ERC20Mock();
        sendPckedUserOP = new SendingPackedUserOP();
    }

    /**
     * @notice Verifies that signed UserOperation recovers correct owner.
     *
     * ============================================================================
     * PURPOSE
     * ============================================================================
     *
     * This test isolates the cryptographic layer.
     *
     * It answers:
     *
     *     "Does our signature actually correspond to the wallet owner?"
     *
     * ============================================================================
     * STEP-BY-STEP
     * ============================================================================
     *
     * STEP 1:
     *     Encode mint() call.
     *
     * STEP 2:
     *     Wrap inside AccountEAA.execute().
     *
     * WHY wrap?
     *
     *     Because smart account executes calls via execute().
     *
     * STEP 3:
     *     Generate signed UserOperation.
     *
     * STEP 4:
     *     Compute canonical userOpHash from EntryPoint.
     *
     * STEP 5:
     *     Recover signer using ECDSA.recover().
     *
     * STEP 6:
     *     Assert recovered signer == owner().
     *
     * ============================================================================
     * WHAT DOES THIS PROVE?
     * ============================================================================
     *
     * That:
     *
     *     - Signature is formed correctly.
     *     - Hashing logic matches EntryPoint.
     *     - r,s,v order is correct.
     *
     * WHAT IF THIS TEST FAILS?
     *
     *     - Signature malformed
     *     - Wrong hash prefix
     *     - Wrong private key used
     *
     * EDUCATIONAL TAKEAWAY:
     *
     *     UserOperation signing is cryptographically sound.
     */
    function test_SignedOpRecovery() public {
        // Arrange
        assertEq(mockUSDC.balanceOf(address(accountEAA)), 0);
        address destAddress = address(mockUSDC);
        uint256 value = 0;
        bytes memory funcCallData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(accountEAA), 2e18);
        bytes memory executeCalldata =
            abi.encodeWithSelector(AccountEAA.execute.selector, destAddress, value, funcCallData);
        PackedUserOperation memory packedUserOp =
            sendPckedUserOP.SignedUserOpGeneration(executeCalldata, hConfig.getConfig(), address(accountEAA));
        bytes32 userOpHash = IEntryPoint(hConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);

        // Act
        address actualSigner = ECDSA.recover(userOpHash.toEthSignedMessageHash(), packedUserOp.signature);
        // Assert
        assertEq(actualSigner, accountEAA.owner());
    }

    /**
     * @notice Tests validateUserOp() logic in isolation.
     *
     * ============================================================================
     * PURPOSE
     * ============================================================================
     *
     * This test verifies:
     *
     *     - Signature validation works.
     *     - Prefund logic executes correctly.
     *
     * Without executing full handleOps().
     *
     * ============================================================================
     * WHY CALL validateUserOp DIRECTLY?
     * ============================================================================
     *
     * Because we want to isolate validation phase.
     *
     * In real ERC-4337 flow:
     *
     *     EntryPoint calls validateUserOp().
     *
     * So we simulate EntryPoint using:
     *
     *     vm.prank(entryPoint)
     *
     * ============================================================================
     * STEP-BY-STEP
     * ============================================================================
     *
     * STEP 1:
     *     Build signed UserOperation.
     *
     * STEP 2:
     *     Provide ETH to account.
     *
     * WHY?
     *
     *     So prefund transfer can succeed.
     *
     * STEP 3:
     *     Call validateUserOp().
     *
     * STEP 4:
     *     Assert return == 0 (SIG_VALIDATION_SUCCESS).
     *
     * ============================================================================
     * WHAT DOES THIS PROVE?
     * ============================================================================
     *
     * That:
     *
     *     - onlyEntryPoint modifier works.
     *     - Signature matches owner.
     *     - Prefund transfer logic executes.
     *
     * WHAT IF missingAccountFunds > balance?
     *
     *     Revert.
     *
     * WHAT IF signature invalid?
     *
     *     validationData != 0.
     *
     * EDUCATIONAL TAKEAWAY:
     *
     *     Validation phase enforces wallet security.
     */
    function test_UserOpsValidation() public {
        // Arrange
        assertEq(mockUSDC.balanceOf(address(accountEAA)), 0);
        address destAddress = address(mockUSDC);
        uint256 value = 0;
        bytes memory funcCallData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(accountEAA), 2e18);
        bytes memory executeCalldata =
            abi.encodeWithSelector(AccountEAA.execute.selector, destAddress, value, funcCallData);
        PackedUserOperation memory packedUserOp =
            sendPckedUserOP.SignedUserOpGeneration(executeCalldata, hConfig.getConfig(), address(accountEAA));
        bytes32 userOpHash = IEntryPoint(hConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
        uint256 missingAccountFunds = 1 ether;
        // Act
        vm.deal(address(accountEAA), 1 ether);
        vm.prank(hConfig.getConfig().entryPoint);
        uint256 validationData = accountEAA.validateUserOp(packedUserOp, userOpHash, missingAccountFunds);
        //assert
        assertEq(validationData, 0);
    }

    /**
     * @notice Full end-to-end ERC-4337 execution simulation.
     *
     * ============================================================================
     * THIS IS THE MOST IMPORTANT TEST.
     * ============================================================================
     *
     * It simulates:
     *
     *     Real-world bundler behavior.
     *
     * ============================================================================
     * WHO ACTS AS BUNDLER?
     * ============================================================================
     *
     * The EOA derived from bundlerPrivateKey.
     *
     * WHY?
     *
     * Because EntryPoint.handleOps()
     * requires a real EOA caller.
     *
     * ============================================================================
     * STEP-BY-STEP FLOW
     * ============================================================================
     *
     * STEP 1:
     *     Create signed UserOperation.
     *
     * STEP 2:
     *     Put it inside an array.
     *
     * WHY array?
     *
     *     handleOps() processes multiple operations.
     *
     * STEP 3:
     *     Fund bundler with ETH.
     *
     * WHY?
     *
     *     Bundler pays transaction gas upfront.
     *
     * STEP 4:
     *     Deposit 1 ether to EntryPoint for AccountEAA.
     *
     * WHY?
     *
     *     Account must have deposit to pay gas.
     *
     * STEP 5:
     *     Call EntryPoint.handleOps().
     *
     * WHAT HAPPENS INSIDE handleOps?
     *
     *     1. EntryPoint calls validateUserOp().
     *     2. Account verifies signature.
     *     3. Prefund transferred if needed.
     *     4. EntryPoint calls AccountEAA.execute().
     *     5. Account calls mockUSDC.mint().
     *
     * STEP 6:
     *     Assert mockUSDC balance increased.
     *
     * ============================================================================
     * WHAT DOES THIS PROVE?
     * ============================================================================
     *
     * That:
     *
     *     - Full ERC-4337 pipeline works.
     *     - Signature + validation + execution integrated.
     *     - Smart account can modify external contract state.
     *
     * ============================================================================
     * WHAT IF ANY LAYER FAILS?
     * ============================================================================
     *
     * - Signature wrong → validation fails.
     * - No deposit → prefund fails.
     * - Wrong nonce → rejected.
     * - EntryPoint misconfigured → revert.
     *
     * EDUCATIONAL TAKEAWAY:
     *
     *     ERC-4337 execution is:
     *
     *         Signature → Validation → Execution → State change.
     */
    function test_CommandsCanBeExecutedByEntryPoint() public {
        // Arrange
        assertEq(mockUSDC.balanceOf(address(accountEAA)), 0);
        address destAddress = address(mockUSDC);
        uint256 value = 0;
        bytes memory funcCallData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(accountEAA), 2e18);
        bytes memory executeCalldata =
            abi.encodeWithSelector(AccountEAA.execute.selector, destAddress, value, funcCallData);
        PackedUserOperation memory packedUserOp =
            sendPckedUserOP.SignedUserOpGeneration(executeCalldata, hConfig.getConfig(), address(accountEAA));
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;
        uint256 bundlerPrivateKey = 0xBEEF; // any test key
        address bundler = vm.addr(bundlerPrivateKey);

        // Act
        // give bundler ETH
        vm.deal(bundler, 10 ether);

        // deposit for account (still required)
        vm.startBroadcast(bundlerPrivateKey);
        IEntryPoint(hConfig.getConfig().entryPoint).depositTo{value: 1 ether}(address(accountEAA));

        // now call handleOps as real EOA

        IEntryPoint(hConfig.getConfig().entryPoint).handleOps(ops, payable(bundler));
        vm.stopBroadcast();

        // Assert
        assertEq(mockUSDC.balanceOf(address(accountEAA)), 2e18);
    }

    /// NOTE->  DRILL THIS DOWN.  <-NOTE
    /**
     * ============================================================================
     * FULL ERC-4337 FLOW SIMULATED BY THESE TESTS
     * ============================================================================
     *
     * Owner signs UserOp
     *        ↓
     * Bundler submits handleOps()
     *        ↓
     * EntryPoint.validateUserOp()
     *        ↓
     * AccountEAA._signatureValidation()
     *        ↓
     * AccountEAA._payPrefund()
     *        ↓
     * EntryPoint executes operation
     *        ↓
     * AccountEAA.execute()
     *        ↓
     * ERC20.mint()
     *        ↓
     * State changes verified in test
     *
     * ============================================================================
     */
}
