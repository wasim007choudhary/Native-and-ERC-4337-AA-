// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {AccountZKAA} from "../../src/AA-ZKSYNC/AccountZKAA.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {
    Transaction,
    MemoryTransactionHelper
} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {BOOTLOADER_FORMAL_ADDRESS} from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {
    ACCOUNT_VALIDATION_SUCCESS_MAGIC
} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

contract AccountZKAATest is Test {
    AccountZKAA aZKAA;
    ERC20Mock usdcMock;

    bytes32 constant BYTES32_EMPTY = bytes32(0);

    //A note here sisnce this will only run locally and not on actual network as zk sync doesnt support scripting with the zksync, and thus we can drop off the account prama in hte arg and thus will be owned by the anvil deafult key, the anvil deafult user
    uint256 constant ANVIL_DEFAULT_PKEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    address user = makeAddr("user");

    function setUp() public {
        aZKAA = new AccountZKAA();
        aZKAA.transferOwnership(ANVIL_DEFAULT_ACCOUNT);
        usdcMock = new ERC20Mock();
        vm.deal(address(aZKAA), 5e18);
    }

    function testZKcommandsCanBeExecutedByOwner() public {
        //arrange
        address to = address(usdcMock);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(aZKAA), 5e18);

        Transaction memory transaction = _unsignedTransactionCreation(aZKAA.owner(), 113, to, value, funcData);

        //act
        vm.prank(aZKAA.owner());
        aZKAA.executeTransaction(BYTES32_EMPTY, BYTES32_EMPTY, transaction);

        //assert
        assertEq(usdcMock.balanceOf(address(aZKAA)), 5e18);
    }

    function testZKcommandsCannotExecutedIfNotOwnerOrBootloader() public {
        //arrange
        address to = address(usdcMock);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(aZKAA), 5e18);

        Transaction memory transaction = _unsignedTransactionCreation(aZKAA.owner(), 113, to, value, funcData);
        //act and revert
        vm.prank(user);
        vm.expectRevert(AccountZKAA.AccountZKAA___modifier_onlyByBootloaderOrByOwner__InvalidCaller.selector);
        aZKAA.executeTransaction(BYTES32_EMPTY, BYTES32_EMPTY, transaction);
    }

    function testZKfunctionValidateTransaction() public {
        //arrange
        address to = address(usdcMock);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(aZKAA), 5e18);
        Transaction memory transaction = _unsignedTransactionCreation(aZKAA.owner(), 113, to, value, funcData);
        transaction = transactionSigning(transaction);

        console.log("transaction signature: ");
        console.logBytes(transaction.signature);

        //Act
        vm.prank(BOOTLOADER_FORMAL_ADDRESS);
        bytes4 magic = aZKAA.validateTransaction(BYTES32_EMPTY, BYTES32_EMPTY, transaction);

        //ASSert
        assertEq(magic, ACCOUNT_VALIDATION_SUCCESS_MAGIC);
    }

    /////////////////////////////////////////////////////////////////////////
    //.                    HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////////////////
    function _unsignedTransactionCreation(
        address from,
        uint8 transactionType,
        address to,
        uint256 value,
        bytes memory data
    ) internal view returns (Transaction memory) {
        uint256 nonce = vm.getNonce(address(aZKAA));
        bytes32[] memory factoryDeps = new bytes32[](0);

        return Transaction({
            txType: transactionType, // we can do anytype but here will will do 113 (i.e. 0x71)
            from: uint256(uint160(from)),
            to: uint256(uint160(to)),
            gasLimit: 15000000,
            gasPerPubdataByteLimit: 15000000,
            maxFeePerGas: 15000000,
            maxPriorityFeePerGas: 15000000,
            paymaster: 0,
            nonce: nonce,
            value: value,
            reserved: [uint256(0), uint256(0), uint256(0), uint256(0)],
            data: data,
            signature: hex"",
            factoryDeps: factoryDeps,
            paymasterInput: hex"",
            reservedDynamic: hex""
        });
    }

    function transactionSigning(
        Transaction memory transaction /*, address account */
    )
        internal
        view
        returns (Transaction memory)
    {
        bytes32 unsignedTransactionHash = MemoryTransactionHelper.encodeHash(transaction);
        // bytes digest = MessageHashUtils.toEthSignedMessageHash(unsignedTransactionHash); // we dont need this as zk-native AA usually signs the raw transaction hash. Only if: Your frontend explicitly uses signMessage(...) Or calls personal_sign , Then yes — you'd need:

        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(ANVIL_DEFAULT_PKEY, unsignedTransactionHash);
        Transaction memory signedTransaction = transaction;
        signedTransaction.signature = abi.encodePacked(r, s, v);
        return signedTransaction;
    }
}
