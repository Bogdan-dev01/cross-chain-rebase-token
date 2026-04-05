// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IRebaseToken } from "./interfaces/IRebaseToken.sol";

contract Vault {

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    error Vault__Redeemfailed();

    IRebaseToken private immutable i_rebaseToken;

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    // allows the contract to receive rewards
    receive() external payable {} 

    /**
     * @notice Allows users to deposit ETH intoo the vault and mint tokens in return 
     */
    function deposit() external payable {
        //we need to use the amount of ETH the user has sent to mint tokens to the user
        uint256 interestRate = i_rebaseToken.getInterestRate();
        i_rebaseToken.mint(msg.sender, msg.value, interestRate);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @dev redeems rebase token for the underlying asset
     * @param _amount the amount being redeemed
     */

    function redeem(uint256 _amount) external {

        if(_amount == type(uint256).max) {
        _amount = i_rebaseToken.balanceOf(msg.sender);
        }

        // 1. burn the tokens from the user 
        i_rebaseToken.burn(msg.sender, _amount);
        // 2. we need to send the user ETH
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__Redeemfailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    function getRebaseTokenAddress() public view returns(address) {
        return address(i_rebaseToken);
    }
}