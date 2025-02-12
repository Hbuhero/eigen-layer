// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {TokenPool} from "./TokenPool.sol";

error Slasher__NotOwner();

/**
 * @title Slasher Contract
 * @author Hud Saidi
 * @notice This contract mimicks the external service (AVS) contract that is able to slash stakers for misconduct.
 * Each AVS has its own slashing conditions, hence this contract tells TokenPool contract that a certain staker
 * in the layer is malicious in this AVS. 
 */
contract Slasher {
    address public immutable i_owner;
    
    mapping (address operator => bool slashed) public isSlashed;

    modifier onlyOwner(){
        if (msg.sender != i_owner) revert Slasher__NotOwner();
        _;
    }

    constructor () {
        i_owner = msg.sender;
    }

    /**
     * 
     * @notice This slash function assumes a trusted entity with permission to slash. A more decentralized approach
     * will be submitting and verifying proof about the misconduct of the staker
     */
    function slash(address operator, address tokenPool) public onlyOwner{
        isSlashed[operator] = true;
        TokenPool(tokenPool).slash(operator);
    }

    
}