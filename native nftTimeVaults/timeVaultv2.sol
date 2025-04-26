// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;
interface IUniversalBalance {
    // Errors
    error PluginDelegable_InvalidParameter();
    error PluginDelegable__DelegatingDisabled();
    error PluginDelegable__InvalidCentralRegistry();
    error PluginDelegable__Unauthorized();
    error Reentrancy();
    error UniversalBalance__InsufficientBalance();
    error UniversalBalance__InvalidParameter();
    error UniversalBalance__SlippageError();
    error UniversalBalance__Unauthorized();

    // Events
    event DelegateApproval(
        address indexed owner,
        address indexed delegate,
        uint256 approvalIndex,
        bool isApproved
    );

    event Deposit(
        address indexed by,
        address indexed owner,
        uint256 assets,
        bool lendingDeposit
    );

    event Withdraw(
        address indexed by,
        address indexed to,
        address indexed owner,
        uint256 assets,
        bool lendingRedemption
    );

    // View Functions
    // function centralRegistry() external view returns (ICentralRegistry);
    function checkDelegationDisabled(address user) external view returns (bool);
    function getUserApprovalIndex(address user) external view returns (uint256);
    function isDelegate(address user, address delegate) external view returns (bool);
    // function linkedToken() external view returns (IEToken);
    function underlying() external view returns (address);
    function userBalances(address user) external view returns (uint256 sittingBalance, uint256 lentBalance);

    // State-Changing Functions
    function deposit(uint256 amount, bool willLend) external;
    function depositFor(uint256 amount, bool willLend, address recipient) external;
    function multiDepositFor(
        uint256 depositSum,
        uint256[] calldata amounts,
        bool[] calldata willLend,
        address[] calldata recipients
    ) external;
    function multiWithdrawFor(
        uint256[] calldata amounts,
        bool[] calldata forceLentRedemption,
        address recipient,
        address[] calldata owners
    ) external;
    function rescueToken(address token, uint256 amount) external;
    function setDelegateApproval(address delegate, bool isApproved) external;
    function shiftBalance(uint256 amount, bool fromLent) external returns (uint256 amountWithdrawn, bool lendingBalanceUsed);
    function transfer(
        uint256 amount,
        bool forceLentRedemption,
        bool willLend,
        address recipient
    ) external returns (uint256 amountTransferred, bool lendingBalanceUsed);
    function transferFor(
        uint256 amount,
        bool forceLentRedemption,
        bool willLend,
        address recipient,
        address owner
    ) external returns (uint256 amountTransferred, bool lendingBalanceUsed);
    function updateRewardDelegation() external;
    function withdraw(
        uint256 amount,
        bool forceLentRedemption,
        address recipient
    ) external returns (uint256 amountWithdrawn, bool lendingBalanceUsed);
    function withdrawFor(
        uint256 amount,
        bool forceLentRedemption,
        address recipient,
        address owner
    ) external returns (uint256 amountWithdrawn, bool lendingBalanceUsed);
}
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NativeTimeVault is Ownable, ReentrancyGuard {
    address public nftAddress;
    uint256 public nftPrice;
    uint256 public nftLimitPerAddress;
    uint256 public activeFunds;
    uint256 public totalFunds;
    uint256 public yieldedFunds;
    uint256 public activeYieldedFunds;
    address public tokenAddress;
    address public partnerPool;

    struct Vault {
        uint256 ethAmount;
        uint256 nftAmount;
    }
    mapping(address => Vault) public vaults;
    mapping(uint256 => bool) public nftClaimed;
    uint256 public joiningPeriod;
    uint256 public claimingPeriod;

    constructor(
        uint256 _nftPrice,
        uint256 _nftLimitPerAddress,
        address initialOwner,
        // address _tokenAddress,
        uint256 _nftLimit,
        uint256 _joiningPeriod,
        uint256 _claimingPeriod,
        address _partnerPool
    ) Ownable(initialOwner) {
        nftPrice = _nftPrice;
        nftLimitPerAddress = _nftLimitPerAddress;
        // tokenAddress = _tokenAddress;
        nftAddress = address(new TimeNft(address(this), _nftLimit));
        joiningPeriod = _joiningPeriod;
        claimingPeriod = _claimingPeriod;
        partnerPool=_partnerPool;
    }

    event ClaimedNft(uint256 indexed tokenId, address indexed claimer, uint256 claimedAmount);
    event JoinVault(address indexed joiner, uint256 nftAmount);

    function joinVault(uint256 _nftAmount) public payable nonReentrant {
        require(getState() == 0, "Not in joining period");
        require(getNftCount() + _nftAmount <= TimeNft(nftAddress).nftLimit(), "Exceeds NFT limit");
        require(_nftAmount <= nftLimitPerAddress, "Exceeds per-address limit");
        // require(msg.value == _nftAmount * nftPrice, "Incorrect ETH amount");
    uint totalPrice=_nftAmount*nftPrice;
        IUniversalBalance poolContract=IUniversalBalance(partnerPool);
        IERC20 token=IERC20(poolContract.underlying());
        require(token.transferFrom(msg.sender, address(this),totalPrice ),"token transfer failed");
        Vault storage userVault = vaults[msg.sender];
        require(userVault.nftAmount + _nftAmount <= nftLimitPerAddress, "NFT limit exceeded");
        token.approve(partnerPool, totalPrice);
        poolContract.deposit(totalPrice,false);

        TimeNft(nftAddress).safeMint(msg.sender, _nftAmount);
        userVault.ethAmount += totalPrice;
        userVault.nftAmount += _nftAmount;
        activeFunds += totalPrice;
        totalFunds += totalPrice;

        emit JoinVault(msg.sender, _nftAmount);
    }

    // function withdrawAllFunds(address payable receiver) public onlyOwner {
    //     require(activeFunds > 0, "No funds to withdraw");
    //     receiver.transfer(activeFunds);
    //     activeFunds = 0;
    // }

    // function depositExternalFunds() public payable onlyOwner {
    //     yieldedFunds += msg.value;
    //     activeYieldedFunds += msg.value;
    // }

    function automateCoumpounding() public{
        // require(getState()==1);
        IUniversalBalance poolContract=IUniversalBalance(partnerPool);
        IERC20 token=IERC20(poolContract.underlying());
        (uint sittingBalance, uint lentBalance)=poolContract.userBalances(address(this));
        (uint amountWithdrawn,)= poolContract.withdraw(sittingBalance+lentBalance, true, address(this));
        yieldedFunds=amountWithdrawn;
        activeYieldedFunds=amountWithdrawn;
        token.approve(partnerPool, amountWithdrawn);
        poolContract.deposit(yieldedFunds,false);

    }

    function claimBack() public nonReentrant {
        require(getState() == 2, "Claiming not active");
        uint256 nftBalance = TimeNft(nftAddress).balanceOf(msg.sender);
        require(nftBalance > 0, "No NFTs to claim");

        for (uint256 i = 0; i < nftBalance; i++) {
            uint256 tokenId = TimeNft(nftAddress).tokenOfOwnerByIndex(msg.sender, 0);
            if (!nftClaimed[tokenId]) {
                uint256 amountToClaim = yieldedFunds / getNftCount();
                // payable(msg.sender).transfer(amountToClaim);
                IUniversalBalance poolContract=IUniversalBalance(partnerPool);
        // IERC20 token=IERC20(poolContract.underlying());

        
        (uint amountWithdrawn,)= poolContract.withdraw(amountToClaim, true, msg.sender);
                activeYieldedFunds -= amountWithdrawn;
                nftClaimed[tokenId] = true;
                TimeNft(nftAddress).burn(tokenId);
                emit ClaimedNft(tokenId, msg.sender, amountWithdrawn);
            }
        }
    }

    function getState() public view returns (uint256) {
        if (block.timestamp < joiningPeriod) return 0;
        if (block.timestamp < claimingPeriod) return 1;
        return 2;
    }

    function getNftCount() public view returns (uint256) {
        return TimeNft(nftAddress).tokenIdCounter();
    }
}

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Pausable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";


contract TimeNft is
    ERC721,
    ERC721Pausable,
    ERC721Enumerable,
    Ownable,
    ERC721Burnable
{
    uint256 public tokenIdCounter = 0;
    string private _baseTokenURI;
    address public vaultAddress;
    uint256 public nftLimit;

    constructor(
        address initialOwner,
        // string memory baseURI,
        uint256 _nftLimit
    ) ERC721("TimeNft", "TNFT") Ownable(initialOwner) {
        _baseTokenURI = "https://plum-imaginative-guan-725.mypinata.cloud/ipfs/bafkreihetnwdfbtwz67754zldog4x73f2sqv2supmpy72eg7rgmj2izvb4";

        nftLimit = _nftLimit;
    }

    function setVaultAddress(address _vaultAddress) external onlyOwner {
        vaultAddress = _vaultAddress;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    function nftCount() public view returns (uint256 _nftCount) {
        return tokenIdCounter;
    }

    function tokenURI(uint256) public view override returns (string memory) {
        return _baseTokenURI;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function safeMint(address to, uint256 amount) public {
        require(nftLimit >= tokenIdCounter + amount);
        require(
            msg.sender == owner() || msg.sender == vaultAddress,
            "can mint"
        );
        for (uint256 i = 0; i < amount; i++) {
            tokenIdCounter++;
            uint256 tokenId = tokenIdCounter;
            _safeMint(to, tokenId);
        }
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    )
        internal
        override(ERC721, ERC721Enumerable, ERC721Pausable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
