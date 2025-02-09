pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployTokenPool} from "script/DeployTokenPool.s.sol";
import {TokenPool} from "src/TokenPool.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";


contract TokenPoolTest is Test {
    TokenPool public tokenPool;
    MockERC20 public mockERC20;
    address public USER = address(1);
    uint256 public stakingAmount = 2 ether;
    address public constant ANVIL_DEFAULT_ADDRESS = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;


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

    modifier stake(address user){
        vm.startPrank(user);
        mockERC20.mint(ANVIL_DEFAULT_ADDRESS, 2 ether);
        mockERC20.approve(address(tokenPool), stakingAmount);
        tokenPool.stake(stakingAmount);
        vm.stopPrank();
        _;
    }

    function testWithdraw() public stake(USER) {
        uint256 amountBeforewithdraw = mockERC20.balanceOf(USER);

        vm.prank(USER);
        tokenPool.withdraw();

        uint256 amountAfterWithdraw = mockERC20.balanceOf(USER);

        assertEq(amountAfterWithdraw, amountBeforewithdraw + stakingAmount);
        assertEq(tokenPool.balances(USER), 0);

    }

    // modifier signMessage () {
        // VmSafe.Wallet memory wallet = vm.createWallet("hud"); this is a cheatsheet used to create a  wallet. it brings a private and public key

        // string memory message = "our secret message";
        // bytes32 messageHash = keccak256(abi.encodePacked(message));
        // bytes memory signature = vm.sig
    //     _;
    // }

    // function testSlashWithSignatureVerification() public stake(ANVIL_DEFAULT_ADDRESS) {
    //     // Arrange
    //     string memory message = "our secret message";
    //     bytes32 messageHash = keccak256(abi.encodePacked(message));

    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(ANVIL_DEFAULT_KEY, MessageHashUtils.toEthSignedMessageHash(messageHash));  // a cheatsheet used to return the r v s values of a signature by passing the address and messageHash
    //     bytes memory signature = abi.encodePacked(r, s, v);

    //     // Act
    //     tokenPool.slashBySignatureVerification(ANVIL_DEFAULT_ADDRESS, signature, messageHash);
    //     bool isSigner = tokenPool.verifySignature(messageHash, ANVIL_DEFAULT_ADDRESS, signature);
    //      (uint8 v1,bytes32 r1,)= tokenPool.splitSignature(signature);

    //     // Assert
    //     assertEq(tokenPool.balances(ANVIL_DEFAULT_ADDRESS), 0);
    //     assert(isSigner);
    //     // string memory mnemonic = "test test test test test test test test test test test junk";
    //     // uint256 key = vm.deriveKey(mnemonic, 0);
    //     // address user = vm.addr(key);

    //     // string memory message = "our secret message";
    //     // bytes32 messageHash = keccak256(abi.encodePacked(message));
    //     // bytes32 ethSignedMessage = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

    //     // (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, MessageHashUtils.toEthSignedMessageHash(messageHash));  // a cheatsheet used to return the r v s values of a signature by passing the address and messageHash
    //     // bytes memory signature = abi.encodePacked(r, s, v);

    //     // (, address recovered) = tokenPool.verifySignature(messageHash, user, signature);
    //     // address signer = ecrecover(ethSignedMessage, v, r, s);
    //     // console.log(recovered);
    //     // console.log(signer);
    //     // assertEq(signer, user);

    // }

    // function testLibs() public {
    //     // string memory mnemonic = "test test test test test test test test test test test junk";
    //     // uint256 key = vm.deriveKey(mnemonic, 0);
    //     // address user = vm.addr(key);

    //     string memory message = "our secret message";
    //     bytes32 messageHash = keccak256(abi.encodePacked(message));
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(ANVIL_DEFAULT_KEY, MessageHashUtils.toEthSignedMessageHash(messageHash));  // a cheatsheet used to return the r v s values of a signature by passing the address and messageHash
    //     bytes memory signature = abi.encodePacked(r, s, v);

    //     address signer = tokenPool.verifySignatureUsingECDSA(signature, messageHash);
        
    //     assertEq(signer, ANVIL_DEFAULT_ADDRESS);
    // }

    // to test verifying a signature we need:
    // a signature and the message hash and signer
    // to get the signature we can use vm.sign. This takes the messageHash and either private Key or public address
    // when passing address we need the address to have a wallet. In testing we have to use a made or in built private keys
    // in prod just use an address
    // the return of the vm.sign(privateKey, digest); is the v r s values of the signature
    // to make a full signature just concat the values using abi.encode with the values in order off r s v

    // how to get a private key::
    // either use available ones
    // or define one since its just uin256 and create its corresponding address using vm.addr(privateKey);
    // or create a private key from mnemonic using vm.deriveKey(mnemonic, index);
}