pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployTokenPool} from "script/DeployTokenPool.s.sol";
import {TokenPool} from "src/TokenPool.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenPoolTest is Test {
    TokenPool public tokenPool;
    MockERC20 public mockERC20;
    address public USER = address(1);


    function setUp() external {
        DeployTokenPool deployer = new DeployTokenPool();

        (tokenPool, mockERC20) = deployer.run();
        vm.deal(USER, 10 ether);
        mockERC20.mint(USER, 10 ether);
    }

    function testStake() public {
        uint256 initialContractBalance = IERC20(mockERC20).balanceOf(address(tokenPool));
        uint256 amount = 1 ether;

        vm.startPrank(USER);
        mockERC20.approve(address(tokenPool), amount);
        tokenPool.stake(amount);
        vm.stopPrank();

        uint256 finalBalance = mockERC20.balanceOf(address(tokenPool));

        assertEq(finalBalance, initialContractBalance + amount);
    }
}