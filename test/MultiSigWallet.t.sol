// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2, StdStyle} from "forge-std/Test.sol";
import {MultiSig} from "../src/MultiSigWallet.sol";

contract MultiTest is Test{
    MultiSig public wallet;
    address public alice;
    address public bob;
    
    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        address[] memory owners = new address[](2);
        owners[0] = alice;
        owners[1] = bob;
        wallet = new MultiSig(owners, 2);
        vm.deal(address(wallet), 10 ether);
    }

    function testCheckOwners() public view {
        address[] memory owners = wallet.getOwners();
        assertEq(owners.length, 2);
        assertEq(owners[0], alice);
        assertEq(owners[1], bob);
    }

    function testSubmitTransaction() public {
        vm.startPrank(alice);
        wallet.giveOneEth(alice);
        assertEq(wallet.balanceOf(alice), 1 ether);
        bool isAliceOwner = wallet.isOwner(alice);
        assertTrue(isAliceOwner, "Alice should be an owner");
        wallet.submitTransaction(bob, 1 ether, "");
        (address to, uint256 value, bytes memory data, bool executed, uint256 numConfirmations) = wallet.getTransaction(0);
        assertEq(to, bob);
        assertEq(value, 1 ether);
        assertEq(executed, false);
        assertEq(numConfirmations, 0);
        vm.stopPrank();
    }

    function testConfirmAndExecuteTrasaction() public {
        vm.startPrank(alice);
        wallet.giveOneEth(alice);
        wallet.submitTransaction(bob, 1 ether, "");
        wallet.confirmTransaction(0);
        vm.stopPrank();

        vm.startPrank(bob);
        wallet.confirmTransaction(0);
        vm.stopPrank();

        assertEq(wallet.getConfirmationsCount(0), 2);
        vm.prank(alice);    
        wallet.executeTransaction(0);
    }

    function testRevokeConfirmation() public {
        vm.startPrank(alice);
        wallet.giveOneEth(alice);
        wallet.submitTransaction(bob, 1 ether, "");
        wallet.confirmTransaction(0);
        vm.stopPrank();

        vm.startPrank(bob);
        wallet.confirmTransaction(0);
        wallet.revokeConfirmation(0);
        vm.stopPrank();

        assertEq(wallet.getConfirmationsCount(0), 1);
        
        
    }
}