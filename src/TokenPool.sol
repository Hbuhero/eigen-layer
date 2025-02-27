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
import {DelegationManager} from "./DelegationManager.sol";

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
    address private immutable i_delegationManager;

    mapping(address staker => uint256 balance) private stakerBalance;
    

    event Staked(address indexed staker);
    event Unstaked(address indexed staker);

    modifier onlyOwner(){
        if (msg.sender != i_owner) revert TokenPool__NotOwner();
        _;
    }

    

    constructor (address tokenAddress, address delegationManager) {
        i_tokenAddress = tokenAddress;
        i_owner = msg.sender;
        i_delegationManager = delegationManager;
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
        address operator = DelegationManager(i_delegationManager).getOperator(msg.sender);

        if (operator == address(0)) {
            _withdrawUndelegated(msg.sender);
            return;
        }
        
        uint256 length = DelegationManager(i_delegationManager).getOperatorSlashers(operator).length;

        for (uint256 i; i < length; i++){
            address slasherContract = DelegationManager(i_delegationManager).getOperatorSlashers(operator)[i];
            if (Slasher(slasherContract).isOperatorSlashed(operator)) {
                stakerBalance[msg.sender] = 0;
                revert TokenPool__StakerIsSlashed();
            }
        }
        _withdraw(msg.sender, operator);
    }

    function _withdraw(address staker, address operator) internal {
        uint256 amountWithdrawn = stakerBalance[staker];
        if (amountWithdrawn <= 0) revert TokenPool__ZeroBalance();
        stakerBalance[staker] = 0;
        DelegationManager(i_delegationManager).removeDelegation(staker ,operator, amountWithdrawn);
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

    function getTokenAddress() public view returns (address){
        return i_tokenAddress;
    }

    function getOwnerAddress() public view returns (address){
        return i_owner;
    }

    
}
// in this model a home staker has to stake and delegate to itself to contribute to eigen layer
// since the enroll function is access controlled to operators only, delegation is mandatory to a staker
// for safety of users assests, a staker who didnt delegate can ultimately withdraw if no longer wish to 
// participate (self delegate or otherwise) 