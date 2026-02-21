// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {EntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
//import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    /**
     * ============================================================================
     *  HelperConfig (Network Environment Resolver)
     * ============================================================================
     *
     * CONTRACT CATEGORY:
     *     Deployment Configuration & Environment Resolver
     *
     * PURPOSE:
     *     Provides deterministic network-specific configuration
     *     for ERC-4337 smart account deployments and scripts.
     *
     * THIS CONTRACT DOES NOT:
     *     - Store user funds
     *     - Validate signatures
     *     - Execute account logic
     *
     * THIS CONTRACT ONLY:
     *     - Maps chain IDs to known infrastructure addresses
     *     - Deploys mocks for local testing
     *     - Exposes configuration for scripts
     *
     * ============================================================================
     * 1. SYSTEM ROLE
     * ============================================================================
     *
     * This contract acts as a configuration oracle for deployment scripts.
     *
     * It determines:
     *
     *     - Which EntryPoint address to use
     *     - Which default account address to assume
     *     - Which USDC token address to interact with
     *
     * It is intended for:
     *
     *     - Foundry script execution
     *     - Local Anvil testing
     *     - Multi-chain deployment
     *
     * ============================================================================
     * 2. TRUST ASSUMPTIONS
     * ============================================================================
     *
     * ASSUMPTION A1:
     *     Hardcoded EntryPoint addresses are correct.
     *
     * WHAT IF FALSE?
     *     Deployed wallet may trust malicious EntryPoint.
     *
     * ASSUMPTION A2:
     *     Hardcoded USDC addresses correspond to legitimate tokens.
     *
     * WHAT IF FALSE?
     *     Scripts may interact with incorrect contracts.
     *
     * ASSUMPTION A3:
     *     Local mock deployment only occurs in testing.
     *
     * ============================================================================
     * 3. GLOBAL SECURITY INVARIANTS
     * ============================================================================
     *
     * INVARIANT I1:
     *     For known chain IDs, networkConfig[chainId].accountAddress != 0.
     *
     * INVARIANT I2:
     *     For unsupported chain IDs, function MUST revert.
     *
     * INVARIANT I3:
     *     Anvil deployment must occur only once per script execution.
     *
     * INVARIANT I4:
     *     entryPoint for zkSync networks is intentionally address(0)
     *     because zkSync uses native account abstraction.
     *
     * ============================================================================
     */
    //
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error HelperConfig___InvalidChainId(uint256 chainId);

    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Network-specific configuration parameters.
     *
     * @param entryPoint
     *     ERC-4337 EntryPoint contract address.
     *
     * @param accountAddress
     *     Default account for script broadcasting.
     *
     * @param usdcAddress
     *     Canonical USDC token address for the network.
     *
     * SECURITY NOTE:
     * - entryPoint == address(0) indicates native AA (e.g., zkSync).
     */
    /**
     * @dev Represents network-specific configuration parameters.
     *
     * @param entryPoint
     *     The ERC-4337 EntryPoint contract address.
     *
     *     WHY required?
     *         Smart accounts depend on EntryPoint for execution.
     *
     * @param accountAddress
     *     Default account used for script broadcasting.
     *
     *     WHY required?
     *         Foundry needs a private key context for deployment.
     *
     * @param usdcAddress
     *     Canonical USDC token address for the network.
     *
     *     WHY required?
     *         Used for interaction tests and deployments.
     *
     * FORMAL PROPERTY:
     *
     *     entryPoint == address(0)
     *         ⇒ network uses native AA (e.g., zkSync)
     */

    struct NetworkConfig {
        address entryPoint;
        address accountAddress;
        address usdcAddress;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 constant SEPOLIA_ETH_CHAINID = 11155111;
    uint256 constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 constant SEPOLIA_ZKSYNC_CHAINID = 300;
    uint256 constant ZKSYNC_MAINNET_CHAIN_ID = 324;
    uint256 constant ANVIL_LOCAL_CHAINID = 31337;
    uint256 constant ARBITRUM_MAINNET_CHAIN_ID = 42161;
    address constant BURNER_WALLET = 0x7e0FB8958F507Bf8FEF8173a16d2A3F0f2D5f6b9;
    address constant DEFAULT_ANVIL_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    NetworkConfig public activeNetworkConfig;

    mapping(uint256 chainid => NetworkConfig) public networkConfig;

    /**
     * ============================================================================
     * @notice Initializes known network configurations.
     * ============================================================================
     *
     * BEHAVIOR:
     *
     *     Pre-populates mapping of chain IDs to NetworkConfig.
     *
     * WHY?
     *
     *     Deterministic environment resolution.
     *
     * FORMAL POSTCONDITIONS:
     *
     *     networkConfig[11155111] == Sepolia config
     *     networkConfig[1]        == Ethereum mainnet config
     *     networkConfig[324]      == zkSync mainnet config
     *     networkConfig[42161]    == Arbitrum mainnet config
     *
     * SECURITY PROPERTY:
     *
     *     No external input accepted.
     *     No user-controlled mutation.
     */
    constructor() {
        networkConfig[SEPOLIA_ETH_CHAINID] = getSepoliaEthConfig();
        networkConfig[ZKSYNC_MAINNET_CHAIN_ID] = getZkSyncConfig();
        networkConfig[ETH_MAINNET_CHAIN_ID] = getETHmainnetConfig();
        networkConfig[ARBITRUM_MAINNET_CHAIN_ID] = getArbitrumMainnetConfig();
    }

    /*//////////////////////////////////////////////////////////////
                                CONFIGS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Returns static configuration for Ethereum Sepolia.
     *
     * WHY hardcoded?
     *     Sepolia EntryPoint address is deterministic.
     *
     * SECURITY ASSUMPTION:
     *     Address 0x5FF1...2789 is official ERC-4337 EntryPoint.
     *
     * WHAT IF EntryPoint upgraded?
     *     Config must be updated manually.
     *
     * PURE FUNCTION:
     *     No state mutation.
     */
    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789, // official sepoilia entrypoint address
            accountAddress: BURNER_WALLET,
            usdcAddress: 0x53844F9577C2334e541Aec7Df7174ECe5dF1fCf0
        });
    }

    function getSepoliaZKsyncConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: address(0),
            accountAddress: BURNER_WALLET,
            usdcAddress: 0x5A7d6b2F92C77FAD6CCaBd7EE0624E64907Eaf3E /**
                                                                     * Note It is not the real address tho on zk sepolia
                                                                     */
        }); // as zk have native AA so address 0 unlike ethereum
    }

    /**
     * @notice Returns zkSync network configuration.
     *
     * SPECIAL PROPERTY:
     *
     *     entryPoint == address(0)
     *
     * WHY?
     *     zkSync implements native account abstraction.
     *     It does not rely on ERC-4337 EntryPoint.
     *
     * SECURITY INVARIANT:
     *
     *     Scripts must detect address(0)
     *     and avoid deploying ERC-4337 wallets.
     *
     * THREAT:
     *
     *     If mistakenly treated as ERC-4337,
     *     execution logic will fail.
     */
    function getZkSyncConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: address(0),
            accountAddress: BURNER_WALLET,
            usdcAddress: 0x1d17CBcF0D6D143135aE902365D2E5e2A16538D4
        }); // as zk have native AA so address 0 unlike ethereum
    }

    /**
     * @notice Returns Ethereum mainnet configuration.
     *
     * EntryPoint address:
     *     0x0000000071727De22E5E9d8BAf0edAc6f37da032
     *
     * SECURITY NOTE:
     *     This must match official deployment.
     *
     * WHAT IF incorrect?
     *     Wallet will trust malicious coordinator.
     */
    function getETHmainnetConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032,
            accountAddress: BURNER_WALLET,
            usdcAddress: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
        }); // as zk have native AA so address 0 unlike ethereum
    }

    function getArbitrumMainnetConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032,
            accountAddress: BURNER_WALLET,
            usdcAddress: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831
        }); // as zk have native AA so address 0 unlike ethereum
    }

    /**
     * ============================================================================
     * @notice Deploys mock EntryPoint and USDC for local Anvil testing.
     * ============================================================================
     *
     * PURPOSE:
     *     Provides local deterministic environment for development.
     *
     * EXECUTION FLOW:
     *
     * 1. If activeNetworkConfig already exists:
     *        Return cached version.
     *
     * 2. Else:
     *        Deploy EntryPoint mock.
     *        Deploy ERC20Mock.
     *        Store in activeNetworkConfig.
     *
     * FORMAL POSTCONDITIONS:
     *
     * Q1:
     *     entryPoint != address(0)
     *
     * Q2:
     *     usdcAddress != address(0)
     *
     * Q3:
     *     activeNetworkConfig set exactly once.
     *
     * SECURITY INVARIANT:
     *
     *     Deployment must only occur under ANVIL_LOCAL_CHAINID.
     *
     * WHY cache result?
     *
     *     Prevent redeploying multiple EntryPoints during script run.
     *
     * THREAT MODEL:
     *
     *     This function uses vm.startBroadcast.
     *     It is intended ONLY for development environments.
     *
     * NOT SAFE FOR:
     *     Production on real networks.
     */
    function createOrGetAnvilConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.accountAddress != address(0)) {
            return activeNetworkConfig;
        }

        console2.log("Deploying Mock EntryPoint.........");
        vm.startBroadcast(DEFAULT_ANVIL_ACCOUNT);
        EntryPoint entryPointMock = new EntryPoint();
        ERC20Mock mockUSDC = new ERC20Mock();

        vm.stopBroadcast();
        console2.log("EntryPoint Mock Deployed at ", address(entryPointMock));
        console2.log("Mock USDC deployed at ", address(mockUSDC));
        activeNetworkConfig = NetworkConfig({
            entryPoint: address(entryPointMock), accountAddress: DEFAULT_ANVIL_ACCOUNT, usdcAddress: address(mockUSDC)
        });
        return activeNetworkConfig;
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * ============================================================================
     * @notice Returns configuration for provided chain ID.
     * ============================================================================
     *
     * BEHAVIOR:
     *
     *     If chainId == 31337 (Anvil):
     *         Deploy or return local config.
     *
     *     Else if mapping contains entry:
     *         Return mapped config.
     *
     *     Else:
     *         Revert with HelperConfig___InvalidChainId.
     *
     * FORMAL PRECONDITION:
     *
     *     chainId must be supported.
     *
     * FORMAL POSTCONDITION:
     *
     *     Returned config.accountAddress != address(0)
     *
     * SECURITY INVARIANT:
     *
     *     Unknown networks MUST revert.
     *
     * WHY?
     *
     *     Prevent accidental deployment to unsupported chains.
     */
    function getConfigByChainID(uint256 chainId) public returns (NetworkConfig memory) {
        if (chainId == ANVIL_LOCAL_CHAINID) {
            return createOrGetAnvilConfig();
        } else if (networkConfig[chainId].accountAddress != address(0)) {
            return networkConfig[chainId];
        } else {
            revert HelperConfig___InvalidChainId(chainId);
        }
    }

    /**
     * @notice Returns configuration for current block.chainid.
     *
     * WHY wrapper exists?
     *
     *     Simplifies script usage.
     *
     * SECURITY:
     *
     *     Delegates to getConfigByChainID.
     *
     * FORMAL PROPERTY:
     *
     *     getConfig() == getConfigByChainID(block.chainid)
     */
    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainID(block.chainid);
    }
}
