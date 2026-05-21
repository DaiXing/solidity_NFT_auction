// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// 接口。
interface IAuction {
    // 创建。
    event AuctionCreate(
        address nftContract, // NFT合约地址
        address indexed seller, // 卖家
        uint256 indexed tokenId, // tokenID
        uint256 indexed auctionId, // 拍卖ID
        uint256 minPrice, // 起拍价
        uint256 beginTime, // 开始时间
        uint256 endTime // 结束时间
    );
    // 退款。
    event AuctionRefund(
        uint256 indexed auctionId, // 拍卖ID
        address indexed to, // 给谁。
        uint256 amount, // 退款金额
        uint256 bidId // 竞拍的序号。
    );
    // 竞拍。
    event AuctionBid(
        uint256 indexed auctionId, // 拍卖ID
        address indexed bidder, // 竞拍人。
        uint256 bidPrice, // 竞拍金额
        uint256 bidId // 竞拍的序号。
    );
    // 取消。
    event AuctionCancel(uint256 indexed auctionId);
    // 结束。
    event AuctionEnd(uint256 indexed auctionId, AuctionState state);

    // 初始化。 代理合约需要这个函数，设置字段等。 只能初始化一次。
    function initialize(string memory desc) external;

    // 查描述。
    function queryDesc()
        external
        returns (string memory desc, uint256 auctionId, uint256 bidId);

    // 查询拍卖信息。
    function queryAuction(
        uint256 auctionId
    ) external returns (AuctionData memory);

    // 创建 拍卖。
    function createAuction(
        address nftContract, // NFT合约地址
        uint256 tokenId, // token
        uint256 minPrice, // 起拍价
        uint256 beginTime, // 开始时间
        uint256 periodTime // 持续时间
    ) external returns (uint256 auctionId_);

    // 竞拍。
    function bidAuction(
        uint256 auctionId
    ) external payable returns (uint256 bidId_);

    // 取消。
    function cancelAuction(uint256 auctionId) external;

    // 结束。
    function endAuction(uint256 auctionId) external;
}

// 拍卖的状态
enum AuctionState {
    Normal, // 正常。 未开始或进行中。
    Success, // 成功。 token被拍出了
    Fail, // 失败。 token没有拍出
    Cancel // 取消了。
}
// 拍卖的信息
struct AuctionData {
    address nftContract; // token合约地址
    uint256 tokenId; // token
    uint256 auctionId; // 拍卖
    address seller; // 卖家
    uint256 minPrice; // 起拍价
    uint256 beginTime; // 开始时间
    uint256 endTime; // 结束时间
    AuctionState state; // 状态。
    address bidder; // 出价者。
    uint256 bidPrice; // 出价的金额。
    uint256 bidId; // 出价的序号。
}
