// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

contract Slasher {
    mapping (address staker => bool slashed) public isSlashed;

    function slash() public {}
}