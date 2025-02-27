// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployTokenPool} from "script/DeployTokenPool.s.sol";
import {Slasher} from "src/Slasher.sol";
import {TokenPool} from "src/TokenPool.sol";
import {DelegationManager} from "src/DelegationManager.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";


contract TokenPoolTest is Test {
    TokenPool public tokenPool;
    DelegationManager public manager;
    Slasher public slasher;
    MockERC20 public mockERC20;
    address public USER = address(1);
    address public OPERATOR = address(2);
    uint256 public stakingAmount = 2 ether;
    address public constant ANVIL_DEFAULT_ADDRESS = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;


    function setUp() external {
        DeployTokenPool deployer = new DeployTokenPool();
        (tokenPool, mockERC20, manager) = deployer.run();
        slasher = new Slasher(address(manager));
        vm.deal(USER, 10 ether);
        mockERC20.mint(USER, 10 ether);
    }


    modifier stake(address user){
        vm.startPrank(user);
        mockERC20.mint(ANVIL_DEFAULT_ADDRESS, 2 ether);
        mockERC20.approve(address(tokenPool), stakingAmount);
        tokenPool.stake(stakingAmount);
        vm.stopPrank();
        _;
    }

    modifier delegate(){
        vm.startPrank(USER);
        manager.delegateTo(address(tokenPool), OPERATOR);
        vm.stopPrank();
        _;
    }

    modifier enroll(){
        vm.prank(OPERATOR);
        manager.enroll(address(slasher));
        _;
    }

    function testNewStaker() public {

    }

    function testStaker() public {}

    function testWithdrawByStakerOfMaliciousOperator() public stake(USER) delegate() enroll(){
        //arrange
        slasher.slash(OPERATOR);
        // slasher.setIsSlashedToTrue(USER);

        // act and assert
        vm.startPrank(USER);
        vm.expectRevert();
        tokenPool.withdraw();
        vm.stopPrank();

    }

    function testWithdrawWithValidStaker() public stake(USER){
        // act
        vm.prank(USER);
        tokenPool.withdraw();

        // assert
        assertEq(tokenPool.getStakerBalance(USER), 0);
    }

    function testEnroll() public stake(USER){
        // arrage 
        vm.prank(USER);
        manager.delegateTo(address(tokenPool), OPERATOR);

        // Act 
        vm.prank(OPERATOR);
        manager.enroll(address(slasher));

        // assert
        bool isSlasher = manager.isValidSlasher(address(slasher), OPERATOR);
        assertEq(isSlasher, true);
    }

    function testEnrollWithoutStake() public {
        // Act & assert
        vm.prank(USER);
        vm.expectRevert();
        manager.enroll(address(slasher));
    }

    function testSlashWithValidSlasher() public stake(USER) delegate() enroll() {
        //arrange
        slasher.slash(OPERATOR);

        // Act
        vm.prank(address(slasher));
        manager.slash(OPERATOR);

        // Assert
        // assertEq(tokenPool.getStakerBalance(USER), 0);
        assertEq(manager.getOperatorBalance(OPERATOR), 0);

    }

    function testSlashWithInvalidSlasher() public stake(USER) delegate() enroll() {
        // arrange 
        slasher.slash(OPERATOR);
        Slasher slasher1 = new Slasher(address(manager));

        // Act & Assert
        vm.prank(address(slasher1));
        vm.expectRevert();
        manager.slash(OPERATOR);
    }

    function testExit() public stake(USER) delegate(){
        //Arrange
        Slasher slasher1 = new Slasher(address(manager));
        Slasher slasher2 = new Slasher(address(manager));
        Slasher slasher3 = new Slasher(address(manager));

        vm.startPrank(OPERATOR);
        manager.enroll(address(slasher));
        manager.enroll(address(slasher1));
        manager.enroll(address(slasher2));
        manager.enroll(address(slasher3));
        vm.stopPrank();

        console.log(manager.getOperatorSlashers(OPERATOR)[2]);

        // Act
        vm.prank(OPERATOR);
        manager.exit(address(slasher2));

        //assert
        bool test = manager.isValidSlasher(address(slasher2), OPERATOR);
        assertEq(test, false);
    }

    

    function testExitWithWrongSlasher() public stake(USER) delegate(){
        //Arrange
        Slasher slasher1 = new Slasher(address(manager));
        Slasher slasher2 = new Slasher(address(manager));
        Slasher slasher3 = new Slasher(address(manager));

        vm.startPrank(OPERATOR);
        manager.enroll(address(slasher1));
        manager.enroll(address(slasher2));
        manager.enroll(address(slasher3));
        vm.stopPrank();

        console.log(manager.getOperatorSlashers(OPERATOR)[2]);

        // Act & Assert
        vm.prank(OPERATOR);
        vm.expectRevert();
        manager.exit(address(slasher));
    }

    function testDelegate() public stake(USER){
        // Act
        vm.prank(USER);
        manager.delegateTo(address(tokenPool), OPERATOR);

        assert(manager.getOperatorBalance(OPERATOR) > 0);
    }
}