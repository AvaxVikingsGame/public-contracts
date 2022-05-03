// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";

import "./interfaces/IRewardManager.sol";

/**
 * @title Reward Manager
 * @author JaboiNads
 * @notice Responsible for tracking and distributing rewards
 */
contract RewardManager is OwnableUpgradeable, ERC165Upgradeable, IRewardManager {

    // The token to manage shared rewards for.
    IERC721EnumerableUpgradeable private _token;

    // The maximum reward potential for each token.
    uint256 private _sharedRewardPotential;

    // Maps a token to the reward potential the last time rewards were claimed.
    mapping(uint256 => uint256) private _lastClaimedSharedRewardPotential;

    // Maps an address to its unclaimed personal reward.
    mapping(address => uint256) private _unclaimedPersonalRewards;

    /**
     * @notice Emitted when a shared reward is deposited.
     * @param amount The reward amount distributed to each holders.
     */
    event SharedRewardReceived(
        address indexed sender,
        uint256 amount
    );

    /**
     * @notice Emitted when a personal reward is deposited.
     * @param recipient The address that received the reward.
     * @param amount The reward amount that was received.
     */
     event PersonalRewardReceived(
         address indexed sender,
         address indexed recipient,
         uint256 amount
     );

    /**
     * @notice Emitted when rewards are claimed.
     * @param recipient The address that claimed the rewards.
     * @param amount The amount that was claimed.
     */
    event RewardsReleased(
        address indexed recipient,
        uint256 amount
    );

    function initialize(
        IERC721EnumerableUpgradeable token
    ) external initializer {
        __Ownable_init();
        __RewardsManager_init_unchained(token);
    }

    // solhint-disable-next-line func-name-mixedcase
    function __RewardsManager_init_unchained(
        IERC721EnumerableUpgradeable token
    ) internal onlyInitializing {
        require(token.supportsInterface(type(IERC721EnumerableUpgradeable).interfaceId), "not ERC721Enumerable");
        _token = token;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IRewardManager).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @notice Initializes a token with the reward manager.
     * @param tokenId The id of the token.
     */
    function initializeToken(
        uint256 tokenId
    ) external {
        require(_msgSender() == address(_token), "unauthorized sender");
        require(_lastClaimedSharedRewardPotential[tokenId] == 0, "token already initialized");

        _lastClaimedSharedRewardPotential[tokenId] = _sharedRewardPotential;
    }

    /**
     * @notice Deposits a reward that is evenly distributed to all registered holders.
     */
    function depositSharedReward() external payable {
        require(msg.value > 0, "no reward provided");

        uint256 supply = _token.totalSupply();
        require(supply > 0, "no token supply exists");

        uint256 reward = msg.value / supply;
        _sharedRewardPotential += reward;

        emit SharedRewardReceived(_msgSender(), reward);
    }

    /**
     * @notice Deposits a reward that is given to the specified recipient.
     * @param recipient The receiver of the reward.
     */
    function depositPersonalReward(
        address recipient
    ) external payable {
        require(msg.value > 0, "no reward provided");
        require(recipient != address(0), "cannot reward zero-address");

        _unclaimedPersonalRewards[recipient] += msg.value;
        
        emit PersonalRewardReceived(_msgSender(), recipient, msg.value);
    }

    /**
     * @notice Releases all unclaimed rewards for the caller.
     * @return reward The amount of reward that was claimed.
     */
    function release() external returns (uint256 reward) {
        // Claim all pending personal rewards.
        reward = _unclaimedPersonalRewards[_msgSender()];
        _unclaimedPersonalRewards[_msgSender()] = 0;

        // Claim rewards for all held tokens.
        uint256 numTokens = _token.balanceOf(_msgSender());
        for (uint256 i = 0; i < numTokens; i++) {
            uint256 tokenId = _token.tokenOfOwnerByIndex(_msgSender(), i);

            // Claim pending rewards for the token.
            reward += _sharedRewardPotential - _lastClaimedSharedRewardPotential[tokenId];
            _lastClaimedSharedRewardPotential[tokenId] = _sharedRewardPotential;
        }

        // Transfer the calculated rewards to the sender.
        AddressUpgradeable.sendValue(payable(_msgSender()), reward);

        // Notify the world that rewards were released.
        emit RewardsReleased(_msgSender(), reward);
    }

    function calculateAvailableRewards(
        address recipient
    ) external view returns (uint256 reward) {
        // Claim all pending personal rewards.
        reward = _unclaimedPersonalRewards[recipient];

        // Calculate rewards for all held tokens.
        uint256 numTokens = _token.balanceOf(recipient);
        for (uint256 i = 0; i < numTokens; i++) {
            uint256 tokenId = _token.tokenOfOwnerByIndex(recipient, i);
            reward += _sharedRewardPotential - _lastClaimedSharedRewardPotential[tokenId];
        }
    }

}