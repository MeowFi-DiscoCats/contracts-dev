// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./uniswapHelper.sol";
import "./IWrappedMonad.sol";

// 0x7bde82f20000000000000000000000000000000000000000000000000000421515a234a800000000000000000000000053c02ddd9804e318472dbe5c4297834a7b80ba0e
//Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable
// contract nativeTimeVault is Ownable, ReentrancyGuard {
contract CurvanceTimeVault is Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    address public nftAddress;
    uint256 public nftPrice;
    uint256 public nftLimitPerAddress;
    uint256 public activeFunds;
    uint256 public totalFunds;
    uint256 public yieldedFunds;
    uint256 public activeYieldedFunds;
    address public PartnerContract;
    address public erc20Address;
    uint256 public platformFees = 100; // 1%
    uint256 public totalFeeCollected;
    uint256 public joiningPeriod;
    uint256 public claimingPeriod;
    uint256 public CompoundCounter;
    uint256 public prejoinPeriod;
    uint256 public bribeCount;
    uint public swapFees=10;//0.1
    uint public constant FEE_DENOMINATOR = 10000;

    struct Vault {
        uint256 ethAmount;
        uint256 nftAmount;
    }
    struct Bribe {
        address tokenAddress;
        uint256 value;
    }

    mapping(address => Vault) public vaults;
    mapping(address => mapping(address => uint256)) public briber;
    mapping(address => uint256) public bribes;
    address[] public bribeTokenAddr;
    mapping(uint256 => bool) public nftClaimed;
    IOctoswapRouter02 public router;
    address payable public immutable WETH = payable(0x760AfE86e5de5fa0Ee542fc7B7B713e1c5425701);

    event FundsWithdrawn(address indexed receiver);
    event FeesCollected(uint256 amount);
    event ExternalFundsDeposited(uint256 amount);
    event VaultJoined(address indexed user, uint256 amount);
    event Compounded(uint256 amount);
    event SwapExecuted(
    address indexed user,
    address indexed inputToken,
    uint256 inputAmount,
    address indexed outputToken,
    uint256 outputAmount,
    uint256 slippageBps
);
event EthSwapExecuted(
    address indexed user,
    uint256 ethAmount,
    uint256 shmonAmount,
    uint256 slippageBps
);
event NFTClaimed(address indexed user, uint256 tokenId, uint256 amountClaimed);

    // constructor(
    //     uint256 _nftPrice,
    //     uint256 _nftLimitPerAddress,
    //     address initialOwner,
    //     uint256 _nftLimit,
    //     uint256 _joiningPeriod,
    //     uint256 _claimingPeriod,
    //     address _PartnerContract,
    //     address _erc20Address,
    //     uint256 _prejoinPeriod
    // ) Ownable(initialOwner) {
    //     nftPrice = _nftPrice;
    //     nftLimitPerAddress = _nftLimitPerAddress;
    //     TimeNft nftContract = new TimeNft(
    //         address(this),
    //         _nftLimit,
    //         initialOwner
    //     );
    //     nftAddress = address(nftContract);
    //     joiningPeriod = _joiningPeriod;
    //     claimingPeriod = _claimingPeriod;
    //     PartnerContract = _PartnerContract;
    //     erc20Address = _erc20Address;
    //     prejoinPeriod = _prejoinPeriod;
    // }
    function initialize(
        uint256 _nftPrice,
        uint256 _nftLimitPerAddress,
        address initialOwner,
        uint256 _nftLimit,
        uint256 _joiningPeriod,
        uint256 _claimingPeriod,
        address _PartnerContract,
        address _erc20Address,
        uint256 _prejoinPeriod,
        address _router
    ) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        nftPrice = _nftPrice;
        nftLimitPerAddress = _nftLimitPerAddress;
        TimeNft nftContract = new TimeNft(
            address(this),
            _nftLimit,
            initialOwner
        );
        nftAddress = address(nftContract);
        joiningPeriod = _joiningPeriod;
        claimingPeriod = _claimingPeriod;
        PartnerContract = _PartnerContract;
        erc20Address = _erc20Address;
        prejoinPeriod = _prejoinPeriod;
        router = IOctoswapRouter02(_router);
        
    }
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    function joinVault(uint256 _nftAmount,address user) public {
        require(getState() == 0, "Waiting period");
        require(user != address(0), "Invalid user");

        require(
            getNftCount() + _nftAmount <= TimeNft(nftAddress).nftLimit(),
            "Exceeds NFT limit"
        );
        require(_nftAmount <= nftLimitPerAddress, "Cannot mint more");

        IERC20 erc20 = IERC20(erc20Address);
        uint256 amount = _nftAmount * nftPrice;

        require(erc20.balanceOf(user) >= amount, "insuffBalance");
        require(
            erc20.transferFrom(user, address(this), amount),
            "Transfer failed"
        );
        erc20.approve(PartnerContract, amount);

        (bool success, bytes memory data) = PartnerContract.call(
            abi.encodeWithSignature("mint(uint256)", amount)
        );
        require(success, string(data));
        require(
            TimeNft(nftAddress).balanceOf(user) + _nftAmount <= nftLimitPerAddress,
            "Limit exceeded"
        );

        TimeNft(nftAddress).safeMint(user, _nftAmount);
        activeFunds += amount;
        totalFunds += amount;

        emit VaultJoined(user, amount);
    }
    function swapAndJoin(
    uint256 _nftAmount,
    address user,
    uint16 _slippageBps,
    address _startTokenAddr
) external nonReentrant {
    require(_nftAmount > 0, "Zero NFT amount");
    require(user != address(0), "Invalid user");
    require(_slippageBps <= 1000, "Slippage too high");
    
    uint actualAmnt=_nftAmount * nftPrice;
    uint256 exactShmonOut = actualAmnt* (10000 + swapFees) / FEE_DENOMINATOR;
    uint fee =exactShmonOut-actualAmnt;
    // uint256 exactShmonOut = _nftAmount * nftPrice;
    uint256 maxAmountIn = getInputForExactOutput(_nftAmount, _slippageBps, _startTokenAddr);
    
    // Transfer and approve input tokens
    IERC20(_startTokenAddr).transferFrom(msg.sender, address(this), maxAmountIn);
    IERC20(_startTokenAddr).approve(address(router), maxAmountIn);
    
    // Execute swap to THIS contract
    address[] memory path = new address[](3);
    path[0] = _startTokenAddr;
    path[1] = WETH;
    path[2] = erc20Address;
    
    uint[] memory amounts = router.swapTokensForExactTokens(
        exactShmonOut,
        maxAmountIn,
        path,
        address(this), // Send SHMON to contract, not user
        block.timestamp + 300
    );
    
    // Refund unused input tokens
    if (amounts[0] < maxAmountIn) {
        IERC20(_startTokenAddr).transfer(user, maxAmountIn - amounts[0]);
    }
    
    // Internal join without token transfer
    _joinVault(_nftAmount, user, actualAmnt);
    totalFeeCollected+=fee;
    emit SwapExecuted(
        user,
        _startTokenAddr,
        amounts[0],
        erc20Address,
        exactShmonOut,
        _slippageBps
    );
}

function _joinVault(uint256 _nftAmount, address user, uint256 amount) internal {
    require(getState() == 0, "Waiting period");
    require(user != address(0), "Invalid user");
    require(
        getNftCount() + _nftAmount <= TimeNft(nftAddress).nftLimit(),
        "Exceeds NFT limit"
    );
    require(amount == _nftAmount * nftPrice, "Amount mismatch");
    require(_nftAmount <= nftLimitPerAddress, "Cannot mint more");
    
    // Use SHMON already in contract
    IERC20(erc20Address).approve(PartnerContract, amount);
    
    (bool success, bytes memory data) = PartnerContract.call(
        abi.encodeWithSignature("mint(uint256)", amount)
    );
    require(success, string(data));
    
    TimeNft(nftAddress).safeMint(user, _nftAmount);
    activeFunds += amount;
    totalFunds += amount;

    emit VaultJoined(user, amount);
}

function getInputForExactOutput(
    uint256 _nftAmount,
    uint16 _slippageBps,
    address _startTokenAddr
) public view returns (uint256) {
    uint256 exactShmonOut = _nftAmount * nftPrice;
    
    address[] memory path = new address[](3);
    path[0] = _startTokenAddr;
    path[1] = WETH;
    path[2] = erc20Address;
    
    uint[] memory amounts = router.getAmountsIn(exactShmonOut, path);
    uint256 expectedInput = amounts[0];
    
    // Apply slippage: expectedInput * (10000 + slippageBps) / 10000
    return expectedInput * (10000 + _slippageBps) / FEE_DENOMINATOR;
}
function swapEthAndJoin(
    uint256 _nftAmount,
    address user,
    uint16 _slippageBps // 100 = 1%
) external payable nonReentrant {
    require(_nftAmount > 0, "Zero NFT amount");
    require(user != address(0), "Invalid user");
    require(_slippageBps <= 1000, "Slippage too high");
    
   
    uint actualAmnt=_nftAmount * nftPrice;
    uint256 exactShmonOut = actualAmnt* (10000 + swapFees) / FEE_DENOMINATOR;
    uint fee =exactShmonOut-actualAmnt;
    
   
    uint256 maxEthIn = getEthInputForExactOutput(_nftAmount, _slippageBps);
    require(msg.value >= maxEthIn, "Insufficient ETH sent"); 
    
   
    address[] memory path = new address[](2);
    path[0] = WETH; 
    path[1] = erc20Address; 
    
    uint[] memory amounts = router.swapETHForExactTokens{value: maxEthIn}(
        exactShmonOut,
        path,
        address(this),
        block.timestamp + 300
    );
    
   
    uint256 ethUsed = amounts[0];
    if (msg.value > ethUsed) {
        payable(user).transfer(msg.value - ethUsed);
    }
    
    // 5. Deposit to vault
    _joinVault(_nftAmount, user, actualAmnt);
    totalFeeCollected+=fee;
    
    emit EthSwapExecuted(
        user,
        ethUsed,
        exactShmonOut,
        _slippageBps
    );
}

function getEthInputForExactOutput(
    uint256 _nftAmount,
    uint16 _slippageBps
) public view returns (uint256) {
    uint256 exactShmonOut = _nftAmount * nftPrice;
    
    address[] memory path = new address[](2);
    path[0] = WETH;
    path[1] = erc20Address;
    
    uint[] memory amounts = router.getAmountsIn(exactShmonOut, path);
    uint256 expectedEth = amounts[0];
    
    return expectedEth * (10000 + _slippageBps) / FEE_DENOMINATOR;
}


    
    function getBalanceNft(address _user)external view returns(uint ethAmount,uint nftAmount){
         nftAmount=TimeNft(nftAddress).balanceOf(_user);
         ethAmount=nftAmount * nftPrice;
        return (ethAmount,nftAmount);

    }

    function automateCoumpounding() public {
        EnhancedERC4626 pContract = EnhancedERC4626(PartnerContract);
        IERC20 erc20 = IERC20(erc20Address);
        uint256 stakedBal = pContract.balanceOf(address(this));

        // require(pContract.redeem(), "Redemption failed");
        uint256 before = IERC20(erc20Address).balanceOf(address(this));
        (bool successV2, bytes memory dataV2) = PartnerContract.call(
            abi.encodeWithSignature(
                "redeem(uint256,address)",
                stakedBal,
                address(this)
            )
        );
        require(successV2, string(dataV2));

        uint256 redeemedAmount = IERC20(erc20Address).balanceOf(address(this)) -
            before;
        yieldedFunds = redeemedAmount;
        activeYieldedFunds = redeemedAmount;

        erc20.approve(PartnerContract, redeemedAmount);

        (bool success, bytes memory data) = PartnerContract.call(
            abi.encodeWithSignature("mint(uint256)", redeemedAmount)
        );
        require(success, string(data));
        // pContract.mint(redeemedAmount);
        CompoundCounter++;

        emit Compounded(redeemedAmount);
    }

    function claimBack() public nonReentrant {
        require(getState() == 2, "Wait for claim period");
        uint256 balance = TimeNft(nftAddress).balanceOf(msg.sender);
        require(balance > 0, "No NFTs");

        uint startValue=nftPrice;
        
                uint256 yieldValue = (yieldedFunds / getNftCount())-startValue;
                uint256 fees = (yieldValue * platformFees) / FEE_DENOMINATOR;
                uint256 claimAmount =startValue+ yieldValue - fees;

        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = TimeNft(nftAddress).tokenOfOwnerByIndex(
                msg.sender,
                0
            );
            if (!nftClaimed[tokenId]) {
                

                totalFeeCollected += fees;
                EnhancedERC4626 pContract = EnhancedERC4626(PartnerContract);

                // pContract.redeem();
                (bool successV2, bytes memory dataV2) = PartnerContract.call(
                    abi.encodeWithSignature(
                        "redeem(uint256,address)",
                        pContract.convertToShares(claimAmount),
                        msg.sender
                    )
                );
                require(successV2, string(dataV2));

                activeYieldedFunds -= claimAmount;
                nftClaimed[tokenId] = true;
                TimeNft(nftAddress).burn(tokenId);

                for (uint256 j = 0; j < bribeCount; j++) {
                    uint256 totalP = bribes[bribeTokenAddr[j]] / getNftCount();
                    IERC20 erc20 = IERC20(bribeTokenAddr[j]);
                    erc20.transfer(msg.sender, totalP);
                }
            }
        }
    }

    function changeTimePeriod(
        uint256 _joiningPeriod,
        uint256 _claimingPeriod,
        uint256 _prejoinPeriod
    ) external onlyOwner {
        joiningPeriod = _joiningPeriod;
        claimingPeriod = _claimingPeriod;
        prejoinPeriod = _prejoinPeriod;
    }

    function changeFees(uint256 _fee,uint _swapFees) external onlyOwner {
        platformFees = _fee;
        swapFees=_swapFees;
    }

    function collectFee() external onlyOwner {
        // uint256 total = yieldedFunds;
        // uint256 fees = (total * platformFees) / 10000;
        // totalFeeCollected += fees;

        EnhancedERC4626 pContract = EnhancedERC4626(PartnerContract);
        // pContract.redeem(pContract.convertToShares(fees), msg.sender);

        (bool successV2, bytes memory dataV2) = PartnerContract.call(
            abi.encodeWithSignature(
                "redeem(uint256,address)",
                pContract.convertToShares(totalFeeCollected),
                msg.sender
            )
        );
        require(successV2, string(dataV2));

        activeYieldedFunds -= totalFeeCollected;

        emit FeesCollected(totalFeeCollected);
        totalFeeCollected=0;
    }
    function collectBribe(address tkn,uint amnt)external onlyOwner{
            IERC20 erc20 = IERC20(tkn);
                    erc20.transfer(msg.sender, amnt);
    }

    // function withdrawAllFunds(address payable receiver) public onlyOwner {
    //     EnhancedERC4626 pContract = EnhancedERC4626(PartnerContract);
    //     uint256 stakedBal = pContract.balanceOf(address(this));
    //     require(pContract.redeem(stakedBal, address(this)), "Redemption failed");

    //     activeFunds = 0;
    //     totalFunds = 0;
    //     yieldedFunds = 0;
    //     activeYieldedFunds = 0;
    //     emit FundsWithdrawn(receiver);
    // }

    // function depositExternalFunds() public payable onlyOwner {
    //     yieldedFunds += msg.value;
    //     activeYieldedFunds += msg.value;
    //     emit ExternalFundsDeposited(msg.value);
    // }

    function bribe(uint256 _amnt, address _tknAddress) external {
        require(getState() != 2);
        require(_amnt > 0, "Amount must be positive");
        IERC20 erc20 = IERC20(_tknAddress);
        require(
            erc20.allowance(msg.sender, address(this)) >= _amnt,
            "Insufficient allowance"
        );
        erc20.transferFrom(msg.sender, address(this), _amnt);
        briber[msg.sender][_tknAddress] += _amnt;
        if (bribes[_tknAddress] == 0) {
            bribeCount++;
            bribeTokenAddr.push(_tknAddress);
        }
        bribes[_tknAddress] += _amnt;
    }

    function pauseNft() external onlyOwner {
        TimeNft(nftAddress).pause();
    }

    function canCompound()
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        canExec = getState() == 1;
        execPayload = abi.encodeWithSelector(
            this.automateCoumpounding.selector
        );
    }

    function getState() public view returns (uint256) {
        if (block.timestamp < joiningPeriod && block.timestamp > prejoinPeriod)
            return 0;
        if (block.timestamp < claimingPeriod && block.timestamp > prejoinPeriod)
            return 1;
        if (block.timestamp < prejoinPeriod) return 3;
        return 2;
    }

    function getNftCount() public view returns (uint256) {
        return TimeNft(nftAddress).tokenIdCounter();
    }

    receive() external payable {}
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
    ERC721Burnable,
    IERC2981
{
    uint256 public tokenIdCounter = 0;
    string private _baseTokenURI;
    address public vaultAddress;
    uint256 public nftLimit;
    address public royaltyRecipient;
    uint256 public royaltyBps = 500;

    constructor(
        address initialOwner,
        // string memory baseURI,
        uint256 _nftLimit,
        address _royaltyRecipient
    )
        ERC721("MeowFi - Curvance & Fastlane Vault NFT", "MCF")
        Ownable(initialOwner)
    {
        _baseTokenURI = "https://tan-worthy-leopard-797.mypinata.cloud/ipfs/bafkreihgbtdhqqjtuszdhme2norzthk35rcitbetdmykuxid6d66ab5v5i";

        nftLimit = _nftLimit;
        royaltyRecipient = _royaltyRecipient;
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
        override(ERC721, ERC721Enumerable, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}

interface EnhancedERC4626 is IERC4626 {
    /**
     * @dev New function to get vault utilization ratio
     * @return utilization Percentage of assets being used (0-10000 where 10000 = 100%)
     */

    // Optional: You can keep standard ERC4626 functions virtual for further overriding
    function redeem(uint256 assets, address receiver) external returns (bool);

    function mint(uint256 assets) external returns (bool);
}
