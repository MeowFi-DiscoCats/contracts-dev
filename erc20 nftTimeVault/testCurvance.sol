pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface EnhancedERC4626  {
    /**
     * @dev New function to get vault utilization ratio
     * @return utilization Percentage of assets being used (0-10000 where 10000 = 100%)
     */
    

    // Optional: You can keep standard ERC4626 functions virtual for further overriding
    function redeem(uint256 assets, address receiver) external returns (bool) ;
    function mint(uint256 assets) external returns (bool);
}
