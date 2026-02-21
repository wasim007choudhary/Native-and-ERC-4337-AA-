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

/**
 * ============================================================================
 * FORMAL SPECIFICATION — AccountEAA (ERC-4337 Smart Contract Account)
 * ============================================================================
 *
 * @title AccountEAA
 * @author Wasim Choudhary
 *
 * ============================================================================
 * 1. CONTRACT CLASSIFICATION
 * ============================================================================
 *
 * CONTRACT CATEGORY:
 *     ERC-4337 Compatible Smart Contract Account
 *
 * SPECIFICATION TARGET:
 *     ERC-4337 EntryPoint (v0.6+ interface)
 *
 * INTERFACE IMPLEMENTED:
 *     IAccount (as defined by ERC-4337 reference implementation)
 *
 * PURPOSE:
 *     This contract implements a minimal programmable smart contract wallet
 *     that complies with ERC-4337 Account Abstraction standards.
 *
 * ============================================================================
 * 2. SYSTEM OVERVIEW
 * ============================================================================
 *
 * This contract represents a programmable Ethereum wallet that:
 *
 *     • Holds ETH and ERC-20 tokens
 *     • Executes arbitrary external calls
 *     • Validates off-chain signatures
 *     • Prefunds gas via EntryPoint when required
 *
 * Unlike an Externally Owned Account (EOA):
 *
 *     - It does NOT sign transactions internally.
 *     - It verifies signatures produced off-chain.
 *     - Execution is coordinated through EntryPoint.
 *
 * This design enables Account Abstraction while preserving cryptographic
 * ownership control.
 *
 * ============================================================================
 * 3. ARCHITECTURE ROLE MODEL
 * ============================================================================
 *
 * ROLE: Owner
 *     - Cryptographic authority of the wallet
 *     - Holds private key
 *     - Signs UserOperations off-chain
 *
 * ROLE: EntryPoint
 *     - Trusted execution coordinator defined by ERC-4337
 *     - Calls validateUserOp()
 *     - Executes wallet operations
 *     - Handles gas accounting and bundler payments
 *
 * ROLE: Bundler
 *     - Off-chain relayer
 *     - Collects signed UserOperations
 *     - Submits them to EntryPoint
 *     - Receives gas compensation
 *
 * ============================================================================
 * 4. TRUST ASSUMPTIONS
 * ============================================================================
 *
 * ASSUMPTION A1:
 *     EntryPoint is correctly implemented and non-malicious.
 *
 * WHY?
 *     EntryPoint has authority to:
 *         - Execute wallet calls
 *         - Receive prefunds
 *         - Control nonce validation
 *
 * WHAT IF FALSE?
 *     A malicious EntryPoint could drain wallet funds.
 *
 * MITIGATION:
 *     EntryPoint address is immutable after deployment.
 *
 * ASSUMPTION A2:
 *     Owner private key remains secure.
 *
 * WHY?
 *     Signature validation relies entirely on owner identity.
 *
 * WHAT IF FALSE?
 *     Attacker gains full wallet control.
 *
 * ============================================================================
 * 5. ERC-4337 COMPLIANCE MAPPING
 * ============================================================================
 *
 * REQUIREMENT R1:
 *     Account MUST implement validateUserOp().
 *
 * ✔ Implemented.
 *
 * REQUIREMENT R2:
 *     validateUserOp MUST return validationData.
 *
 * ✔ Returns SIG_VALIDATION_SUCCESS (0) or failure.
 *
 * REQUIREMENT R3:
 *     Account MUST prefund missingAccountFunds.
 *
 * ✔ _payPrefund() transfers required ETH to EntryPoint.
 *
 * REQUIREMENT R4:
 *     Account MUST verify cryptographic signature.
 *
 * ✔ _signatureValidation() recovers signer and compares to owner().
 *
 * REQUIREMENT R5:
 *     Account MUST prevent unauthorized direct execution.
 *
 * ✔ execute() restricted via onlyOwnerOrEntryPoint.
 *
 * REQUIREMENT R6:
 *     Replay protection must exist.
 *
 * ✔ Handled by EntryPoint nonce enforcement.
 *
 * ============================================================================
 * 6. GLOBAL SECURITY INVARIANTS
 * ============================================================================
 *
 * INVARIANT I1:
 *     validateUserOp() callable ONLY by EntryPoint.
 *
 * INVARIANT I2:
 *     execute() callable ONLY by Owner OR EntryPoint.
 *
 * INVARIANT I3:
 *     If signature recovery != owner,
 *     validation MUST fail.
 *
 * INVARIANT I4:
 *     Prefund transfers MUST only go to EntryPoint.
 *
 * INVARIANT I5:
 *     EntryPoint address is immutable post-deployment.
 *
 * INVARIANT I6:
 *     No internal state mutation occurs during signature validation.
 *
 * ============================================================================
 * 7. GAS ECONOMICS MODEL
 * ============================================================================
 *
 * WHY PREFUND EXISTS:
 *
 *     Bundlers must be economically compensated to include UserOperations.
 *
 * HOW IT WORKS:
 *
 *     1. EntryPoint calculates required gas cost.
 *     2. EntryPoint determines missingAccountFunds.
 *     3. Wallet transfers exact missing amount.
 *     4. EntryPoint compensates bundler.
 *
 * WHAT IF WALLET HAS INSUFFICIENT ETH?
 *
 *     Operation fails.
 *
 * WHAT IF WALLET OVERPAYS?
 *
 *     EntryPoint manages precise accounting and refunds excess deposit.
 *
 * ECONOMIC SECURITY PROPERTY:
 *
 *     Wallet pays exact required prefund.
 *     Bundler is guaranteed compensation.
 *
 * ============================================================================
 * 8. THREAT MODEL
 * ============================================================================
 *
 * PROTECTED AGAINST:
 *
 *     • Unauthorized execution by random addresses
 *     • Signature forgery
 *     • Cross-chain replay (hash includes chainId)
 *     • Cross-EntryPoint replay
 *     • Gas griefing via restricted prefund logic
 *
 * NOT PROTECTED AGAINST:
 *
 *     • Compromised owner private key
 *     • Malicious EntryPoint (explicit trust assumption)
 *
 * ============================================================================
 * 9. SECURITY DESIGN PHILOSOPHY
 * ============================================================================
 *
 * This implementation is intentionally minimal:
 *
 *     • Single owner ECDSA signature scheme
 *     • No multisig logic
 *     • No paymaster integration
 *     • No session keys
 *     • No upgradeability
 *
 * Purpose:
 *     Serve as a minimal reference ERC-4337 smart account.
 *
 * It is suitable as:
 *
 *     • Educational reference implementation
 *     • Audit training example
 *     • Base layer for production extensions
 *
 * ============================================================================
 */
contract AccountEAA is IAccount, Ownable {
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                    ERRORS
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
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
    /**
     * @dev Restricts function access exclusively to EntryPoint.
     *
     * SECURITY PURPOSE:
     * Ensures that only the trusted EntryPoint contract
     * can trigger validation or prefunding logic.
     *
     * PREVENTS:
     * - External attackers calling validateUserOp().
     * - Direct prefund draining attempts.
     *
     * REVERT CONDITION:
     * If msg.sender != EntryPoint.
     */

    modifier onlyEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert AccountEAA___Modifer__CallNotFromEntryPoint();
        }
        _;
    }

    /**
     * @dev Restricts access to either:
     * - The Owner (direct control)
     * - The EntryPoint (AA execution path)
     *
     * SECURITY PURPOSE:
     * Allows two valid execution paths:
     *
     * 1. Direct Owner execution (manual control)
     * 2. EntryPoint mediated execution (ERC-4337 flow)
     *
     * PREVENTS:
     * - Arbitrary contract calls by unauthorized addresses.
     */

    modifier onlyOwnerOrEntryPoint() {
        if (msg.sender != owner() && msg.sender != address(i_entryPoint)) {
            revert AccountEAA___Modifier__CallNotFromOwnerOrEntryPoint();
        }
        _;
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                     -FUNCTIONS-
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /**
     * @param entryPoint The deployed ERC-4337 EntryPoint address.
     *
     * @dev
     * Sets immutable EntryPoint reference.
     *
     * SECURITY:
     * EntryPoint address cannot be modified after deployment.
     *
     * TRUST:
     * EntryPoint is assumed correct and non-malicious.
     */

    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                    RECEIVE FUNCTIONS-
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    receive() external payable {
        // Handle received ETH
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                     EXTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /**
     * @notice Function validateUserOp()
     * ============================================================================
     * @notice ERC-4337 validation entrypoint for this Smart Contract Account.
     * ============================================================================
     *
     * @dev
     * This function is the mandatory validation gate required by ERC-4337.
     *
     * It acts as the wallet’s security checkpoint before execution.
     *
     * The EntryPoint contract calls this function before executing
     * any UserOperation submitted by a bundler.
     *
     * The wallet must determine:
     *
     *     "Was this operation genuinely authorized by my owner?"
     *
     * If YES → execution may continue.
     * If NO  → the entire operation must be rejected.
     *
     * ============================================================================
     * PARAMETERS
     * ============================================================================
     *
     * @param userOp The full PackedUserOperation submitted by a bundler.
     *
     *     WHY provided?
     *         Because validation logic may inspect any field
     *         (nonce, callData, gas fields, paymaster, etc).
     *
     * @param userOpHash The canonical hash computed by EntryPoint.
     *
     *     WHY not recomputed locally?
     *         ERC-4337 defines EntryPoint as the canonical hashing authority.
     *
     *     WHAT does it contain?
     *         - All UserOperation fields
     *         - EntryPoint address
     *         - Chain ID
     *
     *     WHY include EntryPoint + chainId?
     *         To prevent cross-chain replay attacks
     *         and cross-EntryPoint replay attacks.
     *
     * @param missingAccountFunds The exact amount of ETH required to prefund execution.
     *
     *     WHAT is it?
     *         The difference between required gas cost
     *         and the wallet’s current deposit inside EntryPoint.
     *
     *     WHY is it needed?
     *         Bundlers must be guaranteed compensation.
     *
     * ============================================================================
     * ACCESS CONTROL
     * ============================================================================
     *
     * WHO is allowed to call this function?
     *
     *     ONLY the EntryPoint contract.
     *
     * WHY?
     *
     *     Because ERC-4337 centralizes validation coordination
     *     inside EntryPoint.
     *
     * WHAT IF arbitrary addresses could call this?
     *
     *     - They could trigger unwanted prefund transfers.
     *     - They could probe validation behavior.
     *     - They could grief the wallet.
     *
     * ENFORCEMENT:
     *
     *     onlyEntryPoint modifier.
     *
     * FORMAL PRECONDITION:
     *
     *     require(msg.sender == EntryPoint)
     *
     * ============================================================================
     * STEP-BY-STEP EXECUTION FLOW
     * ============================================================================
     *
     * Step 1:
     *     EntryPoint calls validateUserOp().
     *
     * Step 2:
     *     Wallet verifies signature via _signatureValidation().
     *
     * Step 3:
     *     If signature invalid:
     *         return SIG_VALIDATION_FAILED.
     *
     * Step 4:
     *     If signature valid:
     *         return SIG_VALIDATION_SUCCESS (0).
     *
     * Step 5:
     *     If missingAccountFunds > 0:
     *         wallet transfers ETH to EntryPoint.
     *
     * Step 6:
     *     EntryPoint continues execution if validation succeeded.
     *
     * ============================================================================
     * SIGNATURE VERIFICATION LOGIC
     * ============================================================================
     *
     * HOW is authenticity proven?
     *
     *     1. userOpHash is wrapped with Ethereum Signed Message prefix.
     *     2. ECDSA.recover extracts signer address.
     *     3. Signer is compared to owner().
     *
     * WHY prefix the hash?
     *
     *     To prevent signing raw transaction-like hashes
     *     that could be misused elsewhere.
     *
     * WHAT IF signature does not match owner?
     *
     *     validationData must signal failure.
     *
     * WHAT IF owner private key compromised?
     *
     *     Attacker gains full control.
     *     This is outside contract-level protection.
     *
     * ============================================================================
     * GAS ECONOMICS MODEL
     * ============================================================================
     *
     * Why does prefunding happen during validation?
     *
     *     Because bundlers need guaranteed payment
     *     BEFORE execution begins.
     *
     * missingAccountFunds represents:
     *
     *     required_prefund - current_deposit
     *
     * If missingAccountFunds > 0:
     *
     *     Wallet must transfer exactly that amount to EntryPoint.
     *
     * If missingAccountFunds == 0:
     *
     *     No transfer occurs.
     *
     * SECURITY PROPERTY:
     *
     *     ETH prefunding can only go to EntryPoint.
     *
     * WHAT IF transfer fails?
     *
     *     Entire operation reverts.
     *
     * ECONOMIC INVARIANT:
     *
     *     Wallet never overpays.
     *     Wallet never underpays.
     *
     * ============================================================================
     * FORMAL POSTCONDITIONS
     * ============================================================================
     *
     * Q1:
     *     Returns 0 only if signature valid.
     *
     * Q2:
     *     Returns non-zero if signature invalid.
     *
     * Q3:
     *     If missingAccountFunds > 0:
     *         ETH transferred to EntryPoint.
     *
     * Q4:
     *     No persistent state variables are modified.
     *
     * ============================================================================
     * SECURITY INVARIANTS
     * ============================================================================
     *
     * INVARIANT 1:
     *     Caller must be EntryPoint.
     *
     * INVARIANT 2:
     *     Invalid signatures must never return success.
     *
     * INVARIANT 3:
     *     Prefund transfers must only go to EntryPoint.
     *
     * INVARIANT 4:
     *     No storage mutation during validation.
     *
     * ============================================================================
     * THREAT MODEL ANALYSIS
     * ============================================================================
     *
     * PROTECTED AGAINST:
     *
     *     - Forged signatures.
     *     - Unauthorized direct validation calls.
     *     - Gas-draining via prefund manipulation.
     *     - Replay across chains or EntryPoints.
     *
     * TRUST ASSUMPTIONS:
     *
     *     - EntryPoint implementation is correct.
     *     - Owner private key remains secure.
     *
     * NOT PROTECTED AGAINST:
     *
     *     - Malicious EntryPoint contract.
     *     - Compromised owner key.
     *
     * ============================================================================
     * ERC-4337 COMPLIANCE MAPPING
     * ============================================================================
     *
     * Requirement:
     *     Account MUST implement validateUserOp().
     *
     * ✔ Implemented.
     *
     * Requirement:
     *     MUST return validationData.
     *
     * ✔ Returns SIG_VALIDATION_SUCCESS or failure.
     *
     * Requirement:
     *     MUST handle prefunding.
     *
     * ✔ _payPrefund(missingAccountFunds).
     *
     * ============================================================================
     *
     * @return validationData
     *     0  → signature valid
     *     ≠0 → signature invalid
     *
     * ============================================================================
     */

    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        onlyEntryPoint
        returns (uint256 validationData)
    {
        validationData = _signatureValidation(userOp, userOpHash);
        _payPrefund(missingAccountFunds);
    }

    /**
     * @notice Executes arbitrary call from wallet.
     *
     * @param destAddress Target contract address.
     * @param value ETH value to send.
     * @param abiEncodedFunctionData Encoded function call data.
     *
     * BEHAVIOR:
     *
     * Performs low-level call:
     *     destAddress.call{value: value}(data)
     *
     * ACCESS CONTROL:
     *
     * Allowed callers:
     *     - Owner (direct execution)
     *     - EntryPoint (AA flow)
     *
     * SECURITY:
     * Reverts if external call fails.
     *
     * RISKS:
     * - If destAddress is malicious,
     *   wallet may lose funds.
     *
     * Responsibility lies with owner signature.
     *
     * ============================================================================
     * FORMAL SPEC AND WITH WHY WHAT IF Q/A:
     * ============================================================================
     *
     * PURPOSE:
     *     Executes arbitrary external call.
     *
     * FORMAL PRECONDITIONS:
     *
     * P1:
     *     Caller == Owner OR EntryPoint.
     *
     * WHY?
     *     Prevent arbitrary fund transfers.
     *
     * ENFORCEMENT:
     *     onlyOwnerOrEntryPoint modifier.
     *
     * P2:
     *     destAddress != zero address (implicit assumption).
     *
     * FORMAL POSTCONDITIONS:
     *
     * Q1:
     *     If external call succeeds → no revert.
     *
     * Q2:
     *     If external call fails → revert with error data.
     *
     * SECURITY QUESTIONS:
     *
     * WHY allow EntryPoint?
     *     Required for ERC-4337 mediated execution.
     *
     * WHY allow Owner?
     *     Enables direct manual control.
     *
     * WHAT IF destAddress malicious?
     *     Wallet trusts Owner's signature.
     *
     * WHAT IF reentrancy?
     *     No state mutation after call.
     *     No internal balance accounting.
     *
     * GAS ECONOMICS:
     *
     * Gas forwarded fully to destAddress.
     * Gas limits controlled by EntryPoint during AA flow.
     *
     * ERC-4337 COMPLIANCE:
     *
     * ✔ Enables execution of validated UserOperations.
     */

    function execute(address destAddress, uint256 value, bytes calldata abiEncodedFunctionData)
        external
        onlyOwnerOrEntryPoint
    {
        (bool success, bytes memory callResult) = destAddress.call{value: value}(abiEncodedFunctionData);
        if (!success) {
            revert AccountEAA___Execute__CallFailed(callResult);
        }
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                    INTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /**
     * @dev Verifies that userOp signature matches owner.
     *
     * PROCESS:
     *
     * 1. Convert userOpHash to Ethereum signed message hash.
     * 2. Recover signer via ECDSA.
     * 3. Compare signer with owner().
     *
     * RETURNS:
     *     SIG_VALIDATION_SUCCESS (0) if valid.
     *     SIG_VALIDATION_FAILED otherwise.
     *
     * SECURITY:
     * Prevents unauthorized execution.
     *
     * CRYPTO ASSUMPTION:
     * ECDSA implementation is secure (OpenZeppelin).
     *
     *
     * ============================================================================
     * FORMAL SPEC AND WITH WHY WHAT IF Q/A:
     * ============================================================================
     *
     * PURPOSE:
     *     Verify cryptographic authenticity.
     *
     * FORMAL PRECONDITION:
     *
     * P1:
     *     userOpHash must represent entire UserOperation.
     *
     * WHY?
     *     Prevent partial signature manipulation.
     *
     * FORMAL POSTCONDITION:
     *
     * Q1:
     *     Return success only if recovered signer == owner().
     *
     * SECURITY QUESTIONS:
     *
     * WHY use toEthSignedMessageHash?
     *     Prevent raw hash replay attacks.
     *
     * WHAT IF signature malleable?
     *     OpenZeppelin ECDSA prevents malleability.
     *
     * WHAT IF wrong owner?
     *     Validation fails.
     *
     * ERC-4337 COMPLIANCE:
     *
     * ✔ Implements signature verification requirement.
     */

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

    /**
     * @dev Transfers required prefund ETH to EntryPoint.
     *
     * @param missingAccountFunds Amount of ETH required.
     *
     * BEHAVIOR:
     * If missingAccountFunds > 0:
     *     Send ETH to EntryPoint.
     *
     * GAS LOGIC:
     * Gas forwarded = type(uint256).max
     * Ensures no accidental gas shortage.
     *
     * SECURITY:
     * - Only callable by EntryPoint.
     * - Sends ETH exclusively to EntryPoint.
     *
     * REVERTS:
     * If transfer fails.
     * ============================================================================
     * FORMAL SPEC AND WITH WHY WHAT IF Q/A:
     * ============================================================================
     *
     * PURPOSE:
     *     Transfers required ETH to EntryPoint.
     *
     * FORMAL PRECONDITION:
     *
     * P1:
     *     Caller == EntryPoint.
     *
     * WHY?
     *     Prevent draining wallet.
     *
     * FORMAL POSTCONDITION:
     *
     * Q1:
     *     If missingAccountFunds == 0 → no transfer.
     *
     * Q2:
     *     If > 0 → transfer exact amount.
     *
     * SECURITY QUESTIONS:
     *
     * WHY unlimited gas?
     *     Ensure transfer cannot fail due to gas restriction.
     *
     * WHAT IF transfer fails?
     *     Revert.
     *
     * WHAT IF attacker tries direct call?
     *     onlyEntryPoint blocks.
     *
     * ERC-4337 COMPLIANCE:
     *
     * ✔ Handles prefunding requirement.
     */

    function _payPrefund(uint256 missingAccountFunds) internal onlyEntryPoint {
        if (missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");

            if (!success) {
                revert AccountEAA___PayPreFun__NotSuccessful();
            }
        }
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                     GETTERS FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /**
     * ============================================================================
     * @notice Returns the immutable EntryPoint address.
     * ============================================================================
     *
     * PURPOSE:
     *     Transparency and auditability.
     *
     * WHY expose?
     *
     *     Frontends and auditors may verify trust anchor.
     *
     * SECURITY:
     *
     *     Pure getter.
     *     No state mutation.
     */

    function getEntryPointAddress() external view returns (address) {
        return address(i_entryPoint);
    }
}
