pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {TokenPool} from "src/TokenPool.sol";
import {DelegationManager} from "src/DelegationManager.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployTokenPool is Script{
    function run() external returns (TokenPool, MockERC20, DelegationManager){
        HelperConfig helper = new HelperConfig();
        (address mockToken, address deployerKey, address delegationManager) = helper.activeConfig();
        vm.startBroadcast(deployerKey);
        TokenPool tokenPool = new TokenPool(address(mockToken), delegationManager);
        vm.stopBroadcast();
        
        return (tokenPool, MockERC20(mockToken), DelegationManager(delegationManager));
    }
}