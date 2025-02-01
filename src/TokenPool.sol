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
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error TokenPool__ZeroAmount();
error TokenPool__FailedTransfer();

contract TokenPool {

    uint256 private constant STAKE_PENALTY = 1 ether;

    address public immutable i_tokenAddress;

    mapping(address staker => uint256 stakerBalance) public balances;

    event Staked(address indexed staker);
    event Unstaked(address indexed staker);

    constructor (address tokenAddress) {
        i_tokenAddress = tokenAddress;
    }
    

    function stake (uint256 amount) public {
        address sender = msg.sender;
        if (amount <= 0) revert TokenPool__ZeroAmount();

        // implement ERC20 token transfer logics. Test in net if works
        bool success = IERC20(i_tokenAddress).transferFrom(msg.sender, address(this), amount);
        balances[sender] = amount;

        if (!success) revert TokenPool__FailedTransfer();

        emit Staked(msg.sender);
    }

    function withdraw () public {
        uint256 amountWithdrawn = balances[msg.sender];
        if (amountWithdrawn <= 0) revert TokenPool__ZeroAmount();
        balances[msg.sender] = 0;

        IERC20(address(this)).transfer(msg.sender, amountWithdrawn);

        emit Unstaked(msg.sender);
    }

    /**
     * @notice We will implement this function in two ways
     * 1. Is by using a trusted slasher to slash the staker. 
     * Here the proof will only be recorded.
     * 
     * 2. Using a more decentralized approach: using a signed message for proof verification or on-chain verification
     */
    function slash (address staker) public {
    
    }
}