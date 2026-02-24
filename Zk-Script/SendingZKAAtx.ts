//explained in Zk-Script/ZKAAdeployment.ts see for natspecs
import "dotenv/config";

/**
 * Used here ONLY for:
 *   - Signature formatting
 *   - ethers.Signature.from(...)
 *   - ethers.concat(...)
 *
 * WHY still import ethers?
 *   zksync-ethers extends ethers, but low-level signature helpers
 *   are reused from base ethers package.
 */ import * as ethers from "ethers";

//explained in Zk-Script/ZKAAdeployment.ts see for natspecs
import * as fs from "fs-extra";

/**
 * CRITICAL zkSync-specific imports.
 *
 * Provider:
 *   zkSync RPC provider (not standard Ethereum provider).
 *
 * Wallet:
 *   zkSync-compatible signer.
 *
 * Contract:
 *   Used to read contract state.
 *
 * EIP712Signer:
 *   Required to compute zkSync transaction digest.
 *
 * types:
 *   Contains zkSync-specific transaction type encoders.
 *
 * utils:
 *   Provides zkSync constants like DEFAULT_GAS_PER_PUBDATA_LIMIT.
 *
 * WHY NOT plain ethers?
 *   zkSync uses:
 *     - Type 113 transactions
 *     - EIP-712 structured signing
 *     - customData fields
 */ import {
  Contract,
  EIP712Signer,
  Provider,
  types,
  utils,
  Wallet,
} from "zksync-ethers";

// Mainnet
// const ZK_MINIMAL_ADDRESS = ""

// Sepolia
// const ZK_MINIMAL_ADDRESS = ""

// Local
// Update this YOUR OWN
/**
 * The deployed AccountZKAA contract address.
 *
 * ⚠️ YOUR COMMENT HIGHLIGHTED:
 *   "// Update this YOUR OWN"
 *
 * WHY?
 *   This must be your deployed account contract.
 *
 * WHAT IF wrong address?
 *   Transaction will fail or affect wrong contract.
 */ const ZK_MINIMAL_ADDRESS = "0x19a519025994A1F32188dE1F0E11014A791fB358";

// Update this too!
/**
 * Address receiving ERC20 approval.
 *
 * WHO receives allowance?
 *   RANDOM_APPROVER.
 */ const RANDOM_APPROVER = "0x9EA9b0cc1919def1A3CfAEF4F7A66eE3c36F86fC";

// Mainnet
// const USDC_ZKSYNC = "0x1d17CBcF0D6D143135aE902365D2E5e2A16538D4"
// Sepolia
/**
 * USDC token contract on zkSync Sepolia.
 *
 * ⚠️ NOTE:
 *   zkSync tokens are separate from Ethereum L1.
 *
 * WHAT IF wrong token address?
 *   approve() will call wrong contract.
 */ const USDC_ZKSYNC = "0x5249Fd99f1C1aE9B04C65427257Fc3B8cD976620"; // Sepolia

// Local
// let USDC_ZKSYNC = ""

/**
 * Amount of USDC to approve.
 *
 * NOTE:
 *   ERC20 uses token decimals.
 *   This is raw units.
 */ const AMOUNT_TO_APPROVE = "1000000";

async function main() {
  // explain why this async in ZKAAdeployment.tx
  console.log("Let's do this!");

  // Local net
  // let provider = new Provider("http://127.0.0.1:8011")
  // let wallet = new Wallet(process.env.PRIVATE_KEY!)

  // // Sepolia - Uncomment to use
  /**
   * Connects to zkSync Sepolia L2 RPC.
   *
   * WHERE?
   *   zkSync Layer 2 network.
   *
   * DIFFERENCE FROM ETHEREUM:
   *   This RPC speaks zkSync-specific transaction format.
   */ let provider = new Provider(process.env.ZKSYNC_SEPOLIA_RPC_URL!); // // Sepolia - Uncomment to use

  /**
   * Loads encrypted keystore file.
   *
   * WHY encrypted?
   *   Security best practice.
   *
   * WHAT IF wrong password?
   *   Throws decryption error.
   *
   * WHO signs?
   *   This wallet signs EIP-712 transaction.
   */ const encryptedJson = fs.readFileSync(".encryptedKey.json", "utf8");
  let wallet = Wallet.fromEncryptedJsonSync(
    encryptedJson,
    process.env.PRIVATE_KEY_PASSWORD!,
  );

  // // Mainnet - Uncomment to use
  // let provider = new Provider(process.env.ZKSYNC_RPC_URL!)
  // const encryptedJson = fs.readFileSync(".encryptedKey.json", "utf8")
  // let wallet = Wallet.fromEncryptedJsonSync(
  //     encryptedJson,
  //     process.env.PRIVATE_KEY_PASSWORD!
  // )
  /**Attaches RPC to wallet. */ wallet = wallet.connect(provider);

  /**
   * Loads ABI for AccountZKAA.
   *
   * NOTE:
   *   Only ABI from ./out is needed (bytecode not needed here).
   */ const abi = JSON.parse(
    fs.readFileSync("./out/AccountZKAA.sol/AccountZKAA.json", "utf8"),
  )["abi"];
  console.log("Setting up contract details...");

  /**
   * Creates read-only contract instance.
   *
   * ⚠️ YOUR COMMENT HIGHLIGHTED:
   *   "// If this doesn't log the owner, you have an issue!"
   *
   * WHY?
   *   Confirms:
   *     - Correct address
   *     - Correct ABI
   *     - Correct network
   */ const accountZKAA = new Contract(ZK_MINIMAL_ADDRESS, abi, provider);

  // If this doesn't log the owner, you have an issue!
  console.log(
    `The owner of this minimal account is: `,
    await accountZKAA.owner(),
  );
  const usdcAbi = JSON.parse(
    fs.readFileSync("./out/ERC20/IERC20.sol/IERC20.json", "utf8"),
  )["abi"];
  const usdcContract = new Contract(USDC_ZKSYNC, usdcAbi, provider);

  console.log("Populating transaction...");

  /**
   * Generates calldata for:
   *   approve(address,uint256)
   *
   * DOES NOT send transaction.
   *
   * WHY populateTransaction?
   *   We need raw calldata to embed inside zkSync AA transaction.
   */ let approvalData = await usdcContract.approve.populateTransaction(
    RANDOM_APPROVER,
    AMOUNT_TO_APPROVE,
  );

  let aaTx = approvalData;

  /**
   * Estimates gas for transaction execution.
   *
   * WHO estimates?
   *   zkSync RPC node.
   *
   * WHAT IF underestimate?
   *   Transaction may fail.
   */ const gasLimit = await provider.estimateGas({
    ...aaTx,
    from: wallet.address,
  });
  /**Gets L2 gas price */ const gasPrice = (await provider.getFeeData())
    .gasPrice!;

  /**
   * CRITICAL SECTION.
   *
   * type: 113
   *   Native zkSync AA transaction type. adn the struct being filled
   *
   * customData:
   *   zkSync-specific field.
   *
   * gasPerPubdata:
   *   Controls pubdata gas pricing.
   *
   * WHY needed?
   *   zkSync encodes transactions differently from Ethereum.
   *
   * WHAT IF missing customData?
   *   Transaction rejected.
   */
  aaTx = {
    ...aaTx,
    from: ZK_MINIMAL_ADDRESS,
    gasLimit: gasLimit,
    gasPrice: gasPrice,
    chainId: (await provider.getNetwork()).chainId,
    nonce: await provider.getTransactionCount(ZK_MINIMAL_ADDRESS),
    type: 113,
    customData: {
      gasPerPubdata: utils.DEFAULT_GAS_PER_PUBDATA_LIMIT,
    } as types.Eip712Meta,
    value: 0n,
  };
  /**
   * Computes structured EIP-712 digest.
   *
   * WHY?
   *   zkSync Type 113 uses EIP-712 signing.
   *
   * DIFFERENCE:
   *   Not personal_sign.
   */ const signedTxHash = EIP712Signer.getSignedDigest(aaTx);

  console.log("Signing transaction...");
  /**
   * Signs digest using private key.
   *
   * Produces r, s, v signature.
   */ const signature = ethers.concat([
    ethers.Signature.from(wallet.signingKey.sign(signedTxHash)).serialized,
  ]);
  console.log(signature);

  /**
   * Embeds signature into zkSync transaction.
   *
   * Bootloader will verify this signature.
   */ aaTx.customData = {
    ...aaTx.customData,
    customSignature: signature,
  };

  console.log(
    `The minimal account nonce before the first tx is ${await provider.getTransactionCount(
      ZK_MINIMAL_ADDRESS,
    )}`,
  );

  /**
   * Serializes Type 113 transaction.
   * Sends raw transaction to zkSync network.
   *
   * WHO validates?
   *   Bootloader.
   *
   * WHAT HAPPENS NEXT?
   *   1. Bootloader calls validateTransaction().
   *   2. Account increments nonce.
   *   3. Signature verified.
   *   4. payForTransaction().
   *   5. executeTransaction().
   */ const sentTx = await provider.broadcastTransaction(
    types.Transaction.from(aaTx).serialized,
  );

  console.log(`Transaction sent from minimal account with hash ${sentTx.hash}`);
  await sentTx.wait();

  // Checking that the nonce for the account has increased
  console.log(
    `The account's nonce after the first tx is ${await provider.getTransactionCount(
      ZK_MINIMAL_ADDRESS,
    )}`,
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
