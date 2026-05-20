// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Counter} from "../src/Counter.sol";
import {AuctionContractV1} from "../src/NftAuctionV1.sol";
import {AuctionContractV2} from "../src/NftAuctionV2.sol";
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

    address userOwner = address(0xAA01);
    address user1 = address(0xBB01);
    address user2 = address(0xBB02);

    function setUp() public {
        vm.startPrank(userOwner);
        auctionV1 = new AuctionContractV1();
        auctionV2 = new AuctionContractV2();
        addrAuctionV1 = address(auctionV1);
        addrAuctionV2 = address(auctionV2);

        // 初始化。
        bytes memory funcData = abi.encodeWithSignature("initialize()", ());

        // 配置代理。
        proxy = new ERC1967Proxy(addrAuctionV1, funcData);
        addrProxy = address(proxy);
        vm.stopPrank();

        deal(user1, 2000);
    }

    function test_Increment() public {}

    function testFuzz_SetNumber(uint256 x) public {}
}
