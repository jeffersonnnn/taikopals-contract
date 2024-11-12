// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

// Hemera integration for player profiles and engagement metrics
interface IHemeraIndexer {
    function updateDailyWalletStats(
        address wallet,
        uint256 actionType,
        uint256 value
    ) external;
}

/**
 * @title TaikoPalsGame
 * @dev Core contract for the TaikoPals game, managing character cards and player interactions
 */
contract TaikoPalsGame is 
    Initializable, 
    UUPSUpgradeable, 
    ReentrancyGuard, 
    Pausable, 
    AccessControl 
{
    // === Errors ===
    error InvalidAddress();
    error InvalidCharacterType();
    error InvalidCardId();
    error CardNotFound();
    error NotCardOwner();
    error MaxLevelReached();
    error SelfTradeNotAllowed();
    error CardAlreadyExists();

    // === Constants ===
    uint256 private constant MAX_LEVEL = 100;
    uint256 private constant MAX_CHARACTER_TYPE = 10;
    
    // === Data Structures ===
    struct Card {
        uint256 characterType;
        uint256 level;
        address owner;
        bool exists;
    }

    // === State Variables ===
    mapping(uint256 => Card) private cards;  // cardId => Card
    mapping(address => uint256[]) private playerCardIds;  // player => array of cardIds
    uint256 private nextCardId;

    // === Role Definitions ===
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant TRADER_ROLE = keccak256("TRADER_ROLE");
    bytes32 public constant ADMIN_ROLE = DEFAULT_ADMIN_ROLE;

    // === Events ===
    event CardMinted(
        address indexed player,
        uint256 indexed cardId,
        uint256 characterType,
        uint256 timestamp
    );

    event CardUpgraded(
        uint256 indexed cardId,
        uint256 newLevel,
        address indexed player,
        uint256 timestamp
    );

    event CardTraded(
        address indexed from,
        address indexed to,
        uint256 indexed cardId,
        uint256 timestamp
    );

    // === Hemera Integration ===
    IHemeraIndexer public hemeraIndexer;
    
    // Action types for Hemera indexing
    uint256 private constant ACTION_MINT = 1;
    uint256 private constant ACTION_UPGRADE = 2;
    uint256 private constant ACTION_TRADE = 3;

    // === Initialization ===
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _hemeraIndexer) public initializer {
        __UUPSUpgradeable_init();
        __Pausable_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        
        hemeraIndexer = IHemeraIndexer(_hemeraIndexer);
    }

    // === Core Functions ===

    /**
     * @notice Mints a new character card for a player
     * @param player Address of the player receiving the card
     * @param characterType Type/class of the character
     */
    function mintCharacterCard(
        address player,
        uint256 characterType
    ) external onlyRole(MINTER_ROLE) whenNotPaused nonReentrant {
        if (player == address(0)) revert InvalidAddress();
        if (characterType == 0 || characterType > MAX_CHARACTER_TYPE) revert InvalidCharacterType();

        uint256 cardId = nextCardId++;
        
        cards[cardId] = Card({
            characterType: characterType,
            level: 1,
            owner: player,
            exists: true
        });

        playerCardIds[player].push(cardId);
        
        // Update Hemera indexer with minting action
        hemeraIndexer.updateDailyWalletStats(
            player,
            ACTION_MINT,
            1
        );
        
        emit CardMinted(
            player,
            cardId,
            characterType,
            block.timestamp
        );
    }

    /**
     * @notice Upgrades the level of a specific card
     * @param cardId ID of the card to upgrade
     */
    function upgradeCard(
        uint256 cardId
    ) external whenNotPaused nonReentrant {
        Card storage card = cards[cardId];
        if (!card.exists) revert CardNotFound();
        if (card.owner != msg.sender) revert NotCardOwner();
        if (card.level >= MAX_LEVEL) revert MaxLevelReached();
        
        card.level++;
        
        // Update Hemera indexer with upgrade action
        hemeraIndexer.updateDailyWalletStats(
            msg.sender,
            ACTION_UPGRADE,
            card.level
        );
        
        emit CardUpgraded(
            cardId,
            card.level,
            msg.sender,
            block.timestamp
        );
    }

    /**
     * @notice Trades a card between players
     * @param from Address of the sender
     * @param to Address of the receiver
     * @param cardId ID of the card to trade
     */
    function tradeCards(
        address from,
        address to,
        uint256 cardId
    ) external whenNotPaused nonReentrant {
        if (from == address(0) || to == address(0)) revert InvalidAddress();
        if (from == to) revert SelfTradeNotAllowed();
        
        Card storage card = cards[cardId];
        if (!card.exists) revert CardNotFound();
        if (card.owner != from) revert NotCardOwner();

        // Remove card from sender's array
        uint256[] storage fromCards = playerCardIds[from];
        for (uint256 i = 0; i < fromCards.length; i++) {
            if (fromCards[i] == cardId) {
                fromCards[i] = fromCards[fromCards.length - 1];
                fromCards.pop();
                break;
            }
        }

        // Update card ownership and add to receiver's array
        card.owner = to;
        playerCardIds[to].push(cardId);
        
        // Update Hemera indexer with trade action
        hemeraIndexer.updateDailyWalletStats(from, ACTION_TRADE, 1);
        hemeraIndexer.updateDailyWalletStats(to, ACTION_TRADE, 1);
        
        emit CardTraded(from, to, cardId, block.timestamp);
    }

    /**
     * @notice Retrieves all cards owned by a player
     * @param player Address of the player
     * @return Array of card IDs owned by the player
     */
    function getPlayerCardIds(address player) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return playerCardIds[player];
    }

    /**
     * @notice Retrieves card details by ID
     * @param cardId ID of the card
     * @return Card details
     */
    function getCard(uint256 cardId)
        external
        view
        returns (Card memory)
    {
        if (!cards[cardId].exists) revert CardNotFound();
        return cards[cardId];
    }

    // === Admin Functions ===
    
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    // === Upgrade Functions ===
    
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(ADMIN_ROLE) {}

    // === Role Management Functions ===
    
    function grantMinterRole(address account) external onlyRole(ADMIN_ROLE) {
        grantRole(MINTER_ROLE, account);
    }

    function revokeMinterRole(address account) external onlyRole(ADMIN_ROLE) {
        revokeRole(MINTER_ROLE, account);
    }

    function grantTraderRole(address account) external onlyRole(ADMIN_ROLE) {
        grantRole(TRADER_ROLE, account);
    }

    function revokeTraderRole(address account) external onlyRole(ADMIN_ROLE) {
        revokeRole(TRADER_ROLE, account);
    }

    // Helper function to get card by ID
    function _getCard(uint256 cardId) internal view returns (Card storage) {
        for (uint i = 0; i < playerCardIds[msg.sender].length; i++) {
            if (playerCardIds[msg.sender][i] == cardId) {
                return cards[cardId];
            }
        }
        revert("Card not found");
    }
}