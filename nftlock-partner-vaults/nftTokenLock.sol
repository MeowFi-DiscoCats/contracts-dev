// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract PartnerLock is Ownable {
    struct Vault {
        address partner;
        uint256 nftCount;
        uint256[] nftIds;
        uint256 tokenCount;
    }
    address public erc20Address;
    address public erc721Address;
    mapping(address => Vault) public vaults;
    uint256 public joiningPeriod;
    uint256 public claimingPeriod;
    uint256 public totalfunds;
    uint256 public partnerCount;
    uint256 public afterYieldFunds;

    constructor(
        address initialOwner,
        address _erc20Address,
        address _erc721Address,
        uint256 _joiningPeriod,
        uint256 _claimingPeriod
    ) Ownable(initialOwner) {
        erc20Address = _erc20Address;
        erc721Address = _erc721Address;
        joiningPeriod = block.timestamp + (_joiningPeriod * 86400);
        claimingPeriod = joiningPeriod + (_claimingPeriod * 86400);
    }

    event VaultJoined(
        address indexed partner,
        uint256 tokenAmount,
        uint256[] nftIds
    );
    event Claimed(
        address indexed partner,
        uint256 tokenAmount,
        uint256[] nftIds
    );

    function joinVault(uint256 _erc20Count, uint256[] memory _erc721TokenId)
        public
    {
        // require(block.timestamp<=joiningPeriod,"joining period expired");
        require(
            IERC20(erc20Address).balanceOf(msg.sender) >= _erc20Count,
            "not enough erc20"
        );
        require(
            IERC721(erc721Address).balanceOf(msg.sender) >=
                _erc721TokenId.length,
            "not enough erc721"
        );
        Vault storage temp = vaults[msg.sender];
        if (temp.tokenCount == 0 && temp.nftCount == 0) {
            partnerCount++;
        }
        temp.partner = msg.sender;

        require(
            IERC20(erc20Address).transferFrom(
                msg.sender,
                address(this),
                _erc20Count
            ),
            "ERC20 transfer failed"
        );

        temp.tokenCount += _erc20Count;
        totalfunds += _erc20Count;
        for (uint256 i = 0; i < _erc721TokenId.length; i++) {
            IERC721(erc721Address).transferFrom(
                msg.sender,
                address(this),
                _erc721TokenId[i]
            );
            temp.nftCount++;
            temp.nftIds.push(_erc721TokenId[i]);
        }
        emit VaultJoined(msg.sender, _erc20Count, _erc721TokenId);
    }

    function activeFunds() public view returns (uint256) {
        return IERC20(erc20Address).balanceOf(address(this));
    }
    function yieldGeneratedPer() public
        view
        returns (uint256){
            return((afterYieldFunds - totalfunds) * 100) / totalfunds;
        }

    function claimableFundsPrcentage(address user)
        public
        view
        returns (uint256)
    {
        Vault storage temp = vaults[user];
        require(afterYieldFunds > 0, "Yield funds not set");
        return ((temp.tokenCount * 100) / totalfunds);
    }

    function claimBack() public {
        // require(block.timestamp>=claimingPeriod,"Claim period not started");
        Vault storage temp = vaults[msg.sender];
        uint256 amnt = (claimableFundsPrcentage(msg.sender) * afterYieldFunds) /
            100;

        require(amnt > 0 || temp.nftCount > 0, "Nothing to claim");
        require(
            IERC20(erc20Address).transfer(msg.sender, amnt),
            "ERC20 transfer failed"
        );

        temp.tokenCount = 0;
        for (uint256 i = 0; i < temp.nftIds.length; i++) {
            IERC721(erc721Address).transferFrom(
                address(this),
                msg.sender,
                temp.nftIds[i]
            );
        }
        emit Claimed(msg.sender, amnt, temp.nftIds);
        delete vaults[msg.sender];
    }

    function withdrawFund() public onlyOwner {
        require(totalfunds > 0, "no funds to withdraw");
        IERC20(erc20Address).transfer(owner(), totalfunds);
        // totalfunds = 0;
    }

    function depositYieldedFunds(uint256 _amnt) public onlyOwner {
        IERC20(erc20Address).transferFrom(owner(), address(this), _amnt);
        afterYieldFunds += _amnt;
    }
}
