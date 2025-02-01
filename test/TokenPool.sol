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
contract TokenPool {

    uint256 private constant STAKE_PENALTY = 1 ether;

    mapping(address staker => uint256 stakerBalance) public balances;
    

    function stake (uint256 amount) public {

    }

    function withdraw () public {}

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