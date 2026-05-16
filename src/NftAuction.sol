// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract MyNFT is ERC721URIStorage {
    uint256 _tokenId = 0; // id
    constructor() ERC721("MyNFT", "MyNFT") {}

    // 铸造新的token
    function mintToken(string memory tokenUri) public {
        _tokenId++;
        uint256 newTokenId = _tokenId;

        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenUri);
    }
}

// 拍卖的状态
enum AuctionState {
    Success,
    Fail
}
// 拍卖的信息
struct AuctionData {
    uint256 tokenId; // 币
    uint256 auctionId; // 拍卖
    uint256 minPrice; // 起拍价
    uint256 beginTime; // 开始时间
    uint256 periodTime; // 持续时间
    AuctionState state; // 状态。
    address bider; // 出价者。
    uint256 biderPrice; // 出价的金额。
}

contract Auction {
    MyNFT myNFT; // 管理token。
    uint256 _auctionId = 0; // 序号

    // key1=用户  key2=tokenID value=auctionID
    mapping(address => mapping(uint256 => uint256)) tokenAuctionMap;
    // key=auctionID
    mapping(uint256 => AuctionData) auctionMap;

    event AuctionCreated(
        address tokenOwner,
        uint256 tokenId, // 用Go取日志。这里还需要索引吗？
        uint256 auctionId,
        uint256 minPrice,
        uint256 beginTime,
        uint256 periodTime
    );

    constructor() {
        myNFT = new MyNFT();
    }

    // owner校验。
    modifier needTokenOwner(uint256 tokenId) {
        address owner = myNFT.ownerOf(tokenId);
        require(msg.sender == owner, "not owner");
        _;
    }

    // 创建 拍卖。
    function createAuction(
        uint256 tokenId,
        uint256 minPrice,
        uint256 beginTime,
        uint256 periodTime
    ) public needTokenOwner(tokenId) {
        //  校验数据
        require(minPrice > 0, "minPrice is invalid");
        require(beginTime >= block.timestamp, "beginTime is invalid");
        require(periodTime > 5 minutes, "periodTime is invalid");

        // 序号。
        _auctionId++;
        uint256 auctionId = _auctionId;

        // 拍卖信息。
        AuctionData storage auctionData = auctionMap[auctionId];
        auctionData.tokenId = tokenId;
        auctionData.auctionId = auctionId;
        auctionData.minPrice = minPrice;
        auctionData.beginTime = beginTime;
        auctionData.periodTime = periodTime;

        // 事件。
        emit AuctionCreated(
            msg.sender,
            tokenId,
            auctionId,
            minPrice,
            beginTime,
            periodTime
        );
    }
}
