// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract TimeVaultV1 is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    address public tokenAddress;
    address public nftAddress;
    uint256 public tokenDecimals;
    uint256 public nftPrice;
    uint256 public nftLimitPerAddress;
    uint256 public activeFunds;
    uint256 public totalFunds;
    uint256 public yieldedFunds;
    uint256 public activeYeildedFunds;

    struct Vault {
        uint256 tokenAmount;
        uint256 nftAmount;
    }
    mapping(address => Vault) public vaults;
    mapping(uint256 => bool) public nftClaimed;
    uint256 public joiningPeriod;
    uint256 public claimingPeriod;

    // constructor(
    //     address initialOwner,
    //     // uint256 _nftPrice,
    //     // uint256 _nftLimitPerAddress,
    //     address _tokenAddress,
    //     address _nftAddress
    // ) Ownable(initialOwner) {
    //     nftPrice = 1e18; //_nftPrice;
    //     nftLimitPerAddress = 10; //_nftLimitPerAddress;
    //     tokenAddress = _tokenAddress;
    //     nftAddress = _nftAddress;
    // }
    function initialize(
        
        uint256 _nftPrice,
        uint256 _nftLimitPerAddress,
        address initialOwner,
        address _tokenAddress,
        uint256 _nftLimit,
        uint _joiningPeriod,
        uint _claimingPeriod
    ) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        nftPrice = _nftPrice; //_nftPrice;
        nftLimitPerAddress = _nftLimitPerAddress; //_nftLimitPerAddress;
        tokenAddress = _tokenAddress;
        TimeNft nftContract = new TimeNft(address(this), _nftLimit);
        nftAddress= address(nftContract);
        joiningPeriod=_joiningPeriod;
        claimingPeriod=_claimingPeriod;
    }

    event claimedNft(
        uint256 indexed tokenId,
        address indexed _claimer,
        uint256 _claimedAmount
    );
    event joinVaultEvent(address indexed _joiner, uint256 _nftamount);

    function setNftPrice(uint256 _nftPrice) external onlyOwner{
        nftPrice = _nftPrice;
    }
    function setNftLimitPerAddress(uint256 _nftLimitPerAddress) external onlyOwner{
        nftLimitPerAddress = _nftLimitPerAddress;
    }
    function setTimePeriod(uint256 _joiningPeriod, uint256 _claim)public onlyOwner{
        joiningPeriod=_joiningPeriod*86400+block.timestamp;
        claimingPeriod = _claim*86400+joiningPeriod;
    }

    function setTokenAddress(address _tokenAddress, uint256 _tokenDecimals)
        public
        onlyOwner
    {
        tokenAddress = _tokenAddress;
        tokenDecimals = _tokenDecimals;
    }

    function joinVault(uint256 _nftAmount) public {
        require(getState()==0,"waiting period");
        require(getNftCount() <= TimeNft(nftAddress).nftLimit());
        require(_nftAmount <= nftLimitPerAddress, "cant mint more");
        // require(_tokenAmount >= _nftAmount * nftPrice, "sent less");
        Vault storage tempVault = vaults[msg.sender];
        require(tempVault.nftAmount + _nftAmount <= nftLimitPerAddress);
        uint256 tknAmnt = _nftAmount * nftPrice;
        require(
            IERC20(tokenAddress).transferFrom(
                msg.sender,
                address(this),
                tknAmnt
            ),
            "transaction failed"
        );
        TimeNft(nftAddress).safeMint(msg.sender, _nftAmount);
        tempVault.tokenAmount += tknAmnt;
        tempVault.nftAmount += _nftAmount;
        activeFunds += tknAmnt;
        totalFunds += tknAmnt;
        emit joinVaultEvent(msg.sender, _nftAmount);
    }

    function withdrawAllFunds(address receiver) public onlyOwner {
        require(
            IERC20(tokenAddress).transfer(receiver, activeFunds),
            "transaction failed"
        );
        activeFunds = 0;
    }

    function getNftCount() public view returns (uint256 _nftAmount) {
        return TimeNft(nftAddress).tokenIdCounter();
    }

    function yieldGenerated() external view returns (uint256 _amount) {
        return yieldedFunds - totalFunds;
    }

    // function yieldGeneratedPercentage()
    //     external
    //     view
    //     returns (uint256 _percentage)
    // {
    //     if (totalFunds == 0) return 0;
    //     return ((yieldedFunds - totalFunds) * 100) / totalFunds;
    // }

    function depositExternalFunds(uint256 _amount) public {
        require(
            IERC20(tokenAddress).transferFrom(
                msg.sender,
                address(this),
                _amount
            ),
            "transaction failed"
        );
        yieldedFunds += _amount;
        activeYeildedFunds += _amount;
    }
    function getState()public view returns (uint){
        if(block.timestamp<joiningPeriod){
            return 0;
        }else if(block.timestamp>joiningPeriod && block.timestamp<claimingPeriod){
            return 1;
        }else {
            return 2;
        }
    }

    function claimBack() public nonReentrant  {
        // Vault storage tempVault=vaults[msg.sender];
        // require(_nftAmount<=tempVault.nftAmount,"cant claimmore than minted");
        require(getState()==2,"wait for period");
        uint256 _nftBalance = TimeNft(nftAddress).balanceOf(msg.sender);
        require(_nftBalance > 0, "no NFTs");
        require(
            TimeNft(nftAddress).isApprovedForAll(msg.sender, address(this))
        );
        // require(_nftBalance>=_nftAmount);
        for (uint256 i = 0; i < _nftBalance; i++) {
            uint256 _tknId = TimeNft(nftAddress).tokenOfOwnerByIndex(
                msg.sender,
                0
            );
            if (nftClaimed[_tknId] == false) {
                uint256 amountTobeClaim = (yieldedFunds) / getNftCount();
                require(
                    IERC20(tokenAddress).transfer(msg.sender, amountTobeClaim),
                    "transaction failed"
                );
                // tempVault.nftAmount=tempVault.nftAmount-_nftAmount;
                activeYeildedFunds = activeYeildedFunds - amountTobeClaim;
                nftClaimed[_tknId] = true;

                TimeNft(nftAddress).burn(_tknId);
                emit claimedNft(_tknId, msg.sender, amountTobeClaim);
            }
        }
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    function upgrade(address newImplementation) public onlyOwner {
        upgradeToAndCall(newImplementation, "");
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
