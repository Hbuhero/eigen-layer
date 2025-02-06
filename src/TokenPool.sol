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
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

error TokenPool__ZeroAmount();
error TokenPool__FailedTransfer();
error TokenPool__NotOwner();

contract TokenPool {
   

    uint256 private constant STAKE_PENALTY = 1 ether;
    string private constant MESSAGE_HASH_PREFIX = "\x19Ethereum Signed Message:\n32";

    address public immutable i_tokenAddress;
    address public immutable i_owner;

    mapping(address staker => uint256 stakerBalance) public balances;

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

        IERC20(i_tokenAddress).transfer(msg.sender, amountWithdrawn);

        emit Unstaked(msg.sender);
    }

    /**
     * @dev We will implement the slashing function in various ways
     * 1. Is by using a trusted slasher to slash the staker. 
     * 
     * 2. Verifying signatures to prove that a staker has acted maliciously
     * 
     * 3. Verifying Merkle proofs submitted from offchain computation of a malicious staker
     * 
     * @notice The slashing functions only illustrates different ways of proving malicious activities but are not the actual implementation
     */

    function slashByTrustedOwner (address staker, bytes32[] calldata proof) public onlyOwner{
        if (balances[staker] <= 0) revert TokenPool__ZeroAmount();
        balances[staker] = 0;
        emit Slashed(staker);
    }

    function slashByMerkleProofVerification (
        address staker, 
        bytes32[] calldata proof,
        bytes32 leaf,
        bytes32 root
    ) public {
        bool isSlashed = MerkleProof.verify(proof, root, leaf);

        slash(isSlashed, staker);
        
    }

    function slashBySignatureVerification(
        address staker,
        bytes memory signature,
        bytes32 messageHash
    ) public {
            (bool isSlashed, ) = verifySignature(messageHash, staker, signature);

            slash(isSlashed, staker);
    }

    function usingLibs(
        address staker,
        bytes memory signature,
        bytes32 messageHash
    ) public returns (address, bool) {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        address signer = ECDSA.recover(ethSignedMessageHash, signature);
        return (signer, signer == staker);
    }


    function verifySignature(
        bytes32 messageHash,
        address staker,
        bytes memory signature
    ) public pure returns (bool, address){
        bytes32 prefixedMessageHash = keccak256(abi.encodePacked(MESSAGE_HASH_PREFIX, messageHash));
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);
        address recoveredSigner = ecrecover(prefixedMessageHash, v, r, s);
        return (recoveredSigner == staker, recoveredSigner);
    }

    function slash (bool isSlashed, address staker) public {
        if (!isSlashed) {
            emit ValidStaker(staker);
            return;
        }

        if (balances[staker] <= 0) revert TokenPool__ZeroAmount();
        balances[staker] = 0;
        emit Slashed(staker);
    }

    function splitSignature(bytes memory signature) public pure returns (uint8 v, bytes32 r, bytes32 s){
        require(signature.length == 65, "invalid signature length");

        assembly {
            /*
            First 32 bytes stores the length of the signature

            add(sig, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature

            mload(p) loads next 32 bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(signature, 32))
            // second 32 bytes
            s := mload(add(signature, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(signature, 96)))
        }
    }
}