// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract BurrBearXBeraPawHuntNFT is ERC721, ERC721Enumerable, Ownable {
    uint256 private _nextTokenId;
    string private _baseTokenURI;

    constructor(address initialOwner)
        ERC721("BurrBear x BeraPaw Hunt NFT", "BXB")
        Ownable(initialOwner)
    {
        _baseTokenURI = "https://tan-worthy-leopard-797.mypinata.cloud/ipfs/bafkreibutf7lksixmqunqv4gancpq5gdbzmecsvosbbklbbtrf5fywdqwy";
    }

    function tokenURI(uint256 /*tokenId*/) public view override returns (string memory) {
        return _baseTokenURI;
    }

    function safeMint(address to) public returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        return tokenId;
    }

    // The following functions are overrides required by Solidity.

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
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