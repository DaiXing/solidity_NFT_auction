// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

// 简单的NFT。测试用。
contract MySimpleNFT is ERC721URIStorage {
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
    Normal, // 正常。
    Success, // 竞拍成功。
    Fail, // 竞拍失败。
    Cancel // 取消了。
}
// 拍卖的信息
struct AuctionData {
    address nftContract; // token合约地址
    uint256 tokenId; // token
    uint256 auctionId; // 拍卖
    address creator; // 创建者
    uint256 minPrice; // 起拍价
    uint256 beginTime; // 开始时间
    uint256 endTime; // 结束时间
    AuctionState state; // 状态。
    address bidder; // 出价者。
    uint256 bidPrice; // 出价的金额。
}

// 拍卖合约。
contract AuctionContract {
    uint256 _auctionId = 0; // 序号

    // key1=NFT合约地址  key2=tokenID value=auctionID
    mapping(address => mapping(uint256 => uint256)) tokenAuctionMap;
    // key=auctionID
    mapping(uint256 => AuctionData) auctionMap;

    // 创建。
    event AuctionCreate(
        address tokenOwner,
        uint256 tokenId, // 用Go取日志。这里还需要索引吗？
        uint256 auctionId,
        uint256 minPrice,
        uint256 beginTime,
        uint256 endTime
    );
    // 退款。
    event AuctionRefund(
        uint256 tokenId, // 用Go取日志。这里还需要索引吗？
        uint256 auctionId,
        address to, // 给谁。
        uint256 amount // 退款金额
    );
    // 竞拍。
    event AuctionBid(
        uint256 tokenId, // 用Go取日志。这里还需要索引吗？
        uint256 auctionId,
        address bidder, // 竞拍人。
        uint256 bidPrice // 竞拍金额
    );
    // 取消。
    event AuctionCancel(
        uint256 tokenId, // 用Go取日志。这里还需要索引吗？
        uint256 auctionId
    );
    // 结束。
    event AuctionEnd(
        uint256 tokenId, // 用Go取日志。这里还需要索引吗？
        uint256 auctionId,
        AuctionState state // 状态。
    );

    constructor() {}

    // owner校验。
    modifier needTokenOwner(address nftContract, uint256 tokenId) {
        address owner = IERC721(nftContract).ownerOf(tokenId);
        require(msg.sender == owner, "not token owner");
        _;
    }
    // owner校验。
    modifier needAuctionOwner(uint256 auctionId) {
        require(auctionId > 0, "auctionId is invalid");
        AuctionData storage auctionData = auctionMap[auctionId];
        require(auctionData.creator == msg.sender, "not auction owner");
        _;
    }

    // 创建 拍卖。
    function createAuction(
        address nftContract,
        uint256 tokenId,
        uint256 minPrice,
        uint256 beginTime,
        uint256 periodTime
    ) public needTokenOwner(nftContract, tokenId) {
        // 校验数据
        require(minPrice > 0, "minPrice is invalid");
        require(beginTime >= block.timestamp, "beginTime is invalid");
        require(periodTime > 5 minutes, "periodTime is invalid");

        // 检查授权。
        IERC721 nft = IERC721(nftContract);
        address tokenAppr = nft.getApproved(tokenId);
        require(tokenAppr == address(this), "token approve not match");

        // 序号。
        _auctionId++;
        uint256 auctionId = _auctionId;

        // 结束时间。
        uint256 endTime = beginTime + periodTime;

        // 拍卖信息。
        AuctionData storage auctionData = auctionMap[auctionId];
        auctionData.nftContract = nftContract;
        auctionData.tokenId = tokenId;
        auctionData.auctionId = auctionId;
        auctionData.creator = msg.sender;
        auctionData.minPrice = minPrice;
        auctionData.beginTime = beginTime;
        auctionData.endTime = endTime;
        auctionData.state = AuctionState.Normal;

        // 映射。
        mapping(uint256 => uint256) map2 = tokenAuctionMap[nftContract];
        map2[tokenId] = auctionId;

        // 事件。
        emit AuctionCreate(
            msg.sender,
            tokenId,
            auctionId,
            minPrice,
            beginTime,
            endTime
        );
    }

    // 竞拍。
    function bidAuction(uint256 auctionId) public payable {
        uint256 amount = msg.value;
        require(amount > 0, "amount is invalid");
        AuctionData storage auctionData = auctionMap[auctionId];
        require(auctionData.beginTime > 0, "auction not found");
        // 判断时间
        require(block.timestamp > auctionData.beginTime, "time not begin");
        require(auctionData.endTime > block.timestamp, "time is end");
        require(
            auctionData.state == AuctionState.Normal,
            "state is not Normal"
        );
        // 不能重复。
        require(auctionData.bidder == msg.sender, "bid repeated");
        // 金额必须够
        require(
            amount > auctionData.minPrice,
            "amount is smaller than minPrice"
        );
        require(
            amount > auctionData.bidPrice,
            "amount is smaller than bidPrice"
        );

        uint256 tokenId = auctionData.tokenId;

        // 退款。
        address oldbidder = auctionData.bidder;
        uint256 oldbidPrice = auctionData.bidPrice;

        // 出价更高。保存价格。
        auctionData.bidder = msg.sender;
        auctionData.bidPrice = amount;

        // 退款。
        if (oldbidder != address(0) && oldbidPrice > 0) {
            // 退款。
            (bool ok, ) = payable(oldbidder).call{value: oldbidPrice}("");
            require(ok, "refund error");

            // 事件。
            emit AuctionRefund(tokenId, auctionId, oldbidder, oldbidPrice);
        }

        // 事件。
        emit AuctionBid(tokenId, auctionId, msg.sender, amount);
    }

    // 取消。
    function cancelAuction(
        uint256 auctionId
    ) public needAuctionOwner(auctionId) {
        AuctionData storage auctionData = auctionMap[auctionId];
        // 未开始的，才能取消。
        require(auctionData.beginTime <= block.timestamp, "auction is begin");

        // 修改状态。
        auctionData.state = AuctionState.Cancel; // 取消。

        // 事件。
        emit AuctionCancel(auctionData.tokenId, auctionId);
    }

    // 结束。
    function endAuction(uint256 auctionId) public needAuctionOwner(auctionId) {
        AuctionData storage auctionData = auctionMap[auctionId];
        // 时间完结，才能结束。
        require(auctionData.endTime > block.timestamp, "auction is end");
        require(
            auctionData.state == AuctionState.Normal,
            "state is not Normal"
        );

        uint256 tokenId = auctionData.tokenId;
        address creator = auctionData.creator;
        address bidder = auctionData.bidder;
        uint256 bidPrice = auctionData.bidPrice;

        // 有人出价。
        if (auctionData.bidder > address(0) && auctionData.bidPrice > 0) {
            // 把钱给 creator
            (bool ok, ) = payable(creator).call{value: bidPrice}("");
            require(ok, "transfer money error");

            // 把token给 bidder
            myNFT.transferFrom(creator, bidder, tokenId);

            // 竞拍成功了。
            auctionData.state = AuctionState.Success;
        } else {
            // 竞拍失败了。
            auctionData.state = AuctionState.Fail;
        }

        // 事件。
        emit AuctionEnd(auctionData.tokenId, auctionId, auctionData.state);
    }
}
