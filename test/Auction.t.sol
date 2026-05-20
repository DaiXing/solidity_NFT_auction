// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
// import {Counter} from "../src/Counter.sol";
import {AuctionContractV1} from "../src/NftAuctionV1.sol";
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

    function test_AuctionCreateError() public {
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
    }

    function testFuzz_SetNumber(uint256 x) public {}
}
