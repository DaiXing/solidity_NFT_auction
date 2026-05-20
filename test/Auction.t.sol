// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
// import {Counter} from "../src/Counter.sol";
import {AuctionContractV1, AuctionData} from "../src/NftAuctionV1.sol";
import {AuctionContractV2} from "../src/NftAuctionV2.sol";
import {MySimpleNFT} from "../src/NftOnly.sol";
import {
    ERC1967Proxy
} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AuctionTest is Test {
    AuctionContractV1 auctionV1; // 逻辑合约V1
    AuctionContractV2 auctionV2; // 逻辑合约V2
    ERC1967Proxy proxy; // 代理合约。

    address addrAuctionV1;
    address addrAuctionV2;
    address addrProxy;

    MySimpleNFT nft; // token
    address addrNft;

    address userOwner = address(0xAA01);
    address user1 = address(0xBB01);
    address user2 = address(0xBB02);

    // 几个token。
    uint256 tokenApple;
    uint256 tokenOrange;

    function setUp() public {
        // 发币。
        deal(userOwner, 2000);
        deal(user1, 2000);
        deal(user2, 2000);

        // 设置时间
        vm.warp(300000000);

        vm.startPrank(userOwner);
        auctionV1 = new AuctionContractV1();
        auctionV2 = new AuctionContractV2();
        addrAuctionV1 = address(auctionV1);
        addrAuctionV2 = address(auctionV2);

        // 初始化。
        bytes memory funcData = abi.encodeWithSignature("initialize()");

        // 配置代理。
        proxy = new ERC1967Proxy(addrAuctionV1, funcData);
        addrProxy = address(proxy);

        // 铸币。
        nft = new MySimpleNFT();
        addrNft = address(nft);
        tokenApple = nft.mintToken("http://aa.com/apple.json");
        tokenOrange = nft.mintToken("http://aa.com/orange.json");

        vm.stopPrank();
    }

    // 测试，创建异常。
    function test_AuctionCreateError() public {
        console.log(unicode"\n>> 测试，创建异常。 ");
        // 使用代理合约。
        AuctionContractV1 auctionContract = AuctionContractV1(addrProxy);

        // 错误。不是 token 的 owner
        vm.prank(user2);
        vm.expectRevert();
        auctionContract.createAuction(
            addrNft,
            tokenApple,
            100,
            block.timestamp + 1,
            5
        );

        // 错误。 token 不存在。  ERC721NonexistentToken
        vm.prank(userOwner);
        vm.expectRevert();
        auctionContract.createAuction(
            addrNft,
            uint256(9999),
            100,
            block.timestamp + 1,
            5
        );

        // 错误。 beginTime is invalid
        vm.prank(userOwner);
        vm.expectRevert();
        auctionContract.createAuction(
            addrNft,
            tokenApple,
            100,
            block.timestamp - 99999,
            5
        );

        // 错误。 periodTime is too short
        vm.prank(userOwner);
        vm.expectRevert();
        auctionContract.createAuction(
            addrNft,
            tokenApple,
            100,
            block.timestamp + 1,
            3 seconds
        );

        // 错误。 NFT没有授权。 token approve not match
        vm.prank(userOwner);
        vm.expectRevert();
        auctionContract.createAuction(
            addrNft,
            tokenApple,
            100,
            block.timestamp + 1,
            7 minutes
        );
    }

    // 成功创建1个拍卖。
    function createAuctionForTokenApple() public returns (uint256) {
        // 使用代理合约。
        AuctionContractV1 logicV1 = AuctionContractV1(addrProxy);

        // NFT 授权。
        vm.prank(userOwner);
        nft.approve(addrProxy, tokenApple);

        // 创建1个拍卖。
        vm.prank(userOwner);
        uint256 auctionId = logicV1.createAuction(
            addrNft,
            tokenApple,
            100,
            block.timestamp + 1,
            6 minutes
        );
        return auctionId;
    }

    // 出价。
    function test_BidAuction() public {
        console.log(unicode"\n>> 测试，出价。");

        uint256 auctionId = createAuctionForTokenApple();
        console.log(unicode"   创建的拍卖 = ", auctionId);

        // 使用代理合约。
        AuctionContractV1 logicV1 = AuctionContractV1(addrProxy);

        // 错误。时间未开始。 time not begin
        vm.prank(user1);
        vm.expectRevert();
        logicV1.bidAuction{value: 102}(auctionId);

        // 开始了。
        vm.warp(block.timestamp + 3);

        // 错误。余额不足。  EvmError: OutOfFunds
        // vm.prank(user1);
        // vm.expectRevert(); // EVM 报错。无法这里捕获。
        // logicV1.bidAuction{value: 900000000}(auctionId);

        // 错误。金额太低。 amount is smaller than minPrice
        vm.prank(user1);
        vm.expectRevert();
        logicV1.bidAuction{value: 22}(auctionId);

        // 出价成功。
        uint amount1 = 101;
        vm.prank(user1);
        uint256 bid1 = logicV1.bidAuction{value: amount1}(auctionId);
        console.log(unicode"   出价 = ", bid1);

        // 查看。
        AuctionData memory auctionA = logicV1.queryAuction(auctionId);
        require(auctionA.bidder == user1, "bidder not match");
        require(auctionA.bidPrice == amount1, "bidPrice not match");

        // 错误。不能重复出价。 bid repeated
        vm.prank(user1);
        vm.expectRevert();
        logicV1.bidAuction{value: 101}(auctionId);

        // 错误。出价不够。 amount is smaller than minPrice
        vm.prank(user2);
        vm.expectRevert();
        logicV1.bidAuction{value: 100}(auctionId);

        // 出价成功。 价格更高。
        vm.prank(user2);
        uint256 bid2 = logicV1.bidAuction{value: 103}(auctionId);
        console.log(unicode"   出价 = ", bid2);

        // 查看。
        AuctionData memory auctionB = logicV1.queryAuction(auctionId);
        require(auctionB.bidder == user2, "bidder not match");
        require(auctionB.bidPrice == 103, "bidPrice not match");
    }

    // 升级。
    function test_Upgrade() public {
        console.log(unicode"\n>> 测试，升级。");
        // 使用代理合约。
        AuctionContractV1 logicV1 = AuctionContractV1(addrProxy);

        // NFT 授权。
        vm.prank(userOwner);
        nft.approve(addrProxy, tokenApple);

        // V1 创建1个拍卖。
        vm.prank(userOwner);
        uint256 auctionId = logicV1.createAuction(
            addrNft,
            tokenApple,
            100,
            block.timestamp + 1,
            6 minutes
        );
        console.log(unicode"  V1 创建的拍卖 = ", auctionId);

        // vm.prank(user1);
        // logicV1.bidAuction{value: 102}(auctionId);
    }

    function testFuzz_SetNumber(uint256 x) public {}
}
