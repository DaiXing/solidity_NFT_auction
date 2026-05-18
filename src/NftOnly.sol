// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {
    ERC721URIStorage
} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

// 简单的NFT。测试用。
contract MySimpleNFT is ERC721URIStorage {
    uint256 _tokenId = 100; // id
    constructor() ERC721("MyNFT", "MyNFT") {}

    // 铸造新的token
    function mintToken(string memory tokenUri) public {
        _tokenId++;
        uint256 newTokenId = _tokenId;

        // 给用户发一个token
        _safeMint(msg.sender, newTokenId);
        // 给token绑定URI
        _setTokenURI(newTokenId, tokenUri);
    }
}
