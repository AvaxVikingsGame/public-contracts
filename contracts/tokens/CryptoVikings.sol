// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableMapUpgradeable.sol";

import "../interfaces/IERC721Mintable.sol";
import "../interfaces/IRewardManager.sol";

/**
 * @title CryptoVikings NFT
 * @author JaboiNads
 * @notice An ERC-721 compliant implementation of the CryptoVikings NFT.
 */
contract CryptoVikings is OwnableUpgradeable, PausableUpgradeable, ERC721EnumerableUpgradeable, IERC721Mintable {
    using AddressUpgradeable for address payable;
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using EnumerableMapUpgradeable for EnumerableMapUpgradeable.UintToAddressMap;
    using ERC165CheckerUpgradeable for address;

    /**
     * @dev Configuration properties.
     */
    struct Config {
        // The cost to mint a Viking.
        uint256 mintFee;
        // The wallet to send developer payments to.
        address developerWallet;
        // The shared reward rate.
        uint16 sharedRewardRate;                
        // The maximum number of mints allowed in a single transaction.
        uint8 maxMintsPerTransaction;
        // The reward manager instance.
        IRewardManager rewardManager;
    }

    // The reward precision calculator.
    uint256 private constant RATE_PRECISION_SCALAR = 1_000;

    // Base URI for token metadata.
    string private constant BASE_TOKEN_URI = "https://api.cryptovikings.art/viking/";

    // The maximum supply of Vikings that can ever be minted.
    uint256 public constant MAX_SUPPLY = 10_000;

    // The configuration properties instance.
    Config private _config;

    // Maps a token to the address that minted it.
    EnumerableMapUpgradeable.UintToAddressMap private _minters;

    // Counter for generating new token IDs.
    CountersUpgradeable.Counter private _tokenIdCounter;

    /**
     * @notice Emitted when the mint fee changes.
     * @param oldMintFee The old mint fee.
     * @param newMintFee The new mint fee.
     */
    event MintFeeChanged(
        uint256 oldMintFee,
        uint256 newMintFee
    );

    /**
     * @notice Emitted when the reward rate changes.
     * @param oldRewardRate The old reward rate.
     * @param newRewardRate The new reward rate.
     */
    event RewardRateChanged(
        uint256 oldRewardRate,
        uint256 newRewardRate
    );

    /**
     * @notice Emitted when the maximum mints per transaction changes.
     * @param oldMaxMintsPerTransaction The old maximum mints per transaction.
     * @param newMaxMintsPerTransaction The new maximum mints per transaction.
     */
    event MaxMintsPerTransactionChanged(
        uint8 oldMaxMintsPerTransaction,
        uint8 newMaxMintsPerTransaction
    );

    /**
     * @notice Emitted when the reward manager changes.
     * @param oldRewardManager The old reward manager.
     * @param newRewardManager The new reward manager.
     */
    event RewardManagerChanged(
        IRewardManager oldRewardManager,
        IRewardManager newRewardManager
    );

    /**
     * @notice Emitted when the developer wallet changes.
     * @param oldDeveloperWallet The old developer wallet.
     * @param newDeveloperWallet The new developer wallet.
     */
    event DeveloperWalletChanged(
        address oldDeveloperWallet,
        address newDeveloperWallet
    );

    /**
     * @notice Emitted whenever a new Viking is minted.
     * @param minter The wallet that minted the token.
     * @param tokenId The id of the token that was minted.
     * @param price The price that the token was minted at.
     */
    event Minted(
        address indexed minter,
        uint256 indexed tokenId,
        uint256 price
    );

    function initialize(
        address developerWallet
    ) public initializer {
        __Ownable_init();
        __Pausable_init_unchained();
        __ERC721_init_unchained("CryptoVikings", "VIKING");
        __ERC721Enumerable_init_unchained();
        __CryptoVikings_init_unchained(developerWallet);
    }

    function __CryptoVikings_init_unchained(
        address developerWallet
    ) internal onlyInitializing {
        setMintFee(2 ether);
        setSharedRewardRate(100); // 10.0%
        setMaxMintsPerTransaction(10);
        setDeveloperWallet(developerWallet);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165Upgradeable, ERC721EnumerableUpgradeable) returns (bool) {
        return interfaceId == type(IERC721Mintable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Mintable-minterOf}.
     */
    function minterOf(
        uint256 tokenId
    ) public view returns (address) {
        return _minters.get(tokenId);
    }

    /**
     * @notice Sets the mint fee.
     * @param mintFee The new mint fee, must be non-zero.
     */
    function setMintFee(
        uint256 mintFee
    ) public onlyOwner {
        require(mintFee > 0, "mint fee must be positive");

        emit MintFeeChanged(_config.mintFee, mintFee);
        _config.mintFee = mintFee;
    }

    /**
     * @notice Sets the shared reward rate for every mint.
     * @param sharedRewardRate The new reward rate (0.1% precision), must be non-zero.
     */
    function setSharedRewardRate(
        uint16 sharedRewardRate
    ) public onlyOwner {
        require(sharedRewardRate > 0 && sharedRewardRate <= RATE_PRECISION_SCALAR, "bad reward rate");

        emit RewardRateChanged(_config.sharedRewardRate, sharedRewardRate);
        _config.sharedRewardRate = sharedRewardRate;
    }
    
    /**
     * @notice Sets the reward manager instance.
     * @param rewardManager The new rewards manager.
     */
    function setRewardManager(
        IRewardManager rewardManager
    ) public onlyOwner {
        require(address(rewardManager).supportsInterface(type(IRewardManager).interfaceId));

        emit RewardManagerChanged(_config.rewardManager, rewardManager);
        _config.rewardManager = rewardManager;
    }

    /**
     * @notice Sets the developer wallet.
     * @param developerWallet The new developer wallet.
     */
    function setDeveloperWallet(
        address developerWallet
    ) public onlyOwner {
        require(developerWallet != address(0), "developer wallet cannot be zero-address");

        emit DeveloperWalletChanged(_config.developerWallet, developerWallet);
        _config.developerWallet = developerWallet;
    }

    /**
     * @notice Sets the maximum number of mints per transaction.
     * @param maxMintsPerTransaction The maximum number of mints per transaction.
     */
    function setMaxMintsPerTransaction(
        uint8 maxMintsPerTransaction
    ) public onlyOwner {
        require(maxMintsPerTransaction > 0, "bad max mints");

        emit MaxMintsPerTransactionChanged(_config.maxMintsPerTransaction, maxMintsPerTransaction);
        _config.maxMintsPerTransaction = maxMintsPerTransaction;
    }

    /**
     * @notice Gets the current mint fee.
     */
    function getMintFee() external view returns (uint256) {
        return _config.mintFee;
    }

    /**
     * @notice Gets the maximum number of mints per transaction.
     */
    function getMaxMintsPerTransaction() external view returns (uint8) {
        return _config.maxMintsPerTransaction;
    }

    /**
     * @notice Pauses the contract functionality.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses contract functioanlity.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Airdrops tokens to holders.
     * @param tokenIds The ids of the tokens to airdrop.
     * @param minters The addresses that minted the tokens.
     * @param owners The addresses that currently own the tokens.
     */
    function airdrop(
        uint256[] memory tokenIds,
        address[] memory minters,
        address[] memory owners
    ) external onlyOwner {
        require(tokenIds.length == minters.length && tokenIds.length == owners.length, "array length mismatch");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            _tokenIdCounter.increment();
            require(tokenIds[i] == _tokenIdCounter.current(), "token id mismatch");

            _safeMint(owners[i], tokenIds[i]);
            _minters.set(tokenIds[i], minters[i]);
        }
    }

    /**
     * @notice Mints new vikings and transfers ownership to the minter.
     * @param minter The address to transfer ownership of the newly minted tokens to.
     * @param amount The number of new tokens to mint.
     */
    function mint(
        address minter,
        uint256 amount
    ) external payable whenNotPaused {
        require(totalSupply() + amount <= MAX_SUPPLY, "exceeds supply");
        require(amount > 0 && amount <= _config.maxMintsPerTransaction, "bad mint amount");

        // Owner can mint Vikings for free for promos.
        uint256 price = (_msgSender() == owner()) ? 0 : amount * _config.mintFee;
        require(msg.value == price, "wrong amount paid");

        // Mint each of the vikings and initialize them with the reward manager.
        for (uint256 i = 0; i < amount; i++) {
            // Generates the next token id, starting at #1.
            _tokenIdCounter.increment();

            uint256 tokenId = _tokenIdCounter.current();
            _safeMint(minter, tokenId);

            _minters.set(tokenId, minter);

            emit Minted(minter, tokenId, price / amount);

            _config.rewardManager.initializeToken(tokenId);
        }

        if (price > 0) {
            // Calculate the reward cut to be distributed to holders.
            uint256 rewardAmount = (price * _config.sharedRewardRate) / RATE_PRECISION_SCALAR;
            _config.rewardManager.depositSharedReward{value: rewardAmount}();

            // Transfer the remaining mint fee to the developers.
            payable(_config.developerWallet).sendValue(msg.value - rewardAmount);
        }
    }

}