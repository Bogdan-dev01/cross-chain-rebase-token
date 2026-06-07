# Cross-Chain Rebase Token

![Solidity](https://img.shields.io/badge/Solidity-0.8.x-blue)
![Foundry](https://img.shields.io/badge/Built%20with-Foundry-orange)
![Chainlink CCIP](https://img.shields.io/badge/Chainlink-CCIP-blue)

A Foundry-based educational project demonstrating a rebasing ERC20 token integrated with Chainlink CCIP for cross-chain transfers.

## Overview

This project implements a yield-bearing rebasing token backed by a Vault contract.

Users deposit ETH into a Vault and receive Rebase Tokens representing their underlying position. Token balances grow over time according to a user-specific interest rate.

The project also demonstrates how to preserve balances and interest rates while bridging tokens across chains using Chainlink CCIP.

---

## Protocol Design

### Vault Deposits

Users deposit ETH into the Vault and receive Rebase Tokens.

The Vault acts as the collateral layer for the protocol.

### Rebasing Mechanism

The token uses a dynamic balance model.

Instead of storing continuously updated balances, the protocol calculates accrued interest when users interact with the system.

Key properties:

* Balances increase linearly over time.
* Interest is materialized during:

  * Minting
  * Burning
  * Transfers
  * Cross-chain bridging

### User Interest Rates

Each user receives an individual interest rate when they first acquire tokens.

The interest rate is derived from the protocol's current global interest rate.

Key properties:

* Early users can lock in higher interest rates.
* Existing users keep their assigned rates.
* New users receive the current global rate.
* The global interest rate can only decrease.

This design rewards early adopters and encourages protocol adoption.

### Cross-Chain Compatibility

The protocol preserves rebasing behavior across chains.

When tokens are bridged:

* Tokens are burned on the source chain.
* A CCIP message is transmitted.
* Tokens are minted on the destination chain.
* User-specific interest rates are preserved.

---

## Architecture

### RebaseToken

Main ERC20 rebasing token.

Responsibilities:

* Minting and burning
* Interest accrual
* User interest rate management
* Dynamic balance calculation

### Vault

ETH-backed collateral vault.

Responsibilities:

* Accept ETH deposits
* Mint Rebase Tokens
* Redeem tokens for ETH

### RebaseTokenPool

Custom Chainlink CCIP Token Pool implementation.

Responsibilities:

* Handle cross-chain transfers
* Preserve user interest rates
* Mint and burn tokens during bridging

---

## Cross-Chain Flow

```text
User
 │
 ▼
Deposit ETH
 │
 ▼
Vault
 │
 ▼
Mint Rebase Tokens
 │
 ▼
CCIP Bridge
 │
 ▼
Burn on Source Chain
 │
 ▼
CCIP Message
 │
 ▼
Mint on Destination Chain
```

---

## Project Structure

```text
src/
├── interfaces/
│   └── IRebaseToken.sol
├── RebaseToken.sol
├── RebaseTokenPool.sol
└── Vault.sol

script/
├── BridgeTokens.s.sol
├── ConfigurePool.s.sol
└── Deployer.s.sol

test/
├── RebaseToken.t.sol
└── Crosschain.t.sol
```

---

## Technologies Used

* Solidity
* Foundry
* OpenZeppelin Contracts
* Chainlink CCIP
* Chainlink Local Simulator

---

## Installation

Clone the repository:

```bash
git clone https://github.com/YOUR_USERNAME/cross-chain-rebase-token.git
cd cross-chain-rebase-token
```

Install dependencies:

```bash
forge install
```

Build:

```bash
forge build --via-ir
```

---

## Testing

Run all tests:

```bash
forge test
```

Run verbose tests:

```bash
forge test -vvvv
```

Run fork tests:

```bash
forge test --match-test testBridgeAlltokens -vvvv
```

---

## Learning Objectives

This project was built to practice:

* ERC20 token development
* Rebasing token mechanics
* Vault-based token systems
* Chainlink CCIP integration
* Cross-chain token transfers
* Foundry scripting
* Fork testing
* Chainlink Local Simulator

---

## Security Notice

This project was built for educational purposes and has not been audited.

Do not use this code in production without a professional security review.
