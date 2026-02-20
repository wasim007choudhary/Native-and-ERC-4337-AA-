// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {EntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";
//import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error HelperConfig___InvalidChainId(uint256 chainId);

    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/
    struct NetworkConfig {
        address entryPoint;
        address accountAddress;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 constant SEPOLIA_ETH_CHAINID = 11155111;
    uint256 constant SEPOLIA_ZKSYNC_CHAINID = 300;
    uint256 constant ANVIL_LOCAL_CHAINID = 31337;
    address constant BURNER_WALLET = 0x7e0FB8958F507Bf8FEF8173a16d2A3F0f2D5f6b9;
    address constant DEFAULT_ANVIL_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    NetworkConfig public activeNetworkConfig;

    mapping(uint256 chainid => NetworkConfig) public networkConfig;

    constructor() {
        networkConfig[SEPOLIA_ETH_CHAINID] = getSepoliaEthConfig();
        networkConfig[SEPOLIA_ZKSYNC_CHAINID] = getSepoliaZKsyncConfig();
    }

    /*//////////////////////////////////////////////////////////////
                                CONFIGS
    //////////////////////////////////////////////////////////////*/
    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789, // official sepoilia entrypoint address
            accountAddress: BURNER_WALLET
        });
    }

    function getSepoliaZKsyncConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({entryPoint: address(0), accountAddress: BURNER_WALLET}); // as zk have native AA so address 0 unlike ethereum
    }

    function createOrGetAnvilConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.accountAddress != address(0)) {
            return activeNetworkConfig;
        }

        console2.log("Deploying Mock EntryPoint.........");
        vm.startBroadcast(DEFAULT_ANVIL_ACCOUNT);
        EntryPoint entryPointMock = new EntryPoint();
        // ERC20Mock mockUSDC = new ERC20Mock();

        vm.stopBroadcast();
        console2.log("EntryPoint Mock Deployed at ", address(entryPointMock));
        activeNetworkConfig =
            NetworkConfig({entryPoint: address(entryPointMock), accountAddress: DEFAULT_ANVIL_ACCOUNT});
        return activeNetworkConfig;
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getConfigByChainID(uint256 chainId) public returns (NetworkConfig memory) {
        if (chainId == ANVIL_LOCAL_CHAINID) {
            return createOrGetAnvilConfig();
        } else if (networkConfig[chainId].accountAddress != address(0)) {
            return networkConfig[chainId];
        } else {
            revert HelperConfig___InvalidChainId(chainId);
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainID(block.chainid);
    }
}
