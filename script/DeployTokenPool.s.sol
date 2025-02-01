pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {TokenPool} from "src/TokenPool.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract DeployTokenPool is Script{
    function run() external returns (TokenPool, MockERC20){
        vm.startBroadcast();
        MockERC20 mockERC20 = new MockERC20("Token", "TK", 100 ether);
        TokenPool tokenPool = new TokenPool(address(mockERC20));
        vm.stopBroadcast();
        
        return (tokenPool, mockERC20);
    }
}