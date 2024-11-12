// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/TaikoPalsGame.sol";

contract TaikoPalsGameTest is Test {
    TaikoPalsGame game;
    address admin = address(this);
    address player1 = address(0x1);
    address player2 = address(0x2);
    address minter = address(0x3);
    address trader = address(0x4);

    event CardMinted(address indexed player, uint256 cardId, uint256 characterType);
    event CardUpgraded(uint256 cardId, uint256 newLevel);
    event CardTraded(address indexed from, address indexed to, uint256 cardId);

    function setUp() public {
        // Deploy and initialize contract
        game = new TaikoPalsGame();
        game.initialize();

        // Setup test accounts
        vm.deal(player1, 100 ether);
        vm.deal(player2, 100 ether);

        // Grant roles to test accounts
        game.grantMinterRole(minter);
        game.grantTraderRole(trader);
    }

    // === Role Tests ===
    function testRoleAssignment() public {
        assertTrue(game.hasAdminRole(admin));
        assertTrue(game.hasMinterRole(minter));
        assertTrue(game.hasTraderRole(trader));
        assertFalse(game.hasMinterRole(player1));
        assertFalse(game.hasTraderRole(player1));
    }

    function testRoleRevocation() public {
        game.revokeMinterRole(minter);
        game.revokeTraderRole(trader);
        assertFalse(game.hasMinterRole(minter));
        assertFalse(game.hasTraderRole(trader));
    }

    // === Minting Tests ===
    function testMintCharacterCard() public {
        vm.prank(minter);
        vm.expectEmit(true, true, true, true);
        emit CardMinted(player1, 1, 1);
        game.mintCharacterCard(player1, 1);

        TaikoPalsGame.Card[] memory cards = game.getPlayerCards(player1);
        assertEq(cards.length, 1);
        assertEq(cards[0].characterType, 1);
        assertEq(cards[0].level, 1);
        assertEq(cards[0].owner, player1);
    }

    function testFailMintWithInvalidCharacterType() public {
        vm.prank(minter);
        game.mintCharacterCard(player1, 0);
    }

    function testFailMintWithoutMinterRole() public {
        vm.prank(player1);
        game.mintCharacterCard(player1, 1);
    }

    // === Upgrade Tests ===
    function testUpgradeCard() public {
        // First mint a card
        vm.prank(minter);
        game.mintCharacterCard(player1, 1);

        // Then upgrade it
        vm.prank(player1);
        vm.expectEmit(true, true, true, true);
        emit CardUpgraded(1, 2);
        game.upgradeCard(1);

        TaikoPalsGame.Card[] memory cards = game.getPlayerCards(player1);
        assertEq(cards[0].level, 2);
    }

    function testFailUpgradeNonexistentCard() public {
        vm.prank(player1);
        vm.expectRevert("Card not found");
        game.upgradeCard(999);
    }

    function testFailUpgradeOtherPlayerCard() public {
        // Mint card for player1
        vm.prank(minter);
        game.mintCharacterCard(player1, 1);

        // Try to upgrade as player2
        vm.prank(player2);
        vm.expectRevert("Card not found");
        game.upgradeCard(1);
    }

    function testFailUpgradeMaxLevel() public {
        // Mint card
        vm.prank(minter);
        game.mintCharacterCard(player1, 1);

        // Upgrade to max level
        vm.startPrank(player1);
        for(uint i = 1; i < 100; i++) {
            game.upgradeCard(1);
        }
        
        // Try to upgrade beyond max level
        vm.expectRevert("Maximum level reached");
        game.upgradeCard(1);
        vm.stopPrank();
    }

    // === Trading Tests ===
    function testTradeCards() public {
        // Mint card for player1
        vm.prank(minter);
        game.mintCharacterCard(player1, 1);

        // Trade card from player1 to player2
        vm.prank(trader);
        vm.expectEmit(true, true, true, true);
        emit CardTraded(player1, player2, 1);
        game.tradeCards(player1, player2, 1);

        // Verify trade
        TaikoPalsGame.Card[] memory player1Cards = game.getPlayerCards(player1);
        TaikoPalsGame.Card[] memory player2Cards = game.getPlayerCards(player2);
        assertEq(player1Cards.length, 0);
        assertEq(player2Cards.length, 1);
        assertEq(player2Cards[0].id, 1);
        assertEq(player2Cards[0].owner, player2);
    }

    function testFailTradeWithoutTraderRole() public {
        vm.prank(minter);
        game.mintCharacterCard(player1, 1);

        vm.prank(player1);
        vm.expectRevert();
        game.tradeCards(player1, player2, 1);
    }

    function testFailTradeNonexistentCard() public {
        vm.prank(trader);
        vm.expectRevert("Card not found");
        game.tradeCards(player1, player2, 999);
    }

    function testFailTradeToSelf() public {
        vm.prank(minter);
        game.mintCharacterCard(player1, 1);

        vm.prank(trader);
        vm.expectRevert("Cannot trade to self");
        game.tradeCards(player1, player1, 1);
    }

    // === Pause Tests ===
    function testPauseAndUnpause() public {
        // Test pause
        game.pause();
        assertTrue(game.paused());

        // Verify minting is blocked when paused
        vm.prank(minter);
        vm.expectRevert("Pausable: paused");
        game.mintCharacterCard(player1, 1);

        // Test unpause
        game.unpause();
        assertFalse(game.paused());

        // Verify minting works after unpause
        vm.prank(minter);
        game.mintCharacterCard(player1, 1);
        TaikoPalsGame.Card[] memory cards = game.getPlayerCards(player1);
        assertEq(cards.length, 1);
    }

    function testFailPauseWithoutAdminRole() public {
        vm.prank(player1);
        vm.expectRevert();
        game.pause();
    }
} 