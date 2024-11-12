// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title TaikoPalsGame
 * @dev Core contract for the TaikoPals game, managing character cards and player interactions
 */
contract TaikoPalsGame is 
    Initializable, 
    UUPSUpgradeable, 
    AccessControl, 
    Pausable, 
    ReentrancyGuard 
{
    // === Data Structures ===
    struct Card {
        uint256 id;
        uint256 characterType;
        uint256 level;
        address owner;
    }

    // === State Variables ===
    mapping(address => Card[]) private playerCards;
    uint256 private nextCardId;

    // === Role Definitions ===
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant TRADER_ROLE = keccak256("TRADER_ROLE");

    // === Events ===
    event CardMinted(address indexed player, uint256 cardId, uint256 characterType);
    event CardUpgraded(uint256 cardId, uint256 newLevel);
    event CardTraded(address indexed from, address indexed to, uint256 cardId);

    // === Initialization ===
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __Pausable_init();
        
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        nextCardId = 1;
    }

    // === Core Functions ===

    /**
     * @notice Mints a new character card for a player
     * @param player Address of the player receiving the card
     * @param characterType Type/class of the character
     */
    function mintCharacterCard(address player, uint256 characterType) 
        external 
        onlyRole(MINTER_ROLE) 
        whenNotPaused 
        nonReentrant 
    {
        require(player != address(0), "Invalid player address");
        require(characterType > 0, "Invalid character type");

        uint256 cardId = nextCardId++;
        
        Card memory newCard = Card({
            id: cardId,
            characterType: characterType,
            level: 1,
            owner: player
        });

        playerCards[player].push(newCard);
        
        emit CardMinted(player, cardId, characterType);
    }

    /**
     * @notice Upgrades the level of a specific card
     * @param cardId ID of the card to upgrade
     */
    function upgradeCard(uint256 cardId) 
        external 
        whenNotPaused 
        nonReentrant 
    {
        bool found = false;
        Card[] storage cards = playerCards[msg.sender];
        
        for (uint256 i = 0; i < cards.length; i++) {
            if (cards[i].id == cardId) {
                require(cards[i].owner == msg.sender, "Not card owner");
                cards[i].level += 1;
                emit CardUpgraded(cardId, cards[i].level);
                found = true;
                break;
            }
        }
        
        require(found, "Card not found");
    }

    /**
     * @notice Trades a card between players
     * @param from Address of the sender
     * @param to Address of the receiver
     * @param cardId ID of the card to trade
     */
    function tradeCards(address from, address to, uint256 cardId) 
        external 
        onlyRole(TRADER_ROLE) 
        whenNotPaused 
        nonReentrant 
    {
        require(from != address(0) && to != address(0), "Invalid addresses");
        require(from != to, "Cannot trade to self");

        bool found = false;
        Card[] storage fromCards = playerCards[from];
        
        for (uint256 i = 0; i < fromCards.length; i++) {
            if (fromCards[i].id == cardId) {
                Card memory cardToTrade = fromCards[i];
                cardToTrade.owner = to;
                
                // Remove card from sender
                fromCards[i] = fromCards[fromCards.length - 1];
                fromCards.pop();
                
                // Add card to receiver
                playerCards[to].push(cardToTrade);
                
                emit CardTraded(from, to, cardId);
                found = true;
                break;
            }
        }
        
        require(found, "Card not found");
    }

    /**
     * @notice Retrieves all cards owned by a player
     * @param player Address of the player
     * @return Array of cards owned by the player
     */
    function getPlayerCards(address player) 
        external 
        view 
        returns (Card[] memory) 
    {
        return playerCards[player];
    }

    // === Admin Functions ===
    
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // === Upgrade Functions ===
    
    function _authorizeUpgrade(address newImplementation) 
        internal 
        override 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {}
}