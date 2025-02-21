pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployTokenPool} from "script/DeployTokenPool.s.sol";
import {Slasher} from "src/Slasher.sol";
import {TokenPool} from "src/TokenPool.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";


contract TokenPoolTest is Test {
    TokenPool public tokenPool;
    Slasher public slasher;
    MockERC20 public mockERC20;
    address public USER = address(1);
    address public OPERATOR = address(2);
    uint256 public stakingAmount = 2 ether;
    address public constant ANVIL_DEFAULT_ADDRESS = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;


    function setUp() external {
        DeployTokenPool deployer = new DeployTokenPool();
        slasher = new Slasher();
        (tokenPool, mockERC20) = deployer.run();
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
        tokenPool.delegateTo(OPERATOR);
        vm.stopPrank();
        _;
    }

    modifier enroll(){
        vm.prank(OPERATOR);
        tokenPool.enroll(address(slasher));
        _;
    }

    function testNewStaker() public {

    }

    function testStaker() public {}

    function testWithdrawByStakerOfMaliciousOperator() public stake(USER) delegate() enroll(){
        //arrange
        slasher.slash(OPERATOR, address(tokenPool));
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
        tokenPool.delegateTo(OPERATOR);

        // Act 
        vm.prank(OPERATOR);
        tokenPool.enroll(address(slasher));

        // assert
        bool isSlasher = tokenPool.isValidSlasher(address(slasher), OPERATOR);
        assertEq(isSlasher, true);
    }

    function testEnrollWithoutStake() public {
        // Act & assert
        vm.prank(USER);
        vm.expectRevert();
        tokenPool.enroll(address(slasher));
    }

    function testSlashWithValidSlasher() public stake(USER) delegate() enroll() {
        //arrange
        slasher.slash(OPERATOR, address(tokenPool));

        // Act
        vm.prank(address(slasher));
        tokenPool.slash(OPERATOR);

        // Assert
        // assertEq(tokenPool.getStakerBalance(USER), 0);
        assertEq(tokenPool.getOperatorBalance(OPERATOR), 0);

    }

    function testSlashWithInvalidSlasher() public stake(USER) delegate() enroll() {
        // arrange 
        slasher.slash(OPERATOR, address(tokenPool));
        Slasher slasher1 = new Slasher();

        // Act & Assert
        vm.prank(address(slasher1));
        vm.expectRevert();
        tokenPool.slash(OPERATOR);
    }

    function testExit() public stake(USER) delegate(){
        //Arrange
        Slasher slasher1 = new Slasher();
        Slasher slasher2 = new Slasher();
        Slasher slasher3 = new Slasher();

        vm.startPrank(OPERATOR);
        tokenPool.enroll(address(slasher));
        tokenPool.enroll(address(slasher1));
        tokenPool.enroll(address(slasher2));
        tokenPool.enroll(address(slasher3));
        vm.stopPrank();

        console.log(tokenPool.getOperatorSlashers(OPERATOR)[2]);

        // Act
        vm.prank(OPERATOR);
        tokenPool.exit(address(slasher2));

        //assert
        bool test = tokenPool.isValidSlasher(address(slasher2), OPERATOR);
        assertEq(test, false);
    }

    

    function testExitWithWrongSlasher() public stake(USER) delegate(){
        //Arrange
        Slasher slasher1 = new Slasher();
        Slasher slasher2 = new Slasher();
        Slasher slasher3 = new Slasher();

        vm.startPrank(OPERATOR);
        tokenPool.enroll(address(slasher));
        tokenPool.enroll(address(slasher1));
        tokenPool.enroll(address(slasher2));
        tokenPool.enroll(address(slasher3));
        vm.stopPrank();

        console.log(tokenPool.getOperatorSlashers(OPERATOR)[2]);

        // Act
        vm.startPrank(OPERATOR);
        tokenPool.exit(address(slasher1));
        vm.expectRevert();
        tokenPool.exit(address(slasher1));
        vm.stopPrank();
    }

    function testDelegate() public stake(USER){
        // Act
        vm.prank(USER);
        tokenPool.delegateTo(OPERATOR);

        assert(tokenPool.getOperatorBalance(OPERATOR) > 0);
    }
}