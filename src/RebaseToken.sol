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
// internal & private view & pure functions
// external & public view & pure functions

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @author BohdanDev
 * @notice This is cross-chain rebase token that incentivises users to deposit into a vault and gane interest in the rewards
 * @notice The interest rate in contract can only decrease
 * @notice Each user will have their own interest rate that is the global interest rate at the time of depositing
 */

contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__InterestRateCanOnlyDecrease(
        uint256 oldInterestRate,
        uint256 newInterestRate
    );

    uint256 private s_interestRate = (5 * PRECISION_FACTOR) / 1e8;
    uint256 private constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    mapping(address => uint256) private s_usersInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimeStamp;

    event InterestRateSet(uint256 newInterestRate);

    constructor() ERC20("Rebase Token", "RBTK") Ownable(msg.sender) {}

    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
     * @notice Set the interest rate in the contract
     * @param _newInterestRate The new interest rate to set
     * @dev The interest rate can only decrease
     */

    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if (_newInterestRate >= s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(
                s_interestRate,
                _newInterestRate
            );
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }


    /**
    * @notice Get the principlebalace of the user. This is a number of tokens that have currently been minted to the user, not including any interest that has accured since the last time the user interact with protocol.
    * @param _user The user to get the principle balance for
    * @return The principle balance of the user 
    */  
    function principleBalanceOf(address _user) external view returns(uint256) {
        return super.balanceOf(_user);
    }

    /**
     * @notice Mint the user tokens when they deposit into the vault
     * @param _to The user to mint the tokens to
     * @param _amount The amount of tokens to mint
     */
    function mint(address _to, uint256 _amount, uint256 _userInterestRate) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccuredinterest(_to);
        s_usersInterestRate[_to] = _userInterestRate;
        _mint(_to, _amount);
    }

    /**
    * @notice Burn the user tokens when the withdraw from the vault
    * @param _from The user to burn the tokens from
    * @param _amount The amount of tokens to burn 
    */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if(_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccuredinterest(_from);
        _burn(_from, _amount);
    } 

    /** 
     * @notice To calculate the balance for the user including the interest that has accumulated since the last update
     * (principle balance) + some interest that has accrude
     * @param _user The user to calculate the balance for
     * @return The balance of the user including the interest that has accumulated since the last update
     */

    function balanceOf(address _user) public view override returns (uint256) {
        // get the current principle balance of the user (the number of token that have actually been minted)
        // multiply the principle balance by the interest that has been accumulated in the time since the balance was last updated
        return
            (super.balanceOf(_user) *
                _calculateUserAccumulatedInterestSinceLastUpdated(_user)) /
            PRECISION_FACTOR;
    }

    /**
    * @notice Transfer token from one user to another 
    * @param _recipient The user to transfer token to
    * @param _amount The amount tokens to trasfer
    * @return True if the transfer was success
    */
    function transfer(address _recipient, uint256 _amount) public override returns(bool) {
        _mintAccuredinterest(msg.sender);
        _mintAccuredinterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender); 
        }
        if (balanceOf(_recipient) == 0) {
            s_usersInterestRate[_recipient] = s_usersInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    } 

    /**
    * @notice Transfer token from one user to another 
    * @param _sender The user to transfer tokens from
    * @param _recipient The user to transfer token to
    * @param _amount The amount tokens to trasfer
    * @return True if the transfer was success
    */
     // not tested
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccuredinterest(_sender);
        _mintAccuredinterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_usersInterestRate[_recipient] = s_usersInterestRate[_sender]; 
        }
        return super.transferFrom(_sender, _recipient, _amount);
        
    }

    /**
     * @notice Calculate the interest that has accumulated since the last update
     * @param _user The user to calculate the interest for
     * @return linearInterest The interest that has accumulated since the last update
     */

    function _calculateUserAccumulatedInterestSinceLastUpdated(
        address _user
    ) internal view returns (uint256 linearInterest) {
        // we need to calculate the interest that has accumulated since the last update
        // this is going to be linear growth with the time
        // 1. calculate the time since the last update
        // 2. calculate the amount of linear growth
        // deposit = 10 tokens
        // interest rate = 0.05 tokens per second
        // time elapsed = 2 sec
        // 10 + (10 * 0.5 * 2)
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimeStamp[_user];
        linearInterest = PRECISION_FACTOR + (s_usersInterestRate[_user] * timeElapsed);
    }

    /**
    * @notice Mint the accured interest to the user since the last time they interacted with the protocol
    * @param _user The user to mint the accrued interest to
    */ 
    function _mintAccuredinterest(address _user) internal {
        
         // (1) Find their current balance of rebase tokens that have been minted to the user -> principle balance
        uint256 previousPrincipleBalance = super.balanceOf(_user);
         // (2) Calculate their current balance including any interest -> balanceOf
        uint256 currentBalance = balanceOf(_user);
         // Calculate the number of tokens that need to be minted to the user -> (2) - (1)
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;
        
         // Set the users last updated timestamp
        s_userLastUpdatedTimeStamp[_user] = block.timestamp;
         // Call _mint to mint the tokens to the user
        _mint(_user, balanceIncrease); 
    }


    /**
    * @notice get the interest rate that is currently set for the contract. Any future depositors will receive that interest rate
    * @return Interest rate of the contract
    */
    function getInterestRate() public view returns(uint256) {
        return s_interestRate;
    }

    /**
     * @notice Get the interest rate for the user
     * @param _user The user to get interest rate for
     * @return The interest rate for the user
     */
    function getUsersInterestRate(
        address _user
    ) external view returns (uint256) {
        return s_usersInterestRate[_user];
    }
}
