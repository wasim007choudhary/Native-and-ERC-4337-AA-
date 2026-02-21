// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "./HelperConfig.sol";
import {AccountEAA} from "../src/AA-ETHEREUN/Account.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

/**
 * ============================================================================
 * EDUCATIONAL SPECIFICATION — SendingPackedUserOP
 * ============================================================================
 *
 * WHAT IS THIS CONTRACT?
 * ----------------------------------------------------------------------------
 *
 * This is NOT a wallet.
 * This is NOT a bundler.
 * This is NOT infrastructure.
 *
 * This is a Foundry Script designed for understanding ERC-4337.
 *
 * It simulates the full lifecycle of a UserOperation:
 *
 *     1. Construct intent
 *     2. Wrap intent inside smart account call
 *     3. Create UserOperation struct
 *     4. Sign the operation
 *     5. Submit to EntryPoint
 *
 * Think of this as a “manual transmission simulator”
 * for understanding how Account Abstraction works.
 *
 * ============================================================================
 * WHO ARE THE ACTORS IN THIS SCRIPT?
 * ============================================================================
 *
 * 1. HUMAN (You)
 *      You decide the action (approve token).
 *
 * 2. ACCOUNT OWNER (EOA private key)
 *      Signs the UserOperation.
 *
 * 3. AccountEAA (Smart Account)
 *      Executes the action.
 *
 * 4. EntryPoint (ERC-4337 Coordinator)
 *      Validates and executes.
 *
 * 5. Bundler
 *      In this script, the broadcasted EOA acts as bundler.
 *
 * ============================================================================
 * WHY DOES THIS SCRIPT EXIST?
 * ============================================================================
 *
 * Because ERC-4337 does NOT use normal transactions.
 *
 * Instead of:
 *
 *      EOA → direct transaction
 *
 * We have:
 *
 *      EOA signs → UserOperation → EntryPoint → Smart Account
 *
 * This script lets you see that entire pipeline explicitly.
 *
 * ============================================================================
 * WHAT WOULD HAPPEN WITHOUT THIS SCRIPT?
 * ============================================================================
 *
 * You would need:
 *      - A frontend
 *      - A bundler service
 *      - A signing client
 *      - Gas estimation logic
 *
 * This script compresses that stack into one educational file.
 *
 * ============================================================================
 */
contract SendingPackedUserOP is Script {
    using MessageHashUtils for bytes32;

    /*//////////////////////////////////////////////////////////////
                               State Variables
    //////////////////////////////////////////////////////////////*/
    address constant APPROVER = 0x708FCA42c433dFf7e6CcA886137aC8cA3985193d; // Dont use this address on mainnets, this my test dummy type wallet. For
    uint256 constant APV_AMOUNT = 1e18;

    /*//////////////////////////////////////////////////////////////
                               functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Executes full ERC-4337 operation lifecycle for demonstration.
     *
     * ============================================================================
     * WHAT DOES THIS FUNCTION DO?
     * ============================================================================
     *
     * It performs a complete UserOperation from scratch.
     *
     * Specifically:
     *
     *     "Approve a spender to spend tokens from AccountEAA."
     *
     * But instead of sending a normal transaction,
     * it builds and submits a UserOperation.
     *
     * ============================================================================
     * STEP-BY-STEP EXPLANATION
     * ============================================================================
     *
     * STEP 1 — Load Network Configuration
     *
     * WHY?
     *     Because EntryPoint address changes per network.
     *
     * WHAT IF wrong EntryPoint?
     *     Operation fails or funds risked.
     *
     *
     * STEP 2 — Locate Deployed AccountEAA
     *
     * WHY?
     *     We must know which smart account executes the call.
     *
     * WHAT IF wrong address?
     *     Signature mismatch → validation fails.
     *
     *
     * STEP 3 — Encode ERC20 approve()
     *
     * WHY encode?
     *     Smart contracts do not understand function names.
     *     They only understand ABI-encoded bytes.
     *
     *
     * STEP 4 — Wrap inside AccountEAA.execute()
     *
     * WHY?
     *     Because AccountEAA is the executor.
     *     It must call external contracts via execute().
     *
     *
     * STEP 5 — Construct Signed UserOperation
     *
     * WHY?
     *     EntryPoint only accepts PackedUserOperation structs.
     *
     *
     * STEP 6 — Submit to EntryPoint.handleOps()
     *
     * WHY handleOps?
     *     EntryPoint batches and processes UserOperations.
     *
     *
     * ============================================================================
     * WHO PAYS GAS?
     * ============================================================================
     *
     * The AccountEAA deposit inside EntryPoint.
     *
     * The broadcasting EOA here acts as bundler.
     *
     *
     * ============================================================================
     * WHAT IF SOMETHING FAILS?
     * ============================================================================
     *
     * - Wrong nonce → rejected.
     * - Invalid signature → rejected.
     * - Insufficient deposit → rejected.
     * - Incorrect gas values → rejected.
     *
     *
     * ============================================================================
     * EDUCATIONAL TAKEAWAY
     * ============================================================================
     *
     * This function shows that:
     *
     *     A UserOperation is not magic.
     *
     * It is simply:
     *
     *     A struct + signature + EntryPoint execution.
     */
    function run() public {
        HelperConfig hConfig = new HelperConfig();
        address destAddress = hConfig.getConfig().usdcAddress; // the usdc address of the deployed chain , see helper config to understant
        uint256 value = 0;
        address accountEAAAddress = DevOpsTools.get_most_recent_deployment("AccountEAA", block.chainid);

        bytes memory funcCallData = abi.encodeWithSelector(IERC20.approve.selector, APPROVER, APV_AMOUNT);

        bytes memory executeCallData =
            abi.encodeWithSelector(AccountEAA.execute.selector, destAddress, value, funcCallData);

        PackedUserOperation memory packedUserOp =
            SignedUserOpGeneration(executeCallData, hConfig.getConfig(), accountEAAAddress);

        PackedUserOperation[] memory Ops = new PackedUserOperation[](1);
        Ops[0] = packedUserOp;

        vm.startBroadcast();
        IEntryPoint(hConfig.getConfig().entryPoint).handleOps(Ops, payable(hConfig.getConfig().accountAddress));
        vm.stopBroadcast();
    }

    /**
     * @notice Creates and signs a complete UserOperation.
     *
     * @param callData Encoded AccountEAA.execute() call.
     * @param nConfig Network configuration.
     * @param accountEAA Smart account address.
     *
     * @return PackedUserOperation Fully signed operation.
     *
     * ============================================================================
     * WHY IS THIS FUNCTION NECESSARY?
     * ============================================================================
     *
     * Because EntryPoint will NOT accept:
     *
     *     - Plain function calls
     *     - Raw transactions
     *
     * It ONLY accepts:
     *
     *     PackedUserOperation structs.
     *
     *
     * ============================================================================
     * STEP 1 — Fetch Nonce
     * ============================================================================
     *
     * WHY fetch from EntryPoint?
     *
     * Because ERC-4337 nonces are stored inside EntryPoint,
     * not inside the smart account.
     *
     * WHAT IF wrong nonce?
     *     EntryPoint rejects operation.
     *
     *
     * ============================================================================
     * STEP 2 — Build Unsigned Operation
     * ============================================================================
     *
     * WHY separate unsigned?
     *
     * Because signature must be computed
     * over the final exact struct values.
     *
     *
     * ============================================================================
     * STEP 3 — Compute userOpHash
     * ============================================================================
     *
     * WHY not hash locally?
     *
     * Because ERC-4337 defines EntryPoint as
     * canonical hashing authority.
     *
     * This prevents:
     *     Cross-chain replay
     *     Cross-EntryPoint replay
     *
     *
     * ============================================================================
     * STEP 4 — Sign Hash
     * ============================================================================
     *
     * WHY convert to Ethereum Signed Message?
     *
     * To prevent misuse of raw transaction hashes.
     *
     *
     * WHAT IF signature incorrect?
     *
     * AccountEAA.validateUserOp() returns failure.
     *
     *
     * ============================================================================
     * CRITICAL SIGNATURE ORDER
     * ============================================================================
     *
     * abi.encodePacked(r, s, v)
     *
     * WHY this order?
     *
     * Because ECDSA.recover expects (r,s,v).
     *
     * Changing order breaks validation.
     *
     *
     * ============================================================================
     * EDUCATIONAL TAKEAWAY
     * ============================================================================
     *
     * Signing a UserOperation is conceptually identical to:
     *
     *     Signing a normal Ethereum transaction.
     *
     * Except:
     *
     *     It signs a struct instead of a tx.
     */
    function SignedUserOpGeneration(
        bytes memory callData,
        HelperConfig.NetworkConfig memory nConfig,
        address accountEAA
    ) public view returns (PackedUserOperation memory) {
        uint256 nonce = IEntryPoint(nConfig.entryPoint).getNonce(accountEAA, 0);
        PackedUserOperation memory userOp = UnsignedUserOpGeneration(callData, accountEAA, nonce);

        bytes32 userOpHash = IEntryPoint(nConfig.entryPoint).getUserOpHash(userOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash();
        uint256 DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        uint8 v;
        bytes32 r;
        bytes32 s;

        if (block.chainid == 31337) {
            (v, r, s) = vm.sign(DEFAULT_ANVIL_PRIVATE_KEY, digest);
        } else {
            (v, r, s) = vm.sign(nConfig.accountAddress, digest);
        }
        userOp.signature = abi.encodePacked(r, s, v); // will cause error if order is changed!
        return userOp;
    }

    /**
     * @notice Builds base UserOperation before signing.
     *
     * @param callData Encoded execute() call.
     * @param sender Smart account address.
     * @param nonce EntryPoint nonce.
     *
     * @return PackedUserOperation Unsigned struct.
     *
     * ============================================================================
     * WHAT IS A UserOperation REALLY?
     * ============================================================================
     *
     * It is a data packet describing:
     *
     *     WHO executes
     *     WHAT is executed
     *     HOW MUCH gas is allowed
     *     HOW MUCH gas is paid
     *     OPTIONAL paymaster sponsorship
     *
     *
     * ============================================================================
     * WHY initCode IS EMPTY?
     * ============================================================================
     *
     * Because account already exists.
     *
     * initCode is used only for counterfactual deployment.
     *
     *
     * ============================================================================
     * WHY PACK GAS INTO bytes32?
     * ============================================================================
     *
     * ERC-4337 specification packs:
     *
     *     verificationGasLimit (upper 128 bits)
     *     callGasLimit         (lower 128 bits)
     *
     * WHY?
     *
     * To reduce calldata size.
     *
     *
     * ============================================================================
     * WHAT IF GAS LIMITS WRONG?
     * ============================================================================
     *
     * Too low:
     *     Execution reverts.
     *
     * Too high:
     *     Unnecessary deposit locked.
     *
     *
     * ============================================================================
     * WHY paymasterAndData EMPTY?
     * ============================================================================
     *
     * Because this script uses no gas sponsor.
     *
     * Account pays its own gas.
     *
     *
     * ============================================================================
     * EDUCATIONAL TAKEAWAY
     * ============================================================================
     *
     * A UserOperation is not mysterious.
     *
     * It is a structured transaction envelope.
     */
    function UnsignedUserOpGeneration(bytes memory callData, address sender, uint256 nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        uint128 gasLimitForVerification = 150000000;
        uint128 gasLimitForCall = gasLimitForVerification; //  or 150000000 but gasLimitForVerification better for me !
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeesPerGas = maxPriorityFeePerGas;
        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"", // ignoring init code for now
            callData: callData,
            accountGasLimits: bytes32(uint256(gasLimitForVerification) << 128 | gasLimitForCall),
            preVerificationGas: gasLimitForVerification,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeesPerGas),
            paymasterAndData: hex"", // ignoring paymaster for now
            signature: hex"" // signature will be added later
        });
    }
}
