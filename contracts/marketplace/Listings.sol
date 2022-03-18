// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import "../interfaces/IERC721Mintable.sol";

/**
 * @title Listings Library
 * @author JaboiNads
 * @notice Encapsulates functionality for listings on the Marketplace.
 */
library Listings {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using SafeCastUpgradeable for uint256;

    uint256 constant private PRECISION_SCALAR = 1000;

    /**
     * @dev The different types of listing.
     */
    enum ListingType {
        Unlisted,
        FixedPrice,
        DutchAuction,
        EnglishAuction
    }

    /**
     * @dev Data for an individual listing.
     */
    struct Listing {
        // The type of token that is listed.
        IERC721Mintable token;
        // The unique identifier of the token.
        uint256 tokenId;
        // The address that created the listing.
        address seller;
        // The unix timestamp of the block the listing was created on (in seconds).
        uint64 createdAt;
        // [Auctions Only]: The duration of the listing (in seconds).
        uint32 duration;
        // [Auctions Only]: The price to begin bidding at.
        uint128 startingPrice;
        // The ending price (Dutch Auctions), or the buyout price (Fixed price, English auction) if present.
        uint128 buyoutOrEndingPrice;
        // The address with the highest bid (English Auctions only)
        address highestBidder;
        // The current highest bid (English Auctions only)
        uint128 highestBid;
        // The type of listing.
        ListingType listingType;
        // How long the contract was paused at the time the listing was created.
        uint256 pauseDurationAtCreation;
    }

    /**
     * @dev Data for managing active listings.
     */
    struct Data {
        // The counter for generating unique listing ids.
        CountersUpgradeable.Counter idCounter;
        // Maps a token to its listing id, or zero if the listing does not exist.
        mapping(IERC721Mintable => mapping(uint256 => uint256)) indices;
        // Maps a listing ID to the listing.
        mapping(uint256 => Listing) listings;
    }

    /**
     * @notice Creates a fixed price listing and adds it to storage.
     * @param self The data set to operate on.
     * @param token The contract of the token.
     * @param tokenId The id of the token.
     * @param seller The seller of the token.
     * @param price The price to list the token at.
     */
    function addFixedPriceListing(
        Data storage self,
        IERC721Mintable token,
        uint256 tokenId,
        address seller,
        uint128 currentPauseDuration,
        uint128 price
    ) internal returns (uint256) {
        require(price > 0, "no price provided");

        return _addListing(
            self,
            ListingType.EnglishAuction,
            token,
            tokenId,
            seller,
            currentPauseDuration,
            0,
            0,
            price
        );
    }

    /**
     * @notice Creates a fixed price listing and adds it to storage.
     * @param self The data set to operate on.
     * @param token The contract of the token.
     * @param tokenId The id of the token.
     * @param seller The seller of the token.
     * @param currentPauseDuration The marketplace's current pause duration.
     * @param startingPrice The price to begin the auction at.
     * @param endingPrice The price to end the auction at.
     * @param duration The length of time to run the auction for (in seconds).
     */
    function addDutchAuctionListing(
        Data storage self,
        IERC721Mintable token,
        uint256 tokenId,
        address seller,
        uint128 currentPauseDuration,
        uint128 startingPrice,
        uint128 endingPrice,
        uint32 duration
    ) internal returns (uint256) {
        require(startingPrice > endingPrice, "starting price must exceed ending price");
        require(endingPrice > 0, "no ending price provided");
        require(duration > 0, "no duration provided");

        return _addListing(
            self,
            ListingType.DutchAuction,
            token,
            tokenId,
            seller,
            currentPauseDuration,
            duration,
            startingPrice,
            endingPrice
        );
    }

    /**
     * @notice Creates a English auction listing and adds it to storage.
     * @param self The data set to operate on.
     * @param token The contract of the token.
     * @param tokenId The id of the token.
     * @param seller The seller of the token.
     * @param currentPauseDuration The marketplace's current pause duration.
     * @param startingPrice The price to begin the auction at.
     * @param buyoutPrice The price to automatically buy the token at, or 0 for no buyout.
     * @param duration The length of time to run the auction for (in seconds).
     */
    function addEnglishAuctionListing(
        Data storage self,
        IERC721Mintable token,
        uint256 tokenId,
        address seller,
        uint128 currentPauseDuration,
        uint128 startingPrice,
        uint128 buyoutPrice,
        uint32 duration
    ) internal returns (uint256) {
        require(startingPrice > 0, "no starting price provided");
        require(buyoutPrice == 0 || buyoutPrice > startingPrice, "buyout price must exceed starting price");
        require(duration > 0, "no duration provided");

        return _addListing(
            self,
            ListingType.EnglishAuction,
            token,
            tokenId,
            seller,
            currentPauseDuration,
            duration,
            startingPrice,
            buyoutPrice
        );
    }

    /**
     * @notice Removes the specified listing from storage.
     * @param self The data set to operate on.
     * @param listingId The id of the listing to remove.
     * @dev This function will revert if the listing does not exist.
     */
    function removeListing(
        Data storage self,
        uint256 listingId
    ) internal {
        Listing storage listing = get(self, listingId);
        _removeListing(self, listing.token, listing.tokenId, listingId);
    }

    /**
     * @notice Removes the specified listing from storage.
     * @param self The data set to operate on.
     * @param listingId The id of the listing to remove.
     */
    function tryRemoveListing(
        Data storage self,
        uint256 listingId
    ) internal returns (bool) {
        (bool success, Listing storage listing) = tryGet(self, listingId);
        if (success) {
            _removeListing(self, listing.token, listing.tokenId, listingId);
        }
        return success;
    }

    /**
     * @notice Returns whether the specified listing exists.
     * @param self The data set to operate on.
     * @param listingId The unique id of the listing.
     */
    function exists(
        Data storage self,
        uint256 listingId
    ) internal view returns (bool) {
        return self.listings[listingId].listingType != ListingType.Unlisted;
    }

    /**
     * @notice Returns whether the specified listing exists.
     * @param self The data set to operate on.
     * @param token The contract of the token.
     * @param tokenId The id of the token.
     */
    function exists(
        Data storage self,
        IERC721Mintable token,
        uint256 tokenId
    ) internal view returns (bool) {
        return exists(self, self.indices[token][tokenId]);
    }

    /**
     * @notice Returns the listing associated with the specified id.
     * @param self The data set to operate on.
     * @param listingId The unique id of the listing.
     * @dev This function will revert if the listing does not exist.
     */
    function get(
        Data storage self,
        uint256 listingId
    ) internal view returns (Listing storage) {
        Listing storage listing = self.listings[listingId];
        require(listing.listingType != ListingType.Unlisted, "nonexistent listing");
        return listing;
    }

    /**
     * @notice Returns the listing associated with the specified token.
     * @param self The data set to operate on.
     * @param token The contract of the token.
     * @param tokenId The id of the token.
     * @dev This function will revert if the listing does not exist.
     */
    function get(
        Data storage self,
        IERC721Mintable token,
        uint256 tokenId
    ) internal view returns (Listing storage) {
        return get(self, self.indices[token][tokenId]);
    }
    
    /**
     * @notice Returns the listing associated with the specified id.
     * @param self The data set to operate on.
     * @param listingId The unique identifier of the listing.
     */
    function tryGet(
        Data storage self,
        uint256 listingId
    ) internal view returns (bool, Listing storage) {
        Listing storage listing = self.listings[listingId];
        return (listing.listingType != ListingType.Unlisted, listing);
    }

    /**
     * @notice Returns the listing associated with the specified token.
     * @param self The data set to operate on.
     * @param token The contract of the token.
     * @param tokenId The id of the token.
     */
    function tryGet(
        Data storage self,
        IERC721Mintable token,
        uint256 tokenId
    ) internal view returns (bool, Listing storage) {
        return tryGet(self, self.indices[token][tokenId]);
    }

    /**
     * @notice Gets the price to buy the specified listing.
     * @param self The data set to operate on.
     * @param listingId The id of the listing to buy.
     */
    function getBuyPrice(
        Data storage self,
        uint256 listingId
    ) internal view returns (uint256) {
        Listing storage listing = get(self, listingId);
        if (listing.listingType == ListingType.DutchAuction) {
            // Calculate the percentage of the auction that has finished so far.
            uint256 alpha = ((block.timestamp - listing.createdAt) * PRECISION_SCALAR) / listing.duration;
            // Linearly interpolate between the starting and ending prices, then normalize the result to get the real price. 
            return (listing.startingPrice - ((listing.startingPrice - listing.buyoutOrEndingPrice) * alpha)) / PRECISION_SCALAR;
        } else {
            return listing.buyoutOrEndingPrice;
        }
    }

    /**
     * @notice Generates a unique identifier for a listing.
     * @param self The data set to operate on.
     */
    function _generateNextId(
        Data storage self
    ) private returns (uint256) {
        self.idCounter.increment();
        return self.idCounter.current();
    }

    /**
     * @notice Adds a listing to storage.
     * @param self The data set to operate on.
     * @param token The contract of the token to add.
     * @param tokenId The id of the token to add.
     * @param seller The address that created the listing.
     * @param duration The length of time to run the auction (in seconds).
     * @param startingPrice The starting price of the auction.
     * @param buyoutOrEndingPrice The buyout or ending price, or zero if
     */
    function _addListing(
        Data storage self,
        ListingType listingType,
        IERC721Mintable token,
        uint256 tokenId,
        address seller,
        uint128 currentPauseDuration,
        uint32 duration,
        uint128 startingPrice,
        uint128 buyoutOrEndingPrice
    ) private returns (uint256) {
        require(!exists(self, token, tokenId), "token is already listed");
        require(seller != address(0), "seller cannot be zero-address");
        require(seller == token.ownerOf(tokenId), "seller must own token");

        // Generate a unique identifier for the listing.
        uint256 listingId = _generateNextId(self);

        // Write the listing to storage.
        self.indices[token][tokenId] = listingId;
        self.listings[listingId] = Listing({
            listingType: listingType,
            token: token,
            tokenId: tokenId,
            seller: seller,
            pauseDurationAtCreation: currentPauseDuration,
            createdAt: block.timestamp.toUint64(),
            duration: duration,
            startingPrice: startingPrice,
            buyoutOrEndingPrice: buyoutOrEndingPrice,
            highestBidder: address(0),
            highestBid: 0
        });

        // Return the listing id.
        return listingId;
    }

    /**
     * @notice Deletes a listing from storage.
     * @param self The data set to operate on.
     * @param token The contract of the token to delete.
     * @param tokenId The id of the token to delete.
     * @param listingId The id of the listing to delete.
     */
    function _removeListing(
        Data storage self,
        IERC721Mintable token,
        uint256 tokenId,
        uint256 listingId
    ) private {
        delete self.indices[token][tokenId];
        delete self.listings[listingId];
    }

}