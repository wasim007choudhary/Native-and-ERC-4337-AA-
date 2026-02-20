// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {DeployAccountEAA} from "../../script/DeployAccountEAA.sol";
import {HelperConfig} from "../../script/HelperConfig.sol";
import {AccountEAA} from "../../src/AA-ETHEREUN/Account.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendingPackedUserOP, IEntryPoint} from "../../script/SendingPackedUserOP.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

contract AccountEAATest is Test {
    using MessageHashUtils for bytes32;

    HelperConfig hConfig;
    AccountEAA accountEAA;
    DeployAccountEAA deployEAA;
    ERC20Mock mockUSDC;
    SendingPackedUserOP sendPckedUserOP;
    address other = makeAddr("other");

    function setUp() public {
        deployEAA = new DeployAccountEAA();
        (hConfig, accountEAA) = deployEAA.depolyEAA();
        mockUSDC = new ERC20Mock();
        sendPckedUserOP = new SendingPackedUserOP();
    }

    function test_OwnerCanExecuteCommands() public {
        assertEq(mockUSDC.balanceOf(address(accountEAA)), 0);

        address destAddress = address(mockUSDC);
        uint256 value = 0;
        bytes memory funcCallData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(accountEAA), 2e18);

        vm.prank(accountEAA.owner());
        accountEAA.execute(destAddress, value, funcCallData);
        console.log("USDC balance of accountEAA after minting:", mockUSDC.balanceOf(address(accountEAA)));
        assertEq(mockUSDC.balanceOf(address(accountEAA)), 2e18);
        bytes memory funcCalldata2 = abi.encodeWithSelector(ERC20Mock.ttransfer.selector, other, 1e18);
        vm.prank(accountEAA.owner());
        accountEAA.execute(destAddress, value, funcCalldata2);
        console.log("USDC balance of accountEAA after transfer:", mockUSDC.balanceOf(address(accountEAA)));
        console.log("USDC balance of other after receiving transfer:", mockUSDC.balanceOf(other));
        assertEq(mockUSDC.balanceOf(address(accountEAA)), 1e18);
        assertEq(mockUSDC.balanceOf(other), 1e18);
    }

    function test_CannotExecuteIfNotOwnerOrEntryPoint() public {
        assertEq(mockUSDC.balanceOf(address(accountEAA)), 0);

        address destAddress = address(mockUSDC);
        uint256 value = 0;
        bytes memory funcCallData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(accountEAA), 2e18);

        vm.prank(other);

        vm.expectRevert(AccountEAA.AccountEAA___Modifier__CallNotFromOwnerOrEntryPoint.selector);
        accountEAA.execute(destAddress, value, funcCallData);
    }

    function test_SignedOpRecovery() public {
        assertEq(mockUSDC.balanceOf(address(accountEAA)), 0);
        address destAddress = address(mockUSDC);
        uint256 value = 0;
        bytes memory funcCallData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(accountEAA), 2e18);
        bytes memory executeCalldata =
            abi.encodeWithSelector(AccountEAA.execute.selector, destAddress, value, funcCallData);
        PackedUserOperation memory packedUserOp =
            sendPckedUserOP.SignedUserOpGeneration(executeCalldata, hConfig.getConfig(), address(accountEAA));
        bytes32 userOpHash = IEntryPoint(hConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);

        address actualSigner = ECDSA.recover(userOpHash.toEthSignedMessageHash(), packedUserOp.signature);
        assertEq(actualSigner, accountEAA.owner());
    }

    function test_UserOpsValidation() public {
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
        vm.deal(address(accountEAA), 1 ether);
        vm.prank(hConfig.getConfig().entryPoint);
        uint256 validationData = accountEAA.validateUserOp(packedUserOp, userOpHash, missingAccountFunds);
        assertEq(validationData, 0);
    }

    function test_CommandsCanBeExecutedByEntryPoint() public {
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

        // give bundler ETH
        vm.deal(bundler, 10 ether);

        // deposit for account (still required)
        vm.startBroadcast(bundlerPrivateKey);
        IEntryPoint(hConfig.getConfig().entryPoint).depositTo{value: 1 ether}(address(accountEAA));

        // now call handleOps as real EOA

        IEntryPoint(hConfig.getConfig().entryPoint).handleOps(ops, payable(bundler));
        vm.stopBroadcast();

        assertEq(mockUSDC.balanceOf(address(accountEAA)), 2e18);
    }
}
