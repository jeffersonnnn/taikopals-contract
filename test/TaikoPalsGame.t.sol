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

    event CardMinted(address indexed player, uint256 indexed cardId, uint256 characterType);
    event CardUpgraded(uint256 indexed cardId, uint256 newLevel);
    event CardTraded(address indexed from, address indexed to, uint256 indexed cardId);

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
        assertTrue(game.hasRole(game.ADMIN_ROLE(), admin));
        assertTrue(game.hasRole(game.MINTER_ROLE(), minter));
        assertTrue(game.hasRole(game.TRADER_ROLE(), trader));
        assertFalse(game.hasRole(game.MINTER_ROLE(), player1));
        assertFalse(game.hasRole(game.TRADER_ROLE(), player1));
    }

    function testRoleRevocation() public {
        game.revokeMinterRole(minter);
        game.revokeTraderRole(trader);
        assertFalse(game.hasRole(game.MINTER_ROLE(), minter));
        assertFalse(game.hasRole(game.TRADER_ROLE(), trader));
    }

    // === Minting Tests ===
    function testMintCharacterCard() public {
        vm.prank(minter);
        vm.expectEmit(true, true, true, true);
        emit CardMinted(player1, 1, 1);
        game.mintCharacterCard(player1, 1);

        uint256[] memory cardIds = game.getPlayerCardIds(player1);
        assertEq(cardIds.length, 1);
        
        TaikoPalsGame.Card memory card = game.getCard(cardIds[0]);
        assertEq(card.characterType, 1);
        assertEq(card.level, 1);
        assertEq(card.owner, player1);
        assertTrue(card.exists);
    }

    function testMintWithInvalidCharacterType() public {
        vm.prank(minter);
        vm.expectRevert(TaikoPalsGame.InvalidCharacterType.selector);
        game.mintCharacterCard(player1, 0);

        vm.prank(minter);
        vm.expectRevert(TaikoPalsGame.InvalidCharacterType.selector);
        game.mintCharacterCard(player1, 11); // Above MAX_CHARACTER_TYPE
    }

    function testMintWithoutMinterRole() public {
        vm.prank(player1);
        vm.expectRevert();
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

        TaikoPalsGame.Card memory card = game.getCard(1);
        assertEq(card.level, 2);
    }

    function testUpgradeNonexistentCard() public {
        vm.prank(player1);
        vm.expectRevert(TaikoPalsGame.CardNotFound.selector);
        game.upgradeCard(999);
    }

    function testUpgradeOtherPlayerCard() public {
        // Mint card for player1
        vm.prank(minter);
        game.mintCharacterCard(player1, 1);

        // Try to upgrade as player2
        vm.prank(player2);
        vm.expectRevert(TaikoPalsGame.NotCardOwner.selector);
        game.upgradeCard(1);
    }

    function testUpgradeMaxLevel() public {
        // Mint card
        vm.prank(minter);
        game.mintCharacterCard(player1, 1);

        // Upgrade to max level
        vm.startPrank(player1);
        for(uint i = 1; i < 100; i++) {
            game.upgradeCard(1);
        }
        
        // Try to upgrade beyond max level
        vm.expectRevert(TaikoPalsGame.MaxLevelReached.selector);
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
        uint256[] memory player1Cards = game.getPlayerCardIds(player1);
        uint256[] memory player2Cards = game.getPlayerCardIds(player2);
        assertEq(player1Cards.length, 0);
        assertEq(player2Cards.length, 1);
        
        TaikoPalsGame.Card memory card = game.getCard(player2Cards[0]);
        assertEq(card.owner, player2);
    }

    function testTradeWithoutTraderRole() public {
        vm.prank(minter);
        game.mintCharacterCard(player1, 1);

        vm.prank(player1);
        vm.expectRevert();
        game.tradeCards(player1, player2, 1);
    }

    function testTradeNonexistentCard() public {
        vm.prank(trader);
        vm.expectRevert(TaikoPalsGame.CardNotFound.selector);
        game.tradeCards(player1, player2, 999);
    }

    function testTradeToSelf() public {
        vm.prank(minter);
        game.mintCharacterCard(player1, 1);

        vm.prank(trader);
        vm.expectRevert(TaikoPalsGame.SelfTradeNotAllowed.selector);
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
        uint256[] memory cardIds = game.getPlayerCardIds(player1);
        assertEq(cardIds.length, 1);
    }

    function testPauseWithoutAdminRole() public {
        vm.prank(player1);
        vm.expectRevert();
        game.pause();
    }

    // === Additional Tests for New Functionality ===
    function testGetNonexistentCard() public {
        vm.expectRevert(TaikoPalsGame.CardNotFound.selector);
        game.getCard(999);
    }

    function testMintWithZeroAddress() public {
        vm.prank(minter);
        vm.expectRevert(TaikoPalsGame.InvalidAddress.selector);
        game.mintCharacterCard(address(0), 1);
    }

    function testTradeWithZeroAddress() public {
        vm.prank(minter);
        game.mintCharacterCard(player1, 1);

        vm.prank(trader);
        vm.expectRevert(TaikoPalsGame.InvalidAddress.selector);
        game.tradeCards(player1, address(0), 1);

        vm.prank(trader);
        vm.expectRevert(TaikoPalsGame.InvalidAddress.selector);
        game.tradeCards(address(0), player2, 1);
    }
}