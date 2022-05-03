# CryptoVikings public contracts
This repository serves as a centralized hub for people to view our smart contracts.

## RewardManager
The [RewardManager](./contracts/RewardManager.sol) contract is responsible for tracking and distributing rewards earned by users.

## DeveloperPaymentSplitter
The [DeveloperPaymentSplitter](./contracts/DeveloperPaymentSplitter.sol) contract automatically distributes payments made to the developers.

## CryptoVikings
The [CryptoVikings](./contracts/tokens/CryptoVikings.sol) contract implements the core ERC-721 "Viking" token.

## Marketplace
The [Marketplace](./contracts/marketplace/Marketplace.sol) contract implements the marketplace functionality. The [Listings](./contracts//marketplace/Listings.sol) and [Offers](./contracts/marketplace/Offers.sol) libraries contain the listing and offer functionality respectively.

## Libraries
The [PauseMetrics](./contracts/libraries/PauseMetrics.sol) library tracks metadata about pauses, which are currently used by the Marketplace to extend auctions whenever a contract is paused.

The [SelfCastExtended](./contracts/libraries/SafeCastExtended.sol) library expands on [OpenZeppelin's SafeCast](https://docs.openzeppelin.com/contracts/4.x/api/utils#SafeCast) utility library to add some casting to additional types.

## Interfaces
The [IERC721Mintable](./contracts/interfaces/IERC721Mintable.sol) interface adds a `minterOf` function to the existing ERC721 interfaces. Currently this is used by our Marketplace contract to reward users whenever a token that they minted is sold.

The [IRewardManager](./contracts/interfaces/IRewardManager.sol) interface defines the functionality for the RewardManager interface. This is used by the CryptoVikings and Marketplace contracts to deposit personal and shared rewards to users.