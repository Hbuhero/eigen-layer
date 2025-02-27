// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Slasher} from "./Slasher.sol";
import {TokenPool} from "./TokenPool.sol";


error DelegationManager__InvalidOperator();
error DelegationManager__StakerHasDelegation();
error DelegationManager__InvalidSlasher();
error DelegationManager__IsSlashed();
error DelegationManager__ZeroBalance();

contract DelegationManager {
    mapping(address operator => uint256 stakerBalance) private operatorBalance;
    mapping(address operator => address[] allowedSlashers) private slasher;
    mapping(address staker => address operator) private delegation;

    event Slashed(address indexed operator);

    modifier operatorOnly(){
        if (operatorBalance[msg.sender] <= 0) revert DelegationManager__InvalidOperator();
        _;
    }

    function delegateTo (address tokenPool, address operator) public {
        address staker = msg.sender;
        uint256 balance = TokenPool(tokenPool).getStakerBalance(staker);

        if (balance <= 0) revert DelegationManager__ZeroBalance();

        if (delegation[staker] != address(0)) revert DelegationManager__StakerHasDelegation();

        delegation[staker] = operator;
        operatorBalance[operator] += balance;
    }

    function enroll(address slasherContract) public operatorOnly{
        if (operatorBalance[msg.sender] == 0) revert DelegationManager__ZeroBalance();

        slasher[msg.sender].push(slasherContract);
    }

    function exit(address slasherAddress) public operatorOnly {
        if (!isValidSlasher(slasherAddress, msg.sender)) revert DelegationManager__InvalidSlasher();

        if (Slasher(slasherAddress).isOperatorSlashed(msg.sender)) revert DelegationManager__IsSlashed();
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

    function isValidSlasher(address slasherAddress, address operator) public view returns (bool){
        address[] memory slashers = slasher[operator];
        uint256 length = slashers.length;

        for (uint256 i = 0; i < length; i++){
            if (slashers[i] == slasherAddress) {
                
                return true;
            }
        }

        return false;
    }

    function slash(address operator) external {
        address[] memory slashers = slasher[operator];
        uint256 length = slashers.length;
        address slasherAddress = msg.sender;

        for (uint256 i; i < length; i++){
            address slasherContract = slashers[i];
            if (Slasher(slasherContract).isOperatorSlashed(operator) && slasherContract == slasherAddress) {
                operatorBalance[operator] = 0;
                emit Slashed(operator);
                return;
            }
        }

        revert DelegationManager__InvalidSlasher();
    }

    function removeDelegation(address staker, address operator, uint256 amountWithdrawn) external {
        operatorBalance[operator] -= amountWithdrawn;
        delete delegation[staker];
    }

    function slashOperator(address operator) external {
        operatorBalance[operator] = 0;

    }

    function getOperatorBalance(address operator) public view returns (uint256) {
        return operatorBalance[operator];
    }

    function getOperatorSlashers(address operator) public view returns(address[] memory){
        return slasher[operator];
    }

    function getOperator(address staker) public view returns(address){
        return delegation[staker];
    }

}