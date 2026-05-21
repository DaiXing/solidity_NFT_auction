// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IAuction, AuctionData, AuctionState} from "./AuctionInterface.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {
    UUPSUpgradeable
} from "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {
    Initializable
} from "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {
    OwnableUpgradeable
} from "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

// 拍卖合约。 V1
contract AuctionContractV1 is
    IAuction, // 接口。
    Initializable, // 初始化函数
    UUPSUpgradeable, // proxy
    OwnableUpgradeable // owner
{
    uint256 _auctionId; // 拍卖的序号
    uint256 _bidId; // 竞拍的序号。
    string _desc; // 描述。

    // key1=NFT合约地址  key2=tokenID value=auctionID
    mapping(address => mapping(uint256 => uint256)) nftTokenAuctionMap;
    // key=auctionID value=拍卖信息
    mapping(uint256 => AuctionData) auctionMap;

    // --------------------
    constructor() {
        _disableInitializers(); // 只能初始化1次。
    }

    // 初始化。 代理合约需要这个函数，设置字段等。
    function initialize(string memory desc) public initializer {
        // 调用者为owner。
        __Ownable_init(msg.sender);
        // 初始化数据。
        _auctionId = 1;
        _bidId = 1;
        _desc = desc;
    }

    // 授权升级。 只有owner才能升级。
    function _authorizeUpgrade(address newImpl) internal override onlyOwner {
        // 修饰器，判断了owner。不需要其他逻辑。
    }

    // --------------------

    // owner校验。
    modifier needTokenOwner(address nftContract, uint256 tokenId) {
        needTokenOwner_(nftContract, tokenId);
        _;
    }
    function needTokenOwner_(
        address nftContract,
        uint256 tokenId
    ) internal view {
        address owner = IERC721(nftContract).ownerOf(tokenId);
        require(msg.sender == owner, "not token owner");
    }
    // owner校验。
    modifier needAuctionOwner(uint256 auctionId) {
        needAuctionOwner_(auctionId);
        _;
    }
    function needAuctionOwner_(uint256 auctionId) internal view {
        require(auctionId > 0, "auctionId is invalid");
        AuctionData storage auctionData = auctionMap[auctionId];
        require(auctionData.seller == msg.sender, "not auction owner");
    }

    // 查描述。
    function queryDesc()
        public
        view
        returns (string memory desc, uint256 auctionId, uint256 bidId)
    {
        return (_desc, _auctionId, _bidId);
    }

    // 查询拍卖信息。
    function queryAuction(
        uint256 auctionId
    ) public view returns (AuctionData memory) {
        return auctionMap[auctionId];
    }

    // 创建 拍卖。
    function createAuction(
        address nftContract, // NFT合约地址
        uint256 tokenId, // token
        uint256 minPrice, // 起拍价
        uint256 beginTime, // 开始时间
        uint256 periodTime // 持续时间
    ) public needTokenOwner(nftContract, tokenId) returns (uint256 auctionId_) {
        address seller = msg.sender;
        // 校验数据
        require(minPrice > 0, "minPrice is invalid");
        require(beginTime >= block.timestamp, "beginTime is invalid");
        require(periodTime > 2 minutes, "periodTime is too short");

        // 检查授权。
        IERC721 nft = IERC721(nftContract);
        address tokenAppr = nft.getApproved(tokenId);
        require(tokenAppr == address(this), "token approve not match");

        // 映射。
        mapping(uint256 => uint256)
            storage tokenAuctionMap = nftTokenAuctionMap[nftContract];
        uint256 auctionIdTmp = tokenAuctionMap[tokenId];
        // 不能重复拍卖。
        require(auctionIdTmp == 0, "auction is repeated");

        // 序号。
        _auctionId++;
        uint256 auctionId = _auctionId;
        // 映射。
        tokenAuctionMap[tokenId] = auctionId;

        // 结束时间。
        uint256 endTime = beginTime + periodTime;

        // 拍卖信息。
        AuctionData storage auctionData = auctionMap[auctionId];
        auctionData.nftContract = nftContract;
        auctionData.tokenId = tokenId;
        auctionData.auctionId = auctionId;
        auctionData.seller = seller;
        auctionData.minPrice = minPrice;
        auctionData.beginTime = beginTime;
        auctionData.endTime = endTime;
        auctionData.state = AuctionState.Normal;

        // 把币转给拍卖合约。防止一币多卖。
        nft.transferFrom(seller, address(this), tokenId);

        // 事件。
        emit AuctionCreate(
            nftContract,
            seller,
            tokenId,
            auctionId,
            minPrice,
            beginTime,
            endTime
        );
        return auctionId;
    }

    // 竞拍。
    function bidAuction(
        uint256 auctionId
    ) public payable returns (uint256 bidId_) {
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
        require(auctionData.bidder != msg.sender, "bid repeated");
        // 金额必须够
        require(
            amount > auctionData.minPrice,
            "amount is smaller than minPrice"
        );
        require(
            amount > auctionData.bidPrice,
            "amount is smaller than bidPrice"
        );

        // 退款。
        address oldbidder = auctionData.bidder;
        uint256 oldbidPrice = auctionData.bidPrice;
        uint256 oldbidId = auctionData.bidId;

        // 序号。
        _bidId++;
        uint256 newbidId = _bidId;

        // 出价更高。保存价格。
        auctionData.bidder = msg.sender;
        auctionData.bidPrice = amount;
        auctionData.bidId = newbidId;

        // 退款。
        if (oldbidder != address(0) && oldbidPrice > 0) {
            // 退款。
            (bool ok, ) = payable(oldbidder).call{value: oldbidPrice}("");
            require(ok, "refund error");

            // 事件。
            emit AuctionRefund(auctionId, oldbidder, oldbidPrice, oldbidId);
        }

        // 事件。
        emit AuctionBid(auctionId, msg.sender, amount, newbidId);
        return newbidId;
    }

    // 取消。
    function cancelAuction(
        uint256 auctionId
    ) public needAuctionOwner(auctionId) {
        AuctionData storage auctionData = auctionMap[auctionId];
        // 未开始的，才能取消。
        require(auctionData.beginTime > block.timestamp, "auction has begun");
        // 判断状态
        require(
            auctionData.state == AuctionState.Normal,
            "state is not Normal"
        );

        // 修改状态。
        auctionData.state = AuctionState.Cancel; // 取消。

        address nftContract = auctionData.nftContract;
        uint256 tokenId = auctionData.tokenId;
        IERC721 nft = IERC721(nftContract);

        // 取消了。清除。
        delete nftTokenAuctionMap[nftContract][tokenId];

        // 事件。
        emit AuctionCancel(auctionId);

        // 把币返给卖家。
        nft.transferFrom(address(this), auctionData.seller, tokenId);
    }

    // 结束。
    function endAuction(uint256 auctionId) public needAuctionOwner(auctionId) {
        AuctionData storage auctionData = auctionMap[auctionId];
        // 时间完结，才能结束。
        require(auctionData.endTime < block.timestamp, "end time not match");
        require(
            auctionData.state == AuctionState.Normal,
            "state is not Normal"
        );

        address nftContract = auctionData.nftContract;
        IERC721 nft = IERC721(nftContract);
        uint256 tokenId = auctionData.tokenId;
        address seller = auctionData.seller;
        address bidder = auctionData.bidder;
        uint256 bidPrice = auctionData.bidPrice;

        // 这个token拍卖结束了。
        delete nftTokenAuctionMap[nftContract][tokenId];

        // 有人出价。
        if (auctionData.bidder > address(0) && auctionData.bidPrice > 0) {
            // 竞拍成功了。
            auctionData.state = AuctionState.Success;

            // 把钱给 seller
            (bool ok, ) = payable(seller).call{value: bidPrice}("");
            require(ok, "transfer money error");

            // 把token给 bidder
            nft.transferFrom(address(this), bidder, tokenId);
        } else {
            // 竞拍失败了。
            auctionData.state = AuctionState.Fail;

            // 把币返给卖家。
            nft.transferFrom(address(this), seller, tokenId);
        }

        // 事件。
        emit AuctionEnd(auctionId, auctionData.state);
    }
}
