pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {TokenPool} from "src/TokenPool.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployTokenPool is Script{
    function run() external returns (TokenPool, MockERC20){
        HelperConfig helper = new HelperConfig();
        (address mockToken, uint256 deployerKey) = helper.activeConfig();
        vm.startBroadcast(deployerKey);
        TokenPool tokenPool = new TokenPool(address(mockToken));
        vm.stopBroadcast();
        
        return (tokenPool, MockERC20(mockToken));
    }
}