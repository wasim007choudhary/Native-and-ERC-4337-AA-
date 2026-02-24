/**
 * WHY?
 * Loads environment variables from a `.env` file into process.env.
 *
 * WHO uses this?
 * The Node.js runtime.
 *
 * WHAT VARIABLES are expected?
 *   - ZKSYNC_SEPOLIA_RPC_URL
 *   - PRIVATE_KEY_PASSWORD
 *   - (optionally) PRIVATE_KEY
 *
 * WHAT IF not used?
 * Environment variables would not load automatically.
 *
 * SECURITY NOTE:
 * Never hardcode private keys. Always load from env.
 *
 * WHERE executed?
 * Locally in Node.js runtime (not on-chain).
 */ import "dotenv/config";

/**
 * WHAT is fs-extra?
 * A superset of Node's native `fs` module.
 *
 * WHY needed?
 * To read:
 *   - Encrypted private key file
 *   - Compiled contract artifacts (ABI + bytecode)
 *
 * WHAT IF we used native fs?
 * Would also work. fs-extra adds convenience methods.
 *
 * WHERE does this run?
 * Off-chain in Node.js.
 *
 * GAS IMPACT?
 * None — this is entirely off-chain.
 */ import * as fs from "fs-extra";

/**
 * WHAT is zksync-ethers?
 * zkSync's fork/extension of ethers.js adapted for zkSync Era.
 *
 * WHY NOT regular ethers?
 * Because zkSync:
 *   - Uses custom transaction types (Type 113, EIP-712 style)
 *   - Uses system contracts for deployment
 *   - Requires customData field for gasPerPubdata
 *   - Has different deployment mechanics
 *
 * Provider:
 *   Connects to zkSync RPC.
 *
 * Wallet:
 *   Represents a private key signer.
 *
 * ContractFactory:
 *   Used to deploy contracts.
 *
 * Contract:
 *   Represents deployed contract instance.
 *
 * WHAT IF you use plain ethers.js?
 * Deployment will fail or behave incorrectly.
 *
 * CONTEXT:
 * zkSync is NOT identical to Ethereum EVM execution.
 */ import { Contract, ContractFactory, Provider, Wallet } from "zksync-ethers";

/**
 * WHY async?
 * Deployment requires awaiting RPC responses.
 *
 * WHAT does this function do?
 * 1. Connect to zkSync network.
 * 2. Load private key.
 * 3. Load ABI + bytecode.
 * 4. Deploy contract.
 * 5. Print deployment info.
 *
 * WHO runs this?
 * Node.js runtime when script is executed.
 */ async function main() {
  // Local net - comment to unuse
  // let provider = new Provider("http://127.0.0.1:8011")
  // let wallet = new Wallet(process.env.PRIVATE_KEY!)

  // Sepolia - uncomment to use
  /**
   * WHAT is Provider?
   * An RPC client connected to zkSync node.
   *
   * WHY needed?
   * All blockchain interactions go through RPC.
   *
   * WHO provides RPC?
   * zkSync public node or custom endpoint.
   *
   * WHERE does this connect?
   * zkSync L2 network (Sepolia testnet).
   *
   * WHAT IF RPC wrong?
   * Deployment fails.
   *
   * WHAT HAPPENS NEXT?
   * Wallet will attach to this provider.
   */ let provider = new Provider(process.env.ZKSYNC_SEPOLIA_RPC_URL!);

  /**
   * WHY encrypted?
   * Security best practice.
   *
   * WHAT is inside?
   * Encrypted wallet JSON (keystore format).
   *
   * WHO decrypts?
   * Wallet.fromEncryptedJsonSync().
   *
   * WHAT IF file missing?
   * Script crashes.
   *
   * WHERE stored?
   * Local machine only.
   */ const encryptedJson = fs.readFileSync(".encryptedKey.json", "utf8");

  /**
   * WHAT happens here?
   * Decrypts encrypted private key using password.
   *
   * WHY needed?
   * To sign deployment transaction.
   *
   * WHAT IF wrong password?
   * Throws error.
   *
   * SECURITY RISK?
   * Password exposed → key compromised.
   *
   * GAS IMPACT?
   * None — signing is off-chain.
   */ let wallet = Wallet.fromEncryptedJsonSync(
    encryptedJson,
    process.env.PRIVATE_KEY_PASSWORD!,
  );

  // // Mainnet - uncomment to use
  // let provider = new Provider(process.env.ZKSYNC_RPC_URL!)
  // const encryptedJson = fs.readFileSync(".encryptedKey.json", "utf8")
  // let wallet = Wallet.fromEncryptedJsonSync(
  //     encryptedJson,
  //     process.env.PRIVATE_KEY_PASSWORD!
  // )

  /**
   * WHAT does connect do?
   * Attaches wallet signer to RPC provider.
   *
   * WHY?
   * Wallet alone can sign.
   * Provider alone can read chain.
   * Together → can send transactions.
   *
   * WHO pays gas?
   * This wallet.
   *
   * WHERE gas paid?
   * zkSync L2 ETH.
   */ wallet = wallet.connect(provider);
  console.log(`Working with wallet: ${await wallet.getAddress()}`);

  /**
   * WHAT is ABI?
   * Application Binary Interface.
   *
   * WHY needed?
   * Tells ContractFactory how to encode constructor & function calls.
   *
   * WHY from ./out?
   * Foundry default output directory for ABI.
   *
   * IMPORTANT:
   * On zkSync, bytecode must come from zkout (compiled via zksolc).
   */ const abi = JSON.parse(
    fs.readFileSync("./out/AccountZKAA.sol/AccountZKAA.json", "utf8"),
  )["abi"];

  /**
   * CRITICAL zkSync DETAIL:
   *
   * WHY from ./zkout and NOT ./out?
   *
   * Because:
   * - zkSync uses zksolc compiler.
   * - Bytecode differs from Ethereum solc output.
   *
   * WHAT IF wrong bytecode used?
   * Deployment fails or contract unusable.
   *
   * WHERE generated?
   * forge build --zksync
   *
   * WHAT IS DIFFERENT?
   * zkSync bytecode includes additional metadata for EraVM.
   */ const bytecode = JSON.parse(
    fs.readFileSync("./zkout/AccountZKAA.sol/AccountZKAA.json", "utf8"),
  )["bytecode"]["object"];

  const factoryDeps = [bytecode]; // We can skip this, but this is what's happening

  /**
   * WHAT is ContractFactory?
   * A deployment helper.
   *
   * WHY pass "createAccount"?
   * zkSync deploys contracts through system deployer using
   * special factory method.
   *
   * DIFFERENCE FROM ETHEREUM:
   * Ethereum uses CREATE opcode directly.
   * zkSync may route through deployer system contract.
   *
   * WHAT IF omitted?
   * Deployment may not use correct constructor path.
   */ const aZKAAfactory = new ContractFactory<any[], Contract>(
    abi,
    bytecode,
    wallet,
    "createAccount",
  );

  // const deployOptions = {
  //     customData: {
  //         salt: ethers.ZeroHash,
  //         // What if we don't do factoryDeps?
  //         // factoryDeps,
  //         // factoryDeps: factoryDeps
  //         // Ah! The ContractFactory automatically adds it in!
  //     },
  // }

  /**
   * WHAT happens internally?
   * 1. Encodes constructor calldata.
   * 2. Constructs zkSync Type 113 transaction.
   * 3. Signs transaction.
   * 4. Sends to zkSync RPC.
   * 5. Bootloader validates.
   * 6. Deployer system contract executes deployment.
   *
   * WHO validates?
   * Bootloader invokes account validation.
   *
   * GAS?
   * Paid in zkSync ETH.
   *
   * ERROR PROPAGATION:
   * If constructor reverts → entire tx reverts.
   */ const accountZKAA = await aZKAAfactory.deploy();

  // The above should send the following calldata:
  // 0xecf95b8a0000000000000000000000000000000000000000000000000000000000000000010006ddf1eae1b53a0a62fab1fc8b4fd95c8a6f4d5fe540bf109f17bae0a431000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000
  //
  // If you pop it into `calldata-decode` you'd see that the inputs to the `createAccount` are correct
  // cast calldata-decode "createAccount(bytes32,bytes32,bytes,uint8)"

  /**
   * WHY?
   * Print deployed contract address.
   *
   * WHERE stored?
   * zkSync L2 state.
   */ console.log(`accountZKAA deployed to: ${await accountZKAA.getAddress()}`);

  /**
   * WHAT is deploymentTransaction()?
   * Returns transaction object used for deployment.
   *
   * WHY useful?
   * Can verify on explorer.
   */ console.log(
    `With transaction hash: ${(await accountZKAA.deploymentTransaction())!.hash}`,
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
