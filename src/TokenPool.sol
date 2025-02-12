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

error TokenPool__ZeroAmount();
error TokenPool__FailedTransfer();
error TokenPool__NotOwner();
error TokenPool__StakerIsSlashed();
error TokenPool__InvalidSlasherForStaker();
error TokenPool__InvalidOperator();

contract TokenPool {

    string private constant MESSAGE_HASH_PREFIX = "\x19Ethereum Signed Message:\n32";

    address private immutable i_tokenAddress;
    address private immutable i_owner;

    mapping(address staker => uint256 stakerBalance) private stakerBalance;
    mapping(address staker => uint256 stakerBalance) private operatorBalance;
    mapping(address staker => address[] allowedSlashers) private slasher;
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

        if (amount <= 0) revert TokenPool__ZeroAmount();

        // implement ERC20 token transfer logics. Test in net if works
        bool success = IERC20(i_tokenAddress).transferFrom(sender, address(this), amount);
        stakerBalance[sender] = amount;

        if (!success) revert TokenPool__FailedTransfer();

        emit Staked(sender);
    }

    function withdraw () public {
        address staker = msg.sender;
        uint256 length = slasher[staker].length;

        for (uint256 i; i < length; i++){
            address slasherContract = slasher[staker][i];
            if (Slasher(slasherContract).isSlashed(staker)) {
                revert TokenPool__StakerIsSlashed();
            }
        }
        _withdraw(staker);
    }

    function delegateTo (address operator) public {}

    function enroll(address slasherContract) public {
        if (stakerBalance[msg.sender] == 0) revert TokenPool__ZeroAmount();

        IERC20(i_tokenAddress).approve(slasherContract, stakerBalance[msg.sender]);
        slasher[msg.sender].push(slasherContract);
    }

    function exit(address slasher) public operatorOnly {}

    function slash(address staker) external {
        uint256 length = slasher[staker].length;
        address slasherAddress = msg.sender;

        for (uint256 i; i < length; i++){
            address slasherContract = slasher[staker][i];
            if (Slasher(slasherContract).isSlashed(staker) && slasherContract == slasherAddress) {
                stakerBalance[staker] = 0;
                emit Slashed(staker);
                return;
            }
        }

        revert TokenPool__InvalidSlasherForStaker();
    }

    function isValidSlasher(address slasherAddress, address staker) public view returns (bool){
        uint256 length = slasher[staker].length;

        for (uint256 i; i < length; i++){

            address slasherContract = slasher[staker][i];

            if (slasherContract == slasherAddress) {
                
                return true;
            }
        }

        return false;
    }

    function getStakerBalance(address staker) public view returns (uint256) {
        return stakerBalance[staker];
    }

    function getOperatorBalance(address staker) public view returns (uint256) {
        return stakerBalance[staker];
    }

    function getTokenAddress() public view returns (address){
        return i_tokenAddress;
    }

    function getOwnerAddress() public view returns (address){
        return i_owner;
    } 

    function _withdraw(address staker) internal {
        uint256 amountWithdrawn = stakerBalance[staker];
        if (amountWithdrawn <= 0) revert TokenPool__ZeroAmount();
        stakerBalance[staker] = 0;

        IERC20(i_tokenAddress).transfer(staker, amountWithdrawn);

        emit Unstaked(staker);
    }

    function _stake(uint256 amount, address sender) internal {
        if (amount <= 0) revert TokenPool__ZeroAmount();

        // implement ERC20 token transfer logics. Test in net if works
        bool success = IERC20(i_tokenAddress).transferFrom(sender, address(this), amount);
        stakerBalance[sender] = amount;

        if (!success) revert TokenPool__FailedTransfer();

        emit Staked(sender);
    }
}
