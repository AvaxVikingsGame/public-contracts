// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/finance/PaymentSplitter.sol";

/**
 * @title Developer Payment Splitter
 * @author JaboiNads
 * @notice Splits payments made to the developers.
 */
contract DeveloperPaymentSplitter is PaymentSplitter {

    // solhint-disable-next-line no-empty-blocks
    constructor(address[] memory payees, uint256[] memory shares) PaymentSplitter(payees, shares) {}

}