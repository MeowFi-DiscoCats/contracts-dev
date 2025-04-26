// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MyContractProxy is ERC1967Proxy {
    constructor(
        address _logic,
        uint256 _nftPrice,
        uint256 _nftLimitPerAddress,
        address initialOwner,
        address _tokenAddress,
        uint256 _nftLimit,
        uint256 _joiningPeriod,
        uint256 _claimingPeriod
    )
        ERC1967Proxy(
            _logic,
            abi.encodeWithSignature(
                "initialize(uint256,uint256,address,address,uint256,uint256,uint256)",
                _nftPrice,
                _nftLimitPerAddress,
                initialOwner,
                _tokenAddress,
                _nftLimit,
                _joiningPeriod,
                _claimingPeriod
            )
        )
    {}
}
