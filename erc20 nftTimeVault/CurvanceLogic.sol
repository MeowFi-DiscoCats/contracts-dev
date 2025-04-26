// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./CurvanceStorage.sol";
// import "./TimeNft.sol";
import "./curvanceTimeVaultV3.sol";

contract CurvanceLogic is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    CurvanceStorage public storageContract;
    
    event FundsWithdrawn(address indexed receiver);
    event FeesCollected(uint256 amount);
    event ExternalFundsDeposited(uint256 amount);

    function initialize(address _storageAddress, address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __ReentrancyGuard_init();
        storageContract = CurvanceStorage(_storageAddress);
    }

    // ========== ALL ORIGINAL FUNCTIONS ==========
    
     function joinVault(uint256 _nftAmount) public {
        require(getState() == 0, "Waiting period");
        require(
            getNftCount() + _nftAmount <= (TimeNft(storageContract.nftAddress())).nftLimit(),
            "Exceeds NFT limit"
        );
        require(_nftAmount <= storageContract.nftLimitPerAddress(), "Cannot mint more");
        
        IERC20 erc20 = IERC20(storageContract.erc20Address());
        uint256 amount = _nftAmount * storageContract.nftPrice();
        
        require(erc20.balanceOf(msg.sender) >= amount, "insuffBalance");
        require(erc20.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        EnhancedERC4626(storageContract.PartnerContract()).mint(amount, address(this));
        
        (uint256 ethAmt, uint256 nftAmt) = storageContract.vaults(msg.sender);
        require(nftAmt + _nftAmount <= storageContract.nftLimitPerAddress(), "Limit exceeded");

        TimeNft(storageContract.nftAddress()).safeMint(msg.sender, _nftAmount);
        storageContract.setVault(msg.sender, ethAmt + amount, nftAmt + _nftAmount);
        storageContract.setFunds(storageContract.activeFunds() + amount, storageContract.totalFunds() + amount);
    }
    function automateCoumpounding() public {
        EnhancedERC4626 pContract = EnhancedERC4626(storageContract.PartnerContract());
        uint256 stakedBal = pContract.balanceOf(address(this));
        require(pContract.redeem(stakedBal, address(this)), "Redemption failed");
        
        uint256 redeemedAmount = IERC20(storageContract.erc20Address()).balanceOf(address(this));
        storageContract.setYieldedFunds(redeemedAmount, redeemedAmount);
        pContract.mint(redeemedAmount, address(this));
        storageContract.setCompoundCounter(storageContract.CompoundCounter() + 1);
    }

    function claimBack() public nonReentrant {
        require(getState() == 2, "Wait for claim period");
        uint256 balance = TimeNft(storageContract.nftAddress()).balanceOf(msg.sender);
        require(balance > 0, "No NFTs");

        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = TimeNft(storageContract.nftAddress()).tokenOfOwnerByIndex(msg.sender, 0);
            if (!storageContract.nftClaimed(tokenId)) {
                uint256 total = storageContract.yieldedFunds() / getNftCount();
                uint256 fees = (total * storageContract.platformFees()) / 10000;
                uint256 claimAmount = total - fees;
                
                storageContract.setFeeCollected(fees);
                EnhancedERC4626 pContract = EnhancedERC4626(storageContract.PartnerContract());
                pContract.redeem(pContract.convertToAssets(claimAmount), msg.sender);

                storageContract.setYieldedFunds(storageContract.yieldedFunds(), storageContract.activeYieldedFunds() - claimAmount);
                storageContract.setNftClaimed(tokenId, true);
                TimeNft(storageContract.nftAddress()).burn(tokenId);
            }
        }
    }

    function changeTimePeriod(uint256 _joiningPeriod, uint256 _claimingPeriod) external onlyOwner {
        storageContract.setTimePeriod(_joiningPeriod, _claimingPeriod);
    }

    function changeFees(uint256 _fee) external onlyOwner {
        storageContract.setPlatformFees(_fee);
    }

    function collectFee() external onlyOwner {
        uint256 total = storageContract.yieldedFunds();
        uint256 fees = (total * storageContract.platformFees()) / 10000;
        storageContract.setFeeCollected(fees);

        EnhancedERC4626 pContract = EnhancedERC4626(storageContract.PartnerContract());
        pContract.redeem(pContract.convertToAssets(fees), msg.sender);

        storageContract.setYieldedFunds(
            storageContract.yieldedFunds(),
            storageContract.activeYieldedFunds() - fees
        );
        emit FeesCollected(fees);
    }

    function withdrawAllFunds(address payable receiver) public onlyOwner {
        EnhancedERC4626 pContract = EnhancedERC4626(storageContract.PartnerContract());
        uint256 stakedBal = pContract.balanceOf(address(this));
        require(pContract.redeem(stakedBal, address(this)), "Redemption failed");
        
        storageContract.setFunds(0, 0);
        storageContract.setYieldedFunds(0, 0);
        emit FundsWithdrawn(receiver);
    }

    function depositExternalFunds() public payable onlyOwner {
        storageContract.setYieldedFunds(
            storageContract.yieldedFunds() + msg.value,
            storageContract.activeYieldedFunds() + msg.value
        );
        emit ExternalFundsDeposited(msg.value);
    }

    function pauseNft() external onlyOwner {
        TimeNft(storageContract.nftAddress()).pause();
    }

    function canCompound() external view returns (bool canExec, bytes memory execPayload) {
        canExec = getState() == 1;
        execPayload = abi.encodeWithSelector(this.automateCoumpounding.selector);
    }

    function getState() public view returns (uint256) {
        if (block.timestamp < storageContract.joiningPeriod()) return 0;
        if (block.timestamp < storageContract.claimingPeriod()) return 1;
        return 2;
    }

    function getNftCount() public view returns (uint256) {
        return TimeNft(storageContract.nftAddress()).tokenIdCounter();
    }

    receive() external payable {}
}