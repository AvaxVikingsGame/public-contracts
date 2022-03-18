// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

/**
 * @title PauseMetrics
 * @author JaboiNads
 * @notice Adds functionality for tracking how long a contract has been paused.
 */
library PauseMetrics {
    using SafeCastUpgradeable for uint256;

    struct Data {
        // The unix timestamp of the time the contract was paused.
        uint128 lastPauseTimestamp;
        // The total amount of time that this contract has been paused (in seconds).
        uint128 totalDuration;
    }

    /**
     * @notice Updates the pause time.
     * @param self The data set to operate on.
     */
    function pause(
        PauseMetrics.Data storage self
    ) internal {
        require(!isPaused(self), "already paused");
        self.lastPauseTimestamp = block.timestamp.toUint128();
    }

    /**
     * @notice Updates the total pause duratio
     */
    function unpause(
        PauseMetrics.Data storage self
    ) internal {
        require(isPaused(self), "already unpaused");
        require(self.lastPauseTimestamp != 0, "already unpaused");
        self.totalDuration = (block.timestamp - self.lastPauseTimestamp).toUint128();
        self.lastPauseTimestamp = 0;
    }

    /**
     * @notice Gets whether the metrics are already paused.
     */
    function isPaused(
        PauseMetrics.Data storage self
    ) internal view returns (bool) {
        return self.lastPauseTimestamp != 0;
    }

}