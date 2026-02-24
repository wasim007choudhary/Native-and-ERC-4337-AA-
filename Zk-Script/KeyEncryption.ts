/**
 * @title Private Key Encryption Script
 * @author Wasim Choudhary
 * @notice Encrypts a raw private key using a password and saves it as a JSON keystore file.
 *
 * @dev
 * This script:
 * 1. Reads a raw private key from environment variables.
 * 2. Encrypts it using ethers.js built-in encryption (AES + scrypt).
 * 3. Saves the encrypted output to `.encryptedKey.json`.
 *
 * This is an OFF-CHAIN utility script.
 * It does NOT interact with Ethereum or zkSync.
 * No gas is used.
 *
 * Why is this needed?
 * Storing raw private keys in `.env` is unsafe.
 * This converts the raw key into an encrypted keystore file,
 * similar to how MetaMask stores keys.
 */

import "dotenv/config"; //explained in ZKAAdeployment.ts
import { ethers } from "ethers"; //explained in ZKAAdeployment.ts
import * as fs from "fs-extra";

async function main() {
   /**
 * @dev Creates a wallet instance from the raw private key.
 *
 * WARNING:
 * At this moment the private key exists in memory unencrypted.
    */const wallet = new ethers.Wallet(process.env.PRIVATE_KEY!)
    
    /**
 * @dev Encrypts the wallet using the provided password.
 *
 * Internally:
 * - Uses scrypt key derivation.
 * - Uses AES encryption.
 *
 * Returns:
 * Encrypted JSON string (Ethereum keystore format).
 */const encryptedJsonKey = await wallet.encrypt(
        process.env.PRIVATE_KEY_PASSWORD!,
    )
    /**
 * @dev Writes encrypted keystore file to disk.
 *
 * File created:
 *   .encryptedKey.json
 *
 * This file can later be decrypted using:
 * Wallet.fromEncryptedJsonSync(...)
 */
fs.writeFileSync("./.encryptedKey.json", encryptedJsonKey)
}

/**
 * @dev Executes the script.
 *
 * - Exits with code 0 on success.
 * - Logs error and exits with code 1 on failure.
 */main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })