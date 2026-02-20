// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "./HelperConfig.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

contract SendingPackedUserOP is Script {
    using MessageHashUtils for bytes32;

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/
    function run() public {}

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
        userOp.signature = abi.encodePacked(r, s, v);
        return userOp;
    }

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
