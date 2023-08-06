// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DeployDecentralizedStableCoin} from "../../script/DeployDecentralizedStableCoin.s.sol";

/**
 * @title Tests for Decentralized stable coin contract
 * @author Michael Koch
 * @notice These tests were written strictly by me, DSCEngineTest file is where tests from course will be written.
 */

contract DecentralizedStableCoinTest is Test {
    error DecentralizedStableCoin__MustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    uint256 public constant INITIAL_COIN_AMOUNT = 5;

    address public USER = makeAddr("Mike");

    DeployDecentralizedStableCoin public deployer;
    DecentralizedStableCoin public decentralizedStableCoin;

    modifier mintCoin() {
        vm.prank(msg.sender);
        decentralizedStableCoin.mint(USER, INITIAL_COIN_AMOUNT);
        _;
    }

    function setUp() public {
        deployer = new DeployDecentralizedStableCoin();
        (decentralizedStableCoin,,) = deployer.run();
    }

    function testRevertIfAddressIsZeroMinting() public {
        vm.expectRevert(DecentralizedStableCoin__NotZeroAddress.selector);
        vm.prank(msg.sender);
        decentralizedStableCoin.mint(address(0), 1);
    }

    function testRevertIfAmountIsZeroMinting() public {
        vm.expectRevert(DecentralizedStableCoin__MustBeMoreThanZero.selector);
        vm.prank(msg.sender);
        decentralizedStableCoin.mint(USER, 0);
    }

    function testBalanceOfIsUpdatedAfterMinting() public mintCoin {
        assertEq(decentralizedStableCoin.balanceOf(USER), INITIAL_COIN_AMOUNT);
    }

    function testRevertIfAmountIsZeroBurning() public {
        vm.expectRevert(DecentralizedStableCoin__MustBeMoreThanZero.selector);
        vm.prank(msg.sender);
        decentralizedStableCoin.burn(0);
    }

    function testRevertIfBurnAmountExceedsBalanceBurning() public {
        vm.expectRevert(DecentralizedStableCoin__BurnAmountExceedsBalance.selector);
        vm.prank(msg.sender);
        decentralizedStableCoin.burn(1);
    }

    // my understanding is that the holder of the coins must send the coins to the owner of the contract before they can be burned. Only the owner can burn tokens, so the owner is the only one
    // who can control the supply of coins. We must send tokens from USER to msg.sender, then burn tokens from there.
    function testBurnTokensSuccessfully() public mintCoin {
        vm.prank(USER);
        decentralizedStableCoin.transfer(msg.sender, INITIAL_COIN_AMOUNT);
        vm.prank(msg.sender);
        decentralizedStableCoin.burn(INITIAL_COIN_AMOUNT);
        assertEq(decentralizedStableCoin.balanceOf(USER), 0);
        assertEq(decentralizedStableCoin.balanceOf(msg.sender), 0);
    }
}
