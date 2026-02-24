// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/*////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                     IMPORTS
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
/**
 * IAccount
 *
 * Defines the required interface for zkSync native account abstraction.
 *
 * Provides:
 *   - validateTransaction()
 *   - executeTransaction()
 *   - executeTransactionFromOutside()
 *   - payForTransaction()
 *   - prepareForPaymaster()
 *
 * WHO calls these?
 *   The zkSync Bootloader system contract.
 */

/**
 * ACCOUNT_VALIDATION_SUCCESS_MAGIC
 *
 * A bytes4 constant equal to:
 *   IAccount.validateTransaction.selector
 *
 * WHY?
 *   The Bootloader expects this exact return value to treat validation as successful.
 *
 * HOW used?
 *   validateTransaction() must return this value on success.
 *
 * WHAT IF wrong value returned?
 *   Bootloader rejects the transaction.
 *
 * SECURITY ROLE:
 *   Prevents ambiguous validation outcomes.
 */
import {
    IAccount,
    ACCOUNT_VALIDATION_SUCCESS_MAGIC
} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
//---------------------------------------------------------------------------------------------------------------------------------------------------

/**
 * Transaction
 *
 * zkSync-native transaction struct (Type 113 format).
 *
 * Contains:
 *  struct Transaction {
 *     uint256 txType;
 *     uint256 from;
 *     uint256 to;
 *     uint256 gasLimit;
 *     uint256 gasPerPubdataByteLimit;
 *     uint256 maxFeePerGas;
 *     uint256 maxPriorityFeePerGas;
 *     uint256 paymaster;
 *     uint256 nonce;
 *     uint256 value;
 *     uint256[4] reserved;
 *     bytes data;
 *     bytes signature;
 *     bytes32[] factoryDeps;
 *     bytes paymasterInput;
 *     bytes reservedDynamic;
 *     }
 *
 * WHY not Ethereum transaction?
 *   zkSync extends transaction format with additional fields
 *   (e.g., gasPerPubdataByteLimit, paymaster, reserved fields).
 *
 * SECURITY ROLE:
 *   Canonical representation of AA transaction inside protocol.
 */

/**
 * MemoryTransactionHelper
 *
 * Provides helper functions bound to Transaction struct:
 *
 *   - encodeHash()
 *       Computes canonical transaction hash.
 *
 *   - totalRequiredBalance()
 *       Computes required ETH for gas + value.
 *
 *   - payToTheBootloader()
 *       Transfers transaction fee to Bootloader.
 *
 * WHY needed?
 *   zkSync transaction format differs from Ethereum's.
 *   Canonical hashing and fee calculation must follow protocol rules.
 *
 * WHAT IF implemented incorrectly?
 *   - Signature verification would fail.
 *   - Fee logic would be incorrect.
 *   - Bootloader would reject transaction.
 *
 * SECURITY ROLE:
 *   Ensures protocol-consistent hashing and accounting.
 */
import {
    Transaction,
    MemoryTransactionHelper
} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
//---------------------------------------------------------------------------------------------------------------------------------------------------

/**
 * SystemContractsCaller
 *
 * Library for calling zkSync kernel-space system contracts.
 *
 * Provides:
 *   - systemCallWithPropagatedRevert()
 *
 * WHY needed?
 *   zkSync system contracts exist in reserved kernel address space.
 *   They require specialized calling semantics.
 *
 * WHAT IF normal call() used?
 *   Behavior may be incorrect or revert unexpectedly.
 *
 * SECURITY ROLE:
 *   Ensures safe interaction with protocol-level system contracts.
 */
import {
    SystemContractsCaller
} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/SystemContractsCaller.sol";

//-------------------------------------------------------------------------------------------------------------------------------------------------

/**
 * NONCE_HOLDER_SYSTEM_CONTRACT
 *
 * zkSync system contract responsible for storing account nonces.
 *
 * WHY separate contract?
 *   Nonce is stored in kernel space, not in the account contract.
 *
 * WHO modifies nonce?
 *   Account must call incrementMinNonceIfEquals().
 *
 * WHAT IF nonce not incremented?
 *   Bootloader rejects validation.
 *
 * SECURITY ROLE:
 *   Prevents replay attacks.
 */

/**
 * BOOTLOADER_FORMAL_ADDRESS
 *
 * The zkSync Bootloader system contract address.
 *
 * WHAT is Bootloader?
 *   Protocol-level contract orchestrating transaction lifecycle.
 *
 * RESPONSIBILITIES:
 *   - Calls validateTransaction()
 *   - Calls payForTransaction()
 *   - Calls executeTransaction()
 *
 * WHY restrict access to it?
 *   Prevent unauthorized validation or execution.
 *
 * SECURITY ROLE:
 *   Enforces protocol-level control.
 */

/**
 * DEPLOYER_SYSTEM_CONTRACT
 *
 * zkSync system contract responsible for contract deployment.
 *
 * WHY needed?
 *   zkSync does not rely on raw CREATE in same way as Ethereum.
 *   Deployments must be routed through system deployer.
 *
 * WHEN used?
 *   When transaction target equals DEPLOYER_SYSTEM_CONTRACT.
 *
 * SECURITY ROLE:
 *   Ensures controlled deployment semantics.
 */
import {
    NONCE_HOLDER_SYSTEM_CONTRACT,
    BOOTLOADER_FORMAL_ADDRESS,
    DEPLOYER_SYSTEM_CONTRACT
} from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
//---------------------------------------------------------------------------------------------------------------------------------------------------

/**
 * INonceHolder
 *
 * Interface for interacting with the NonceHolder system contract.
 *
 * Provides:
 *   - incrementMinNonceIfEquals(uint256 expectedNonce)
 *
 * WHY interface required?
 *   Needed for abi.encodeCall() when calling system contract.
 *
 * SECURITY ROLE:
 *   Ensures nonce increment call is correctly encoded.
 */
import {INonceHolder} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/INonceHolder.sol";
//---------------------------------------------------------------------------------------------------------------------------------------------------

/**
 * Ownable
 *
 * OpenZeppelin access control contract.
 *
 * Provides:
 *   - owner()
 *   - transferOwnership()
 *
 * WHY needed?
 *   Signature validation compares recovered signer to owner().
 *
 * WHAT IF no owner enforcement?
 *   Anyone could authorize transactions.
 *
 * SECURITY ROLE:
 *   Defines cryptographic authority of account.
 */
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
//---------------------------------------------------------------------------------------------------------------------------------------------------

//import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
//---------------------------------------------------------------------------------------------------------------------------------------------------

/**
 * ECDSA
 *
 * OpenZeppelin cryptography library.
 *
 * Provides:
 *   - recover(hash, signature)
 *
 * WHY needed?
 *   To recover signer address from transaction signature.
 *
 * WHAT IF implemented manually?
 *   Risk of subtle cryptographic bugs.
 *
 * SECURITY ROLE:
 *   Ensures correct signature verification.
 */
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
//---------------------------------------------------------------------------------------------------------------------------------------------------

/**
 * Utils
 *
 * zkSync helper library for safe casting and numeric constraints.
 *
 * Provides:
 *   - safeCastToU128()
 *   - safeCastToU32()
 *
 * WHY needed?
 *   zkSync internally restricts certain values to fixed bit-widths.
 *
 * WHAT IF overflow occurs?
 *   Transaction reverts instead of silent truncation.
 *
 * SECURITY ROLE:
 *   Prevents numeric overflow vulnerabilities.
 */
import {Utils} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/Utils.sol";

/**
 * =============================================================================
 *                                 AccountZKAA
 * =============================================================================
 *
 * @title zkSync Era Native Account Abstraction Implementation
 *
 * @author Wasim Choudhary
 * Implementation of zkSync Era's protocol-level account abstraction model.
 *
 * -----------------------------------------------------------------------------
 * 🧠 WHAT THIS CONTRACT ACTUALLY IS
 * -----------------------------------------------------------------------------
 *
 * This contract is NOT just a wallet.
 *
 * It is:
 *   - A transaction validator
 *   - A nonce participant (via system contract)
 *   - A fee-paying account
 *   - An execution engine
 *   - A protocol-integrated identity
 *
 * It implements `IAccount`, which is required for zkSync native AA.
 *
 * -----------------------------------------------------------------------------
 * 🏗 ARCHITECTURE CONTEXT
 * -----------------------------------------------------------------------------
 *
 * On Ethereum L1:
 *   - EOAs sign
 *   - Protocol validates
 *   - Protocol executes
 *
 * On ERC-4337:
 *   - UserOp signed
 *   - EntryPoint validates
 *   - Bundler submits
 *
 * On zkSync Native AA:
 *   - Account contract validates
 *   - Bootloader orchestrates lifecycle
 *   - Nonce lives in system contract
 *
 * There is:
 *   ❌ No EntryPoint
 *   ❌ No Bundler
 *   ❌ No separate mempool
 *
 * Everything is enforced by zkSync protocol.
 *
 * -----------------------------------------------------------------------------
 * 🔄 FULL LIFECYCLE OF A TYPE 113 TRANSACTION
 * -----------------------------------------------------------------------------
 *
 * Type 113 (0x71) = zkSync Native AA transaction.
 *
 * PHASE 1 — VALIDATION
 *
 * 1️⃣ User signs transaction off-chain.
 * 2️⃣ User sends signed transaction to zkSync API.
 * 3️⃣ API simulates validation.
 * 4️⃣ Bootloader calls validateTransaction().
 * 5️⃣ Nonce must be incremented.
 * 6️⃣ Balance must be checked.
 * 7️⃣ Signature must be verified.
 * 8️⃣ payForTransaction() is called.
 *
 * PHASE 2 — EXECUTION
 *
 * 9️⃣ Bootloader calls executeTransaction().
 * 🔟 Target contract is called.
 *
 * -----------------------------------------------------------------------------
 * 👶 CHILD ANALOGY (HIGH LEVEL)
 *
 * Think of this contract as a smart robot guard.
 *
 * A person (user) brings a signed permission slip.
 *
 * The robot:
 *   - Checks if permission slip is real (signature)
 *   - Checks if this slip was already used (nonce)
 *   - Checks if person paid entry fee (balance)
 *   - If all good → lets them inside (execution)
 *
 * Bootloader = school principal supervising robot.
 *
 * -----------------------------------------------------------------------------
 * 🔒 SECURITY GUARANTEES
 *
 * - Only Bootloader can validate during protocol flow
 * - Nonce strictly increases
 * - Replay impossible
 * - Owner signature required
 * - Fee must be paid before execution
 * - Deployment routed via system deployer
 *
 */
contract AccountZKAA is IAccount, Ownable {
    /*////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                    Libraries
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    using MemoryTransactionHelper for Transaction;

    /*////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                    ERRORS
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    /**
     * Custom errors are cheaper than revert strings.
     *
     * WHY use them?
     *   - Lower gas
     *   - Clear audit trail
     *
     * Each error corresponds to a specific security failure.
     */
    error AccountZKAA___validateTransaction__BalanceNotEnoughForTransaction();
    error AccountZKAA___executeTransaction__TransactionExecutionFailed();
    error AccountZKAA___modifier_onlyByBootloader__InvalidCaller();
    error AccountZKAA___modifier_onlyByBootloaderOrByOwner__InvalidCaller();
    error AccountZKAA___payForTransaction__FailedToPay();
    error AccountZKAA___executeTransaction__TransactionExecutionFailedDueToInvalidSignature();

    /*////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                         MODIFIERS
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    /**
     * WHY?
     * Only Bootloader should validate transactions.
     *
     * WHO calls validateTransaction?
     * Bootloader only.
     *
     * WHAT IF someone else calls?
     * Revert immediately.
     *
     * SECURITY QUESTION:
     * Can attacker simulate Bootloader?
     * No. Bootloader address is fixed system address.
     */
    modifier onlyByBootloader() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            revert AccountZKAA___modifier_onlyByBootloader__InvalidCaller();
        }
        _;
    }

    /**
     * @dev Allows either Bootloader OR owner to call.
     *
     * WHY?
     * During protocol flow → Bootloader executes.
     * For manual/direct execution → owner may execute.
     *
     * WHO calls?
     * - Bootloader during normal lifecycle
     * - Owner during direct calls
     *
     * WHAT IF unauthorized?
     * Reverts.
     */
    modifier onlyByBootloaderOrByOwner() {
        if (msg.sender != owner() && msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            revert AccountZKAA___modifier_onlyByBootloaderOrByOwner__InvalidCaller();
        }
        _;
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                   FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    constructor() Ownable(msg.sender) {}

    /*////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                   Receive FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    receive() external payable {}

    /*////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                    EXTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Validates zkSync native transaction.
     *
     * -----------------------------------------------------------------------------
     * STEP 1 — NONCE UPDATE
     *
     * Why increment first?
     *
     * Because:
     *   - If signature valid but nonce not incremented,
     *     transaction could replay.
     *
     * What does incrementMinNonceIfEquals do?
     *
     * If current nonce == expected:
     *     increment.
     *
     * Else:
     *     revert.
     *
     * WHAT IF nonce wrong?
     * Validation fails.
     *
     * WHAT IF attacker replays old tx?
     * Nonce mismatch → revert.
     *
     * -----------------------------------------------------------------------------
     * STEP 2 — BALANCE CHECK
     *
     * requiredTotalTransactionFee =
     *     maxFeePerGas * gasLimit + value
     *
     * WHY?
     * Because user must pay gas AND transfer value.
     *
     * WHAT IF paymaster used?
     * paymaster would cover gas.
     *
     * WHAT IF insufficient?
     * revert.
     *
     * -----------------------------------------------------------------------------
     * STEP 3 — SIGNATURE CHECK
     *
     * txHash = _transaction.encodeHash()
     *
     * Why raw hash? (Not raw actually but can) and no  bytes32 convertedHash = MessageHashUtils.toEthSignedMessageHash(txHash);
     *
     * zkSync expects raw ECDSA signature,(Also here in encodeHash() it is already converted to its txType see that function encodeHash() and you will understand)
     * not Ethereum personal_sign prefixed hash
     *  And no  bytes32 convertedHash = MessageHashUtils.toEthSignedMessageHash(txHash); because ZKsync's use of EIP-712 makes this hack unnecessary because domain separation is built into the standard.No, not all ZKsync transactions are EIP-712 transactions, but the most powerful and ZKsync-specific ones are
     *
     * signer = ECDSA.recover(txHash, signature)
     *
     * WHAT IF wrong signature?
     * Return 0.
     * Bootloader rejects.
     *
     * WHAT IF owner changes?
     * New owner must sign future tx.
     *
     * -----------------------------------------------------------------------------
     * RETURN VALUE
     *
     * ACCOUNT_VALIDATION_SUCCESS_MAGIC
     *
     * Bootloader checks:
     *   if return == magic → proceed
     *   else → reject
     *
     */
    function validateTransaction(
        bytes32,
        /* _txHash // Not used as for ours the bootloader will call this and the next arg*/
        bytes32,
        /*_suggestedSignedHash , same reason as above*/
        Transaction memory _transaction
    )
        external
        payable
        onlyByBootloader
        returns (bytes4 magic)
    {
        return _validateTransaction(_transaction);
    }

    /**
     * @notice Executes validated transaction.
     *
     * -----------------------------------------------------------------------------
     * WHY separate from validate?
     *
     * zkSync splits:
     *   - validation
     *   - payment
     *   - execution
     *
     * -----------------------------------------------------------------------------
     * ADDRESS CASTING
     *
     * Transaction stores address as uint256.
     *
     * WHY?
     * Uniform struct layout.
     *
     * We cast to:
     * address(uint160(_transaction.to))
     *
     * -----------------------------------------------------------------------------
     * VALUE CAST
     *
     * uint128 value = safeCastToU128(...)
     *
     * WHY?
     * zkSync internal balance system uses 128-bit values.
     *
     * WHAT IF value > 2^128 - 1?
     * Revert.
     *
     * -----------------------------------------------------------------------------
     * DEPLOYER CHECK
     *
     * If target == DEPLOYER_SYSTEM_CONTRACT:
     *
     * Use systemCallWithPropagatedRevert.
     *
     * WHY?
     * zkSync requires system deployer for contract creation.
     *
     * -----------------------------------------------------------------------------
     * NORMAL CALL PATH
     *
     * assembly call:
     *
     * call(
     *     gas(),
     *     to,
     *     value,
     *     add(data, 0x20),
     *     mload(data),
     *     0,
     *     0
     * )
     *
     * What is 0x20?
     * First 32 bytes store length of dynamic bytes.
     *
     * add(data, 0x20) skips length field.
     *
     * WHAT IF call fails?
     * revert.
     *
     */
    function executeTransaction(
        bytes32,
        /*_txHash, see validateTransaction arg */
        bytes32,
        /*_suggestedSignedHash, same reason */
        Transaction memory _transaction
    )
        external
        payable
        onlyByBootloaderOrByOwner
    {
        _executeTransaction(_transaction);
    }

    /**
     * @notice Allows external caller to execute.
     *
     * DIFFERENCE FROM NORMAL FLOW:
     *
     * Bootloader not involved.
     * Caller pays gas.
     *
     * WHY included?
     * For relayers or manual execution.
     *
     * SECURITY?
     * Signature still required.
     */
    function executeTransactionFromOutside(Transaction memory _transaction) external payable {
        // her no bootloader, aa stuff....it is like you can send my transaction and you will pay the gas
        bytes4 magic = _validateTransaction(_transaction);
        if (magic != ACCOUNT_VALIDATION_SUCCESS_MAGIC) {
            revert AccountZKAA___executeTransaction__TransactionExecutionFailedDueToInvalidSignature();
        }
        _executeTransaction(_transaction);
    }

    /**
     * @notice Transfers fee to Bootloader.
     *
     * WHY?
     * Bootloader must be paid before execution.
     *
     * WHAT IF fails?
     * Transaction reverts.
     *
     * WHY separate function?
     * zkSync lifecycle enforces structured phases.
     *
     */
    function payForTransaction(
        bytes32,
        /*_txHash, same reason as the others*/
        bytes32,
        /*_suggestedSignedHash, see reson in validate, same reason*/
        Transaction memory _transaction
    )
        external
        payable
    {
        //this function happens beore the executeTransactuon function in the same sequence of the validatateTrasaction function
        bool success = _transaction.payToTheBootloader();

        if (!success) {
            revert AccountZKAA___payForTransaction__FailedToPay();
        }
    }

    function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction memory _transaction)
        external
        payable {}

    /*////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                    INTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    function _validateTransaction(Transaction memory _transaction) internal returns (bytes4 magic) {
        // =============================================
        // STEP 1: PREVENT REPLAY ATTACKS Explaing the  SystemContractsCaller.systemCallWithPropagatedRevert() and its args
        // =============================================
        // Every transaction must have a unique nonce.
        // This ensures the same transaction can't be submitted twice.
        // The NonceHolder system contract tracks used nonces.
        //
        // We call: incrementMinNonceIfEquals(_transaction.nonce)
        // This checks: "Has nonce X been used yet?"
        // If NO → mark it as used and proceed
        // If YES → reject transaction (replay attack prevented!)
        // =============================================

        // =============================================
        // STEP 2: SPECIAL "SYSTEM CALL" MODE
        // =============================================
        // The ".systemCallWithPropagatedRevert" function is special.
        //
        // In Foundry config: if "isSystem = true" is set,
        // THEN certain keywords like "call" automatically become
        // "system contract calls" instead of regular calls.
        //
        // What's the difference?
        // - Regular call: like talking to a friend 👥
        // - System call: like talking to the government 🏛️
        //   (higher privileges, special rules, more power!)
        // =============================================

        // =============================================
        // STEP 3: WHY encodeCall IS BETTER
        // =============================================
        // We use: abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (nonce))
        // Instead of old ways like: abi.encodeWithSelector(...)
        //
        // Why encodeCall wins:
        // ✅ Type checking - compiler catches errors!
        // ✅ Safe - can't mess up parameter order
        // ✅ Modern - the "right way" in Solidity
        //
        // Old way (dangerous):
        // abi.encodeWithSelector(
        //     bytes4(keccak256("incrementMinNonceIfEquals(uint256)")),
        //     nonce
        // )
        // 😱 One typo = silent failure!
        // =============================================

        // =============================================
        // WHAT THIS ENTIRE CODE DOES (Simple Version) -

        //  SystemContractsCaller.systemCallWithPropagatedRevert(
        //    uint32(gasleft()), // Use all remaining gas
        //    address(NONCE_HOLDER_SYSTEM_CONTRACT), // The nonce "government"
        //    0, // No ETH being sent
        //    abi.encodeCall( // Safe way to encode function call
        //       INonceHolder.incrementMinNonceIfEquals,
        //       (_transaction.nonce)
        //   )
        // );
        // =============================================
        // 1. Take the transaction's nonce number
        // 2. Ask NonceHolder: "Is this nonce already used?"
        // 3. If NO → mark it as used, proceed with transaction
        // 4. If YES → cancel everything (someone tried to cheat!)
        //
        // Think of it like a ticket number at a deli counter:
        // - You take number 57
        // - The system marks 57 as "taken"
        // - Someone can't later use 57 again!
        // =============================================

        SystemContractsCaller.systemCallWithPropagatedRevert(
            uint32(gasleft()), // Use all remaining gas
            address(NONCE_HOLDER_SYSTEM_CONTRACT), // The nonce "government"
            0, // No ETH being sent
            abi.encodeCall( // Safe way to encode function call
                INonceHolder.incrementMinNonceIfEquals,
                (_transaction.nonce)
            )
        );
        SystemContractsCaller.systemCallWithPropagatedRevert(
            uint32(gasleft()),
            address(NONCE_HOLDER_SYSTEM_CONTRACT),
            0,
            abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce))
        ); //encodeCall is modern and more safe than withSelector etc and they are manual type

        ///next we will check fee to pa for the transction if it has or not
        uint256 requiredTotalTransactionFee = _transaction.totalRequiredBalance();
        if (requiredTotalTransactionFee > address(this).balance) {
            revert AccountZKAA___validateTransaction__BalanceNotEnoughForTransaction();
        }

        // then check the signature
        bytes32 txHash = _transaction.encodeHash();
        /**
         * @notice bytes32 convertedHash = MessageHashUtils.toEthSignedMessageHash(txHash);
         * we are skipping this as This step is already covered isnide encodeHash() fucntion command click and see the function !
         *  Also a point to be noted it accpets raw tx too! ZKsync's use of EIP-712 makes this hack unnecessary because domain separation is built into the standard.
         */

        address signer = ECDSA.recover(txHash, _transaction.signature);
        bool actualSigner = signer == owner();
        if (actualSigner) {
            magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC;
        } else {
            magic = bytes4(0);
        }
        //at last we will retrh the magic number
        return magic;
    }

    function _executeTransaction(Transaction memory _transaction) internal {
        address to = address(uint160(_transaction.to));
        uint128 value = Utils.safeCastToU128(_transaction.value);
        bytes memory data = _transaction.data;

        if (to == address(DEPLOYER_SYSTEM_CONTRACT)) {
            uint32 gas = Utils.safeCastToU32(gasleft());
            SystemContractsCaller.systemCallWithPropagatedRevert(gas, to, value, data);
        } else {
            bool success;
            assembly {
                success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
            }
            if (!success) {
                revert AccountZKAA___executeTransaction__TransactionExecutionFailed();
            }
        }
    }
}
