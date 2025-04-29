# 🏦 CurvanceTimeVault

**CurvanceTimeVault** is a time-locked smart contract vault that allows users to deposit ERC20 tokens or ETH, receive NFTs representing their stake, and later redeem them for principal + yield. It integrates Uniswap-style swaps, ERC4626-based auto-compounding, NFT minting, and bribe distributions.

---

## ✨ Features

- **NFT-based Participation**  
  Users receive NFTs when joining the vault. These NFTs represent their locked position and are burned upon withdrawal.

- **Token & ETH Support**  
  Users can:
  - Deposit ERC20 tokens directly.
  - Swap other tokens or ETH into the vault token (`SHMON`) via `swapAndJoin` or `swapEthAndJoin`.

- **Yield Compounding via ERC4626**  
  Deposits are automatically staked into an ERC4626-compatible yield vault, and compounded periodically.

- **Bribe Distribution**  
  At the end of the vault duration, additional rewards (bribes) are claimable in various ERC20 tokens.

- **Fees**  
  Supports platform and swap fees configurable by the vault owner.

- **Upgradeable**  
  Uses OpenZeppelin’s UUPSUpgradeable proxy pattern for upgradeability.

---

## ⚙️ Initialization

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

Initializes the vault with configuration parameters.

---

## 🯞 Joining the Vault

### Direct ERC20 Deposit

```solidity
function joinVault(uint256 _nftAmount, address user) external
```

Mints vault NFTs and deposits tokens.

### Swap + Join (ERC20)

```solidity
function swapAndJoin(
    address[] calldata path,
    uint256 amountIn,
    uint256 amountOutMin,
    uint256 nftAmount
) external
```

Swaps input token to `vaultToken` and joins the vault.

### Swap + Join (ETH)

```solidity
function swapEthAndJoin(
    address[] calldata path,
    uint256 amountOutMin,
    uint256 nftAmount
) external payable
```

Swaps ETH to `vaultToken` and joins the vault.

---

## 🔁 Compounding

```solidity
function automateCoumpounding() external
```

Harvests yield from the partner ERC4626 vault and re-deposits it for higher APY.

---

## 💸 Claiming

```solidity
function claimBack() external
```

Allows users to:
- Burn vault NFT
- Receive original deposit + proportional yield
- Claim bribe tokens (if any)

---

## 🏆 Bribes

```solidity
function addBribeToken(address token) external onlyOwner
function removeBribeToken(address token) external onlyOwner
function depositBribe(address token, uint256 amount) external
```

Bribe tokens are optional ERC20 rewards distributed at claim time.

---

## 📊 Fees

- `platformFee` — % of the yield sent to `treasury`
- `swapFee` — Optional extra fee on swap-based joins

```solidity
function updatePlatformFee(uint256 newFee) external onlyOwner
function updateSwapFee(uint256 newFee) external onlyOwner
```

---

## 🔐 Admin Functions

- `pause()` / `unpause()` — Emergency stop for key vault functions.
- `updateRouter()` — Change the swap router (e.g., Uniswap).
- `updatePartnerVault()` — Change the ERC4626 yield vault.
- `withdrawStuckToken()` — Rescue stuck tokens.

---

## 🧱 Tech Stack

- Solidity
- ERC20, ERC721
- ERC4626 (Tokenized Vault Standard)
- OpenZeppelin Contracts (UUPSUpgradeable, Pausable, Ownable)
- Uniswap V2/V3 style router support

---

## 📄 License

MIT © 2025 Curvance

