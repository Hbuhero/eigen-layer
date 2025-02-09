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

contract TokenPool {
   

    uint256 private constant STAKE_PENALTY = 1 ether;
    string private constant MESSAGE_HASH_PREFIX = "\x19Ethereum Signed Message:\n32";

    address public immutable i_tokenAddress;
    address public immutable i_owner;

    mapping(address staker => uint256 stakerBalance) public balances;
    mapping(address staker => address[] allowedSlashers) public slasher;

    event Staked(address indexed staker);
    event Unstaked(address indexed staker);
    event Slashed(address indexed staker);
    event ValidStaker(address indexed staker);

    modifier onlyOwner(){
        if (msg.sender != i_owner) revert TokenPool__NotOwner();
        _;
    }

    constructor (address tokenAddress) {
        i_tokenAddress = tokenAddress;
        i_owner = msg.sender;
    }
    

    function stake (uint256 amount, address slasherContract) public {
        address sender = msg.sender;

        if(balances[msg.sender] > 0) {
            _stake(amount, sender);
        }else {
            _stake(amount, sender);
            enroll(slasherContract);
        }
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

    function enroll(address slasherContract) public onlyOwner {
        IERC20(i_tokenAddress).approve(slasherContract, balances[msg.sender]);
    }

    function _withdraw(address staker) internal {
        uint256 amountWithdrawn = balances[staker];
        if (amountWithdrawn <= 0) revert TokenPool__ZeroAmount();
        balances[staker] = 0;

        IERC20(i_tokenAddress).transfer(staker, amountWithdrawn);

        emit Unstaked(staker);
    }

    function _stake(uint256 amount, address sender) internal {
        if (amount <= 0) revert TokenPool__ZeroAmount();

        // implement ERC20 token transfer logics. Test in net if works
        bool success = IERC20(i_tokenAddress).transferFrom(sender, address(this), amount);
        balances[sender] = amount;

        if (!success) revert TokenPool__FailedTransfer();

        emit Staked(sender);
    }
}
