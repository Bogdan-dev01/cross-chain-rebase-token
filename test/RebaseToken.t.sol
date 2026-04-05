//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { RebaseToken } from "../src/RebaseToken.sol";
import { Vault } from "../src/Vault.sol";
import { IRebaseToken } from "../src/interfaces/IRebaseToken.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract RebaseTokenTest is Test {
    RebaseToken public rebaseToken;
    Vault public vault;

    address OWNER = makeAddr("owner");
    address USER = makeAddr("user");

    function addRewardsToVault(uint256 amount) public {
        // send some rewards to the vault using the receive function
        payable(address(vault)).call{value: amount}("");
    }

    function setUp() public {
        vm.startPrank(OWNER);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
    }

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(USER);
        vm.deal(USER, amount);
        vault.deposit{value: amount}();


        uint256 startingBalance = rebaseToken.balanceOf(USER);
        assertEq(amount, startingBalance);
        console.log("Starting balance:", startingBalance);

        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(USER);
        assertGt(middleBalance, startingBalance);
        console.log("Middle balance:", middleBalance);

        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(USER);
        assertGt(endBalance, middleBalance);
        console.log("End balance:", endBalance);

        assertApproxEqAbs(middleBalance - startingBalance, endBalance - middleBalance, 1);

        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {

        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(USER);
        vm.deal(USER, amount);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(USER), amount);

        vault.redeem(type(uint256).max);

        vm.stopPrank();
    }


    function testRedeemAfterTimaHasPassed(uint256 depositAmount, uint256 time) public {
        time = bound(time, 1e5, type(uint32).max);
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);

        vm.deal(USER, depositAmount);
        vm.prank(USER);
        vault.deposit{value: depositAmount}();

        vm.warp(time);

        uint256 balance = rebaseToken.balanceOf(USER);

        vm.deal(OWNER, balance - depositAmount);
        vm.prank(OWNER);
        addRewardsToVault(balance - depositAmount);

        vm.prank(USER);
        vault.redeem(balance);

        uint256 ethBalance = address(USER).balance;

        assertEq(balance, ethBalance);
        assertGt(balance, depositAmount);

    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount);

        vm.deal(USER, amount);
        vm.prank(USER);
        vault.deposit{value: amount}();

        address USER2 = makeAddr("user2");
        uint256 startingBalanceUser = rebaseToken.balanceOf(USER);
        uint256 startingBalanceUser2 = rebaseToken.balanceOf(USER2);

        assertEq(startingBalanceUser, amount);
        assertEq(startingBalanceUser2, 0);

        vm.prank(OWNER);
        rebaseToken.setInterestRate(4e10);

        vm.prank(USER);
        rebaseToken.transfer(USER2, amountToSend);

        uint256 endUserBalance = rebaseToken.balanceOf(USER);
        uint256 endUser2Balance = rebaseToken.balanceOf(USER2);
        uint256 interestRateUser2 = rebaseToken.getUsersInterestRate(USER2);

        assertEq(endUserBalance, amount - amountToSend);
        assertEq(endUser2Balance, amountToSend);
        assertEq(interestRateUser2, 5e10);
    }

    function testRevertIfNotOwnerSetInterestrate(uint256 newInterestRate) public {
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        vm.prank(USER);
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testCannotCallMintAndBurn(uint256 amount) public {
        vm.startPrank(USER);
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebaseToken.mint(USER, amount, type(uint256).max);
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebaseToken.burn(USER, amount);
    }

    function testGetPrincipleAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(USER, amount);
        vm.prank(USER);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.principleBalanceOf(USER), amount);

        vm.warp(block.timestamp + 1 hours);
        assertEq(rebaseToken.principleBalanceOf(USER), amount);
    }

    function testGetRebaseTokenAddress() public view {
        assertEq(vault.getRebaseTokenAddress(), address(rebaseToken));
    }

    function testInterestRateCanOnlyDecrease() public {
        vm.prank(OWNER);
        vm.expectPartialRevert(RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector);
        rebaseToken.setInterestRate(6e10);
    }

    function testBurnWithMaxAmount(uint256 amount) public {
        uint256 max = type(uint256).max;
        amount = bound(amount, 1e5, type(uint96).max);

        vm.deal(USER, amount);
        vm.prank(USER);
        vault.deposit{value: amount}();

        uint256 startuserBalance = rebaseToken.balanceOf(USER);
        assertEq(startuserBalance, amount);

        vm.prank(OWNER);
        rebaseToken.grantMintAndBurnRole(USER);

        vm.prank(USER);
        rebaseToken.burn(USER, max);

        uint256 endUserBalance = rebaseToken.balanceOf(USER);
        assertEq(endUserBalance, 0);
    }

    function testGetInterestRate() public view {
        assertEq(rebaseToken.getInterestRate(), 5e10);
    }

    function testTransferWithMaxAmount(uint256 amount) public {
        uint256 max = type(uint256).max;
        amount = bound(amount, 1e5, type(uint96).max);
        address USER2 = makeAddr("user2");

        vm.deal(USER, amount);
        vm.prank(USER);
        vault.deposit{value: amount}();
        uint256 startUserBalance = rebaseToken.balanceOf(USER);
        uint256 startUser2Balance = rebaseToken.balanceOf(USER2);
        assertEq(startUserBalance, amount);
        assertEq(startUser2Balance, 0);

        vm.prank(USER); 
        rebaseToken.transfer(USER2, max);

        uint256 endUserBalance = rebaseToken.balanceOf(USER);
        uint256 EndUser2Balance = rebaseToken.balanceOf(USER2);
        assertEq(EndUser2Balance, startUserBalance);
        assertEq(endUserBalance, 0);
    }

    function testTransferFrom(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        address USER2 = makeAddr("user2");
        address SPENDER = makeAddr("spender");

        vm.deal(USER, amount);
        vm.prank(USER);
        vault.deposit{value: amount}();
        uint256 startUserInterestrate = rebaseToken.getUsersInterestRate(USER);

        vm.warp(block.timestamp + 1 hours);
        uint256 startUserBalance = rebaseToken.principleBalanceOf(USER);

        vm.prank(USER);
        rebaseToken.approve(SPENDER, amount);

        vm.prank(SPENDER);
        rebaseToken.transferFrom(USER, USER2, amount);
        

        uint256 endUser2Balance = rebaseToken.principleBalanceOf(USER2);
        uint256 user2Interestrate = rebaseToken.getUsersInterestRate(USER2);



        assertEq(startUserBalance, endUser2Balance);
        assertEq(startUserInterestrate, user2Interestrate);
    }
}
