// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

import "../interfaces/IERC721Mintable.sol";
import "../interfaces/IRewardManager.sol";

import "../libraries/PauseMetrics.sol";
import "./Listings.sol";
import "./Offers.sol";

/**
 * @title Marketplace
 * @author JaboiNads
 * @notice NFT Marketplace for the CryptoVikings project.
 */
contract Marketplace is OwnableUpgradeable, PausableUpgradeable, ERC721HolderUpgradeable {
    using AddressUpgradeable for address payable;
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using SafeCastUpgradeable for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
    using ERC165CheckerUpgradeable for address;
    using Listings for Listings.Data;
    using Offers for Offers.Data;
    using PauseMetrics for PauseMetrics.Data;

    /**
     * @dev Marketplace configuration properties.
     */
    struct Config {
        // The address to send developer payments to.
        address developerWallet;
        // The minimum auction duration.
        uint32 minValidDuration;
        // The maximum auction duration
        uint32 maxValidDuration;
        // The rate from sales that goes to the token's minter (0.1% precision).
        uint16 minterRate;
        // The rate from sales that goes to the developers (0.1% precision).
        uint16 developerRate;
        // The reward manager instance.
        IRewardManager rewardManager;
        // 
        uint16 bidExtensionTime;
        // The minimum percentage that a bid must increase by (0.1% precision).
        uint16 minBidIncrease;
    }

    // The precision scalar for rate calculations (1000 = 0.1% precision)
    uint256 private constant PRECISION_SCALAR = 1000;

    // The configuration instance.
    Config private _config;

    // The pause metrics instance.
    PauseMetrics.Data private _pauseMetrics;

    // The set of tokens that can be traded on the marketplace.
    EnumerableSetUpgradeable.AddressSet private _whitelistedTokens;

    // The currently active listings.
    Listings.Data private _listings;

    // The currently active offers.
    Offers.Data private _offers;

    /**
     * @notice Emitted when the minter rate changes.
     * @param oldMinterRate The old minter rate (0.1% precision).
     * @param newMinterRate The new minter rate (0.1% precision).
     */
    event MinterRateChanged(
        uint256 oldMinterRate,
        uint256 newMinterRate
    );

    /**
     * @notice Emitted when the developer rate changes.
     * @param oldDeveloperRate The old developer rate (0.1% precision).
     * @param newDeveloperRate The new developer rate (0.1% precision).
     */
    event DeveloperRateChanged(
        uint256 oldDeveloperRate,
        uint256 newDeveloperRate
    );

    /**
     * @notice Emitted when the valid auction duration range changes.
     * @param oldMinimumAuctionDuration The old minimum auction duration.
     * @param oldMinimumAuctionDuration The old maximum auction duration.
     * @param newMinimumAuctionDuration The new maximum auction duration.
     * @param newMaximumAuctionDuration The new maximum auction duration.
     */
    event ValidDurationRangeChanged(
        uint256 oldMinimumAuctionDuration,
        uint256 oldMaximumAuctionDuration,
        uint256 newMinimumAuctionDuration,
        uint256 newMaximumAuctionDuration
    );

    /**
     * @notice Emitted when the minimum bid increase changes.
     * @param oldMinimumBidIncrease The old minimum bid increase.
     * @param newMinimumBidIncrease The new minimum bid increase.
     */
    event MinimumBidIncreaseChanged(
        uint32 oldMinimumBidIncrease,
        uint32 newMinimumBidIncrease
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
     * @notice Emitted when the reward manager changes.
     * @param oldRewardManager The old reward manager.
     * @param newRewardManager The new reward manager.
     */
    event RewardManagerChanged(
        IRewardManager oldRewardManager,
        IRewardManager newRewardManager
    );

    /**
     * @notice Emitted when a token is added to the whitelist.
     * @param token The token that was added.
     */
    event AddedWhitelistedToken(
        IERC721Mintable indexed token
    );

    /**
     * @notice Emitted when a token is removed from the whitelist.
     * @param token The token that was removed.
     */
    event RemovedWhitelistedToken(
        IERC721Mintable indexed token
    );

    /**
     * @notice Emitted when a fixed price listing is created.
     * @param listingId The unique id of the listing.
     * @param token The token that was listed.
     * @param tokenId The id of the token that was listed.
     * @param seller The address that created the listing.
     * @param price The asking price.
     */
    event FixedPriceListingCreated(
        uint256 indexed listingId,
        IERC721Mintable indexed token,
        uint256 indexed tokenId,
        address seller,
        uint256 price
    );

    /**
     * @notice Emitted when a Dutch auction listing is created.
     * @param listingId The unique id of the listing.
     * @param token The token that was listed.
     * @param tokenId The id of the token that was listed.
     * @param seller The address that created the listing.
     * @param startingPrice The price to start the auction at.
     * @param endingPrice The price to end the auction at.
     * @param duration How long the auction will run for (in seconds).
     */
    event DutchAuctionListingCreated(
        uint256 indexed listingId,
        IERC721Mintable indexed token,
        uint256 indexed tokenId,
        address seller,
        uint256 startingPrice,
        uint256 endingPrice,
        uint256 duration
    );

    /**
     * @notice Emitted when an English auction listing is created.
     * @param listingId The unique id of the listing.
     * @param token The token that was listed.
     * @param tokenId The id of the token that was listed.
     * @param seller The address that created the listing.
     * @param startingPrice The price to start the auction at.
     * @param buyoutPrice The price to instantly but the token, or 0 if no buyout is available.
     * @param duration How long the auction will run for (in seconds).
     */
    event EnglishAuctionListingCreated(
        uint256 indexed listingId,
        IERC721Mintable indexed token,
        uint256 indexed tokenId,
        address seller,
        uint256 startingPrice,
        uint256 buyoutPrice,
        uint256 duration
    );

    /**
     * @notice Emitted when a listing is cancelled by the seller.
     * @param listingId The unique identifier for the listing.
     */
    event ListingCancelled(
        uint256 indexed listingId
    );

    /**
     * @notice Emitted when a listing has concluded successfully.
     * @param listingId The unique identifier for the listing.
     * @param buyer The address that bought the token.
     * @param price The amount that the token sold for.
     */
    event ListingSuccessful(
        uint256 indexed listingId,
        address buyer,
        uint256 price
    );

    /**
     * @notice Emitted when a new bid is created.
     * @param listingId The unique identifier for the listing.
     * @param bidder The address that placed the bid.
     * @param amount The amount that was bid.
     */
    event BidCreated(
        uint256 indexed listingId,
        address bidder,
        uint256 amount
    );

    /**
     * @notice Emitted when an offer is created for a token.
     * @param offerId The unique identifier for the offer.
     * @param token The token that the offer was made for.
     * @param tokenId The id of the token that the offer was made for.
     * @param offerer The address that created the offer.
     * @param amount The amount that was offered.
     */
    event OfferCreated(
        uint256 indexed offerId,
        IERC721Mintable indexed token,
        uint256 indexed tokenId,
        address offerer,
        uint256 amount
    );

    /**
     * @notice Emitted when an existing offer is updated.
     */
    event OfferUpdated(
        uint256 indexed offerId,
        uint128 newAmount
    );

    /**
     * @notice Emitted when an offer is cancelled.
     * @param offerId The unique identifier for the offer.
     */
    event OfferCancelled(
        uint256 indexed offerId
    );

    /**
     * @notice Emitted when an offer is accepted.
     * @param offerId The unique identifier for the offer.
     */
    event OfferAccepted(
        uint256 indexed offerId
    );

    /**
     * @notice Emitted when an offer is rejected.
     * @param offerId The unique identifier for the offer.
     */
    event OfferRejected(
        uint256 indexed offerId
    );

    /**
     * @notice Restricts functionality to tokens that are whitelisted.
     * @param token The token to check.
     */
    modifier onlyWhitelisted(
        IERC721Mintable token
    ) {
        require(_whitelistedTokens.contains(address(token)), "token not whitelisted");
        _;
    }
    
    /**
     * @notice Restricts functionality to tokens that are not currently listed.
     * @param token The token to check.
     * @param tokenId The id of the token to check.
     */
    modifier onlyUnlisted(
        IERC721Mintable token,
        uint256 tokenId
    ) {
        require(!_listings.exists(token, tokenId), "token already listed");
        _;
    }

    /**
     * @notice Initializes the contract when it is first deployed. This will not run when
     */
    function initialize(
        address developerWallet,
        IRewardManager rewardManager
    ) public initializer {
        __Ownable_init();
        __Pausable_init_unchained();
        __ERC721Holder_init_unchained();
        __Marketplace_init_unchained(developerWallet, rewardManager);
    }

    function __Marketplace_init_unchained(
        address developerWallet,
        IRewardManager rewardManager
    ) internal onlyInitializing {
        setSalesRates(20, 30); // 2.0% minter, 3.0% developer
        setValidDurationRange(30 minutes, 14 days);
        setDeveloperWallet(developerWallet);
        setRewardManager(rewardManager);
    }

    /**
     * @notice Pauses marketplace functionality.
     */
    function pause() external onlyOwner {
        _pause();
        _pauseMetrics.pause();
    }

    /**
     * @notice Unpauses marketplace functionality.
     */
    function unpause() external onlyOwner {
        _unpause();
        _pauseMetrics.unpause();
    }

    /**
     * @notice Sets the rate that minters and developers get on all sales.
     * @param minterRate The minter rate
     */
    function setSalesRates(
        uint16 minterRate,
        uint16 developerRate
    ) public onlyOwner {
        require(minterRate + developerRate <= PRECISION_SCALAR, "bad rates");

        if (minterRate != _config.minterRate) {
            emit MinterRateChanged(_config.minterRate, minterRate);
            _config.minterRate = minterRate;
        }

        if (developerRate != _config.developerRate) {
            emit DeveloperRateChanged(_config.developerRate, developerRate);
            _config.developerRate = developerRate;
        }
    }

    /**
     * @notice Sets the valid auction duration range.
     * @param minValidDuration The minimum valid auction duration (in seconds).
     * @param maxValidDuration The maximum valid auction duration (in seconds).
     */
    function setValidDurationRange(
        uint32 minValidDuration,
        uint32 maxValidDuration
    ) public onlyOwner {
        require(minValidDuration != 0 && minValidDuration < maxValidDuration, "invalid duration range");

        emit ValidDurationRangeChanged(_config.minValidDuration, _config.maxValidDuration, minValidDuration, maxValidDuration);
        _config.minValidDuration = minValidDuration;
        _config.maxValidDuration = maxValidDuration;
    }

    /**
     * @notice Sets the developer wallet.
     * @param developerWallet The new developer wallet.
     */
    function setDeveloperWallet(
        address developerWallet
    ) public onlyOwner {
        require(developerWallet != address(0), "bad developer address");
        require(developerWallet != _config.developerWallet, "same address");

        emit DeveloperWalletChanged(_config.developerWallet, developerWallet);
        _config.developerWallet = developerWallet;
    }

    /**
     * @notice Sets the reward manager.
     * @param rewardManager The new reward manager.
     */
    function setRewardManager(
        IRewardManager rewardManager
    ) public onlyOwner {
        require(address(rewardManager).supportsInterface(type(IRewardManager).interfaceId));
        require(rewardManager != _config.rewardManager, "same address");

        emit RewardManagerChanged(_config.rewardManager, rewardManager);
        _config.rewardManager = rewardManager;
    }

    /**
     * @notice Adds a token to the whitelist.
     * @param token The token to add.
     */
    function addWhitelistedToken(
        IERC721Mintable token
    ) external onlyOwner {
        require(_whitelistedTokens.add(address(token)), "token already whitelisted");
        emit AddedWhitelistedToken(token);
    }

    /**
     * @notice Removes a token from the whitelist.
     * @param token The token to remove.
     */
    function removeWhitelistedToken(
        IERC721Mintable token
    ) external onlyOwner {
        require(_whitelistedTokens.remove(address(token)), "token not whitelisted");
        emit RemovedWhitelistedToken(token);
    }

    /**
     * @notice Creates a new fixed price listing.
     * @param token The token to list.
     * @param tokenId The id of the token to list.
     * @param price The asking price.
     */
    function createFixedPriceListing(
        IERC721Mintable token,
        uint256 tokenId,
        uint128 price
    ) external
        whenNotPaused
        onlyWhitelisted(token)
    {
        require(price > 0, "no price provided");

        // Write the listing to storage. This will fail if the listing already exists.
        uint256 listingId = _listings.addFixedPriceListing(token, tokenId, _msgSender(), _pauseMetrics.totalDuration, price);

        // Transfer ownership of the token to the marketplace. The sender must own the token, and the
        // marketplace must be approved to transfer the token, otherwise this will fail.
        token.safeTransferFrom(_msgSender(), address(this), tokenId);

        // Notify the world that a new listing was created.
        emit FixedPriceListingCreated(listingId, token, tokenId, _msgSender(), price);
    }

    /**
     * @notice Creates a new dutch auction listing.
     * @param token The token to list.
     * @param tokenId The id of the token to list.
     * @param startingPrice The price to start the auction at.
     * @param endingPrice The price to end the auction at.
     * @param duration The length of time to run the auction for (in seconds).
     */
    function createDutchAuctionListing(
        IERC721Mintable token,
        uint256 tokenId,
        uint128 startingPrice,
        uint128 endingPrice,
        uint32 duration
    ) external
        whenNotPaused
        onlyWhitelisted(token)
    {
        require(endingPrice > 0, "ending price is zero");
        require(startingPrice > endingPrice, "start price must be greater than ending price");
        require(duration >= _config.minValidDuration && duration <= _config.maxValidDuration, "bad auction duration");

        // Write the listing to storage. This will fail if the listing already exists.
        uint256 listingId = _listings.addDutchAuctionListing(token, tokenId, _msgSender(), _pauseMetrics.totalDuration, startingPrice, endingPrice, duration);

        // Transfer ownership of the token to the marketplace. The sender must own the token, and the
        // marketplace must be approved to transfer the token, otherwise this will fail.
        token.safeTransferFrom(_msgSender(), address(this), tokenId);

        // Notify the world that a Dutch auction was created.
        emit DutchAuctionListingCreated(listingId, token, tokenId, _msgSender(), startingPrice, endingPrice, duration);
    }

    /**
     * @notice Creates a new English auction listing.
     * @param token The token to list.
     * @param tokenId The id of the token to list.
     * @param startingPrice The price to start the auction at.
     * @param buyoutPrice The price to automatically end the auction at, or 0 if not available.
     * @param duration The length of time to run the auction for (in seconds).
     */
    function createEnglishAuctionListing(
        IERC721Mintable token,
        uint256 tokenId,
        uint128 startingPrice,
        uint128 buyoutPrice,
        uint32 duration
    ) external
        whenNotPaused
        onlyWhitelisted(token)
    {
        require(startingPrice > 0, "starting price cannot be 0");
        require(buyoutPrice == 0 || buyoutPrice > startingPrice, "bad buyout price");
        require(duration >= _config.minValidDuration && duration <= _config.maxValidDuration, "bad auction duration");

        // Write the listing to storage. This will fail if the listing already exists.
        uint256 listingId = _listings.addEnglishAuctionListing(token, tokenId, _msgSender(), _pauseMetrics.totalDuration, startingPrice, buyoutPrice, duration);

        // Transfer ownership of the token to the marketplace. The sender must own the token, and the
        // marketplace must be approved to transfer the token, otherwise this will fail.
        token.safeTransferFrom(_msgSender(), address(this), tokenId);

        // Notify the world that an English auction was created.
        emit EnglishAuctionListingCreated(listingId, token, tokenId, _msgSender(), startingPrice, buyoutPrice, duration);
    }

    /**
     * @notice Cancels a listing and returns the token to the seller.
     * @param listingId The id of the listing to cancel.
     */
    function cancelListing(
        uint256 listingId
    ) external
        whenNotPaused
    {
        Listings.Listing storage listing = _listings.get(listingId);
        require(_msgSender() == owner() || _msgSender() == listing.seller, "only owner or seller");
        require(listing.highestBidder == address(0), "cannot cancel listing with bids");

        // Transfer ownership of the token back to the seller.
        listing.token.safeTransferFrom(address(this), listing.seller, listing.tokenId);

        // Remove the listing from storage.
        _listings.removeListing(listingId);

        // Notify the world that the listing was removed.
        emit ListingCancelled(listingId);
    }

    /**
     * @notice Buys a listing from the marketplace.
     * @param listingId The id of the listing to buy.
     */
    function buy(
        uint256 listingId
    ) external payable
        whenNotPaused
    {
        Listings.Listing storage listing = _listings.get(listingId);
        require(_msgSender() != listing.seller, "seller cannot buy own listing");

        uint256 price = _listings.getBuyPrice(listingId);
        require(price != 0, "listing has no buyout price");
        require(msg.value >= price, "not enough paid");

        // Distribute the payment to the seller, minter, and developers.
        _distributeSalePayment(listing.seller, listing.token.minterOf(listing.tokenId), price);

        // Transfer ownership of the token to the buyer.
        listing.token.safeTransferFrom(address(this), _msgSender(), listing.tokenId);

        // Remove the listing from storage
        _listings.removeListing(listingId);

        // Refund any excess payment back to the buyer.
        if (msg.value > price) {
            payable(_msgSender()).sendValue(msg.value - price);
        }

        // Notify the world that the listing was successful.
        emit ListingSuccessful(listingId, _msgSender(), msg.value);
    }

    /**
     * @notice Creates a new bid on a listed item.
     * @param listingId The id of the listing to bid on.
     */
    function createBid(
        uint256 listingId
    ) external payable
        whenNotPaused
    {
        Listings.Listing storage listing = _listings.get(listingId);
        require(_msgSender() != listing.seller, "seller cannot bid on own listing");
        require(listing.listingType == Listings.ListingType.EnglishAuction, "can only bid on English auctions");

        // Pausing the contract will extend the auction duration by the length of time that the contract was paused.
        uint256 auctionEndTime = listing.createdAt + listing.duration - (_pauseMetrics.totalDuration - listing.pauseDurationAtCreation);
        require(block.timestamp < auctionEndTime, "auction has concluded");

        // Calculate the minimum required bid.
        uint256 minAcceptedBid = listing.startingPrice;
        if (listing.highestBidder != address(0)) {
            minAcceptedBid = (listing.highestBid * _config.minBidIncrease) / PRECISION_SCALAR;
        }
        require(msg.value >= minAcceptedBid, "bid is too low");

        // Refund the previous highest bidder.
        if (listing.highestBidder != address(0)) {
            _config.rewardManager.depositPersonalReward{value: listing.highestBid}(listing.highestBidder);
        }

        // Write the new bidder to storage.
        listing.highestBidder = _msgSender();
        listing.highestBid = msg.value.toUint128();

        // Notify the world that a bid was placed.
        emit BidCreated(listingId, _msgSender(), msg.value);
    }

    /**
     * @notice Creates a new offer for an item.
     * @param token The token contract.
     * @param tokenId The id of the token.
     */
    function createOffer(
        IERC721Mintable token,
        uint256 tokenId
    ) external payable
        whenNotPaused
        onlyWhitelisted(token)
    {
        // Create the offer and write it to storage.
        uint256 offerId = _offers.addOffer(token, tokenId, _msgSender(), msg.value.toUint128());

        // Notify the world that an offer was created.
        emit OfferCreated(offerId, token, tokenId, _msgSender(), msg.value);
    }

    /**
     * @notice Cancels an existing offer.
     * @param offerId The id of the offer to cancel.
     */
    function cancelOffer(
        uint256 offerId
    ) external
        whenNotPaused
    {
        Offers.Offer storage offer = _offers.get(offerId);
        require(_msgSender() == owner() || _msgSender() == offer.offerer, "only developer and offerer can cancel offer");

        // Remove the offer from storage and refund the offerer.
        address offerer = offer.offerer;
        uint128 amount = offer.amount;

        // Remove the offer from storage.
        _offers.removeOffer(offerId);

        // Refund the offerer.
        payable(offerer).sendValue(amount);

        // Notify the world that the offer was cancelled.
        emit OfferCancelled(offerId);
    }

    /**
     * @notice Accepts an existing offer.
     * @param offerId The id of the offer to accept.
     */
    function acceptOffer(
        uint256 offerId
    ) external
        whenNotPaused
    {
        Offers.Offer storage offer = _offers.get(offerId);
        require(_msgSender() == offer.token.ownerOf(offer.tokenId), "only token owner can accept offer");

        // Distribute payment to the seller, minter, and developers.
        _distributeSalePayment(_msgSender(), offer.token.minterOf(offer.tokenId), offer.amount);

        // Transfer the token to the offerer.
        offer.token.safeTransferFrom(_msgSender(), offer.offerer, offer.tokenId);

        // Remove the offer from storage.
        _offers.removeOffer(offerId);

        // Notify the world that the offer was accepted.
        emit OfferAccepted(offerId);
    }

    /**
     * @notice Accepts an existing offer.
     * @param offerId The id of the offer to accept.
     */
    function rejectOffer(
        uint256 offerId
    ) external
        whenNotPaused
    {
        Offers.Offer storage offer = _offers.get(offerId);
        require(_msgSender() == offer.token.ownerOf(offer.tokenId), "only token owner can reject offer");

        // Remove the offer from storage and refund the offerer.
        address offerer = offer.offerer;
        uint128 amount = offer.amount;

        // Remove the offer from storage.
        _offers.removeOffer(offerId);

        // Refund the offerer.
        payable(offerer).sendValue(amount);

        // Notify the world that the offer was rejected.
        emit OfferRejected(offerId);
    }

    /**
     * @notice Distributes payment from a sale or offer to the token's owner, minter, and the developers.
     * @param seller The address that is selling the sold token.
     * @param minter The address that minted the sold token.
     * @param price The amount that was paid for the token.
     */
    function _distributeSalePayment(
        address seller,
        address minter,
        uint256 price
    ) internal {
        // Calculate the minter cut and deposit it to the minter's reward balance.
        uint256 minterCut = (price * _config.minterRate) / PRECISION_SCALAR;
        _config.rewardManager.depositPersonalReward{value: minterCut}(minter);

        // Calculate the developer cut and deposit it to the developer wallet.
        uint256 developerCut = (price * _config.developerRate) / PRECISION_SCALAR;
        payable(_config.developerWallet).sendValue(developerCut);

        // Deposit the remainder of the payment to the seller's reward balance.
        _config.rewardManager.depositPersonalReward{value: price - minterCut - developerCut}(seller);
    }

}