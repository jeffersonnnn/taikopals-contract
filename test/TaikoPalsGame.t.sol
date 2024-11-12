// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/TaikoPalsGame.sol";

contract TaikoPalsGameTest is Test {
    TaikoPalsGame game;
    address admin = address(this);
    address player1 = address(0x1);
    address player2 = address(0x2);

    function setUp() public {
        game = new TaikoPalsGame();
        game.initialize();
    }

    function testMintCharacterCard() public {
        game.mintCharacterCard(player1, 1);
        TaikoPalsGame.Card[] memory cards = game.getPlayerCards(player1);
        assertEq(cards.length, 1);
        assertEq(cards[0].characterType, 1);
        assertEq(cards[0].level, 1);
        assertEq(cards[0].owner, player1);
    }

    // Add more tests for upgradeCard, tradeCards, etc.
} 