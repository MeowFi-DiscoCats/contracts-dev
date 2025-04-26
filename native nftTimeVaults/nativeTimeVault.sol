// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
//Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable
contract curvanceTimeVault is Ownable ,ReentrancyGuard {
    address public nftAddress;
    uint256 public nftPrice;
    uint256 public nftLimitPerAddress;
    uint256 public activeFunds;
    uint256 public totalFunds;
    uint256 public yieldedFunds;
    uint256 public activeYieldedFunds;

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
        uint256 _nftLimit,
        uint _joiningPeriod,
        uint _claimingPeriod
    ) Ownable(initialOwner) {
    nftPrice = _nftPrice;
        nftLimitPerAddress = _nftLimitPerAddress;
        TimeNft nftContract = new TimeNft(address(this), _nftLimit);
        nftAddress = address(nftContract);
        joiningPeriod = _joiningPeriod;
        claimingPeriod = _claimingPeriod;
    }

    // function initialize(
    //     uint256 _nftPrice,
    //     uint256 _nftLimitPerAddress,
    //     address initialOwner,
    //     uint256 _nftLimit,
    //     uint _joiningPeriod,
    //     uint _claimingPeriod
    // ) public initializer {
    //     __Ownable_init(initialOwner);
    //     __UUPSUpgradeable_init();
    //     nftPrice = _nftPrice;
    //     nftLimitPerAddress = _nftLimitPerAddress;
    //     TimeNft nftContract = new TimeNft(address(this), _nftLimit);
    //     nftAddress = address(nftContract);
    //     joiningPeriod = _joiningPeriod;
    //     claimingPeriod = _claimingPeriod;
    // }

    event claimedNft(uint256 indexed tokenId, address indexed _claimer, uint256 _claimedAmount);
    event joinVaultEvent(address indexed _joiner, uint256 _nftAmount);

    function joinVault(uint256 _nftAmount) public payable {
        require(getState() == 0, "Waiting period");
        require(getNftCount() + _nftAmount <= TimeNft(nftAddress).nftLimit(), "Exceeds NFT limit");
        require(_nftAmount <= nftLimitPerAddress, "Cannot mint more");
        require(msg.value == _nftAmount * nftPrice, "Incorrect ETH amount");

        Vault storage tempVault = vaults[msg.sender];
        require(tempVault.nftAmount + _nftAmount <= nftLimitPerAddress, "NFT limit exceeded");

        TimeNft(nftAddress).safeMint(msg.sender, _nftAmount);
        tempVault.ethAmount += msg.value;
        tempVault.nftAmount += _nftAmount;
        activeFunds += msg.value;
        totalFunds += msg.value;
        emit joinVaultEvent(msg.sender, _nftAmount);
    }

    function withdrawAllFunds(address payable receiver) public onlyOwner {
        require(activeFunds > 0, "No funds to withdraw");
        receiver.transfer(activeFunds);
        activeFunds = 0;
    }

    function depositExternalFunds() public payable onlyOwner {
        yieldedFunds += msg.value;
        activeYieldedFunds += msg.value;
    }

    function claimBack() public nonReentrant {
        require(getState() == 2, "Wait for claim period");
        uint256 _nftBalance = TimeNft(nftAddress).balanceOf(msg.sender);
        require(_nftBalance > 0, "No NFTs");

        for (uint256 i = 0; i < _nftBalance; i++) {
            uint256 _tknId = TimeNft(nftAddress).tokenOfOwnerByIndex(msg.sender, 0);
            if (!nftClaimed[_tknId]) {
                uint256 amountToClaim = (yieldedFunds) / getNftCount();
                payable(msg.sender).transfer(amountToClaim);
                activeYieldedFunds -= amountToClaim;
                nftClaimed[_tknId] = true;
                TimeNft(nftAddress).burn(_tknId);
                emit claimedNft(_tknId, msg.sender, amountToClaim);
                
            }
        }
    }

    function getState() public view returns (uint) {
        if (block.timestamp < joiningPeriod) {
            return 0;
        } else if (block.timestamp > joiningPeriod && block.timestamp < claimingPeriod) {
            return 1;
        } else {
            return 2;
        }
    }

    function getNftCount() public view returns (uint256 _nftAmount) {
        return TimeNft(nftAddress).tokenIdCounter();
    }

    // function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
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
