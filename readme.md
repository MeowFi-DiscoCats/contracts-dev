# TimeVaultV1

![TimeVault Logo](https://via.placeholder.com/728x90.png?text=TimeVault)

## Overview
TimeVaultV1 is a smart contract designed for secure time-locked NFT staking using ERC-20 tokens. It integrates OpenZeppelin's upgradeable contracts to ensure flexibility and security.

## Features
- **Upgradeable Smart Contract**: Built using OpenZeppelin's UUPS pattern.
- **NFT Staking Mechanism**: Users can stake ERC-20 tokens to receive NFTs.
- **Time-Locked Funds**: Implements joining and claiming periods for staking.
- **Yield Distribution**: Rewards users based on their stake.
- **Ownership Control**: Utilizes Ownable for restricted access.

## Smart Contracts

### **TimeVaultV1.sol**
This is the main contract that manages deposits, NFT minting, and funds withdrawal.

#### **Key Functions:**
- `initialize(...)`: Initializes contract with necessary parameters.
- `joinVault(uint256 _nftAmount)`: Allows users to stake tokens and mint NFTs.
- `claimBack()`: Users can claim their rewards after the staking period.
- `withdrawAllFunds(address receiver)`: Owner can withdraw the total active funds.
- `setNftPrice(uint256 _nftPrice)`: Updates the NFT price.
- `setTimePeriod(uint256 _joiningPeriod, uint256 _claimingPeriod)`: Sets the joining and claiming period.
- `depositExternalFunds(uint256 _amount)`: Allows external deposits to increase yield.
- `getState()`: Returns the contract's current state (joining, waiting, or claiming).

### **TimeNft.sol**
A custom ERC-721 NFT contract used for representing locked funds.

#### **Key Functions:**
- `safeMint(address to, uint256 amount)`: Mints NFTs to users.
- `burn(uint256 tokenId)`: Burns NFTs upon claiming.
- `pause() / unpause()`: Enables and disables transfers.

### **MyContractProxy.sol**
Implements UUPS proxy to enable contract upgrades.

## Installation
Ensure you have **Foundry** and **Remix** installed for local development.

```sh
forge install
forge build
```

For deploying via Remix:
1. Open [Remix IDE](https://remix.ethereum.org/).
2. Compile `TimeVaultV1.sol`.
3. Deploy with your desired parameters.

## Usage
1. **Join Vault**:
   ```solidity
   vault.joinVault(2);
   ```
2. **Claim Rewards**:
   ```solidity
   vault.claimBack();
   ```

## Security Considerations
- Uses **ReentrancyGuardUpgradeable** to prevent reentrancy attacks.
- Implements **OwnableUpgradeable** for restricted access to admin functions.
- Uses **ERC1967Proxy** for upgradeability.

## License
This project is licensed under the **MIT License**.

---
*Built with ❤️ using Solidity, Remix & Foundry*

