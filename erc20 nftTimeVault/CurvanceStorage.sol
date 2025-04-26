// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CurvanceStorage {
    // All original storage variables
    address public nftAddress;
    uint256 public nftPrice;
    uint256 public nftLimitPerAddress;
    uint256 public activeFunds;
    uint256 public totalFunds;
    uint256 public yieldedFunds;
    uint256 public activeYieldedFunds;
    address public PartnerContract;
    address public erc20Address;
    uint256 public platformFees = 100;
    uint256 public totalFeeCollected;
    uint256 public joiningPeriod;
    uint256 public claimingPeriod;
    uint256 public CompoundCounter;

    struct Vault {
        uint256 ethAmount;
        uint256 nftAmount;
    }
    
    mapping(address => Vault) public vaults;
    mapping(uint256 => bool) public nftClaimed;
    
    address public logicContract;
    
    modifier onlyLogic() {
        require(msg.sender == logicContract, "Only logic contract");
        _;
    }

    // Setters for all state modifications
    function setLogicContract(address _logicContract) external {
        require(logicContract == address(0), "Logic already set");
        logicContract = _logicContract;
    }
    
    function setVault(address user, uint256 ethAmount, uint256 nftAmount) external onlyLogic {
        vaults[user] = Vault(ethAmount, nftAmount);
    }
    
    function setFunds(uint256 _active, uint256 _total) external onlyLogic {
        activeFunds = _active;
        totalFunds = _total;
    }
    
    function setYieldedFunds(uint256 _yielded, uint256 _activeYielded) external onlyLogic {
        yieldedFunds = _yielded;
        activeYieldedFunds = _activeYielded;
    }
    
    function setFeeCollected(uint256 _fee) external onlyLogic {
        totalFeeCollected += _fee;
    }
    
    function setNftClaimed(uint256 tokenId, bool _claimed) external onlyLogic {
        nftClaimed[tokenId] = _claimed;
    }
    
    function setCompoundCounter(uint256 _count) external onlyLogic {
        CompoundCounter = _count;
    }
    
    function setTimePeriod(uint256 _joining, uint256 _claiming) external onlyLogic {
        joiningPeriod = _joining;
        claimingPeriod = _claiming;
    }
    
    function setPlatformFees(uint256 _fee) external onlyLogic {
        platformFees = _fee;
    }
    
    function setNftAddress(address _nftAddress) external onlyLogic {
        nftAddress = _nftAddress;
    }
}