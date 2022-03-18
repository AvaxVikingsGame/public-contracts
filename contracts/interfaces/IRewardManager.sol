// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol";

/**
 * @title IRewardsManager
 * @author JaboiNads
 */
interface IRewardManager {

    /**
     * @notice Initializes a token with the rewards manager.
     * @param tokenId The id of the token.
     */
    function initializeToken(
        uint256 tokenId
    ) external;

    /**
     * @notice Deposits a reward that is evenly distributed to all registered holders.
     */
    function depositSharedReward() external payable;

    /**
     * @notice Deposits a reward for a specified recipient.
     * @param recipient The receiver of the reward.
     */
    function depositPersonalReward(
        address recipient
    ) external payable;

    /**
     * @notice Releases all unclaimed rewards belonging to the caller.
     * @return reward The amount of reward that was claimed.
     */
    function release() external returns (uint256 reward);

}