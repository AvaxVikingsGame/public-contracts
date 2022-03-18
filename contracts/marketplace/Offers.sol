// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import "../interfaces/IERC721Mintable.sol";

/**
 * @title Offers Library
 * @author JaboiNads
 * @notice Encapsulates functionality for offers on the Marketplace.
 */
library Offers {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using SafeCastUpgradeable for uint256;
    
    /**
     * @dev Represents an individual offer made on a token.
     */
    struct Offer {
        // The token the offer was made on.
        IERC721Mintable token;
        // The id of the token the offer was made on.
        uint256 tokenId;
        // The address that made the offer.
        address offerer;
        // The amount that was offered.
        uint128 amount;
    }

    struct Data {
        // Generates unique identifiers for each offer.
        CountersUpgradeable.Counter idCounter;
        // Maps a token/offerer pair to the offer's id.
        mapping(IERC721Mintable => mapping(uint256 => mapping(address => uint256))) indices;
        // Maps an offer's id to the offer data.
        mapping(uint256 => Offer) offers;
    }

    /**
     * @notice Creates a new offer and adds it to storage.
     * @param self The data set to operate on.
     * @param token The token's contract address.
     * @param tokenId The id of the token.
     * @param offerer The address that created the offer.
     * @param amount The amount that was offered.
     */
    function addOffer(
        Data storage self,
        IERC721Mintable token,
        uint256 tokenId,
        address offerer,
        uint128 amount
    ) internal returns (uint256) {
        require(!exists(self, token, tokenId, offerer), "offer already exists");
        require(token.ownerOf(tokenId) != address(0), "token does not exist");
        require(offerer != address(0), "offerer cannot be zero-address");
        require(amount > 0, "no amount offered");

        // Generate a unique identifier for the listing.
        uint256 offerId = _generateNextId(self);

        // Write the offer to storage.
        self.indices[token][tokenId][offerer] = offerId;
        self.offers[offerId] = Offer({
            token: token,
            tokenId: tokenId,
            offerer: offerer,
            amount: amount
        });

        // Return the offer id.
        return offerId;
    }

    /**
     * @notice Removes the offer associated with the specified id from storage.
     * @param self The data set to operate on.
     * @param offerId The id of the offer to remove.
     * @dev This function will revert if the offer does not exist.
     */
    function removeOffer(
        Data storage self,
        uint256 offerId
    ) internal {
        Offer storage offer = get(self, offerId);
        _removeOffer(self, offerId, offer.token, offer.tokenId, offer.offerer);
    }

    /**
     * @notice Removes the offer associated with the specified id from storage.
     * @param self The data set to operate on.
     * @param offerId The id of the offer to remove.
     */
    function tryRemoveOffer(
        Data storage self,
        uint256 offerId
    ) internal returns (bool) {
        (bool success, Offer storage offer) = tryGet(self, offerId);
        if (success) {
            _removeOffer(self, offerId, offer.token, offer.tokenId, offer.offerer);
        }
        return success;
    }

    /**
     * @notice Returns whether the specified offer exists.
     * @param self The data set to operate on.
     * @param offerId The unique id of the offer.
     */
    function exists(
        Data storage self,
        uint256 offerId
    ) internal view returns (bool) {
        return self.offers[offerId].offerer != address(0);
    }

    /**
     * @notice Returns whether an offer associated with the token and offerer exists.
     * @param self The data set to operate on.
     * @param token The token's contract address.
     * @param tokenId The id of the token.
     * @param offerer The address that created the offer.
     */
    function exists(
        Data storage self,
        IERC721Mintable token,
        uint256 tokenId,
        address offerer
    ) internal view returns (bool) {
        return exists(self, self.indices[token][tokenId][offerer]);
    }

    /**
     * @notice Returns the offer associated with the specified id.
     * @param self The data set to operate on.
     * @param offerId The id of the offer to get.
     * @dev This function will revert if the listing does not exist.
     */
    function get(
        Data storage self,
        uint256 offerId
    ) internal view returns (Offer storage) {
        Offer storage offer = self.offers[offerId];
        require(offer.offerer != address(0), "nonexistent offer");
        return offer;
    }

    /**
     * @notice Returns the offer associated with the specified id.
     * @param self The data set to operate on.
     * @param token The token's contract address.
     * @param tokenId The id of the token.
     * @param offerer The address that made the offer.
     * @dev This function will revert if the listing does not exist.
     */
    function get(
        Data storage self,
        IERC721Mintable token,
        uint256 tokenId,
        address offerer
    ) internal view returns (Offer storage) {
        return get(self, self.indices[token][tokenId][offerer]);
    }

    /**
     * @notice Returns the offer associated with the specified id.
     * @param self The data set to operate on.
     * @param offerId The id of the offer to get.
     */
    function tryGet(
        Data storage self,
        uint256 offerId
    ) internal view returns (bool, Offer storage) {
        Offer storage offer = self.offers[offerId];
        return (offer.offerer != address(0), offer);
    }

    /**
     * @notice Returns the offer associated with the specified token and offerer.
     * @param token The token's contract address.
     * @param tokenId The id of the token.
     * @param offerer The address that made the offer.
     */
    function tryGet(
        Data storage self,
        IERC721Mintable token,
        uint256 tokenId,
        address offerer
    ) internal view returns (bool, Offer storage) {
        return tryGet(self, self.indices[token][tokenId][offerer]);
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
     * @notice Removes an offer from storage.
     * @param self The data set to operate on.
     * @param offerId The id of the offer.
     * @param token The token's contract address.
     * @param tokenId The id of the token.
     * @param offerer The address that made the offer.
     */
    function _removeOffer(
        Data storage self,
        uint256 offerId,
        IERC721Mintable token,
        uint256 tokenId,
        address offerer
    ) private {
        delete self.indices[token][tokenId][offerer];
        delete self.offers[offerId];
    }

}