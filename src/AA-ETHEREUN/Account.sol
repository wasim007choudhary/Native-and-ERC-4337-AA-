// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/*////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                     IMPORTS
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
/**
 * @title AA PackedUserOperation struct explanation -
 * 1. address sender
 *
 * Purpose: This field specifies the address of the smart contract account that intends to execute the operation. It is the account being controlled by this UserOperation.
 *
 * Significance: In the context of account abstraction, this sender is not an Externally Owned Account (EOA) but rather a smart contract wallet, such as our AccountEAA contract example. This is the account that will ultimately perform the desired action.
 *
 * 2. uint256 nonce
 *
 * Purpose: The nonce is a unique, sequential number used by the sender account to prevent replay attacks. Each UserOperation must have a unique nonce to ensure it's processed only once.
 *
 * Significance: Similar to the nonce used by EOAs to order transactions, this field ensures that malicious actors cannot resubmit a previously executed UserOperation. It acts as a sequence number for operations originating from the smart contract account, ensuring ordered and unique execution.
 *
 * 3. bytes initCode
 *
 * Purpose: This field contains the bytecode necessary to deploy the sender smart contract account if it does not already exist. It typically includes the factory contract address and the constructor arguments for the new account.
 *
 * Significance: If the sender account already exists on the blockchain, initCode will be empty. This mechanism allows for counterfactual account deployment, where an account address can be determined and funded before its actual deployment. For scenarios dealing with already deployed accounts, this field can often be set to empty bytes.
 *
 * 4. bytes callData
 *
 * Purpose: This is the core of the UserOperation, containing the actual instruction set for the sender account to execute. It usually consists of a function selector and ABI-encoded arguments for a function call.
 *
 * Significance: This field dictates what action the smart contract account will perform. For example, it could specify a call to the approve function on a token contract for a certain number of tokens, a transfer of assets, or any other interaction with the blockchain. This is effectively the "payload" or "intent" of the transaction.
 *
 * 5. bytes32 accountGasLimits
 *
 * Purpose: This field contains packed gas limits relevant to the execution of the UserOperation by the account. It typically bundles verificationGasLimit (gas allocated for the validateUserOp function) and callGasLimit (gas allocated for executing the callData).
 *
 * Significance: Proper gas limit specification is crucial for ensuring the UserOperation can be processed without running out of gas during its validation or execution phases. These are the gas limits directly associated with the smart contract account's operations.
 *
 * 6. uint256 preVerificationGas
 *
 * Purpose: This value represents the gas cost incurred before the validateUserOp function is called by the EntryPoint contract. It covers overheads like hashing the UserOperation, SLOADs from storage to fetch account nonces or check for existing deployments, and other preparatory steps performed by the bundler or EntryPoint.
 *
 * Significance: It ensures that the bundler (the entity submitting the UserOperation to the EntryPoint) is compensated for these preliminary gas expenses, which are not part of the validateUserOp or the main execution call.
 *
 * 7. bytes32 gasFees
 *
 * Purpose: This field holds packed gas fee parameters, specifically maxFeePerGas and maxPriorityFeePerGas. These are analogous to the EIP-1559 gas parameters for standard Ethereum transactions.
 *
 * Significance: It allows the user to specify their willingness to pay for gas, influencing how quickly their UserOperation is picked up by bundlers and included in a block. These parameters manage the different gas fees associated with the transaction.
 *
 * 8. bytes paymasterAndData
 *
 * Purpose: If a Paymaster is sponsoring the transaction (i.e., paying the gas fees on behalf of the user), this field contains the Paymaster's contract address and any additional data the Paymaster requires for its own validation logic (e.g., a signature from the user authorizing the Paymaster).
 *
 * Significance: This field is key to enabling gas abstraction. By default, the sender account must have sufficient funds to cover gas costs. However, with a Paymaster, a third party can cover these fees, meaning the user's smart contract account might not need to hold native currency. If no Paymaster is used, this field remains empty.
 *
 * 9. bytes signature
 *
 * Purpose: This field contains the cryptographic signature that authenticates the UserOperation. The sender account's validateUserOp function is responsible for verifying this signature against a userOpHash. The userOpHash is a hash of the PackedUserOperation's fields, the EntryPoint contract's address, and the current chain ID.
 *
 * Significance: This is a critical security component. It proves that the owner of the sender account has authorized this specific operation. Account abstraction allows for flexible signature schemes beyond the standard ECDSA used by EOAs. The validateUserOp function in the smart contract account will implement custom logic to determine what constitutes a valid signature (e.g., multi-sig, social recovery mechanisms, passkeys, etc.). The inclusion of the EntryPoint address and chain ID in the signed data is crucial for preventing replay attacks across different chains or different EntryPoint contract implementations.
 *
 */

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SIG_VALIDATION_SUCCESS, SIG_VALIDATION_FAILED} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract AccountEAA is IAccount, Ownable {
    /*////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                         ERRORS
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    error AccountEAA___Modifer__CallNotFromEntryPoint();
    error AccountEAA___Modifier__CallNotFromOwnerOrEntryPoint();
    error AccountEAA___Execute__CallFailed(bytes);
    error AccountEAA___PayPreFun__NotSuccessful();
    /*////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                         STATE VARIABLES
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    IEntryPoint private immutable i_entryPoint;

    /*////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                         MODIFIERS
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    modifier onlyEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert AccountEAA___Modifer__CallNotFromEntryPoint();
        }
        _;
    }

    modifier onlyOwnerOrEntryPoint() {
        if (msg.sender != owner() && msg.sender != address(i_entryPoint)) {
            revert AccountEAA___Modifier__CallNotFromOwnerOrEntryPoint();
        }
        _;
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                         -FUNCTIONS-
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                         RECEIVE FUNCTIONS-
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    receive() external payable {
        // Handle received ETH
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                         EXTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        onlyEntryPoint
        returns (uint256 validationData)
    {
        validationData = _signatureValidation(userOp, userOpHash);
        _payPrefund(missingAccountFunds);
    }

    function execute(address destAddress, uint256 value, bytes calldata abiEncodedFunctionData)
        external
        onlyOwnerOrEntryPoint
    {
        (bool success, bytes memory callResult) = destAddress.call{value: value}(abiEncodedFunctionData);
        if (!success) {
            revert AccountEAA___Execute__CallFailed(callResult);
        }
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                         INTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    function _signatureValidation(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        returns (uint256 validationData)
    {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);
        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }
        return SIG_VALIDATION_SUCCESS;
    }

    function _payPrefund(uint256 missingAccountFunds) internal onlyEntryPoint {
        if (missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");

            if (!success) {
                revert AccountEAA___PayPreFun__NotSuccessful();
            }
        }
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                         GETTERS FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    function getEntryPointAddress() external view returns (address) {
        return address(i_entryPoint);
    }
}
