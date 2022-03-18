// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol";

/**
 * @title IERC721Mintable
 * @author JaboiNads
 * @notice Adds functionality that allows for a token's minter to be retrieved.
 */
interface IERC721Mintable is IERC721Upgradeable, IERC721MetadataUpgradeable, IERC721EnumerableUpgradeable {

    /**
     * @notice Gets the address of the account that minted the token.
     * @param tokenId The id of the token.
     */
    function minterOf(uint256 tokenId) external view returns(address);

}