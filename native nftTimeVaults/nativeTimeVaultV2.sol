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
// contract nativeTimeVault is Ownable, ReentrancyGuard {
contract nativeTimeVault is Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    address public nftAddress;
    uint256 public nftPrice;
    uint256 public nftLimitPerAddress;
    uint256 public activeFunds;
    uint256 public totalFunds;
    uint256 public yieldedFunds;
    uint256 public activeYieldedFunds;
    address payable public PartnerContract;
    uint public platformFees=100;//100 -> 1%
    uint public totalFeeCollected;

    struct Vault {
        uint256 ethAmount;
        uint256 nftAmount;
    }
    mapping(address => Vault) public vaults;
    mapping(uint256 => bool) public nftClaimed;
    uint256 public joiningPeriod;
    uint256 public claimingPeriod;
    uint public CompoundCounter;

    // constructor(
    //     uint256 _nftPrice,
    //     uint256 _nftLimitPerAddress,
    //     address initialOwner,
    //     uint256 _nftLimit,
    //     uint256 _joiningPeriod,
    //     uint256 _claimingPeriod,
    //     address payable _PartnerContract
    // ) Ownable(initialOwner) {
    //     nftPrice = _nftPrice;
    //     nftLimitPerAddress = _nftLimitPerAddress;
    //     TimeNft nftContract = new TimeNft(address(this), _nftLimit,initialOwner);
    //     nftAddress = address(nftContract);
    //     joiningPeriod = _joiningPeriod;
    //     claimingPeriod = _claimingPeriod;
    //     PartnerContract = _PartnerContract;
    // }

    function initialize(
        uint256 _nftPrice,
        uint256 _nftLimitPerAddress,
        address initialOwner,
        uint256 _nftLimit,
        uint _joiningPeriod,
        uint _claimingPeriod,
        address payable _PartnerContract
    ) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        nftPrice = _nftPrice;
        nftLimitPerAddress = _nftLimitPerAddress;
        TimeNft nftContract = new TimeNft(address(this), _nftLimit,initialOwner);
        nftAddress = address(nftContract);
        joiningPeriod = _joiningPeriod;
        claimingPeriod = _claimingPeriod;
        PartnerContract = _PartnerContract;
    }

    // event claimedNft(
    //     uint256 indexed tokenId,
    //     address indexed _claimer,
    //     uint256 _claimedAmount
    // );
    // event joinVaultEvent(address indexed _joiner, uint256 _nftAmount);

    function joinVault(uint256 _nftAmount) public payable {
        require(getState() == 0, "Waiting period");
        require(
            getNftCount() + _nftAmount <= TimeNft(nftAddress).nftLimit(),
            "Exceeds NFT limit"
        );
        require(_nftAmount <= nftLimitPerAddress, "Cannot mint more");
        require(msg.value == _nftAmount * nftPrice, "Incorrect ETH amount");

        Vault storage tempVault = vaults[msg.sender];
        ICEther Pcontract = ICEther(PartnerContract);
        require(
            tempVault.nftAmount + _nftAmount <= nftLimitPerAddress,
            " limit exceeded"
        );
        Pcontract.mint{value: msg.value}();

        TimeNft(nftAddress).safeMint(msg.sender, _nftAmount);
        tempVault.ethAmount += msg.value;
        tempVault.nftAmount += _nftAmount;
        activeFunds += msg.value;
        totalFunds += msg.value;
        // emit joinVaultEvent(msg.sender, _nftAmount);
    }
    function changeTimePeriod(uint _joiningPeriod,uint _claimingPeriod)onlyOwner external{
        joiningPeriod=_joiningPeriod;
        claimingPeriod=_claimingPeriod;
    }

    function automateCoumpounding() public {
        // require(getState()==1);
        ICEther Pcontract = ICEther(PartnerContract);
        uint256 sdrMon = Pcontract.balanceOf(address(this));


        uint256 balanceBefore = address(this).balance;
        // Pcontract.redeem(sdrMon);
        (bool success, ) = address(Pcontract).call{gas: 500000}(
            abi.encodeWithSignature("redeem(uint256)", sdrMon)
        );
        require(success, "Redemption failed");
        uint256 redeemedAmount = address(this).balance - balanceBefore;
        yieldedFunds = redeemedAmount;
        activeYieldedFunds = redeemedAmount;
        Pcontract.mint{value: redeemedAmount}();
        CompoundCounter++;
    }
    function changeFees(uint _fee)external onlyOwner{
        platformFees=_fee;
    }
    function collectFee()external onlyOwner{
        payable(msg.sender).transfer(address(this).balance);
        
    }
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    function withdrawAllFunds(address payable receiver) public onlyOwner {
        require(activeFunds > 0, "No funds to withdraw");
        receiver.transfer(address(this).balance);
        activeFunds = 0;
        activeYieldedFunds=0;
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
            uint256 _tknId = TimeNft(nftAddress).tokenOfOwnerByIndex(
                msg.sender,
                0
            );
            if (!nftClaimed[_tknId]) {
                uint256 total = (yieldedFunds) / getNftCount();
                uint fees=(total * platformFees) / 10000;
                uint amountToClaim=total-fees;
                totalFeeCollected+=fees;

                ICEther Pcontract = ICEther(PartnerContract);
                (uint256 sdrMon, , , ) = Pcontract.getAccountSnapshot(
                    address(this)
                );

                uint256 balanceBefore = address(this).balance;
                (bool success, ) = address(Pcontract).call{gas: 500000}(
                    abi.encodeWithSignature("redeem(uint256)", sdrMon)
                );
                require(success, "Redemption failed");
                uint256 redeemedAmount = address(this).balance - balanceBefore;

                payable(msg.sender).transfer(amountToClaim);
                activeYieldedFunds -= amountToClaim;
                nftClaimed[_tknId] = true;
                TimeNft(nftAddress).burn(_tknId);
                Pcontract.mint{value: redeemedAmount - amountToClaim}();
                // emit claimedNft(_tknId, msg.sender, amountToClaim);
            }
        }
    }
    function   pauseNft()external onlyOwner{
        TimeNft(nftAddress).pause();
    } 
    function canCompound() external view returns (bool canExec, bytes memory execPayload) {
        
        canExec = getState() == 1 ? true : false;

       
        execPayload = abi.encodeWithSelector(this.automateCoumpounding.selector);
    }

    function getState() public view returns (uint256) {
        if (block.timestamp < joiningPeriod) {
            return 0;
        } else if (
            block.timestamp > joiningPeriod && block.timestamp < claimingPeriod
        ) {
            return 1;
        } else {
            return 2;
        }
    }

    function getNftCount() public view returns (uint256 _nftAmount) {
        return TimeNft(nftAddress).tokenIdCounter();
    }

    receive() external payable {}

    // function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Pausable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

contract TimeNft is
    ERC721,
    ERC721Pausable,
    ERC721Enumerable,
    Ownable,
    ERC721Burnable,IERC2981
{
    uint256 public tokenIdCounter = 0;
    string private _baseTokenURI;
    address public vaultAddress;
    uint256 public nftLimit;
    address public royaltyRecipient;
    uint256 public royaltyBps=500; 

    constructor(
        address initialOwner,
        // string memory baseURI,
        uint256 _nftLimit,
        address _royaltyRecipient
    ) ERC721("TimeNft", "TNFT") Ownable(initialOwner) {
        _baseTokenURI = "https://plum-imaginative-guan-725.mypinata.cloud/ipfs/bafkreidcofzaolcmelvmsh2zezqltq6ouytszk6bubuaidttssoqtfvymy";

        nftLimit = _nftLimit;
        royaltyRecipient=_royaltyRecipient;
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
    function royaltyInfo(uint256, uint256 salePrice)
        external
        view
        returns (address, uint256)
    {
        return (royaltyRecipient, (salePrice * royaltyBps) / 10000);
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
        override(ERC721, ERC721Enumerable,IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }
}

interface ICEther {
    /*** User Interface ***/
    function mint() external payable;

    function redeem(uint256 redeemTokens) external returns (uint256);

    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

    function borrow(uint256 borrowAmount) external returns (uint256);

    function repayBorrow() external payable;

    function repayBorrowBehalf(address borrower) external payable;

    function liquidateBorrow(address borrower, address cTokenCollateral)
        external
        payable;

    function _addReserves() external payable returns (uint256);

    /*** Admin Functions ***/
    function _setPendingAdmin(address payable newPendingAdmin)
        external
        returns (uint256);

    function _acceptAdmin() external returns (uint256);

    function _setComptroller(address newComptroller) external returns (uint256);

    function _setReserveFactor(uint256 newReserveFactorMantissa)
        external
        returns (uint256);

    function _reduceReserves(uint256 reduceAmount) external returns (uint256);

    function _setInterestRateModel(address newInterestRateModel)
        external
        returns (uint256);

    function _setDiscountRate(uint256 discountRateMantissa)
        external
        returns (uint256);

    function _syncUnderlyingBalance() external;

    /*** Token Operations ***/
    function transfer(address dst, uint256 amount) external returns (bool);

    function transferFrom(
        address src,
        address dst,
        uint256 amount
    ) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    /*** View Functions ***/
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function balanceOfUnderlying(address owner) external view returns (uint256);

    function getAccountSnapshot(address account)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        );

    function borrowRatePerBlock() external view returns (uint256);

    function supplyRatePerBlock() external view returns (uint256);

    function borrowBalanceStored(address account)
        external
        view
        returns (uint256);

    function exchangeRateStored() external view returns (uint256);

    function getCash() external view returns (uint256);

    function accrualBlockTimestamp() external view returns (uint256);

    function isDeprecated() external view returns (bool);

    function isCToken() external pure returns (bool);

    function isCEther() external pure returns (bool);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function admin() external view returns (address payable);

    function pendingAdmin() external view returns (address payable);

    function comptroller() external view returns (address);

    function interestRateModel() external view returns (address);

    function initialExchangeRateMantissa() external view returns (uint256);

    function reserveFactorMantissa() external view returns (uint256);

    function borrowIndex() external view returns (uint256);

    function totalBorrows() external view returns (uint256);

    function totalReserves() external view returns (uint256);

    function underlying() external view returns (address);

    function discountRateMantissa() external view returns (uint256);

    function underlyingBalance() external view returns (uint256);

    /*** Calculations ***/
    function liquidateCalculateSeizeTokens(
        address cTokenCollateral,
        uint256 actualRepayAmount
    )
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        );

    /*** State-changing functions that return values ***/
    function totalBorrowsCurrent() external returns (uint256);

    function borrowBalanceCurrent(address account) external returns (uint256);

    function exchangeRateCurrent() external returns (uint256);

    function accrueInterest() external returns (uint256);

    /*** Events ***/
    event AccrueInterest(
        uint256 cashPrior,
        uint256 interestAccumulated,
        uint256 borrowIndex,
        uint256 totalBorrows
    );
    event Mint(address minter, uint256 mintAmount, uint256 mintTokens);
    event Redeem(address redeemer, uint256 redeemAmount, uint256 redeemTokens);
    event Borrow(
        address borrower,
        uint256 borrowAmount,
        uint256 accountBorrows,
        uint256 totalBorrows
    );
    event RepayBorrow(
        address payer,
        address borrower,
        uint256 repayAmount,
        uint256 accountBorrows,
        uint256 totalBorrows
    );
    event LiquidateBorrow(
        address liquidator,
        address borrower,
        uint256 repayAmount,
        address cTokenCollateral,
        uint256 seizeTokens
    );
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);
    event NewAdmin(address oldAdmin, address newAdmin);
    event NewComptroller(address oldComptroller, address newComptroller);
    event NewMarketInterestRateModel(
        address oldInterestRateModel,
        address newInterestRateModel
    );
    event NewReserveFactor(
        uint256 oldReserveFactorMantissa,
        uint256 newReserveFactorMantissa
    );
    event ReservesAdded(
        address benefactor,
        uint256 addAmount,
        uint256 newTotalReserves
    );
    event ReservesReduced(
        address admin,
        uint256 reduceAmount,
        uint256 newTotalReserves
    );
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );
    event NewDiscountRate(
        uint256 oldDiscountRateMantissa,
        uint256 newDiscountRateMantissa
    );

    receive() external payable;
}
