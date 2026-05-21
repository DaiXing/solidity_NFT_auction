// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
// import {Counter} from "../src/Counter.sol";
import {IAuction, AuctionData, AuctionState} from "../src/AuctionV1.sol";
import {AuctionContractV1} from "../src/AuctionV1.sol";
import {AuctionContractV2} from "../src/AuctionV2.sol";
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

    // 初始化金额。
    uint256 initAmount = 2000;

    function setUp() public {
        // 发币。
        deal(userOwner, initAmount);
        deal(user1, initAmount);
        deal(user2, initAmount);

        // 设置时间
        vm.warp(300000000);

        vm.startPrank(userOwner);
        auctionV1 = new AuctionContractV1();
        auctionV2 = new AuctionContractV2();
        addrAuctionV1 = address(auctionV1);
        addrAuctionV2 = address(auctionV2);

        // 初始化。
        bytes memory funcData = abi.encodeWithSignature(
            "initialize(string)",
            "deploy V1"
        );

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
        IAuction auctionContract = IAuction(addrProxy);

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
        IAuction logic = IAuction(addrProxy);

        // NFT 授权。
        vm.prank(userOwner);
        nft.approve(addrProxy, tokenApple);

        // 创建1个拍卖。
        vm.prank(userOwner);
        uint256 auctionId = logic.createAuction(
            addrNft,
            tokenApple,
            100,
            block.timestamp + 1 minutes, // 开始时间
            6 minutes // 持续时间
        );

        // token 的 owner 变化了。
        address tokenOwnerB = nft.ownerOf(tokenApple);
        require(tokenOwnerB == addrProxy, "token owner not match");
        require(tokenOwnerB != userOwner, "token owner not match");

        return auctionId;
    }

    // 出价。结束。
    function test_BidAuctionAndEnd() public {
        console.log(unicode"\n>> 测试，出价，结束。");

        uint256 auctionId = createAuctionForTokenApple();
        console.log(unicode"   创建的拍卖 = ", auctionId);

        // 使用代理合约。
        IAuction logicV1 = IAuction(addrProxy);

        // 错误。时间未开始。 time not begin
        vm.prank(user1);
        vm.expectRevert();
        logicV1.bidAuction{value: 102}(auctionId);

        // 开始了。
        vm.warp(block.timestamp + 3 minutes);

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
        uint256 amount2 = 103;
        vm.prank(user2);
        uint256 bid2 = logicV1.bidAuction{value: amount2}(auctionId);
        console.log(unicode"   出价 = ", bid2);

        // 查看。
        AuctionData memory auctionB = logicV1.queryAuction(auctionId);
        require(auctionB.bidder == user2, "bidder not match");
        require(auctionB.bidPrice == amount2, "bidPrice not match");

        // 查看余额。
        console.log(unicode"   user1 余额 = ", user1.balance);
        console.log(unicode"   user2 余额 = ", user2.balance);
        require(user1.balance == initAmount, "user1 balance not match");
        require(
            user2.balance + amount2 == initAmount,
            "user2 balance not match"
        );

        // 错误。 已经开始的，不能取消。  auction has begun
        vm.prank(userOwner);
        vm.expectRevert();
        logicV1.cancelAuction(auctionId);

        // 错误。 未到结束时间。  end time not match
        vm.prank(userOwner);
        vm.expectRevert();
        logicV1.endAuction(auctionId);

        // 正常结束。
        // mock 结束时间。
        vm.warp(block.timestamp + 22 minutes);
        vm.prank(userOwner);
        logicV1.endAuction(auctionId);
        console.log(unicode"   拍卖，正常结束了");

        // token 给 user2
        address tokenOwner = nft.ownerOf(tokenApple);
        console.log(unicode"   token owner = ", tokenOwner);
        require(tokenOwner == user2, "tokenOwner not match");

        // 钱 给 userOwner
        uint256 balanceB = userOwner.balance;
        console.log(unicode"   userOwner balance = ", balanceB);
        require(
            balanceB == initAmount + amount2,
            "userOwner balance not match"
        );

        // 查看。 状态。
        AuctionData memory auctionC = logicV1.queryAuction(auctionId);
        console.log(unicode"   AuctionState = ", uint256(auctionC.state));
        require(
            auctionC.state == AuctionState.Success,
            "AuctionState not match"
        );

        // 查描述。
        (string memory descB, uint256 auctionIdB, uint256 bidIdB) = logicV1
            .queryDesc();
        console.log(unicode" 在出价、结束之后：");
        console.log("  descB = ", descB);
        console.log("  auctionIdB = ", auctionIdB);
        console.log("  bidIdB = ", bidIdB);
    }

    // 取消。
    function test_CancelAuction() public {
        console.log(unicode"\n>> 测试，取消。");
        uint256 auctionId = createAuctionForTokenApple();

        IAuction logic = IAuction(addrProxy);

        // 前面取值也不起作用。后面一直都当前值。
        uint256 now = block.timestamp;
        uint256 now2 = now;
        console.log("  now = ", now);

        // 只有创建者，才能取消。  not auction owner
        vm.prank(user2);
        vm.expectRevert();
        logic.cancelAuction(auctionId);

        // 已经过了时间，不能取消了。 auction has begun
        vm.prank(userOwner);
        vm.warp(block.timestamp + 1 hours); // 时间过了。
        vm.expectRevert();
        logic.cancelAuction(auctionId);

        console.log("  now  = ", now);
        console.log("  now2 = ", now2);

        // 正常取消。
        vm.prank(userOwner);
        vm.warp(block.timestamp - 1 hours);
        logic.cancelAuction(auctionId);
        console.log("  cancel OK ");

        // 查询。
        AuctionData memory auctionData = logic.queryAuction(auctionId);
        console.log("  state = ", uint256(auctionData.state));
        require(auctionData.state == AuctionState.Cancel, "state not match");

        // token 返回给 owner
        address tokenOwner = nft.ownerOf(tokenApple);
        console.log("  tokenOwner = ", tokenOwner);
        require(tokenOwner == userOwner, "tokenOwner not match");

        // 不能重复取消。 state is not Normal
        vm.prank(userOwner);
        vm.expectRevert();
        logic.cancelAuction(auctionId);
    }

    // 升级。
    function test_Upgrade() public {
        console.log(unicode"\n>> 测试，升级。");
        // V1
        AuctionContractV1 logicV1 = AuctionContractV1(addrProxy);

        // 创建拍卖。
        uint256 auctionId = createAuctionForTokenApple();
        console.log("  create auctionId = ", auctionId);

        // 查描述。
        (string memory descB, uint256 auctionIdB, uint256 bidIdB) = logicV1
            .queryDesc();
        console.log(unicode" 升级之前：");
        console.log("  descB = ", descB);
        console.log("  auctionIdB = ", auctionIdB);
        console.log("  bidIdB = ", bidIdB);

        // 查拍卖。
        AuctionData memory auctionBefore = logicV1.queryAuction(auctionId);
        console.log("  AuctionData seller = ", auctionBefore.seller);
        require(auctionBefore.seller > address(0), "seller invalid");

        // 升级。
        vm.prank(userOwner); // 必须是owner
        bytes memory funcData = abi.encodeWithSignature(
            "upgradeV2(string)",
            "to V2"
        );
        logicV1.upgradeToAndCall(addrAuctionV2, funcData);

        // 查描述。
        (string memory descC, uint256 auctionIdC, uint256 bidIdC) = logicV1
            .queryDesc();
        console.log(unicode" 升级之前：");
        console.log("  descC = ", descC);
        console.log("  auctionIdC = ", auctionIdC);
        console.log("  bidIdC = ", bidIdC);

        // 查拍卖。
        AuctionData memory auctionAfter = logicV1.queryAuction(auctionId);
        console.log("  AuctionData seller = ", auctionAfter.seller);
        require(auctionAfter.seller > address(0), "seller invalid");

        // 数据，相同。
        console.log(unicode" 数据必须相同。");
        require(
            auctionAfter.seller == auctionBefore.seller,
            "seller not match"
        );
        require(auctionIdB == auctionIdC, "auctionId not match");

        // 使用V2的新方法。
        console.log(unicode" 使用V2的新方法：");
        AuctionContractV2 logicV2 = AuctionContractV2(addrProxy);
        logicV2.addCounter();
        uint256 counter = logicV2.addCounter();
        console.log("  counter = ", counter);
        require(counter == 202, "  V2 counter not match");
    }

    function testFuzz_SetNumber(uint256 x) public {}
}
