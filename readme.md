# 🏦 CurvanceTimeVault

**CurvanceTimeVault** is a smart contract vault that allows users to deposit ERC20 tokens or ETH and receive NFTs representing their time-locked stake. Upon maturity, the NFTs can be redeemed for the original deposit plus yield and bribes. It includes auto-compounding via ERC4626, Uniswap-style swap support, and bribe distribution.

---

## ✨ Features

- **NFT-based Vault Participation**: NFTs represent each user's vault share and lock duration.
- **Token & ETH Entry**: Join using direct token transfer or swap to the vault token.
- **ERC4626 Compounding**: Uses an external yield-generating vault.
- **Bribe Support**: Optional extra rewards in ERC20 tokens.
- **Flexible Time Windows**: Configurable phases for join, claim, etc.
- **Upgradeable & Pausable**: UUPS and emergency controls.

---

## 🔧 Initialization

```solidity
function initialize(
    address _nft,
    address _vaultToken,
    address _partnerToken,
    address _partnerVault,
    address _router,
    uint256 _vaultStart,
    uint256 _vaultEnd,
    uint256 _joinEnd,
    uint256 _claimStart,
    uint256 _claimEnd,
    uint256 _minPrice,
    uint256 _maxPerUser,
    uint256 _totalLimit,
    uint256 _platformFee,
    address _treasury
) external initializer
```

Initializes the contract.

- `_nft`: NFT contract address to represent vault entries.
- `_vaultToken`: Token used for deposits.
- `_partnerToken`: Token deposited into ERC4626 vault.
- `_partnerVault`: Address of ERC4626-compatible yield vault.
- `_router`: Router for swaps (e.g., Uniswap).
- `_vaultStart` to `_vaultEnd`: Vault active duration.
- `_joinEnd`: Last timestamp to join.
- `_claimStart` to `_claimEnd`: Claimable window.
- `_minPrice`: Minimum price per NFT.
- `_maxPerUser`: Max vault share per user.
- `_totalLimit`: Total max allowed in the vault.
- `_platformFee`: % fee for platform.
- `_treasury`: Address where fees are sent.

---

## 🧾 Vault Entry Functions

### joinVault

```solidity
function joinVault(uint256 _nftAmount, address user) external
```

Direct deposit into vault in `vaultToken`. Mints `_nftAmount` NFTs.

### swapAndJoin

```solidity
function swapAndJoin(
    address[] calldata path,
    uint256 amountIn,
    uint256 amountOutMin,
    uint256 nftAmount
) external
```

Swaps `amountIn` of first token in `path` to `vaultToken`, then joins vault. Requires approval for input token.

### swapEthAndJoin

```solidity
function swapEthAndJoin(
    address[] calldata path,
    uint256 amountOutMin,
    uint256 nftAmount
) external payable
```

Swaps ETH into `vaultToken` then joins vault. `path` must start with WETH.

---

## 🔁 Compounding

### automateCoumpounding

```solidity
function automateCoumpounding() external
```

Harvests yield from `partnerVault` and reinvests into the same vault.

---

## 💸 Claiming

### claimBack

```solidity
function claimBack() external
```

Burns user's NFTs and returns:
- Original deposit
- Yield earned
- Bribe tokens (if deposited)

---

## 🏆 Bribes

### addBribeToken

```solidity
function addBribeToken(address token) external onlyOwner
```

Adds a token that can be distributed as a bribe.

### removeBribeToken

```solidity
function removeBribeToken(address token) external onlyOwner
```

Removes bribe token from list.

### depositBribe

```solidity
function depositBribe(address token, uint256 amount) external
```

Deposits `amount` of bribe `token`. Must be in `bribeTokens` list.

---

## 🧮 Admin Controls

### pause / unpause

```solidity
function pause() external onlyOwner
function unpause() external onlyOwner
```

Emergency pause/unpause vault functions.

### updateRouter

```solidity
function updateRouter(address newRouter) external onlyOwner
```

Changes swap router.

### updatePartnerVault

```solidity
function updatePartnerVault(address newVault) external onlyOwner
```

Changes ERC4626 vault.

### updatePlatformFee / updateSwapFee

```solidity
function updatePlatformFee(uint256 newFee) external onlyOwner
function updateSwapFee(uint256 newFee) external onlyOwner
```

Update platform fee or swap fee percentages.

### withdrawStuckToken

```solidity
function withdrawStuckToken(address token) external onlyOwner
```

Rescues stuck ERC20 tokens.

---

## 🧾 Events

```solidity
event VaultJoined(address indexed user, uint256 nftAmount, uint256 totalValue);
event Claimed(address indexed user, uint256 amountReturned);
event BribeDeposited(address indexed token, uint256 amount);
event Compounded(uint256 yield);
event VaultPaused();
event VaultUnpaused();
```

---

## 📊 Variables

- `vaultToken` - Token accepted in vault.
- `partnerVault` - ERC4626 yield vault.
- `vaultStart`, `vaultEnd`, `claimStart`, `claimEnd` - Time gates.
- `platformFee`, `swapFee` - Fee percentages.
- `totalDeposited`, `userDeposits` - Tracking deposits.
- `bribeTokens` - List of bribe ERC20 tokens.

---

## 📄 License

MIT © 2025 Curvance

