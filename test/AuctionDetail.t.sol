// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IAuction, AuctionData, AuctionState} from "../src/AuctionV1.sol";
import {AuctionContractV1} from "../src/AuctionV1.sol";
import {AuctionContractV2} from "../src/AuctionV2.sol";
import {MySimpleNFT} from "../src/NftOnly.sol";
import {
    ERC1967Proxy
} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AuctionDetailTest is Test {
    AuctionContractV1 auctionV1; // V1
    AuctionContractV2 auctionV2; // V2
    ERC1967Proxy proxy; // 代理。

    address addrAuctionV1;
    address addrAuctionV2;
    address addrProxy;

    MySimpleNFT nft; // NFT
    address addrNft;

    address userOwner = address(0xAA01);
    address user1 = address(0xBB01);
    address user2 = address(0xBB02);

    // token
    uint256 tokenApple;
    uint256 tokenOrange;

    uint256 initAmount = 2000;

    // 拍卖。
    IAuction auctionContract;
    // uint256 auctionId;

    function setUp() public {
        // 发币
        deal(userOwner, initAmount);
        deal(user1, initAmount);
        deal(user2, initAmount);

        // 设置时间
        vm.warp(300000000);

        vm.startPrank(userOwner);

        // 部署合约
        auctionV1 = new AuctionContractV1();
        auctionV2 = new AuctionContractV2();
        addrAuctionV1 = address(auctionV1);
        addrAuctionV2 = address(auctionV2);

        // 初始化代理
        bytes memory funcData = abi.encodeWithSignature(
            "initialize(string)",
            "deploy V1"
        );
        proxy = new ERC1967Proxy(addrAuctionV1, funcData);
        addrProxy = address(proxy);
        auctionContract = IAuction(addrProxy);

        // 铸造NFT
        nft = new MySimpleNFT();
        addrNft = address(nft);
        tokenApple = nft.mintToken("http://aa.com/apple.json");
        tokenOrange = nft.mintToken("http://aa.com/orange.json");

        vm.stopPrank();
    }

    // ==================== 创建拍卖测试 ====================

    function test_CreateAuction_NotTokenOwner() public {
        console.log(unicode"\n>> 测试：非token owner创建拍卖，应失败");
        vm.prank(user2);
        vm.expectRevert();
        auctionContract.createAuction(
            addrNft,
            tokenApple,
            100,
            block.timestamp + 1,
            5
        );
    }

    function test_CreateAuction_TokenNotExist() public {
        console.log(unicode"\n>> 测试：token不存在，应失败");
        vm.prank(userOwner);
        vm.expectRevert();
        auctionContract.createAuction(
            addrNft,
            uint256(9999),
            100,
            block.timestamp + 1,
            5
        );
    }

    function test_CreateAuction_InvalidBeginTime() public {
        console.log(unicode"\n>> 测试：开始时间无效，应失败");
        vm.prank(userOwner);
        vm.expectRevert();
        auctionContract.createAuction(
            addrNft,
            tokenApple,
            100,
            block.timestamp - 99999,
            5
        );
    }

    function test_CreateAuction_PeriodTooShort() public {
        console.log(unicode"\n>> 测试：持续时间太短，应失败");
        vm.prank(userOwner);
        vm.expectRevert();
        auctionContract.createAuction(
            addrNft,
            tokenApple,
            100,
            block.timestamp + 1,
            3 seconds
        );
    }

    function test_CreateAuction_NoApprove() public {
        console.log(unicode"\n>> 测试：NFT未授权，应失败");
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

    function test_CreateAuction_Success() public {
        console.log(unicode"\n>> 测试：成功创建拍卖");
        _createAuctionForTokenApple();

        // 验证token owner变更为代理地址
        address tokenOwnerB = nft.ownerOf(tokenApple);
        assertEq(tokenOwnerB, addrProxy, "token owner not match");
        assertTrue(
            tokenOwnerB != userOwner,
            "token owner should not be userOwner"
        );
    }

    // ==================== 出价测试 ====================

    function test_BidAuction_BeforeStartTime() public {
        console.log(unicode"\n>> 测试：拍卖开始前出价，应失败");
        uint256 auctionId = _createAuctionForTokenApple();

        vm.prank(user1);
        vm.expectRevert();
        auctionContract.bidAuction{value: 102}(auctionId);
    }

    function test_BidAuction_AmountTooLow() public {
        console.log(unicode"\n>> 测试：出价金额低于底价，应失败");
        uint256 auctionId = _createAuctionForTokenApple();
        _skipToAuctionStart();

        vm.prank(user1);
        vm.expectRevert();
        auctionContract.bidAuction{value: 22}(auctionId);
    }

    function test_BidAuction_Success() public {
        console.log(unicode"\n>> 测试：成功出价");
        uint256 auctionId = _createAuctionForTokenApple();
        _skipToAuctionStart();

        uint256 amount = 101;
        vm.prank(user1);
        uint256 bidId = auctionContract.bidAuction{value: amount}(auctionId);

        assertTrue(bidId > 0, "bidId should be > 0");

        AuctionData memory auction = auctionContract.queryAuction(auctionId);
        assertEq(auction.bidder, user1, "bidder not match");
        assertEq(auction.bidPrice, amount, "bidPrice not match");
    }

    function test_BidAuction_RepeatedBid() public {
        console.log(unicode"\n>> 测试：重复出价，应失败");
        uint256 auctionId = _createAuctionForTokenApple();
        _skipToAuctionStart();

        vm.prank(user1);
        auctionContract.bidAuction{value: 101}(auctionId);

        vm.prank(user1);
        vm.expectRevert();
        auctionContract.bidAuction{value: 101}(auctionId);
    }

    function test_BidAuction_Outbid() public {
        console.log(unicode"\n>> 测试：被更高价超越");
        uint256 auctionId = _createAuctionForTokenApple();
        _skipToAuctionStart();

        vm.prank(user1);
        auctionContract.bidAuction{value: 101}(auctionId);

        vm.prank(user2);
        uint256 amount2 = 103;
        uint256 bidId2 = auctionContract.bidAuction{value: amount2}(auctionId);

        AuctionData memory auction = auctionContract.queryAuction(auctionId);
        assertEq(auction.bidder, user2, "bidder should be user2");
        assertEq(auction.bidPrice, amount2, "bidPrice not match");
    }

    function test_BidAuction_BalanceCheck() public {
        console.log(unicode"\n>> 测试：出价后余额检查");
        uint256 auctionId = _createAuctionForTokenApple();
        _skipToAuctionStart();

        uint256 amount = 103;
        vm.prank(user2);
        auctionContract.bidAuction{value: amount}(auctionId);

        assertEq(user1.balance, initAmount, "user1 balance should not change");
        assertEq(user2.balance, initAmount - amount, "user2 balance incorrect");
    }

    // ==================== 结束拍卖测试 ====================

    function test_EndAuction_BeforeEndTime() public {
        console.log(unicode"\n>> 测试：结束时间未到，应失败");
        uint256 auctionId = _createAuctionForTokenApple();
        _skipToAuctionStart();

        vm.prank(user1);
        auctionContract.bidAuction{value: 101}(auctionId);

        vm.prank(userOwner);
        vm.expectRevert();
        auctionContract.endAuction(auctionId);
    }

    function test_EndAuction_Success() public {
        console.log(unicode"\n>> 测试：成功结束拍卖");
        uint256 auctionId = _createAuctionForTokenApple();
        _skipToAuctionStart();

        uint256 amount = 103;
        vm.prank(user2);
        auctionContract.bidAuction{value: amount}(auctionId);

        _skipToAuctionEnd();

        vm.prank(userOwner);
        auctionContract.endAuction(auctionId);

        // 验证token转移
        address tokenOwner = nft.ownerOf(tokenApple);
        assertEq(tokenOwner, user2, "tokenOwner not match");

        // 验证资金转移
        assertEq(
            userOwner.balance,
            initAmount + amount,
            "userOwner balance not match"
        );

        // 验证状态
        AuctionData memory auction = auctionContract.queryAuction(auctionId);
        assertEq(
            uint256(auction.state),
            uint256(AuctionState.Success),
            "AuctionState not match"
        );
    }

    function test_EndAuction_NoBid() public {
        console.log(unicode"\n>> 测试：无人出价结束拍卖");
        uint256 auctionId = _createAuctionForTokenApple();
        _skipToAuctionEnd();

        vm.prank(userOwner);
        auctionContract.endAuction(auctionId);

        // token应返回给卖家
        address tokenOwner = nft.ownerOf(tokenApple);
        assertEq(tokenOwner, userOwner, "tokenOwner should return to seller");

        AuctionData memory auction = auctionContract.queryAuction(auctionId);
        assertEq(
            uint256(auction.state),
            uint256(AuctionState.Fail),
            "AuctionState should be Failed"
        );
    }

    // ==================== 取消拍卖测试 ====================

    function test_CancelAuction_NotOwner() public {
        console.log(unicode"\n>> 测试：非创建者取消，应失败");
        uint256 auctionId = _createAuctionForTokenApple();

        vm.prank(user2);
        vm.expectRevert();
        auctionContract.cancelAuction(auctionId);
    }

    function test_CancelAuction_AfterStart() public {
        console.log(unicode"\n>> 测试：拍卖开始后取消，应失败");
        uint256 auctionId = _createAuctionForTokenApple();
        _skipToAuctionStart();

        vm.prank(userOwner);
        vm.expectRevert();
        auctionContract.cancelAuction(auctionId);
    }

    function test_CancelAuction_Success() public {
        console.log(unicode"\n>> 测试：成功取消拍卖");
        uint256 auctionId = _createAuctionForTokenApple();

        vm.prank(userOwner);
        auctionContract.cancelAuction(auctionId);

        // 验证状态
        AuctionData memory auction = auctionContract.queryAuction(auctionId);
        assertEq(
            uint256(auction.state),
            uint256(AuctionState.Cancel),
            "state not match"
        );

        // 验证token返回
        address tokenOwner = nft.ownerOf(tokenApple);
        assertEq(tokenOwner, userOwner, "tokenOwner not match");
    }

    function test_CancelAuction_RepeatedCancel() public {
        console.log(unicode"\n>> 测试：重复取消，应失败");
        uint256 auctionId = _createAuctionForTokenApple();

        vm.prank(userOwner);
        auctionContract.cancelAuction(auctionId);

        vm.prank(userOwner);
        vm.expectRevert();
        auctionContract.cancelAuction(auctionId);
    }

    // ==================== 升级测试 ====================

    function test_Upgrade_DataPreserved() public {
        console.log(unicode"\n>> 测试：升级后数据保持不变");
        uint256 auctionId = _createAuctionForTokenApple();

        AuctionData memory auctionBefore = auctionContract.queryAuction(
            auctionId
        );

        // 升级
        _upgradeToV2();

        AuctionData memory auctionAfter = auctionContract.queryAuction(
            auctionId
        );
        assertEq(auctionAfter.seller, auctionBefore.seller, "seller not match");
        assertEq(
            auctionAfter.nftContract,
            auctionBefore.nftContract,
            "nftAddr not match"
        );
        assertEq(
            auctionAfter.tokenId,
            auctionBefore.tokenId,
            "tokenId not match"
        );
        assertEq(
            auctionAfter.minPrice,
            auctionBefore.minPrice,
            "minPrice not match"
        );
    }

    function test_Upgrade_NewFunctionality() public {
        console.log(unicode"\n>> 测试：升级后新功能可用");
        _upgradeToV2();

        AuctionContractV2 logicV2 = AuctionContractV2(addrProxy);
        logicV2.addCounter();
        uint256 counter = logicV2.addCounter();

        assertEq(counter, 202, "V2 counter not match");
    }

    function test_Upgrade_QueryDescChanged() public {
        console.log(unicode"\n>> 测试：升级后描述信息更新");
        _createAuctionForTokenApple();

        (string memory descBefore, , ) = auctionContract.queryDesc();

        _upgradeToV2();

        (string memory descAfter, , ) = auctionContract.queryDesc();
        assertTrue(
            keccak256(bytes(descAfter)) != keccak256(bytes(descBefore)),
            "desc should change after upgrade"
        );
    }

    // ==================== 查询功能测试 ====================

    function test_QueryAuction_Existing() public {
        console.log(unicode"\n>> 测试：查询存在的拍卖");
        uint256 auctionId = _createAuctionForTokenApple();

        AuctionData memory auction = auctionContract.queryAuction(auctionId);
        assertEq(auction.seller, userOwner, "seller not match");
        assertEq(auction.nftContract, addrNft, "nftAddr not match");
        assertEq(auction.tokenId, tokenApple, "tokenId not match");
        assertEq(auction.minPrice, 100, "minPrice not match");
        assertEq(
            uint256(auction.state),
            uint256(AuctionState.Normal),
            "state should be Normal"
        );
    }

    function test_QueryDesc_Initial() public {
        console.log(unicode"\n>> 测试：查询初始描述");
        (string memory desc, , ) = auctionContract.queryDesc();
        assertEq(desc, "deploy V1", "initial desc not match");
    }

    // ==================== 边界条件测试 ====================

    function test_CreateAuction_MultipleAuctions() public {
        console.log(unicode"\n>> 测试：创建多个拍卖");
        uint256 auctionId1 = _createAuctionForTokenApple();
        uint256 auctionId2 = _createAuctionForTokenOrange();

        assertTrue(auctionId2 > auctionId1, "auctionId should increment");

        AuctionData memory auction1 = auctionContract.queryAuction(auctionId1);
        AuctionData memory auction2 = auctionContract.queryAuction(auctionId2);

        assertEq(auction1.tokenId, tokenApple, "first auction token incorrect");
        assertEq(
            auction2.tokenId,
            tokenOrange,
            "second auction token incorrect"
        );
    }

    function test_BidAuction_ExactMinPrice() public {
        console.log(unicode"\n>> 测试：精确等于底价出价");
        uint256 auctionId = _createAuctionForTokenApple();
        _skipToAuctionStart();

        uint256 amount = 100;
        vm.prank(user1);
        uint256 bidId = auctionContract.bidAuction{value: amount}(auctionId);

        AuctionData memory auction = auctionContract.queryAuction(auctionId);
        assertEq(auction.bidPrice, amount, "bidPrice should equal minPrice");
    }

    function test_BidAuction_ZeroValue() public {
        console.log(unicode"\n>> 测试：零金额出价，应失败");
        uint256 auctionId = _createAuctionForTokenApple();
        _skipToAuctionStart();

        vm.prank(user1);
        vm.expectRevert();
        auctionContract.bidAuction{value: 0}(auctionId);
    }

    // ==================== 辅助方法 ====================

    function _createAuctionForTokenApple() internal returns (uint256) {
        vm.prank(userOwner);
        nft.approve(addrProxy, tokenApple);

        vm.prank(userOwner);
        uint256 id = auctionContract.createAuction(
            addrNft,
            tokenApple,
            100,
            block.timestamp + 1 minutes,
            6 minutes
        );

        return id;
    }

    function _createAuctionForTokenOrange() internal returns (uint256) {
        vm.prank(userOwner);
        nft.approve(addrProxy, tokenOrange);

        vm.prank(userOwner);
        uint256 id = auctionContract.createAuction(
            addrNft,
            tokenOrange,
            100,
            block.timestamp + 1 minutes,
            6 minutes
        );

        return id;
    }

    function _skipToAuctionStart() internal {
        vm.warp(block.timestamp + 3 minutes);
    }

    function _skipToAuctionEnd() internal {
        vm.warp(block.timestamp + 22 minutes);
    }

    function _upgradeToV2() internal {
        vm.prank(userOwner);
        bytes memory funcData = abi.encodeWithSignature(
            "upgradeV2(string)",
            "to V2"
        );

        // V1 升级到 V2
        AuctionContractV1 logicV1 = AuctionContractV1(addrProxy);
        logicV1.upgradeToAndCall(addrAuctionV2, funcData);
    }

    // ==================== Fuzz测试 ====================

    function testFuzz_CreateAuction_DifferentMinPrice(uint256 minPrice) public {
        vm.assume(minPrice > 0 && minPrice < 10000);

        vm.prank(userOwner);
        nft.approve(addrProxy, tokenApple);

        vm.prank(userOwner);
        uint256 id = auctionContract.createAuction(
            addrNft,
            tokenApple,
            minPrice,
            block.timestamp + 1 minutes,
            6 minutes
        );

        AuctionData memory auction = auctionContract.queryAuction(id);
        assertEq(auction.minPrice, minPrice, "minPrice not match");
    }

    function testFuzz_BidAuction_VariousAmounts(uint256 bidAmount) public {
        vm.assume(bidAmount >= 100 && bidAmount < initAmount);

        uint256 auctionId = _createAuctionForTokenApple();
        _skipToAuctionStart();

        vm.prank(user1);
        auctionContract.bidAuction{value: bidAmount}(auctionId);

        AuctionData memory auction = auctionContract.queryAuction(auctionId);
        assertEq(auction.bidPrice, bidAmount, "bidPrice not match");
    }
}
