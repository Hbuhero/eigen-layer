// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions
// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Slasher} from "./Slasher.sol";

error TokenPool__ZeroBalance();
error TokenPool__FailedTransfer();
error TokenPool__NotOwner();
error TokenPool__StakerIsSlashed();
error TokenPool__InvalidSlasher();
error TokenPool__InvalidOperator();
error TokenPool__StakerHasDelegation();
error TokenPool__IsSlashed();

contract TokenPool {

    address private immutable i_tokenAddress;
    address private immutable i_owner;

    mapping(address staker => uint256 balance) private stakerBalance;
    mapping(address operator => uint256 stakerBalance) private operatorBalance;
    mapping(address operator => address[] allowedSlashers) private slasher;
    mapping(address staker => address operator) private delegation;

    event Staked(address indexed staker);
    event Unstaked(address indexed staker);
    event Slashed(address indexed staker);
    event ValidStaker(address indexed staker);

    modifier onlyOwner(){
        if (msg.sender != i_owner) revert TokenPool__NotOwner();
        _;
    }

    modifier operatorOnly(){
        if (operatorBalance[msg.sender] <= 0) revert TokenPool__InvalidOperator();
        _;
    }

    constructor (address tokenAddress) {
        i_tokenAddress = tokenAddress;
        i_owner = msg.sender;
    }
    

    function stake (uint256 amount) public {
        address sender = msg.sender;

        if (amount <= 0) revert TokenPool__ZeroBalance();

        // implement ERC20 token transfer logics. Test in net if works
        bool success = IERC20(i_tokenAddress).transferFrom(sender, address(this), amount);
        stakerBalance[sender] = amount;

        if (!success) revert TokenPool__FailedTransfer();

        emit Staked(sender);
    }

    function withdraw () public {
        address operator = delegation[msg.sender];

        if (operator == address(0)) {
            _withdrawUndelegated(msg.sender);
            return;
        }
        
        uint256 length = slasher[operator].length;

        for (uint256 i; i < length; i++){
            address slasherContract = slasher[operator][i];
            if (Slasher(slasherContract).isOperatorSlashed(operator)) {
                stakerBalance[msg.sender] = 0;
                revert TokenPool__StakerIsSlashed();
            }
        }
        _withdraw(msg.sender, operator);
    }

    function delegateTo (address operator) public {
        address staker = msg.sender;
        uint256 balance = stakerBalance[staker];

        if (balance <= 0) revert TokenPool__ZeroBalance();

        if (delegation[staker] != address(0)) revert TokenPool__StakerHasDelegation();

        delegation[staker] = operator;
        operatorBalance[operator] += balance;
    }

    function enroll(address slasherContract) public operatorOnly{
        if (operatorBalance[msg.sender] == 0) revert TokenPool__ZeroBalance();

        slasher[msg.sender].push(slasherContract);
    }

    function exit(address slasherAddress) public operatorOnly {
        if (!isValidSlasher(slasherAddress, msg.sender)) revert TokenPool__InvalidSlasher();

        if (Slasher(slasherAddress).isOperatorSlashed(msg.sender)) revert TokenPool__IsSlashed();
        address[] memory slasherAddresses = slasher[msg.sender];
        uint256 length = slasherAddresses.length;

        for(uint256 i = 0; i < length; i++){
            if(slasherAddresses[i] == slasherAddress){
                slasher[msg.sender][i] = slasher[msg.sender][length-1];
                slasher[msg.sender].pop();
                break;
            }
        }

    }

    // update this to work with both staker and delegator
    function slash(address operator) external {
        uint256 length = slasher[operator].length;
        address slasherAddress = msg.sender;

        for (uint256 i; i < length; i++){
            address slasherContract = slasher[operator][i];
            if (Slasher(slasherContract).isOperatorSlashed(operator) && slasherContract == slasherAddress) {
                operatorBalance[operator] = 0;
                emit Slashed(operator);
                return;
            }
        }

        revert TokenPool__InvalidSlasher();
    }

    // this too
    function isValidSlasher(address slasherAddress, address operator) public view returns (bool){
        uint256 length = slasher[operator].length;

        for (uint256 i = 0; i < length; i++){

            address slasherContract = slasher[operator][i];

            if (slasherContract == slasherAddress) {
                
                return true;
            }
        }

        return false;
    }

    function _withdraw(address staker, address operator) internal {
        uint256 amountWithdrawn = stakerBalance[staker];
        if (amountWithdrawn <= 0) revert TokenPool__ZeroBalance();
        stakerBalance[staker] = 0;
        operatorBalance[operator] -= amountWithdrawn;
        delete delegation[staker];
        IERC20(i_tokenAddress).transfer(staker, amountWithdrawn);

        emit Unstaked(staker);
    }

    function _withdrawUndelegated(address staker) internal {
        uint256 amountWithdrawn = stakerBalance[staker];
        if (amountWithdrawn <= 0) revert TokenPool__ZeroBalance();
        stakerBalance[staker] = 0;
        IERC20(i_tokenAddress).transfer(staker, amountWithdrawn);

        emit Unstaked(staker);
    }

    function _stake(uint256 amount, address sender) internal {
        if (amount <= 0) revert TokenPool__ZeroBalance();

        // implement ERC20 token transfer logics. Test in net if works
        bool success = IERC20(i_tokenAddress).transferFrom(sender, address(this), amount);
        stakerBalance[sender] = amount;

        if (!success) revert TokenPool__FailedTransfer();

        emit Staked(sender);
    }

    function getStakerBalance(address staker) public view returns (uint256) {
        return stakerBalance[staker];
    }

    function getOperatorBalance(address operator) public view returns (uint256) {
        return operatorBalance[operator];
    }

    function getTokenAddress() public view returns (address){
        return i_tokenAddress;
    }

    function getOwnerAddress() public view returns (address){
        return i_owner;
    }

    function getOperatorSlashers(address operator) public view returns(address[] memory){
        return slasher[operator];
    }
}
// in this model a home staker has to stake and delegate to itself to contribute to eigen layer
// since the enroll function is access controlled to operators only, delegation is mandatory to a staker
// for safety of users assests, a staker who didnt delegate can ultimately withdraw if no longer wish to 
// participate (self delegate or otherwise) 