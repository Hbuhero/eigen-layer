// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract HelperConfig is Script {
    NetworkConfig public activeConfig;

    uint256 public constant ETHEREUM_SEPOLIA_CHAINID = 11155111;
    uint256 public constant ANVIL_CHAINID = 31337;

    struct NetworkConfig {
        address tokenAddress;
        address deployerKey;
    }

    uint256 public DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address public DEFAULT_ANVIL_ADDRESS = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    

    constructor() {
        if (block.chainid == ANVIL_CHAINID) {
            activeConfig = getOrCreateAnvilConfig();
        } else {
            activeConfig = getSepoliaConfig();
        }
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory){
        if (activeConfig.tokenAddress != address(0)) return activeConfig;

        vm.startBroadcast();
        MockERC20 mockERC20 = new MockERC20("MockToken", "MTK", 100 ether);
        vm.stopBroadcast();

        return NetworkConfig({
            tokenAddress: address(mockERC20),
            deployerKey: DEFAULT_ANVIL_ADDRESS
        });
    }

    function getSepoliaConfig() public pure returns (NetworkConfig memory){
        return NetworkConfig({
            tokenAddress: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            deployerKey: 0xCE3CEEB3AB15E50aB502c406330fE99b16216fDB
            // deployerKey: vm.envUint(namee);

        });
    }
}