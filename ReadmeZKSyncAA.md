<p align="center">
  <a href="https://x.com/i___wasim">
    <img src="https://img.shields.io/badge/X-@i___wasim-black?logo=x" alt="X (Twitter)">
  </a>
  <a href="https://www.linkedin.com/in/wasim-007-choudhary/">
    <img src="https://img.shields.io/badge/LinkedIn-Wasim%20Choudhary-blue?logo=linkedin" alt="LinkedIn">
  </a>
  <a href="https://www.linkedin.com/in/wasim-007-choudhary/">
    <img src="https://img.shields.io/badge/LinkedIn%20ID-wasim--007--choudhary-0A66C2?logo=linkedin&logoColor=white" alt="LinkedIn ID">
  </a>
</p>

<h1 align="center">📚 zkSync Native Account Abstraction: Complete Architectural Documentation/Dissection</h1>

<p align="center">
  <i>A comprehensive deep dive into zkSync Era's Native Account Abstraction — from child-friendly analogies to low-level complex breakdowns with story-telling firendly way too. It is a perfection Dissection of the system and made in such a way that a folk with no prior knowldege can get the hang of what is going on. Even got perfect code dissection through natspecs to understand even the tiniest of the probelms and doubts + with rapid fire questions(for each topic and our code base too) to tie it tightly. Enough chitchat, just have a look and let the work speak for itself!</i>
</p>

# 📖 Table of Contents

- [1️⃣ High-Level Overview (Big Picture)](#1️⃣-high-level-overview-big-picture)
  - [🧠 High-Level Technical](#-high-level-technical)
  - [❓ Why It Exists](#-why-it-exists)
  - [⚙️ How It Differs](#️-how-it-differs)
  - [👥 Who Interacts](#-who-interacts)
  - [🚀 Problems Solved](#-problems-solved)
  - [🧒 Child Explanation](#-child-explanation)
  - [📖 Story Analogy](#-story-analogy)

- [2️⃣ 🧩 Core Architectural Components](#2️⃣--core-architectural-components)
  - [🏗 System-Level Components](#-system-level-components)
    - [🤖 Bootloader](#-bootloader)
    - [🏛 System Contracts](#-system-contracts)
      - [🧾 NonceHolder](#-nonceholder)
      - [🧮 MemoryTransactionHelper](#-memorytransactionhelper)
      - [🧰 SystemContractsCaller](#-systemcontractscaller)
  - [👤 Account-Level Components](#-account-level-components)
    - [📜 Account Contract](#-account-contract)
    - [✍️ Signature Validation Logic](#️-signature-validation-logic)
    - [🪄 Validation Magic Value](#-validation-magic-value)
    - [🚀 Execution Phase](#-execution-phase)
    - [💳 Paymaster (Optional)](#-paymaster-optional)
  - [🧾 Transaction Struct and Fields](#-transaction-struct-and-fields)

- [3️⃣ 🔄 Full Transaction Lifecycle (Step-by-Step)](#3️⃣--full-transaction-lifecycle-step-by-step)
  - [📦 Pre-Transaction Phase](#-pre-transaction-phase)
  - [🔐 Hash Encoding (`MemoryTransactionHelper.encodeHash`)](#-hash-encoding-memorytransactionhelperencodehash)
  - [✍️ Signature Creation](#️-signature-creation)
  - [📡 Submission to Mempool / Node](#-submission-to-mempool--node)
  - [⛓ Validation Phase (On-Chain)](#-validation-phase-on-chain)
  - [Execution Phase](#execution-phase)  

- [4️⃣ 🚨Failure Matrix](#4️⃣---failure-matrix)

- [5️⃣ 🛡 Security & Attack Surface Analysis](#5️⃣--security--attack-surface-analysis)
  - [🔐 Signature Malleability](#-signature-malleability)
  - [🔁 Replay Attacks (Same Chain)](#-replay-attacks-same-chain)
  - [🌍 Replay Attacks (Cross-Chain)](#-replay-attacks-cross-chain)
  - [🔄 Nonce Reuse (Underflow/Overflow)](#-nonce-reuse-underflowoverflow)
  - [🧱 System Contract Spoofing](#-system-contract-spoofing)
  - [🏦 Bootloader Spoofing (Calling from Wrong Address)](#-bootloader-spoofing-calling-from-wrong-address)
  - [🗄 Storage Collision Risks](#-storage-collision-risks)
  - [🔁 Upgradeability Risks](#-upgradeability-risks)
  - [⛽ Gas Griefing](#-gas-griefing)
  - [📌 Invalid Opcode Attacks](#-invalid-opcode-attacks)
  - [🏃 Frontrunning](#-frontrunning)
  - [💰 MEV Opportunities](#-mev-opportunities)
  - [💳 Paymaster Exploits](#-paymaster-exploits)
  - [🧪 Factory Dep Poisoning](#-factory-dep-poisoning)
  - [🔐 Signature Hash Collision](#-signature-hash-collision)

- [6️⃣ 🧠 Deep Low-Level Breakdown](#6️⃣--deep-low-level-breakdown)
  - [🖤 Cryptographic Details](#-cryptographic-details)
  - [🧱 Memory Layout](#-memory-layout)

- [7️⃣ 🏛 System-Level Details](#7️⃣--system-level-details)

- [8️⃣ ⛽ Gas Mechanics](#8️⃣--gas-mechanics)

- [9️⃣ ❓ Q/A Section](#9️⃣--qa-section)

- [🔟 📌 Summary & Reference](#--summary--reference)
  - [📄 One-Page Cheat Sheet](#-one-page-cheat-sheet)
  - [📚 Key Terms Glossary](#-key-terms-glossary)
  - [🛠️ Common Error Codes & Meanings](#️-common-error-codes--meanings)
  - [🛠️ Debugging Checklist (Failed TXs)](#️-debugging-checklist-failed-txs)
  - [✅ Testing Checklist (Account Developers)](#-testing-checklist-account-developers)
- [1️⃣1️⃣ 📚 Sources & Accuracy](#1️⃣1️⃣--sources--accuracy)
   
---
---
# 1️⃣ High-Level Overview (Big Picture)

Several entities work together in zkSync Era’s native Account Abstraction. Below is the complete big-picture explanation:

---

### 🧠 High-Level Technical

zkSync Era’s native Account Abstraction (AA) means all accounts (even normal EOAs) behave like smart-contract accounts at the protocol level. Instead of requiring a separate EOA to initiate a transaction for a smart wallet, an account itself can contain arbitrary code (validation and execution logic) and sign transactions. This adds Smart Accounts (programmable wallets) and Paymasters (sponsors of gas fees) to the protocol. Smart Accounts can implement custom signature schemes, multi-sig, spending limits, etc. Paymasters let users pay gas in tokens by having the paymaster contract cover fees. Account validation returns a special “magic” success value (typically 0x00000000) to signal correctness.

---

### ❓ Why It Exists

On Ethereum L1, only Externally Owned Accounts (EOAs) can initiate transactions and only one key controls them, so wallets are inflexible (no built-in multi-sig, gas abstraction, etc.). User operations like token payments or batching require clunky workarounds. zkSync AA integrates wallet logic into the rollup protocol to solve these issues. By letting accounts have code, zkSync solves problems like: enabling social recovery, multi-sig, or session keys; paying fees in ERC20 tokens via paymasters; and combining contract logic with normal transactions.

---

### ⚙️ How It Differs

Unlike a plain EOA (just a private key), a zkSync smart account is a contract with custom code. Unlike ERC-4337 (an Ethereum user-land AA standard), zkSync’s AA is built into the protocol. For example, zkSync uses a single unified transaction flow for both EOAs and smart accounts (no separate mempool or bundlers). All accounts on zkSync (even ETH accounts) act like smart contracts supporting AA features and paymasters. In contrast, ERC-4337 relies on an external “EntryPoint” contract and a separate user-op pool. zkSync’s AA is therefore more efficient and seamless in the protocol.

---

### 👥 Who Interacts

Wallets (users) and dApps use AA by deploying or using smart account contracts. The user (or their wallet software) constructs a transaction struct, signs it, and submits it to the node. The zkSync sequencer (operator) collects and batches these transactions. The Bootloader (a special system component at address 0x8001) processes each transaction: it calls the account’s validateTransaction code, then calls its executeTransaction code. System contracts like NonceHolder, MemoryTransactionHelper, and SystemContractsCaller assist in this flow (e.g. managing nonces and hashing). Paymaster contracts may also be invoked if a transaction uses them.

---

### 🚀 Problems Solved

Native AA on zkSync makes wallets far more flexible and user-friendly. It removes the need for a separate sponsoring EOA for smart contracts, enables gas payments in tokens (via paymasters), and allows innovative features like multisig, time locks, and rate limits at the protocol level. It also improves security by requiring an explicit validation pass (with an enforced success “magic” value) before execution. In short, zkSync AA is designed to make account management as flexible as smart contracts, while retaining seamless transaction flow and Ethereum compatibility.

---

### 🧒 Child Explanation

Imagine a magic wallet that’s also a mini-computer. On regular blockchains, wallets are like simple piggy banks opened by a secret key. But zkSync’s AA makes every wallet smart. A smart wallet can follow rules (like “only let mama open it” or “must have two keys open it”). It even allows someone else (a paymaster) to pay for gas. It’s like giving every wallet a robot helper inside it. This helps everyone do more cool things with their money easily.

---

## 📖 Story Analogy

Think of a bank with two types of vaults. In Ethereum’s world, most people have simple vaults (EOAs) that only the owner’s key can open, and some special vaults (smart contracts) that need special actions. zkSync turns all vaults into “smart vaults” from day one. Each vault can have programmable guards (like multi-sig owners, emergency locks, or even someone else promising to cover fees). It’s like upgrading every person’s wallet into a small programmable safe with special features.



---
---

# 2️⃣ 🧩 Core Architectural Components

Below are the main moving parts of zkSync Native AA. For each, we explain what it is, why it’s there, who interacts with it, and how failures or attacks might happen.

---

## 🏗 System-Level Components
---

### 🤖 Bootloader

#### 🔹 **What:**

The Bootloader (at formal address `0x8001` [9]) is the protocol’s core execution engine. It’s a special built-in component that takes in a batch of transactions and processes them in order [10][11]. It’s not a deployable contract; its code and state are fixed by system upgrades.

---

#### 🔹 **Why:**

It implements the entire transaction protocol for zkSync: reading operator inputs, validating transactions, executing them, and writing block state [10]. Think of it as the “master executor” that enforces all rules.

---

#### 🔹 **Who Calls It:**

The sequencer (L2 node operator) populates the Bootloader’s memory with transactions and then invokes its `run_prepared` function [12]. No user directly calls the bootloader – it’s implicitly run on each block.

---

#### 🔹 **How It Works:**

On each transaction, the Bootloader:

- (a) checks the transaction type and format [13]
- (b) calls the target account’s `validateTransaction()` method
- (c) marks the nonce in `NonceHolder`
- (d) deducts fee (possibly via a paymaster)
- (e) calls `executeTransaction()`
- (f) tallies gas and pubdata costs [14][15]

---

#### 🔹 **Fail/Bail Outs:**

If any validation step fails (e.g. wrong signature, used nonce, wrong magic value), the Bootloader reverts the entire transaction (no state change, no fee charged) [16][3]. During execution, if the account call reverts, the transaction is still included in the block (as “failed”) and the user still pays gas used [15].

---

#### 🔹 **Bypass Risks:**

Because the Bootloader is part of the protocol, users cannot bypass it. All transactions must go through it. If Bootloader logic were wrong (a protocol bug), that could break security, but it’s trusted code.

---

#### 🔹 **Attack Surface:**

Very limited at L2 – only the sequencer interacts directly by supplying transactions. A malicious sequencer could reorder or censor transactions. Otherwise, attacks against Bootloader would be catastrophic (the attacker becomes the operator).

---

#### 🔹 **Defenses:**

The Bootloader’s correctness is protected by zk proofs and L1 rollup contracts. Its address is hard-coded in the protocol, and many invariant checks (like transaction formatting and magic value checks) are hardcoded in its code. No contract code can impersonate the Bootloader’s special behavior.

---

#### 🔹 **Opcode Level:**

The Bootloader runs with maximum memory and gas budgets. When it calls account code, it behaves like a normal contract call from address `0x8001`. (E.g. inside `validateTransaction`, `msg.sender` is `0x8001`.) It uses special checks (like validating `txType==113`) before processing [13].

---

### 🧒 Child Explanation

The Bootloader is like a robot cashier who takes your transaction slip and does everything step-by-step: checks your signature, takes your fee, and then carries out what you want. If something is wrong, the robot cancels the order. You never call the robot directly; it automatically processes all orders in a block.

---

### 📖 Story Analogy

• **Story Analogy:** Imagine a very strict bank clerk (the Bootloader) who handles every withdrawal or transfer. You write a withdrawal slip (transaction) and hand it to the clerk. The clerk checks your ID, your account balance, and the clerk’s own checklist of rules. If all checks pass, the clerk executes the withdrawal. If any check fails (wrong signature, used up nonce), the clerk tears up the slip. No one can skip the clerk – the clerk is the gatekeeper for all transactions.

---
---
## 🏛 System Contracts

These are special contracts deployed at reserved L2 addresses (starting from `0x8000…` range) that implement core protocol services [17][8]. They cannot be overwritten by normal contracts and are only callable with a special `isSystem` flag (to prevent malicious use). They include:

---

>### 🧾 NonceHolder


Stores and enforces each account’s nonce (transaction counter) [18]. Only the Bootloader (or contracts calling with `isSystem`) can mark a nonce used. Before validation, the Bootloader uses `NonceHolder.validateNonceUsage(address, nonce)` to ensure the nonce wasn’t used [19]. After successful validation, it marks it used. This prevents replay of transactions with the same nonce. If someone bypassed this, they could replay old txs; but Bootloader enforces it. Only code with `isSystem` can call the updating methods, so a malicious contract can’t cheat nonces. Internally, the NonceHolder simply tracks a number per account (as a mapping).

#### 🔹 **Child Explanation:**

NonceHolder is like a “ticket stub” collector. Each time you make a transaction, the system gives your account a ticket number (nonce). NonceHolder checks you haven’t used that ticket before and then tears it off (marks it used).

#### 🔹 **Story Analogy:**

Think of a queue where each person has a numbered ticket. NonceHolder is the ticket window clerk who verifies that your number is next and then punches it. No one else can punch the tickets (only the clerk).

---
---
>### 🧮 MemoryTransactionHelper


A library-like contract that helps pack and hash the `Transaction` struct in memory for signing [20]. It encodes the transaction fields into a bytes32 hash that the account must sign. The user’s wallet or account code calls `encodeHash(transaction)` to get the correct EIP-712 transaction hash. It ensures the hash covers all fields (type, from, to, gas, nonce, data, etc.) in the precise format the protocol expects [21]. If hashing were done incorrectly, signatures would verify wrong.

#### 🧒**Child Explanation:**

This helper is like a special calculator that takes all the details of your transaction and mixes them into one fingerprint (hash). You sign that fingerprint with your key. It makes sure everyone signs the exact same thing.

#### 🧾 **Story Analogy:**

Imagine writing your entire order (to/from, amount, fee, etc.) into a secret code wheel. MemoryTransactionHelper is the wheel that turns all those words into one secret code number. Only the owner has the key to sign off on that number.

---

>### 🧰 SystemContractsCaller


A library that accounts use to call system contracts with the required `isSystem` flag [8]. Because contracts can only call system contracts when this flag is set, `SystemContractsCaller` provides helper functions like `systemCallWithPropagatedRevert(gas, address, value, data)` that execute the call and automatically revert if it fails. For example, account code calls `SystemContractsCaller.systemCallWithPropagatedRevert(...)` to invoke `NonceHolder.incrementMinNonceIfEquals(nonce)` [22]. This ensures only authorized system calls (like updating nonces or deploying code via `ContractDeployer`) can happen. Bypassing this (e.g. calling a system address without the flag) will automatically revert.

---

#### 🧒 **Child Explanation:**

Think of SystemContractsCaller as the secret handshake. It lets your wallet contract knock on the special system-contract door and say “This is authorized!”. If you knock without the handshake, the door just slams shut (reverts).

---

#### 🧾 **Story Analogy:**

It’s like a master key card that lets you access guarded offices in a building (system contracts). Only with the master card (the `isSystem` flag) can you open those doors. Without it, the call is denied.

---
---
## 👤 Account-Level Components

### 📜 Account Contract

#### 🔹 **What:**

Every wallet address on zkSync is treated as an “account contract.” If an address has custom code deployed (via `createAccount`), that code is the account logic. If an address has no code, zkSync falls back to a `DefaultAccount` contract (an implicit EOA-like account) [23]. The account contract must implement the `IAccount` interface (methods like `validateTransaction` and `executeTransaction`) [24].

---

#### 🔹 **Why:**

This is the core of AA. The account’s code contains the custom rules for validation (e.g. ECDSA or multi-sig verification) and execution (what to do when a transaction is confirmed). It’s what lets users have programmable wallets.

---

#### 🔹 **Who Calls It:**

The Bootloader calls `validateTransaction(tx, txHash)` and `executeTransaction(tx)` on the account contract. Outside of these, nothing else should invoke these methods. If an account has no code, the DefaultAccount system contract handles those calls (making it behave like an EOA) [25].

---

#### 🔹 **If It Fails:**

If `validateTransaction` reverts or returns the wrong magic value, the Bootloader aborts the transaction [16][3]. If `executeTransaction` reverts, the transaction still ends up included as a failed tx and the user still pays gas [15].

---

#### 🔹 **If Bypassed:**

Because the Bootloader always calls into `validateTransaction`, an account cannot skip validation. If somehow a transaction reached `executeTransaction` without passing validation (shouldn’t happen in the protocol), it would be an invalid state. Accounts also should protect any internal entrypoints by insisting `msg.sender == BOOTLOADER` (for example, DefaultAccount’s fallback asserts that the Bootloader should never call it directly) [26].

---

#### 🔹 **Attack Surface:**

The account contract is user-written code, so its vulnerabilities are its own: bad signature checks, reentrancy bugs, insufficient gas, etc. A malicious user could try to exploit another account by tricking it, but typically each account only lets itself update its own state (via NonceHolder). Storage collision is negligible because system contracts use a separate address range. The main risks are in validation logic (e.g. signature malleability) or funds management (e.g. lost funds on revert).

---

#### 🔹 **Defensive Design:**

Accounts should follow best practices: use OpenZeppelin’s SignatureChecker or ECDSA libraries [27], carefully manage nonces with `SystemContractsCaller` and `NonceHolder` [22], and always return the correct magic (0x00000000) on success [20]. The protocol enforces many checks (nonce, signature, magic), so even buggy account code will fail safely (transaction reverts, no funds lost beyond gas).

---

#### 🔹 **Opcode Level:**

`validateTransaction` and `executeTransaction` are regular contract calls executed by the EVM under Bootloader’s context. Inside `validateTransaction`, typical operations include reading a signature (bytes) from memory/calldata, performing `ecrecover` (via the ECRECOVER precompile or Yul pre-deployed contract) [28], and calling system contract methods (using the special `isSystem` flag) to update nonce. All EVM opcodes (PUSH, MLOAD, MSTORE, CALL, SSTORE, etc.) behave normally under the EraVM.

---

#### 🔹 **Child Explanation:**

The account contract is like the brain of your wallet. It’s a custom piece of code that knows your rules: “Is this person allowed to spend my money?” or “Do these two friends both need to sign for a transaction?” The Bootloader (robot cashier) always asks your wallet’s brain: “Okay, is it okay to do this transaction?” (`validateTransaction`) and then, “Now do it.” (`executeTransaction`).

---

#### 🔹 **Story Analogy:**

Imagine each person has a special account vault that contains a small computer. When someone wants to use your vault, the bank’s machine (Bootloader) calls the vault’s computer to ask for approval. The vault’s computer can check a signature, ask for multiple keys, or enforce time locks. Only after it says “Approved!” (returns the magic code) does the machine move your money. If the vault computer says “Nope” (wrong magic or revert), the deal is canceled.

---

### ✍️ Signature Validation Logic:

#### 🔹 **What:**

The account’s `validateTransaction` function contains the code that checks the transaction’s signature and other rules. It typically recovers the signers (via ECDSA) and compares them to the account’s owner(s) or uses EIP-1271, returning `0x00000000` on success. For example, a simple EOA-like account might do:

`signer = ecrecover(txHash, v, r, s);`
`require(signer == owner);`
`magic = 0x00000000;` [29][30].

---

#### 🔹 **Why:**

The protocol itself can’t know what “valid” means for your account. It just enforces that something ran and returned success. So each account provides its own signature check (or other logic) to prove the sender is authorized.

---

#### 🔹 **Who Calls It:**

Only the Bootloader calls `validateTransaction` on the account. This is done exactly once per transaction (in the validation phase) [14]. (During fee estimation or simulation, the node might skip it, but on-chain it’s called once.)

---

#### 🔹 **Failure:**

If the logic inside detects a bad signature (or anything invalid), it either reverts or returns a wrong magic. E.g. many examples catch bad signatures and simply set `magic = bytes4(0)` instead of `0x00000000` [31]. The Bootloader treats that as a failure.

---

#### 🔹 **Bypass:**

An account could implement non-ECDSA schemes, but must still return the success magic. No one else is supposed to call `validateTransaction`, and the Bootloader insists it only runs once per tx.

---

#### 🔹 **Attack Surface:**

The main risk is signature malleability or misuse of ECDSA. For example, if the account code doesn’t enforce low-`s` values, an attacker might find two different signatures for the same hash (malleability). The `ecrecover` precompile enforces `v ∈ {27,28}` and `r,s < secp256k1n`, but it does not enforce low-`s`. High-`s` signatures are valid but “malleable”. Accounts should enforce `s <= n/2` to guard against it (OpenZeppelin’s ECDSA does this). If not, a malicious user might replay a transaction with a different valid signature and cause confusion.

---

#### 🔹 **Defense:**

Use well-tested libraries (e.g. OpenZeppelin’s SignatureChecker or ECDSA routines) [27]. Always compare the recovered address strictly to the intended signer(s) and return failure magic if anything mismatches.

---

#### 🔹 **Opcode Level:**

Usually, validation runs a series of loads and an `ECRECOVER` precompile call. For instance, `ecrecover` in zkSync is implemented as a system contract at address `0x0000…0001` [28]. The account places the hash, v, r, s on memory and then executes `CALL` to that address (like `staticcall(0x01,…)`). The precompile returns the address or empty bytes if invalid. The account code then compares it and sets the return data to the magic constant.

---

#### 🔹 **Child Explanation:**

The signature check is like the vault’s lock. If you have the right key (signature), the vault says “OK, proceed!” by returning the secret handshake code. If the key is wrong, the vault locks up and says “Nope.” The key check itself happens inside the vault (account contract).

---

#### 🔹 **Story Analogy:**

Picture a vault with fingerprint or keycard access. The person who owns the vault registers their fingerprint. When the bank machine asks “Is this owner inside?”, the vault checks the fingerprint. If it matches, the vault yells back “1234” (the magic code) and unlocks. If it doesn’t match, it stays silent or says a wrong code, so the bank clerk refuses.

---

### 🪄 Validation Magic Value:

#### 🔹 **What:**

A fixed 4-byte constant that an account must return from `validateTransaction` to signal success. In zkSync Era, this is `0x00000000` (ACCOUNT_VALIDATION_SUCCESS_MAGIC) [20][3].

---

#### 🔹 **Why:**

It’s a simple way for the Bootloader to know validation passed. Without it, the Bootloader treats the validation as failed. It standardizes the interface regardless of account logic (ECDSA, ERC-1271, custom).

---

#### 🔹 **Who Uses It:**

The account’s `validateTransaction` code returns this magic on success. The Bootloader checks it immediately after the call. Paymasters use a similar mechanism when validating sponsor logic.

---

#### 🔹 **Failure:**

If any other value is returned, the Bootloader throws an “invalid magic” error (transaction fails) [3]. For security, during local fee estimation, wallets might simulate validation but return wrong magic at the end so the simulation doesn’t actually publish. On mainnet, wrong magic means rejection.

---

#### 🔹 **Attack Surface:**

If an account mistakenly returns the wrong magic or executes wrong logic after deciding success, the transaction will fail even if it should have been valid. There’s no upside to returning the wrong magic – only accidental bugs. A malicious account could always refuse any transaction by returning the wrong magic, effectively freezing itself.

---

#### 🔹 **Defense:**

Ensure your code returns exactly `0x00000000` on true success, and not accidentally a different 4-byte value or no return data. Common libraries set `bytes4 magic = EIP1271_SUCCESS_RETURN_VALUE` or directly `0x00000000`. The ZK docs explicitly emphasize that the magic must be returned [20].

---

#### 🔹 **Opcode Level:**

At the end of `validateTransaction`, the code does `return magic`. If magic is wrong, the Bootloader’s next instruction sees it doesn’t match its expected constant and reverts. In the ZK VM, there’s a check opcode that compares the returned word to zero.

---

#### 🔹 **Child Explanation:**

The magic value is like a secret “thumbs-up” code the vault must shout when approving. If the vault doesn’t shout the exact code, the machine won’t proceed.

---

#### 🔹 **Story Analogy:**

Think of saying a secret password. Only if you say “open sesame” exactly does the door open. If you say anything else, the door stays shut. The account must say the secret password (magic value) to the Bootloader to move on.

---

### 🚀 Execution Phase:

#### 🔹 **What:**

After validation, the Bootloader calls `executeTransaction(Transaction calldata tx)` on the account [15]. In this call, the account is expected to perform the requested action (e.g. `CALL` another contract, deploy a contract, transfer funds, etc.). All gas and state changes happen in this phase.

---

#### 🔹 **Why:**

This separates “checking” from “doing.” Validation ensures everything is allowed; execution actually changes the state. This mimics Ethereum’s idea of first checking a signed transaction, then executing it.

---

#### 🔹 **Who Calls It:**

The Bootloader (if validation succeeded) invokes `executeTransaction`. It never calls this if validation failed. No external caller should invoke `executeTransaction` on a valid account (it must come only from Bootloader).

---

#### 🔹 **Revert Behavior:**

If the account’s `executeTransaction` reverts, the transaction is still included but marked failed [15]. All gas used up to that point is still paid by the user. State changes from the account’s external calls are reverted, but the failure itself is recorded (e.g. an event or status).

---

#### 🔹 **Gas Accounting:**

During execution, gas is consumed for every operation (as usual). At the end, unused gas is refunded to the payer (the account or paymaster). The Bootloader also accounts for pubdata gas: it tracks the number of bytes of L1 data the transaction produced and checks it against the provided `gasPerPubdataByteLimit`. If too much pubdata was used, the Bootloader will revert (as a protective check) [32].

---

#### 🔹 **Attack Surface:**

An account’s execution logic could accidentally run out of gas or hit an invalid opcode. This simply causes revert. A malicious account could also try to consume excessive gas or pubdata to grief the operator or others, but the Bootloader’s checks stop transactions that overuse pubdata gas [32]. Frontrunning is possible if someone sees a pending special transaction.

---

#### 🔹 **Defense:**

Accounts should set a reasonable `gasLimit` and compute correct `gasPerPubdataByteLimit` to avoid accidental OOG or pubdata failures. Also, use `require` / `revert` carefully inside `executeTransaction`, since any revert still means the account pays gas. The Bootloader’s built-in checks (post-execution pubdata check) protect against abusing pubdata.

---

#### 🔹 **Opcode Level:**

This call is a normal EVM CALL from address `0x8001` (Bootloader) into the account. Inside, opcodes execute like any contract call. For a simple payment, it might just do `address(dest).call{value: tx.value}(tx.data)`. Storage writes (SSTORE) or external calls may trigger more gas (including additional pubdata). At the end, the Bootloader asserts that the remaining gas covers the pubdata used: `(pubdataBytes * gasPerPubdata) <= gasLeft`.

---

#### 🔹 **Child Explanation:**

Execution is when the vault actually moves money or calls another contract. If during this step something breaks (like not enough gas, or a require-fail), the action is canceled but the clerk still charges you for the effort.

---

#### 🔹 **Story Analogy:**

After the clerk (Bootloader) approves your withdrawal, he gives you the money and you do whatever you wanted with it. But if during that step you change your mind or something goes wrong, you still spent time and gas, so you pay for it but nothing changes in your account.

---

### 💳 Paymaster (Optional):

#### 🔹 **What:**

A Paymaster is a smart contract chosen by the user to sponsor gas fees. If a transaction includes a paymaster address (and input), the Bootloader will call the paymaster’s `validateAndPayForPaymasterTransaction` during validation and `postTransaction` after execution [16][15].

---

#### 🔹 **Why:**

Paymasters enable gas payments in tokens or on behalf of users. For example, a DApp could be a paymaster that pays fees for its users.

---

#### 🔹 **Who Calls It:**

During validation, the Bootloader calls `paymaster.validateAndPayForPaymasterTransaction(tx)` with `isSystem=true`, and after execution it calls `paymaster.postTransaction(tx, actualGasCost)`. Only Bootloader calls these; account contracts do not.

---

#### 🔹 **Failure:**

If the paymaster’s validation reverts or returns wrong magic, the whole transaction is rejected (no one pays). If `postTransaction` reverts, that revert is included but user still pays execution gas.

---

#### 🔹 **Attack Surface:**

A malicious paymaster could steal fees or confirm invalid transactions, but it is required to run only during validation and/or cleanup. The protocol ensures that paymasters must deposit funds into the system ahead of time.

---
#### 🔹 **Defenses:**

Use robust paymasters. The protocol ensures paymasters abide by the magic return values and nonces just like accounts.

---

#### 🔹 **Child Explanation:**

A paymaster is like a friend who says “I’ll pay the fee.” The bank clerk asks your friend to approve paying gas. If the friend says “Yes” (right magic and checks), you don’t pay. If the friend is broke or lies, the transaction fails.

---

#### 🔹 **Story Analogy:**

It’s like asking a sponsor or benefactor to cover your fee. The bank machine checks with that sponsor’s contract instead of yours.

---

### 🧾 Transaction Struct and Fields:

#### 🔹 **What:**

Transactions on zkSync Era use a typed struct (similar to an Ethereum typed data) to pack all info. Main fields include: `txType` (must be 113 for native AA) [13], `from` (uint256 form of sender’s address), `to` (uint256 of destination), `gasLimit`, `gasPerPubdataByteLimit`, `maxFeePerGas`, `maxPriorityFeePerGas`, `paymaster` address, `nonce`, `value` (amount of ETH), `data` (calldata bytes), `factoryDeps` (array of bytecode hashes to pre-deploy), and `paymasterInput`. In addition, there are four reserved uint256 slots (`reserved[4]`) and a reserved dynamic field; for txType 113 these must all be zero [13].

---

#### 🔹 **Why:**

Packing into one struct allows signing all relevant parts and future extensibility. `txType=113 (0x71)` was chosen because Ethereum uses one byte and 113 fits in one byte; it signifies a ZK Era AA transaction [13][21]. From/to are stored as uint256 (address → uint160 → padded to 32 bytes) to simplify hashing under EIP-712. Reserved fields are placeholders for future use (currently zero) [13]. `factoryDeps` lets users include new contract code (by hash) needed for factory deployment; the system will verify those hashes are “known” on L1 [33]. The `gasPerPubdataByteLimit` parameter caps how much gas per byte of L1 data the user is willing to pay [21][32].

---

#### 🔹 **Who Sets/Uses It:**

The user (or wallet software) populates this struct when creating a transaction. The Bootloader reads these fields directly from memory during validation/execution. Contracts use `TransactionHelper` libraries to access fields.

---

#### 🔹 **Reserved Fields:**

For txType 113, the Bootloader requires all `reserved[0..3] = 0` [13]. (Older docs had `reserved0` as nonce, but now nonce is explicit.) If a user sets non-zero here, the transaction will fail the Bootloader’s type checks.

---

#### 🔹 **Factory Deps:**

If non-empty, the transaction must also include the bytecode whose hashes match these `factoryDeps`. The Bootloader/system contract `KnownCodeStorage` will mark them as known, possibly burning fees if they aren’t already on L1 [34]. If the hashes don’t match provided code, the transaction will revert.

---

#### 🔹 **Gas Accounting Fields:**

`maxFeePerGas` / `maxPriorityFeePerGas` behave like Ethereum’s EIP-1559 (though zkSync tips are usually zero) [35]. `gasPerPubdataByteLimit` is unique to zkSync: it multiplies by the pubdata bytes produced during execution (capped on gas left) [32]. The Bootloader enforces `(pubdataBytes * gasPerPubdata) ≤ gasLeft` before and after execution [32].

---

#### 🔹 **Failure:**

If any field is malformed (e.g. `txType ≠ 113` [13], or `from` not matching the signer, or `gasPerPubdataByteLimit` too low causing the pubdata check to fail [32]), the Bootloader will revert the transaction either in validation or execution.

---

>#### 🧒 **Child Explanation:**

>The transaction struct is like a filled-out form with many boxes: who’s sending, who’s receiving, how much money, fees, and other rules. Everything you need to describe the transaction goes into this form, and then the form gets hashed and signed. The reserved boxes are just blank spaces saved for future use (currently left at 0).

---

>#### 🔹 **Story Analogy:**

>Think of a boarding pass you must fill out before a flight. It has fields: “Passenger Name”, “Seat”, “Fare Class”, “Extra Baggage” (`factoryDeps`), etc. The Bootloader checks each field to make sure it’s valid (correct flight number = 113, etc.). If you scribble in the reserved “Comments” boxes (reserved fields), the clerk throws it back saying “Invalid”. If you try to cheat on your fare (gas limits) or sneak too many bags (too much pubdata without fee), security (the Bootloader) will stop you.

---

>#### 🧒 Child Explanation (after Section 2): 
>The system components are like parts of a magic vending machine. The Bootloader is the big robot inside that reads your ticket, checks everything, and gives you your candy (executes the transaction). The `SystemContractsCaller` and `NonceHolder` are like special drawers: only this robot can open them with a secret key to check your ticket number (nonce) and make sure it’s not reused. Your account contract is your own little computer box that has your special access rules (like fingerprints or extra keys). The robot always asks your box, “Is this ticket okay?” and only if your box says the secret password (magic number) does it let you get the candy.

---

>#### 📖 Story Analogy (after Section 2):

>Imagine a futuristic library. A patron (user) fills out a book request form (transaction struct) and submits it. The Librarian robot (Bootloader) takes the form and processes it: it first consults the Membership Checker (NonceHolder) to see if the patron’s request number is new. Then it goes to the patron’s Membership Box (account contract) and asks, “Can I approve this request?” The membership box runs its own program (maybe checking the patron’s fingerprint or some rules) and either returns the correct approval code (magic number) or denies. If approved, the librarian then carries out the request (execute the transaction). If anything goes wrong, the robot cancels the request. Each patron can even have a Helper (Paymaster) who pays for their book fee. The whole system is very strict – only the robot can access the special membership boxes and ticket checks, so no one can pretend to be the librarian or membership checker.

---

# 3️⃣ 🔄 Full Transaction Lifecycle (Step-by-Step)

Below is the journey of a transaction from creation to completion. Each step explains who does what, how calls are made, and what can go wrong.

---

### 📦 Pre-Transaction Phase

1. **Transaction Struct Creation:**

2. **Who:** The user or wallet software constructs the `Transaction` struct with all required fields (as above). For example, they set `txType=113`, `from` to their account, `to` the target address, `gasLimit`, fees, `nonce`, etc. They also fill in `factoryDeps` if deploying new code, and leave `reserved` fields at zero.

3. **How:** In code, this is typically a high-level struct or object. In Foundry/Ethers code, you might write `Transaction({txType: 113, from: myAddr, to: dest, …})`. The `from` and `to` are encoded as uint256(uint160(address)). Dynamic fields like `data`, `signature`, `factoryDeps`, `paymasterInput` are appended appropriately.

4. **EVM-level:** This step is done off-chain by the user, so no opcodes run yet. It results in a fully populated transaction object in memory.

5. **What Can Go Wrong:** The user could set wrong fields: e.g., choose `txType` other than 113, or forget to sign, or mis-encode their address. If `txType ≠ 113`, the Bootloader will reject it immediately [13]. If `nonce` is wrong (too low or already used), it will fail validation.

6. **Error Types:** None yet, since this is client-side. But potential mistakes include wrong data format or values.

7. **Avoiding Failure:** Wallets should validate input (correct chain ID, etc.) and follow the struct spec. Always use provided helpers or SDKs to ensure formatting.

> 8. **Child Explanation:** This is like writing down everything about your request on a form – who you are, what you want to do, and how much fee you’ll pay. You must fill each box correctly.
>9. **Analogy:** Filling out a library checkout card: you write down your name (from), book requested (to), how long you want it (gasLimit), and a special code (nonce).

---

### 🔐 Hash Encoding (`MemoryTransactionHelper.encodeHash`):

10. **Hash Encoding (`MemoryTransactionHelper.encodeHash`):**

11. **Who:** The wallet or account code computes a hash of the transaction for signing.

12. **How:** Using the `MemoryTransactionHelper` (or `TransactionHelper`) library, the code packs the transaction fields (txType, from, to, gas, gasPerPubdataByteLimit, max fees, paymaster, nonce, value, data, factoryDeps, paymasterInput) into a bytes32 hash via EIP-712-style encoding [21]. For example, in Solidity:  
   `bytes32 txHash = TransactionHelper.encodeHash(tx);`  
   This hash is what gets signed.

13. **EVM-level:** Still off-chain (or view execution), so no persistent state change. If done on-chain in `validateTransaction` (for fee estimation), it’s a purely computational step (memory and keccak operations).

14. **What Can Go Wrong:** If hashing misses a field or uses the wrong order/padding, the signature will be invalid. Also, chain ID or domain mismatches can cause different hash. If you sign the wrong hash, later `ecrecover` will not match the expected signer.

15. **Error Types:** N/A (client-side step). But an incorrect hash leads to a signature that fails to verify (see later).

16. **Avoiding Failure:** Always use the official helper library to encode the hash. Do not manually roll your own unless you understand EIP-712 and zkSync’s format.

>17. **Child Explanation:** This step is like taking all the words on your request form and turning them into a single secret code. You’ll sign that code so the system knows it’s really you.

>18. **Analogy:** It’s like having a special machine that reads your entire filled form and prints a secret stamp. You then sign that stamp.

---

### ✍️ Signature Creation:

19. **Signature Creation:**

20. **Who:** The user’s private key (via their wallet) creates an ECDSA signature of the hash from step 2.

21. **How:** Typically, the wallet calls `ecrecover` with `(hash, privateKey)` to produce `(r, s, v)`. It then packs these into a 65-byte `signature` (usually `abi.encodePacked(r,s,v)` with `v` as the last byte) [27]. Some wallets add 27 to `v` if needed.

22. **EVM-level:** This is off-chain. On-chain (inside `validateTransaction`), the code will verify the signature but signing itself happens off-chain.

23. **What Can Go Wrong:** Common mistakes: putting `v` in front instead of at end, not adding 27/28 correctly, or using the wrong hash (see above). Also, Ethereum’s signature may use `0/1` for `v` while zkSync’s `ecrecover` expects `27/28`. If `s` is not in the lower half-order, the signature is malleable (though valid, it’s discouraged).

24. **Error Types:** A malformed signature will simply not verify. The account’s `validateTransaction` should catch it and return failure.

25. **Avoiding Failure:** Use libraries that encode the signature correctly. Ensure `v` is set to 27 or 28, not 0/1 (wallets often do this automatically). If you get a signature with `v = 0 or 1`, add 27.

>26. **Child Explanation:** You use your secret key to “sign” the secret code from step 2, producing a special seal (signature) that proves it’s really you.

>27. **Analogy:** Like stamping your unique seal on the secret code. If you stamp it upside-down or with the wrong ink, the clerk won’t accept it.

---

### 📡 Submission to Mempool / Node:

28. **Submission to Mempool/Node:**

29. **Who:** The user (via a wallet) sends the transaction to the zkSync node (sequencer) — either through an RPC call (`eth_sendRawTransaction`) or via the network.

30. **How:** The signed `Transaction` is serialized (often RLP or JSON) and broadcast. zkSync’s nodes will verify basic syntax and put it in the mempool.

31. **EVM-level:** None yet. The transaction is just queued in the off-chain mempool.

32. **What Can Go Wrong:** If the transaction is syntactically invalid (wrong RLP, missing fields, excessive size, gas costs insane), the node may reject it outright. Also, if fees or nonce are way off, it might be dropped later.

33. **Error Types:** The node might return errors like “Transaction format invalid” or “insufficient fee” immediately. Otherwise, it simply sits pending.

34. **Avoiding Failure:** Make sure to use the correct RPC endpoint and format. Check the mempool or your wallet’s tx status. Ensure fees and nonce are reasonable for inclusion.

>35. **Child Explanation:** It’s like handing the robot librarian your sealed request form. If it looks okay, the librarian holds onto it until it’s your turn.

>36. **Analogy:** Dropping a letter into the post box. If the letter’s envelope is damaged or postage wrong, the post office might refuse it. Otherwise, it goes into the mailbag (mempool) to be delivered.

---

## ⛓ Validation Phase (On-Chain)

#### 1. **Bootloader Receives and Processes:**

2. **Who:** The Bootloader starts processing the batch containing the transaction.

3. **How:** At the start of the block, the sequencer has loaded many transactions into Bootloader memory. The Bootloader’s loop picks the first pending transaction (by index) and begins its preflight checks [36][14].

4. **EVM-level:** Before each transaction, the Bootloader calls a built-in routine (in zkVM) to parse the transaction fields from memory. It ensures correct `txType==113` and that the reserved slots are `0` [13]. If this fails, the tx is rejected immediately.

5. **What Can Go Wrong:** If the operator (sequencer) mistakenly formatted the tx memory, or if `txType` or `reserved` are wrong, the Bootloader will abort the transaction at this stage. It would revert the transaction (it would not be included).

6. **Error Types:** Likely Bootloader-level “invalid transaction format” revert.

7. **Avoiding Failure:** Sequencers must correctly prepare the memory. Users ensure the JSON/RLP they sent matches the expected fields (wallets usually do).

>8. **Child Explanation:** The clerk (Bootloader) picks up your request and double-checks that the form is filled in the right boxes. If something’s in the wrong box, the clerk stops right away.

>9. **Analogy:** The librarian robot scans the card’s header to verify it’s the right type of request. If it says “BOOKBORROW TYPE” instead of “MOVIEBORROW,” the clerk tosses it.

---

#### 10. **Bootloader Calls `validateTransaction()`:**

11. **Who:** The Bootloader calls the account contract’s  
   `validateTransaction(Transaction tx, bytes32 suggestedSignedHash)` method [37]. It may supply the hash it expects (from step 2) or let the account recompute it.

12. **How (CALL vs DELEGATECALL):** It is a normal CALL. The Bootloader executes an EVM CALL to the account address. Inside `validateTransaction`, `msg.sender` is `0x8001` (the Bootloader’s formal address). The `isSystem` flag is off for this call (validation is a normal user-level call).

13. **EVM-level:** The account’s code runs in the EraVM environment. It should do things like check the nonce and signature. For example, a call to  
   `NonceHolder.incrementMinNonceIfEquals(nonce)`  
   is done with `isSystem=true` (see system next step). Then it recovers signature via ECRECOVER and compares addresses [22][30]. Finally, it returns `0x00000000` if valid.

14. **What Can Go Wrong:** Many things:  
   • If the account code calls any forbidden operation (like writing to non-system storage), it’ll revert.  
   • If it runs out of gas mid-check, it’ll revert.  
   • If the signature doesn’t match, it should return failure (magic=0).  
   • If the nonce doesn’t match (checked below), it will revert or fail the increment check.  

15. **Error Types:** The account can explicitly `revert("Bad signature")` or implicitly OOG. The Bootloader might capture a revert and label it “validation revert: account validation error”. If the account returns wrong magic, the Bootloader itself reverts with “invalid magic value”.

16. **Avoiding Failure:** Accounts must implement correct logic. Users must sign the correct hash with the true owner key, and ensure the `nonce` field matches their intended next nonce. Provide enough gas for validation.

>17. **Child Explanation:** The librarian robot now asks your vault (account) “Is this request OK?” The vault runs its check quietly. If everything’s right, it returns the thumbs-up code. If anything’s wrong (bad key, wrong number), it refuses.

>18. **Analogy:** The robot calls the vault’s security panel. The panel checks the fingerprint and prints a green light if it matches. If the panel is broken or the fingerprint is wrong, it prints red and doesn’t approve.

---

#### 19. **Nonce Validation:**

20. **Who:** The Bootloader (via `NonceHolder`) checks the nonce. Specifically, before or during validation, the Bootloader ensures the account’s nonce isn’t already used [14][19].

21. **How:** The Bootloader calls  
   `NonceHolder.validateNonceUsage(account, tx.nonce)`  
   with `isSystem=true`. If it’s unused, it proceeds. After `validateTransaction`, the Bootloader (or the account) calls  
   `NonceHolder.incrementMinNonceIfEquals(account, nonce)`  
   (using `systemCallWithPropagatedRevert`) to mark it used [22].

22. **EVM-level:** These are system calls. Under the hood, `NonceHolder` maintains a mapping of nonces. `validateNonceUsage` does a read (if in SEQUENTIAL mode, it might check equality; in ARBITRARY mode it checks unused). `incrementMinNonceIfEquals` writes to storage inside `NonceHolder`. Both require `isSystem` or the call library.

23. **What Can Go Wrong:** If the nonce is already used or incorrect under the account’s ordering scheme, `validateNonceUsage` will cause a revert. If the account fails to call `incrementMinNonceIfEquals`, the nonce won’t advance and a replay attack could occur. If an attacker tries to reuse a nonce, the Bootloader catches it.

24. **Error Types:** “Nonce already used” reverts from `validateNonceUsage`, causing the whole transaction to fail validation. If an account tries to set an unexpected nonce (like jumping up), it will revert inside `incrementMinNonceIfEquals`.

25. **Avoiding Failure:** Always specify the correct next nonce in your transaction. Use `systemCallWithPropagatedRevert` properly in your `validateTransaction` to update the nonce exactly once. Don’t try to reuse or skip nonces unless your account supports ARBITRARY ordering.

>26. **Child Explanation:** The librarian checks a big ledger (`NonceHolder`) to see if this request number has been used. If someone already borrowed with ticket #5, you can’t use #5 again. The librarian then stamps your ticket as used so it can’t be reused.

>27. **Analogy:** It’s like tickets in a raffle. `NonceHolder` is the raffle ticket counter. You can’t draw ticket #7 twice. The librarian first checks if ticket #7 is still in the box; if it is, he pulls it out so no one else can use it.

---

#### 28. **Signature Recovery:**

29. **Who:** The account code recovers the signer’s address from the signature.

30. **How:** Inside `validateTransaction`, the account executes something like:(Note : we can use diff sig rcovery function too, but it all boils down to the same thing tho, see ECDSA for more info, google it or open my code base and see AccountZKAA.sol)

```solidity
address recovered = ecrecover(txHash, v, r, s);
if (recovered != owner) { magic = 0; } else { magic = 0x00000000; }
```
where `txHash` is the hash from step 2 [30]. `ecrecover` is a precompile at address `0x000...0001` [28] (the account simply uses the Solidity `ecrecover()` function).

31. **EVM-level:** The ECRECOVER precompile is called via a `staticcall` from the account contract. The account code sets up memory with the 32-byte hash, 32-byte `v`, `r`, `s` and executes the precompile. The zkSync system contract then returns either empty bytes (if invalid) or the 20-byte signer address padded to 32 bytes [28].

32. **What Can Go Wrong:** If the signature doesn’t match (`r`, `s`, `v` or `hash`), `ecrecover` returns `0x0` or a wrong address. The account should then fail validation. If `v` is not 27/28, the precompile considers it invalid. If `r` or `s` are out of range, the precompile rejects.

33. **Error Types:** If the account code does not explicitly check, a wrong signature could slip by. But good code will check `recovered == expectedOwner`; if not, it will set `magic=0` or revert. The outcome is that Bootloader rejects the tx.

34. **Avoiding Failure:** Sign the correct hash with the right private key. Use `ecrecover` carefully: for example, OpenZeppelin’s `ECDSA.recover` returns the correct address and handles `v` normalization. Make sure to compare to all authorized owners in multisig cases.

>35. **Child Explanation:** The vault’s fingerprint scanner tries to figure out whose fingerprint (public key) was in the signature. If it matches the owner’s fingerprint, good; otherwise it fails.

>36. **Analogy:** The librarian robot calls out “Who signed this form?” The vault replies “It was Alice!” If Alice isn’t the owner on record, the librarian cancels the request.
---
37. **Magic Value Return:**

38. **What Happens:** If validation succeeded, the account function returns the 4-byte success magic `0x00000000` [20].

39. **Handling:** The Bootloader checks this return value. If it is exactly `0x00000000`, it considers validation successful and proceeds [3]. If not (including if the account returned nothing or a different value), the Bootloader reverts with “invalid magic value”.

40. **Error Types:** Returning any other value (or running out of gas before returning) is treated as a validation failure. The transaction is aborted with a special error.

41. **Avoiding Failure:** Ensure your code returns the exact success magic. Do not accidentally revert too late or forget to return anything.

42. >**Child Explanation:** The vault must shout “OPEN” (in code) to let the library know everything’s okay. If it shouts anything else, the library robot says “Nope” and cancels.

43. >**Analogy:** It’s like having a secret passphrase. Unless you say “Open Sesame” exactly, the door stays shut.
---
44. Validation Result Handling:

45. **Who:** The Bootloader handles the outcome of validation.

46. **How:** If the account returned the correct magic, the Bootloader marks the nonce used (as above), charges fees (either debiting the account’s ETH balance or coordinating with the paymaster), and proceeds to execution [16]. If the magic was wrong or a revert occurred, the Bootloader aborts the transaction: it does not charge any fees, and the transaction will not be included in a block.

47. **Error Types:** You might see errors like “Account validation error: returned invalid magic value” or “validation reverted”. Out-of-gas in validation also simply aborts.

48. **Avoiding Failure:** If validation fails, re-check signature, nonce, and code. Ensure enough gas was given for validation.

>49. **Child Explanation:** The librarian robot decides: if the vault approved, he stamps the ticket and takes the fee. If not, he tears up the ticket and you get nothing (and pay nothing).

>50. **Analogy:** After checking everything, the bank clerk either proceeds or sends you away. If you passed the test, he takes the money; if not, he throws the receipt away without a refund.

---

### **Execution Phase:**

#### ***1. Bootloader Calls `executeTransaction()`:***

• **Who:** The Bootloader (since validation passed) invokes the account’s `executeTransaction(Transaction tx)` method [15].

• **How:** Normal CALL from address `0x8001`. The account’s code will now do whatever the transaction requested. This might be a simple ETH transfer (`transfer` if `to` is just a normal address, or a contract `CALL` if `to` is a contract, or even a `CREATE` if `to` is zero). If it’s a contract create, the language/compiler will invoke the special `ContractDeployer` system contract under the hood.

• **What Happens:** All state changes (transfers, storage writes, contract calls) happen now.

For example:
• If it’s a token transfer, `executeTransaction` might do  
  `IBEP20(to).transfer(recipient, amount)`.

• If it’s a contract call, it does  
  `(bool success, ) = to.call{value: tx.value}(tx.data);`

• If it’s a create, it uses the system contract `ContractDeployer` (likely via a library call).

• **What Can Go Wrong:** The account’s execution logic itself might revert (e.g. an internal `require` failure or OOG). The called destination contract could revert. If the account has custom logic (like a multisig check before calling), it could also fail there. Importantly, even if execution reverts, the transaction is still included in the block (just marked failed) [15].

• **Error Types:** Standard EVM errors apply: `revert`, `assert`, `InvalidOpcode`. Also, if gas was not enough, you get an out-of-gas. Pubdata check might trigger a revert here (if too much data was written) [32].

• **Gas Risks:** The account must be careful with gas: e.g., if it tries to do a very heavy loop or multiple external calls, it might run out. The Bootloader provided `tx.gasLimit`, so if that’s too small, the transaction OOGs here.

• **Avoiding Failure:** Provide a sufficient `gasLimit` and `gasPerPubdataByteLimit` when creating the tx. Keep execution logic efficient.

>• **Child Explanation:** This is the moment the vault actually opens and does what you asked: takes money out, calls another friend, or creates a new vault. If something breaks inside, it just stops and you pay for the attempt.

>• **Analogy:** The librarian acts on your approved request. He either hands you the book, or if something goes wrong (book not found), he tries but can’t, and marks it as a failed request (you still paid for looking).

---

#### ****2. State Changes Occur:***

• **What:** The state updates as instructed by `executeTransaction`: balances move, storage is written, logs/events are emitted. All computational gas and pubdata cost is accumulated.

• **Pubdata Cost:** After execution, the Bootloader calculates how many bytes of L1 “pubdata” were generated by your operations (e.g., storage writes, logs, code deployments). It multiplies by `gasPerPubdataByteLimit` and ensures it did not exceed the gas left after computing execution gas [32]. If this final check fails, the transaction is reverted (so no state changes are kept), and the user still loses the gas (but it won’t be included). This protects the L1 data from overspending.

• **GasConsumption:** All gas used (calc. opcode gas + pubdata cost) is subtracted from the sender/paymaster’s pre-paid amount. If `executeTransaction` created new contracts, those `factoryDeps` costs have been handled by `KnownCodeStorage`.

• **Revert:** If any revert happened, any state changes done inside `executeTransaction` are rolled back. However, logs/events from the failed execution are still part of the transaction’s pubdata, and fees are consumed.

>• **Child Explanation:** Now the vault moved the money or wrote the info. If it tried and changed some counters, those are written down. But if a fire happened inside (revert), everything goes back as if it never happened.

>• **Analogy:** After the librarian executes the action, the books are on the desk. If the book was out of stock and he tries to process it, he refunds it in his computer. Either way, the attempt is logged.

---

#### ***3. Post-State Updates:***

• **What:** Any final steps are done. For example, if a paymaster was used, the Bootloader calls `paymaster.postTransaction` to let it do cleanup (refund leftover, etc.) [15]. No additional state is changed for the account itself. The nonce is already incremented.

• **Gas Accounting:** Unused gas is refunded to the payer (unless consumed by fee). The effective fee (`gasSpent * effectiveGasPrice`) is transferred out to the L1 fee collector (Bootloader’s balance) [12].

>• **Child Explanation:** Finally, any helpers (like the friend paying your fee) tidy up and give change back. The librarian robot tallies up the total gas spent and your account gets any gas change.

>• **Analogy:** The librarian finishes the transaction and accounts for all costs. If someone sponsored your fee, the sponsor might get back unused fee money.

---

#### 4. Gas Accounting Finalization:

• **What:** The Bootloader wraps up the transaction. It records its status (success or failure). It also finalizes the L1 proof context (adding fees to L1 submissions). Then it moves to the next transaction in the batch.

>• **Child Explanation:** The librarian robot puts a stamp on your receipt showing “Done” or “Failed” and moves to the next request in line.

>• **Analogy:** It’s like the machine closing out the transaction on its register and then readying the next customer’s order.
---
---
---

#  4️⃣   🚨Failure Matrix

| ⚠️ Scenario | ❌ Why It Fails | 📍 Where It Fails | 💥 Error Type | 🛡 Prevention |
|-------------|----------------|------------------|--------------|--------------|
| 🔑 Wrong signature | Signature doesn’t match account key | `validateTransaction` (account) | Revert or magic≠success | Sign correct `txHash`, key, format |
| 🔢 Wrong nonce | Nonce used or out-of-order | `NonceHolder` or increment call | Revert ("Nonce used") | Use correct next increment properly |
| 🧾 Wrong txType | Must be 113 for native AA | Bootloader (initial check) | Revert ("Invalid txType") | Set `txType=113` |
| ⛽ Wrong gas limits | Gas under- or over-estimated | During execution or pubdata check | OOG (during exec) or Revert (pubdata check) | Provide sufficient `gasLimit`; correct `gasPerPubdataByteLimit` |
| 👤 Wrong sender (`from` field) | Signature key ≠ `from` address | `validateTransaction` (account) | Revert or magic≠success | Ensure `from == signerAddress` |
| 🏗 Bootloader misuse | Calling from wrong address | Account fallback or verify (DefaultAccount checks) | Assert fail | Only Bootloader calls validate/execute |
| 🧱 System contract call failure | e.g. `NonceHolder` revert, or `ContractDeployer` revert | In account code (Nonce increment call) | Revert (propagated by systemCall) | Provide correct nonce; use `SystemContractsCaller` |
| ⚙️ InvalidOperand / OOG | Math error or out of gas | Any EVM op (validate or exec) | REVERT or OOG | Check arithmetic; provide sufficient gas |
| 🖊 Signature packing issues | Wrong order (`r,s,v`) | `validateTransaction` | Revert or invalid recover | Use correct `abi.encodePacked` |
| 🌐 Chain ID mismatch | Wrong domain for signature | Probably off-chain (wallet) | Signature verify fail | Include correct chain ID hashing (if used) |
| 🧪 Version mismatch (Foundry) | Foundry vs Foundry-zksync differences | Hard to pin; scripts fail | Various test errors | Use correct zkSync config/version |
| 🔁 Replay attempt (same chain) | Nonce already used | `NonceHolder.validateNonceUsage` | Revert ("Nonce used") | Use unique nonce |
| 🌍 Replay attempt (cross-chain) | No EIP-155 style check in zkSync; must rely on chainID in wallet | Off-chain/invalidation | Depends (signature still valid if same key) | Use unique context; protection manually |
| 🏭 Factory deps issues | Unknown or mismatched bytecode hashes | `ContractDeployer` / `KnownCodeStorage` | Revert | Include correct bytecode hash; ensure L1 availability |
| 💰 Paymaster failures | Paymaster returned wrong magic or OOG | `validateAndPayForPaymasterTx` | Revert or magic fail | Ensure paymaster deposit are correct |
| 🧩 Magic value mismatch | Account didn’t return `0x00000000` | Bootloader post-validate | Revert ("invalid magic") | Return correct magic success |
| 📦 GasPerPubdata miscalculation | Too much pubdata for given limit | Pubdata gas check (Bootloader) | Revert (tx rejected) | Estimate pubdata; set adequate limit |

---
---
# 5️⃣ 🛡 Security & Attack Surface Analysis

## 🔐 Signature Malleability

- **👤 Who Attacks:** Malicious signer or attacker who obtains a valid signature.
- **⚙️ How:** They take a valid ECDSA signature (`r,s,v`) and flip `s' = n - s` or toggle `v (27↔28)`, producing another signature for the same hash. In zkSync’s `ecrecover`, high-`s` signatures and both `v` values are accepted (only 27/28 allowed). So a different but valid signature still passes recovery.
- **🎯 Target:** Confusion or replay (same tx hash with different sig). Could allow replaying a valid transaction by re-sending an alternate signature.
- **💣 Consequence:** Duplicate execution if nonce not consumed twice; more dangerously, some signature schemes (like multisig) that expect distinct keys might confuse logic.
- **🛡 Defense (zkSync):** The protocol itself does not forbid malleable signatures (it mirrors Ethereum’s precompile). The account MUST enforce low-`s` and canonical `v`. For example, OpenZeppelin’s `ECDSA` library rejects high-`s`.
- **🧠 Account Implementation:** Use EIP-2 rule: require `s <= secp256k1n/2`. Only accept `v = 27 or 28`. If not, reject. `SignatureChecker` or `ECDSA` libraries handle this.
>- **🧒 Child Analogy:** It’s like having two keys that look almost the same. If you allow either key to open, someone might sneak in twice. To prevent that, you should specify exactly which key (low-`s`) is the right one.

---

## 🔁 Replay Attacks (Same Chain)

- **👤 Who:** An attacker observing a valid signed tx.
- **⚙️ How:** They try to rebroadcast the same transaction again (or one with different `v` producing the same hash).
- **🎯 Target:** Double-spend or repeat a transaction’s effect.
- **💣 Consequence:** If nonce were not managed, the second tx would duplicate actions (e.g. pay again).
- **🛡 Defense (zkSync):** The `NonceHolder` ensures each `(account, nonce)` pair is only used once. Once an account’s nonce is consumed, any replay is immediately blocked at validation.
- **🧠 Account Role:** In `validateTransaction`, always increment the nonce by calling the system contract. Do not allow skipping or reusing.
>- **🧒 Child Analogy:** It’s like marking your ticket as used. The system will not accept the same ticket twice.

---

## 🌍 Replay Attacks (Cross-Chain)

- **👤 Who:** Same signed transaction submitted to multiple zkSync chains (e.g. mainnet vs testnet) if keys reused.
- **⚙️ How:** An attacker takes a user’s signed tx from one chain and tries it on another zkSync chain. zkSync Era does not include a chain ID in the signature by default (unlike EIP-155).
- 🎯 **Target:** Could try to spend the user’s funds on a different chain without permission.  
- 💣 **Consequence:** If the account and nonce are not already used on that chain, it would execute there too — double-spend across chains.  
- 🛡 **Defense:** None at protocol level (since no chain ID is enforced). Users should use different keys or prefix chain info in their custom validation. Some apps include chain context in what they sign (e.g. use a domain separator).  
- 🧠 **Account Role:** They may incorporate a chain ID check in `validateTransaction` manually.  
>- 🧒 **Child Analogy:** It’s like having a universal key. To prevent misuse on a different door, we recommend adding a label (like “Test Door” vs “Main Door”) to ensure it only opens the intended vault.  

---

## 🔄 Nonce Reuse (Underflow/Overflow)

- 👤 **Who:** Account itself or an attacker (e.g. by calling the nonce contract incorrectly).  
- ⚙️ **How:** Trying to bump the nonce backward or overflow.  
- 🎯 **Target:** Could allow old nonces to become valid again.  
- 💣 **Consequence:** Similar to replay: old tx might replay. Nonce increasing by too much could skip numbers.  
- 🛡 **Defense:** `NonceHolder` only allows certain operations (typically increment-by-1). There’s no public function to decrement. The contract is carefully written (e.g. it doesn’t expose arbitrary `setNonce` functions).  
- 🧠 **Account Role:** Don’t expose non-system functions to set nonce. Always use the `incrementMinNonceIfEquals` pattern which only increments if matching expected.  
>- 🧒 **Child Analogy:** Once the ticket is taken, there’s no way to give that ticket number back or use a smaller one.  

---

## 🧱 System Contract Spoofing

- 👤 **Who:** A malicious contract or user.  
- ⚙️ **How:** Attempting to impersonate a system contract by creating a normal contract at a reserved address or calling it without proper flag.  
- 🎯 **Target:** If possible, they might try to call `NonceHolder` methods as a normal user, or pretend to be `Ecrecover`, etc.  
- 🛡 **Defense:** zkSync reserves an address range for system contracts (starting at `0x8000...`). Normal user accounts cannot deploy code there. Additionally, `SystemContractsCaller` ensures calls to system addresses use `isSystem`, and direct calls without the flag are forbidden.  
>- 🧒 **Child Analogy:** It’s like having locked rooms for staff only. You can’t build your own door in the staff area or pretend to be staff — only the administrator (Bootloader) has keys.  

---

## 🏦 Bootloader Spoofing (Calling from Wrong Address)

- 👤 **Who:** User contracts or attackers.  
- ⚙️ **How:** Trying to call `validateTransaction` or `executeTransaction` as if they were the Bootloader.  
- 🎯 **Target:** They could trigger account logic outside the intended flow. For example, DefaultAccount’s fallback function explicitly asserts `msg.sender != BOOTLOADER` [26].  
- 🛡 **Defense:** The Bootloader’s address (`0x8001`) is special. If an account relies on `msg.sender == 0x8001` to do something, it’s safe because no normal contract has that address. DefaultAccount is coded to reject calls from `0x8001` to its fallback, ensuring Bootloader only calls the specific validation functions.  
>- 🧒 **Child Analogy:** Only the main clerk can hit the “execute” button on your vault. No one else can pretend to be the clerk.  

---

## 🗄 Storage Collision Risks

- 👤 **Who:** Account contracts vs system contracts.  
- ⚙️ **How:** Possibly if an account accidentally uses the same slot/contract as a system contract. But system contracts are at distinct addresses.  
- 🛡 **Defense:** System contracts like `NonceHolder`, `Ecrecover`, `KnownCodeStorage` all live at their own special addresses [28][34]. User accounts at ordinary addresses have separate storage. No collision.  
>- 🧒 **Child Analogy:** Everyone has their own locker number range. System lockers (0x8000s) are kept in a different hallway so nobody mixes up lock contents.  

---

## 🔁 Upgradeability Risks

- 👤 **Who:** Protocol developers (for system contracts) or account developers (for their contracts).  
- ⚙️ **How:** System contracts can only be upgraded by a governance-defined upgrade process on L1 [38]. Normal accounts could implement self-destruct or `delegatecall`, but that’s user code risk.  
- 🛡 **Defense:** zkSync’s system contracts are immutable except by explicit system upgrades. Accounts are responsible for their own update logic.  
>- 🧒 **Child Analogy:** The main office computers can only be updated by the central IT team (very controlled). Your personal vault can be changed only by you (owner’s code).  

---

## ⛽ Gas Griefing

- 👤 **Who:** Malicious user of an account.  
- ⚙️ **How:** Exaggerating `gasLimit` to manipulate some fee or forcing others’ txs to pay more. Possibly by setting extremely low `gasPerPubdataByteLimit` to fail someone else’s block (though you only affect yourself).  
- 🎯 **Target:** Usually yourself – this mostly causes your own tx to fail or cost more. No one else pays for your nonsense.  
- 🛡 **Defense:** The Bootloader disallows transactions that violate pubdata limits [32], so even if you try to drown the chain in data, your tx simply won’t be included or will revert. You ultimately pay the cost.  
>- 🧒 **Child Analogy:** If you try to cheat by buying an unlimited jumbo drink (huge `gasLimit`) to game the system, the cashier will just cancel your order if it’s unrealistic.  

---

## 📌 Invalid Opcode Attacks

- 👤 **Who:** Malicious account code or user.  
- ⚙️ **How:** Intentionally execute an undefined opcode in `validateTransaction` or `executeTransaction`.  
- 📉 **Outcome:** The transaction will revert (like an exception). Bootloader will treat it as a failed tx. The user loses gas.  
- 🛡 **Defense:** No special proto-level defense; it’s up to contract code to avoid invalid opcodes. Usually doesn’t happen in normal Solidity code.  
>- 🧒 **Child Analogy:** If your vault tries to do something nonsensical, it simply crashes and locks up.  

---

## 🏃 Frontrunning

- 👤 **Who:** Sequencer/operator or anyone who sees the mempool.  
- ⚙️ **How:** Observing a pending transaction (e.g. DEX trade) and submitting a similar or sandwich transaction.  
- 🎯 **Target:** Funds, better gas price, MEV.  
- 🛡 **Defense:** This is a general blockchain issue. zkSync does not have built-in front-running protection. Users or apps must rely on countermeasures (like setting slippage or managing nonces carefully).  
>- 🧒 **Child Analogy:** Like someone seeing you order a hot chocolate and quickly ordering their own to beat you (on-chain trading front-run).
---
## 💰 MEV Opportunities:

- 👤 **Who:** Miner/sequencer.
- ⚙️ **How:** Similar to above, they might reorder transactions or insert their own to extract value.
- 🎯 **Target:** Profits from trades, arbitrage on DEX, etc.
- 🛡 **Defense:** zkSync merges all txs into large batches, but ordering within a batch is still the sequencer’s privilege. No inherent prevention.
>- 🧒 **Child Analogy:** The librarian robot might rearrange people in line for his own benefit.

## 💳 Paymaster Exploits:

- 👤 **Who:** Malicious or faulty paymaster.
- ⚙️ **How:** A paymaster could approve transactions it shouldn’t or run out of funds.
- 🎯 **Target:** If a paymaster claims to pay for something, but then fails to cover fee, transaction will fail anyway. Or it could keep collected fees.
- 🛡 **Defense:** Paymaster must deposit funds in advance. Its postTransaction can be used to refund or log. The system requires the paymaster’s magic return on validation – if it cheats, validation fails.
>- 🧒 **Child Analogy:** It’s like a sponsor promising to cover your ticket. If the sponsor doesn’t show up with money, your ticket is void.

## 🧪 Factory Dep Poisoning:

- 👤 **Who:** Malicious user submitting huge or unknown bytecode in factoryDeps.
- ⚙️ **How:** They include expensive factory deployments to bloat pubdata.
- 🎯 **Target:** Drive up state and prove costs.
- 💣 Consequence: The user (account) pays for the large pubdata (burns extra ETH). If they include unknown code, they must also prove it on L1 (burn more or fail).
- 🛡 **Defense:** The Bootloader and KnownCodeStorage enforce availability: unknown code triggers L1 publishing burns. Pubdata cost is still constrained by user’s gasPerPubdataByteLimit.
>- 🧒 **Child Analogy:** If you try to attach a giant code book to your request, you’ll either pay a huge fee or the machine will stop you.

## 🔐 Signature Hash Collision:

- 👤 **Who:** Cryptographers or attackers finding collisions.
- ⚙️ **How:** Extremely unlikely for 256-bit hashes.
- 🎯 **Target:** Forge a different transaction with the same hash.
- 🛡 **Defense:** 256-bit hash is safe. Even if hash collision, the signature scheme should fail.
>- 🧒 **Child Analogy:** It’s like two different books having exactly the same fingerprint – practically impossible.
---
---
# 6️⃣ 🧠 Deep Low-Level Breakdown

### 🖤 Cryptographic Details

- 🔎 ***ecrecover Internals:*** In zkSync Era, the `ECRECOVER` precompile is at `address` `0x0000000000000000000000000000000000000001` [28]. It expects input exactly as the Ethereum precompile: **first 32 bytes = hash, next 32 = v, next 32 = r, last 32 = s. It enforces: v ∈ {27, 28}, r, s < secp256k1n.** It returns the recovered address or empty on failure [28]. Internally, it uses pure Yul optimized for `Groth16` circuits.

- 🔁 ***Signature Verification in EVM:*** An account calling ecrecover() translates to a STATICCALL in bytecode to that address. The EraVM intercepts it and runs the precompiled code. If ecrecover fails, it returns zero address. Accounts typically then check recovered == expectedAddress.

- 🧾 ***Raw Hash vs EIP-191:*** Unlike Ethereum’s personal sign (EIP-191) which prefixes `"\x19Ethereum Signed Message:\n"`, zkSync uses the raw EIP-712 transaction hash [21]. This is because zkSync’s native AA needs a consistent, structured signing process. (Users don’t sign personal sign messages here, they sign the typed data directly.)

- 📦 ***abi.encodePacked Memory Layout:*** When an account uses abi.encodePacked(r, s, v), it concatenates the 32-byte r, the 32-byte s, and 1-byte v (plus 31 bytes padding for alignment), yielding a 65-byte packed signature. This packing means in memory you have `***[ r (32B) | s (32B) | v (1B) | padding (31B) ]***`. If done incorrectly (e.g. swapping order or length), ecrecover will fail.

---

## 🧱 Memory Layout

- 📑 ***Transaction Struct in Memory:*** A Transaction calldata struct lays out as follows (all 32-byte words):

0: txType (uint256)
1: from (uint256 = uint160 address)  
2: to (uint256)  
3: gasLimit  
4: gasPerPubdataByteLimit  
5: maxFeePerGas  
6: maxPriorityFeePerGas  
7: paymaster (uint256)  
8: nonce  
9: value  
10–13: reserved[0..3] (uint256 each)  
14: pointer to data (offset from struct base)  
15: pointer to signature (offset)  
16: pointer to factoryDeps array  
17: pointer to paymasterInput  
18: pointer to reservedDynamic (unused)


*(Actual layout may compress dynamic fields, but above is conceptual.)* Dynamic fields (data, signature, factoryDeps, paymasterInput) each have a 32-byte length and then contents. For example, signature (65 bytes) will be padded to 96 bytes in memory. factoryDeps is a bytes32[]; it’s laid out as [length (M) | element0 | ... | elementM-1], each element 32 bytes.

- 🏷 ***Address → uint256:*** In the struct, from and to are uint256(uint160(addr)). So the 20-byte address is right-aligned in a 32-byte word (leading zeros). This uniform sizing (32 bytes) simplifies hashing as fixed fields.

- 🗄 ***Reserved[4] Storage:*** These are four consecutive 32-byte slots (offsets 10–13). Bootloader demands they be zero for txType 113 [13].

- 📚 ***Dynamic Arrays (factoryDeps):*** Suppose factoryDeps has length N. Then in memory you’d find: a 32-byte length (N), followed by N 32-byte elements (each is a code hash). These bytes are included in hashing by the encodeHash function.

- 🧮 ***ABI Packing for Hashing:*** The zkSync typed EIP-712 hash effectively encodes each field (as above) into the domain and struct hash. There is no double-RLP; it’s a straight structured hash. For example, ethers calls generate a typed data hash per [46L269-L277].
---
---
# 7️⃣ 🏛 **System-Level Details**

- **Bootloader Address (0x8001):** This is a reserved special address. It does not hold code on L2; instead, it signifies the context of the Bootloader execution. In any contract call from the Bootloader, **msg.sender** will read as **0x8001**. Users can transfer ETH to **0x8001** (Bootloader collects fees) [40].

- **System Contract Calls:** There are two main modes of calling system contracts from account code:

  - **MimicCall (systemCall):** This is when the Bootloader acts on behalf of the account (like a privileged call). For example, bootloader’s own code might call **NonceHolder** or **KnownCodeStorage**.

  - **SystemContractsCaller (with isSystem):** Account code uses **SystemContractsCaller.systemCallWithPropagatedRevert(...)** to invoke system contracts (like **NonceHolder.increment** or **ContractDeployer**). Internally, this uses an ERA-specific mechanism to set **isSystem=true** on that CALL. Without it, calls to addresses in **[0x8000...0x8FFF]** would fail.

- **ACCOUNT_VALIDATION_SUCCESS_MAGIC (0x00000000):** This constant is defined in the protocol (and in **IAccount.sol**). It signals validation success. It is enforced only in mainnet: Bootloader checks it strictly [3]. During fee estimation (simulations), it may be ignored.

- ❌ **Wrong Magic Handling:** If **validateTransaction** returns anything other than **0x00000000**, the Bootloader reverts. Specifically, it throws **ACCOUNT_VALIDATION_FAILED** (or similar) indicating invalid magic. No state change happens (validation is an atomic check).

- 🔢 **Nonce Check at Opcode Level:** **NonceHolder** is just a contract with storage. For sequential nonces, **incrementMinNonceIfEquals(nonce)** inlines roughly to:

  `if (storage[account] == nonce) storage[account] = nonce+1; else revert.`

  This check+write is done in one CALL (with revert propagation). If sequential, it acts as a strict incrementer; arbitrary mode may allow setting **storage[account] = max(old, nonce)+1**.

---
---
# 8️⃣ ⛽ **Gas Mechanics**

- **gasleft():** In account code, calling **gasleft()** returns the remaining gas of that call frame. This is how an account can see how much gas it has (e.g. to adjust behavior). In zkSync’s Bootloader, the initial **gasLimit** is provided by the transaction, and this is the budget seen in **gasleft()**.

- **gasPerPubdataByteLimit:** This field sets a maximum price-per-byte for L1 pubdata. The Bootloader enforces after validation:  
  **(pubdataAfterValidation * gasPerPubdata) <= gasLeftAfterValidation** [32].  
  If false, tx rejected (not included). After execution, it checks again:  
  **if (pubdataAfterExecution * gasPerPubdata) > gasLeft**, it reverts (state isn’t changed but gas spent). Thus this param effectively caps how much pubdata gas you’re willing to pay.

- **Pubdata (Public Data):** In zkSync, all state writes (storage, logs, code) generate “diffs” that become L1 data. Each byte of this data costs gas. The total is calculated after execution. A pubdata counter is incremented by the verifier for each storage write. The final pubdata gas cost = **bytes * effectiveGasPerPubdata**. Users pay this in L2 gas.

- **Refunds:** Standard EVM refund rules apply. If an account does an **SSTORE(x,0)**, it gets a partial refund. However, the Bootloader collects fees for all gas used minus refunds. Also, if a transaction uses less gas than provided, leftover gas is refunded to the **from** account. All gas costs (execution + pubdata) are ultimately paid to the operator.

- **Gas Price:** **maxFeePerGas** is capped by the epoch’s baseFee which the sequencer provides, and there’s no concept of priority tips (zkSync sets priority fee effectively to 0) [35]. The **effectiveGasPrice = baseFee (since tip=0)** in most cases.

---
---
# 9️⃣ ❓ **Q/A Section**

### ❓ **Q: Why not just use a regular EOA?**

- **Technical:** A plain EOA has no logic: it only checks a single private key. Native AA lets you attach arbitrary logic (multi-sig, session keys, gas/payment logic). It solves EOA limitations like inability to pay fees in tokens or require multiple signatures. On zkSync, EOAs are deprecated: even a simple account uses the **DefaultAccount** contract for EOA-like behavior [1][23].

- **Simplified:** EOAs are like simple piggy banks – one key, no rules. zkSync AA makes your wallet a smart piggy bank with rules and helpers.

>- 🧒 **Child Analogy:** It’s like having a robot that does your chores (AA) instead of doing them yourself (EOA). A robot can follow instructions, while you alone just use your hands.

---

### ❓ **Q: Why not use ERC-4337 (Ethereum’s Account Abstraction)?**

- **Technical:** ERC-4337 is a user-space proposal implemented via an EntryPoint contract and special “UserOperation” pool. It was never integrated at the consensus layer. zkSync’s AA is native: built into the rollup’s protocol and bootloader [6]. That means no extra contract or bundler is needed; the sequencer handles all accounts uniformly. zkSync also extends AA to all EOAs and supports paymasters for them, whereas ERC-4337 only applied to smart-contract accounts [4].

- **Simplified:** ERC-4337 is like an after-school program you have to join, but zkSync’s AA is built right into the school curriculum.

>- 🧒 **Child Analogy:** Think of playing tag with special rules. ERC-4337 would be like adding a new rule that only certain players follow. zkSync’s method is like giving every player the same new power from the start.

---

### ❓ **Q: What’s the difference from Ethereum Account Abstraction?**

- **Technical:** zkSync AA is protocol-level and unified (single mempool, Bootloader = EntryPoint). Ethereum’s version adds complexity: separate user-op pool, bundlers, fees. Also, on zkSync, even normal ETH accounts get paymaster support and smart-account benefits [41].

- **Simplified:** It’s mostly about integration. zkSync’s AA is done at the core, making everything work together seamlessly. Ethereum’s AA is bolted on with separate systems.

>- 🧒 **Child Analogy:** Like teaching everyone a new handshake at school vs. making just a few kids learn a secret handshake in a club. Everyone learns it together in zkSync’s world.

---

### ❓ **Q: Who calls validateTransaction?**

- **Technical:** The Bootloader calls it, as part of transaction validation [14]. It’s not an external user or contract that invokes it.

- **Simplified:** The magic robot (Bootloader) calls it automatically for you.

>- 🧒 **Child Analogy:** The librarian checks your passport for you; you don’t have to ask him to do it.

---

### ❓ **Q: When is validateTransaction called?**

- **Answer:** In the validation phase, before execution of the transaction [14]. Each transaction triggers exactly one validation call in normal operation (aside from simulations which skip it).

>- 🧒 **Child Explanation:** Before you get any candy, the robot first checks your ticket once.

- **Reference:** (See “Full Transaction Lifecycle” above).
---

### ❓ Q: Can `validateTransaction` be called twice?
- **Answer:** No, not in a single transaction processing. It’s called once in validation. In local simulations, some tools skip or mock it. Repeated calls from one Bootloader pass don’t occur.
>- 🧒 **Analogy:** You only hand over your ID to the guard once per entry. You can’t show it twice for the same entrance.

---

### ❓ Q: What if `validateTransaction` returns the wrong magic?
- **Answer:** The Bootloader immediately aborts the transaction. The tx will not be included and no fees are charged [3].
>- 🧒 **Child Explanation:** If the vault doesn’t shout the right code, the robot cancels the order.
- **Ref:** (Section “Magic Value Return” above).

---

### ❓ Q: What if `validateTransaction` reverts?
- **Answer:** Same as wrong magic: the transaction fails validation. Bootloader discards it and does not charge the account [6].
>- 🧒 **Child Explanation:** If the vault’s check crashes, the request is simply canceled safely.
- **Ref:** (Transaction Flow details).

---

### ❓ Q: What if `validateTransaction` consumes all gas?
- **Answer:** If it runs out of gas (OOG) during validation, it reverts. Bootloader treats it as a validation failure. The user’s transaction does not go through, but they lose whatever gas they provided up to that point.
>- 🧒 **Child Explanation:** If the vault runs out of battery while checking, the robot just stops and you don’t get your candy (but you still paid for the time).

---

### ❓ Q: Who checks the nonce?
- **Answer:** The Bootloader enforces nonce checks via the `NonceHolder` system contract [14][22]. Either the Bootloader itself or the account’s validation logic (using `NonceHolder` via `SystemContractsCaller`) confirms the nonce is fresh.
- **Ref:** [5], [12].

---

### ❓ Q: What if nonce is not checked?
- **Answer:** If somehow no one checked, a user could reuse an old nonce and replay a transaction. zkSync guards against this by requiring all accounts (even default) to use `NonceHolder` for unique nonces.
- **Ref:** (Implicit in NonceHolder doc).

---

### ❓ Q: What if nonce is wrong?
- **Answer:** If the nonce field doesn’t match what the account expects (like not equal to current nonce), `validateTransaction` or `NonceHolder` will revert. The tx fails.
>- 🧒 **Child Explanation:** It’s like showing an outdated raffle ticket; the clerk rejects it.

---

### ❓ Q: Who increments the nonce?
- **Answer:** Typically the Bootloader marks it used after validation. Some account code increments it explicitly via `SystemContractsCaller` [22]. In `DefaultAccount`, the increment is done in `validateTransaction` by calling `NonceHolder`.
- **Ref:** [24L438-L447].

---

### ❓ Q: Can nonce be decremented?
- **Answer:** No. `NonceHolder` only has methods to increment or set a higher nonce. There’s no contract call to lower it. The nonce only goes up.
>- 🧒 **Child:** You can’t “give back” a raffle ticket once used.

---

### ❓ Q: Who recovers the signature?
- **Answer:** The account’s validation code does, by calling `ecrecover` (or using a library). The Bootloader does not do any cryptographic check itself.
- **Ref:** [24L1381-L389], [17L158-L166].

---

### ❓ Q: What if signature signs wrong hash?
- **Answer:** `ecrecover` returns a wrong address. The account’s code should detect that (`recovered != actualSigner`) and treat it as failure (magic=0). The tx fails validation.
>- 🧒 **Child Explanation:** It’s like signing the wrong document – the vault sees the wrong fingerprint and shuts you out.

---

### ❓ Q: What if signature is malleable?
- **Answer:** The system permits malleable signatures (both `(r,s,v)` and `(r, n-s, v^1)` are valid). It’s the account’s responsibility to reject one of them. If not handled, an attacker could replay. Good practice is to enforce low-s.
- 🛡 **Defense:** Validate `s <= secp256k1n/2` in code.
>- 🧒 **Analogy:** If you allow flipping a key, you need a rule that only the original shape opens it.

---

### ❓ Q: What if signature is from wrong owner?
- **Answer:** The account’s code compares `recovered` to the list of owners. If it doesn’t match, it sets magic=0. The tx is invalid.
- **Ref:** [24L1381-L389].

---

### ❓ Q: What if signature is packed wrong? (v at end vs beginning)
- **Answer:** If encoded incorrectly, `ecrecover` will simply fail to recover the right address (often giving 0x0). The account must check length and format. Many examples adjust incorrect lengths by padding and still attempt verification [42]. But generally, packing wrong causes validation to fail.
- **Prevention:** Always pack as `(r || s || v)` with `v` last.

---

### ❓ Q: Where can it be attacked?
- **Answer:** Attacks target the account code or the sequencer. For example, front-running can reorder your tx. A malicious sequencer could censor you. The Bootloader and system contracts are trusted, so little else can be attacked at the protocol level. The biggest risk is if your account code has bugs.
>- 🧒 **Child:** Mostly, your own vault code can be tricked if not careful, or the sorting robot could be mean.

---

### ❓ Q: Who pays gas?
- **Answer:** By default, the `from` account pays all gas (fees). If a paymaster is used, the paymaster covers execution costs (at least partially) as agreed. But ultimately someone must pay L1 (often the user or sponsor).
>- 🧒 **Child:** You pay from your wallet, unless you had someone promise to cover it.

---

### ❓ Q: What if bootloader is compromised?
- **Answer:** That would be catastrophic: the security of every tx would be broken. zkSync’s Bootloader code is part of the trust base (and verified on L1). A compromise (bug or hack) would require an emergency fix via system upgrade.
>- 🧒 **Child:** If the robot clerk was bad, nobody’s money would be safe.
---
### ❓ Q: What if system contracts are compromised?
- **Answer:** Similarly, since system contracts (like `NonceHolder`) are part of the protocol, compromising them (impossible without system upgrade) would break invariants. Normal accounts can only call them with `isSystem`, so at least user code can’t directly break `NonceHolder`.
>- 🧒 **Child:** If the head clerk in charge of tickets was bad, then tickets might get double-used. That’s why system guards them.

---

### ❓ Q: What if sequencer is malicious?
- **Answer:** The sequencer can censor, reorder, or include malicious txs (like MEV). zkSync mitigates this partly by submitting proofs and having L1 verification, but it’s still trust-minimized on censorship. Users can always force via L1 priority txs.
>- 🧒 **Child:** The librarian robot could choose whose order to do first – we can’t stop a bad robot from, say, always serving the rich kid first.

---

### ❓ Q: Can transactions be censored?
- **Answer:** Yes, in principle. The sequencer decides what gets into a batch. zkSync’s security model assumes a Byzantine-resilient set of operators, but short of that, censorship is possible. Users may use L1 priority txs to escape censorship.
>- 🧒 **Child:** If the robot refuses your request, you might have to send it by mail (L1) to be sure it gets processed.

---

### ❓ Q: Why is `txType` 113 (0x71)?
- **Answer:** zkSync uses EIP-712 typed transactions. Ethereum’s EIP-712 suggests type 712, but that exceeds a one-byte field. They chose 113 (0x71) because it fits in one byte and stands for zkSync Era AA (like “Zak’s Awesome Account”). It’s just a chosen magic number in the protocol [13][21].
>- 🧒 **Child:** It’s like having a special code on your ticket meaning “zkSync AA ticket.”
- **Ref:** [39L203-L205], [46L269-L277].

---

### ❓ Q: What if transaction type changes?
- **Answer:** If you try another type, the Bootloader will run different validation rules or reject it. For example, type 0x255 is L1→L2, etc. But type 113 is reserved for AA. So using type 255 or others for AA might be rejected.
>- 🧒 **Analogy:** It’s like showing a train ticket for the wrong train; the conductor won’t honor it for this route.

---

### ❓ Q: What if `factoryDeps` is non-empty?
- **Answer:** Then the transaction is also claiming to deploy contracts. zkSync will ensure those code hashes are “Known” on L1. If they aren’t, it will require the user to burn extra ETH for L1 publishing [39]. If this fails or the hash doesn’t match provided code, tx reverts.
>- 🧒 **Child:** If you bring new ingredients, the clerk verifies their recipe is known or else you pay extra.

---

### ❓ Q: What if `gasPerPubdataByteLimit` is wrong?
- **Answer:** If it’s set too low, the pubdata check after execution will fail, causing a revert (state changes undone, fee still charged) [32]. If it’s higher than allowed by user balance, the user might waste gas.
>- 🧒 **Child:** If you promise to pay only 1 coin per pound of luggage but your luggage is too heavy, the robot will refuse your trip.

---

### ❓ Q: What if reserved fields are used maliciously?
- **Answer:** Bootloader enforces they are zero for `txType` 113 [13]. If not zero, validation fails. They currently have no other meaning, so they shouldn’t be used.

---

### ❓ Q: What if `from` / `to` are encoded wrong?
- **Answer:** If `from` is not `uint256(uint160(addr))`, the hash will differ and signature fail. If `to` is wrong, the transaction will call the wrong contract/address. In either case, the transaction will fail (revert or go to unintended target).
>- 🧒 **Child:** It’s like writing the wrong house number; either it never reaches or the wrong house tries to execute it.

---

### ❓ Q: Who calls `executeTransaction`?
- **Answer:** The Bootloader does, right after successful validation [15]. No one else should call it.
>- 🧒 **Child:** Again, the clerk (bootloader) carries out your order after checking it.

---

### ❓ Q: Can `executeTransaction` be called without validation?
- **Answer:** In normal protocol flow, no. The Bootloader only moves to execution if validation returned the magic. If a user somehow tried to call it manually (it’s `external`), it would see `msg.sender != 0x8001` and likely fail (DefaultAccount’s fallback asserts against the bootloader call) [26].
>- 🧒 **Child:** The clerk only acts after saying “yes.”

---

### ❓ Q: What happens after execution?
- **Answer:** State is updated. If execution reverted, state rolls back. Then Bootloader finalizes fees: transfers the fee to its own address (as operator) and records the transaction outcome.
>- 🧒 **Child:** The librarian updates the account book – either with a successful lending or logs a failed attempt.

---

### ❓ Q: How are refunds handled?
- **Answer:** Standard EVM refunds: gas leftover is returned (to payer). If `SSTORE` cleared a slot, the user gets partial gas refund. The Bootloader itself also provides some refunds (e.g. for zeroing storage).
>- 🧒 **Analogy:** If you filled 3kg of water but your bottle only needed 2kg, you get 1kg back.

---

### ❓ Q: What if account has no code?
- **Answer:** The system uses the `DefaultAccount` system contract for it [25]. It behaves like a simple EOA: any call with no data will just be ETH transfer, etc. It also provides a default `validateTransaction` that checks ECDSA signatures against the account’s address (the code is like a built-in wallet).
- **Ref:** [16L217-L221].

---

### ❓ Q: What if account self-destructs?
- **Answer:** If an account destroys itself during execution, subsequent calls to it (within the same transaction) would no longer have code. But usually one transaction only calls `executeTransaction` once. If it self-destructs, its remaining ETH is sent to the designated beneficiary (if any).
- **Risk:** If someone triggers self-destruct mid-tx, anything after that would behave as if no code (DefaultAccount or empty). But since execution only happens once, it just means the account is gone afterward.
>- 🧒 **Child:** It’s like your vault blowing up; after that, it’s just an empty spot. No more checks can happen.

---

### ❓ Q: What if account is upgraded during transaction?
- **Answer:** In one transaction, code can’t spontaneously change. zkSync does not support code changes in the middle of a transaction batch. An account could, in one execution, call a factory to deploy a new version, but that new code wouldn’t affect the current `executeTransaction` (only future txs).
>- 🧒 **Child:** You can’t change the rules of the game while the turn is happening.
---
### ❓ Q: What if paymaster runs out of funds?
- **Answer:** The paymaster must have pre-deposited funds. If it spent its balance or had insufficient gas allowance, then in `validateAndPayForPaymasterTransaction` it should revert. That causes the whole transaction to fail (user’s transaction is rejected).
>- 🧒 **Child:** If your sponsor is broke at that moment, the clerk won’t let you borrow under their name.

---

### ❓ Q: What if gas price changes during execution?
- **Answer:** zkSync sets the baseFee for the entire batch at start. The provided `maxFeePerGas` is checked against that. Within the transaction, `gasleft()` is in terms of gas units, not fee. There’s no mid-tx price change. If the actual baseFee on L1 ends up different when proving, the contract on L1 reconciles it. Typically, users assume baseFee = provided at tx time.
>- 🧒 **Child:** It’s like buying gas when you enter the station; once you’re inside, the price doesn’t change until your fill-up is done.

---
---

# 🔟 📌 Summary & Reference

### 📄 One-Page Cheat Sheet

- **zkSync Native AA = Smart Accounts:** All accounts can have logic; Bootloader enforces transaction flow.
- **Bootloader (0x8001):** Entry point; validates then executes every tx in batch.
- **Account Contract:** Implements `validateTransaction` + `executeTransaction`. Must return magic = `0x00000000` on success.
- **NonceHolder (system contract):** Ensures one-time nonces. Always increment in `validateTransaction`.
- **Transaction Struct:** Fields: `txType=113`, `from(uint256)`, `to(uint256)`, `gasLimit`, `gasPerPubdataByteLimit`, `maxFeePerGas`, `maxPriorityFeePerGas`, `paymaster`, `nonce`, `value`, `data`, `factoryDeps`, `paymasterInput`. Reserved fields must be 0.
- **Signature:** User signs hash of struct. Verify in `validateTransaction` via `ecrecover`. Use libraries to handle v/r/s order.
- **Fee Model:** Gas (compute) + pubdata cost. Pubdata gas = bytes_published * `gasPerPubdataByteLimit`. Bootloader checks pubdata cost before and after execution.
- **Paymasters:** If used, Bootloader calls paymaster for fee sponsorship. Paymaster must return success magic.
- **Failure:** Any revert or wrong magic during validation => tx fails (no fee). Revert during execution => tx included but failed (fee paid).
- **Security Tips:** Enforce low-s signatures, unique nonces, correct magic, use `SystemContractsCaller` for system calls.
- **Help:** Official docs and community examples are invaluable (links above).

---

## 📚 Key Terms Glossary

- **EOA (Externally Owned Account):** Standard account controlled by a private key (no code). On zkSync, EOAs still exist but are treated with a default smart-account behavior. 
>**Child:** A wallet you open with a secret key.
- **AA (Account Abstraction):** Protocol feature making accounts programmable (like smart contracts). 
>**Child:** Giving your wallet a brain.
- **Smart Account / Account Contract:** An account address with custom code implementing validation/execution (IAccount interface). 
>**Child:** A wallet that is also a little computer.
- **DefaultAccount:** The system contract used by empty accounts to mimic EOA behavior. 
>*Child:** The fallback computer for wallets that have no special rules.
- **Bootloader:** The built-in “executor” that runs every transaction sequentially. 
>**Child:** The robot librarian processing each request.
- **System Contracts:** Special contracts (NonceHolder, etc.) at reserved addresses with privileged roles. 
>**Child:** The locked drawers only the robot can open.
- **Nonce:** A number that increases with each transaction to prevent replay. 
>**Child:** Your ticket number in a queue.
- **Magic Value:** The success code `0x00000000` an account must return on validation. 
>**Child:** The secret password you must say to get your candy.
- **txType 113:** The code for native AA transactions (0x71 hex). 
>**Child:** A special stamp on your request saying “zkSync AA order.”
- **gasPerPubdataByteLimit:** Max gas willing to pay per byte of L1 data. 
>**Child:** Your budget for how much you’ll pay to post data on the wall.
- **Paymaster:** A sponsor contract that can pay gas fees for transactions. 
>**Child:** Your generous friend covering the fee.

---

## 🛠️ Common Error Codes & Meanings

- `ACCOUNT_VALIDATION_FAILED` (invalid magic): The account did not return `0x00000000` in validation.
- `nonce was used` or similar: The NonceHolder found the nonce already consumed.
- `invalid signature` or revert in `validateTransaction`: Signature check failed inside account logic.
- `gas limit exceeded` (OutOfGas): Transaction ran out of gas (during validation or execution).
- `PubdataGasLimitExceeded`: (`pubdataBytes * gasPerPubdata`) > `gasLeft`, so Bootloader rejected the tx after validation or execution.
- `Bootloader reverted`: General revert in Bootloader (format or type issue). Likely malformed transaction.

(Exact error strings depend on client implementation.)

---

## 🛠️ Debugging Checklist (Failed TXs)

- **Check Magic:** If “invalid magic,” ensure `validateTransaction` returns `0x00000000` on all success paths.
- **Check Signature:** Verify you signed the correct hash (use `encodeHash`), and that account’s code recovered correctly. Check `v,r,s` ordering.
- **Check Nonce:** Make sure tx.nonce equals account’s current nonce. If your account uses sequential nonces, you must increment exactly.
- **Gas/limits:** Ensure `gasLimit` and `gasPerPubdataByteLimit` are high enough. For pubdata-intensive ops, set them bigger.
- **txType/fields:** Confirm `txType=113` and all reserved fields are zero.
- **Sufficient Balance:** Account must hold enough ETH to pay total (maxFee*gas + burned for factory deps).
- **FactoryDeps:** If deploying, ensure the bytecode’s hashes match and are already known (or be ready to burn fees).
- **Paymaster:** If using one, ensure it has funds and returns magic.
- **Syntax:** Use official libraries or RPC formats to avoid encoding issues.
- **Logs:** Use Debug RPC or local replay to see which step reverts.

---

## ✅ Testing Checklist (Account Developers)

- [ ] **Magic Return:** Test that `validateTransaction` returns exactly `0x00000000` when valid, and non-zero otherwise.
- [ ] **Signature Paths:** Verify behavior on valid and invalid signatures (e.g. wrong key, wrong hash, modified s/v).
- [ ] **Nonce Handling:** Simulate sequential and arbitrary nonces if supported. Try reuse to ensure it fails.
- [ ] **Edge Cases:** Test low gas (`gasLimit` at threshold), high gas, and extreme pubdata. Ensure correct behavior.
- [ ] **Paymaster Interaction:** If relevant, test with a dummy paymaster: ensure `validateAndPayForPaymaster` and `postTransaction` are correctly invoked.
- [ ] **Fallback Behavior:** Ensure `fallback()` and `receive()` in DefaultAccount (if used) behave as intended (e.g., revert if called by bootloader in fallback).
- [ ] **Zero-Code Accounts:** Check that an address with no code still works as an EOA (DefaultAccount) — i.e. can `transfer` ETH and do plain sends.
- [ ] **Custom Logic Tests:** If adding features (multisig, etc.), test failure modes (missing signatures, wrong ordering).
- [ ] **Library Calls:** When using `SystemContractsCaller`, verify that gas is correctly propagated and reverts bubble up as expected.
- [ ] **Version Compatibility:** Ensure your code compiles/runs with the same Solidity version targeted by zkSync (0.8+ recommended) and test on zkSync testnet.

---
---
# 1️⃣1️⃣ 📚 Sources & Accuracy

Content above is based on zkSync Era’s official documentation and contracts. Any statements without a citation are interpretations consistent with these sources. For authoritative details, consult the zkSync docs and the era-system-contracts code.

- **Official zkSync Docs:** We have cited the EraVM Account Abstraction docs, Bootloader docs, System Contracts docs, and Transaction Lifecycle docs from the zkSync documentation site [1][25][30][36]. Statements like “Accounts in zkSync Chains can have arbitrary logic…” and magic value requirements are direct quotes from there [1][3].
- **System Contracts Repository:** For details like DefaultAccount’s behavior and `ACCOUNT_VALIDATION_SUCCESS_MAGIC`, we referenced the era-system-contracts GitHub (now archived) [25][20]. For example, DefaultAccount’s use is documented in the Era contracts section.
- **Foundry / Example Code:** Some workflow specifics and library usage come from community examples and Foundry docs (like `SystemContractsCaller` and `TransactionHelper`) [22][8]. These align with official docs and are standard patterns.
- **Clarifications:** If any detail isn’t explicitly found, we mark it as “interpretation.” However, nearly all statements above are backed by docs. For instance, discussion of pubdata gas is from zkSync’s technical guide [32].
- **Accuracy:** We believe the information is correct as of the latest zkSync Era release (2025). If docs or contracts change, the core concepts (nonce checking, magic values, roles of Bootloader/account) remain valid. Any uncertainty (e.g. exact opcode gas) has been flagged as such in explanations.

---
---

[1][2][3][4]  
**Introduction - ZKsync Docs**  
https://docs.zksync.io/zksync-protocol/era-vm/account-abstraction  

[5][6][41]  
**Native AA vs EIP 4337 - ZKsync Docs**  
https://docs.zksync.io/zksync-protocol/era-vm/differences/native-vs-eip4337  

[7][8][14][15][16][24]  
**Design - ZKsync Docs**  
https://docs.zksync.io/zksync-protocol/era-vm/account-abstraction/design  

[9][10][12][36][40]  
**Bootloader - ZKsync Docs**  
https://docs.zksync.io/zksync-protocol/zksyncos/bootloader  

[11][13]  
**Bootloader - ZKsync Docs**  
https://docs.zksync.io/zksync-protocol/era-vm/contracts/bootloader  

[17][18][19][23][25][28][33][34][38][39]  
**System contracts - ZKsync Docs**  
https://docs.zksync.io/zksync-protocol/era-vm/contracts/system-contracts  

[20][22][26][30][31][37]  
**Native multisig smart account - ZKsync Community Code**  
https://code.zksync.io/tutorials/native-aa-multisig  

[21][35]  
**Transaction lifecycle - ZKsync Docs**  
https://docs.zksync.io/zksync-protocol/era-vm/transactions/transaction-lifecycle  

[27][29][42]  
**Signature validation - ZKsync Docs**  
https://docs.zksync.io/zksync-protocol/era-vm/account-abstraction/signature-validation  

[32]  
**How Max Gas Per Pubdata Works on ZKsync Era - ZKsync Community Code**  
https://code.zksync.io/tutorials/max-gas-pub-data  