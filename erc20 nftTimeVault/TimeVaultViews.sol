// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BaseTimeVault.sol";
import "./TimeNft.sol";

contract TimeVaultViews is BaseTimeVault {
    function getState() public view returns (uint256) {
        if (block.timestamp < joiningPeriod) return 0;
        if (block.timestamp < claimingPeriod) return 1;
        return 2;
    }

    function getNftCount() public view returns (uint256) {
        return TimeNft(nftAddress).tokenIdCounter();
    }

    function canCompound() external view returns (bool canExec, bytes memory execPayload) {
        canExec = getState() == 1;
        execPayload = abi.encodeWithSignature("automateCoumpounding()");
    }
}