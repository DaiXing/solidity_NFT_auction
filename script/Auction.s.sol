// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {AuctionContractV1} from "../src/AuctionV1.sol";
import {
    ERC1967Proxy
} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AuctionScript is Script {
    function setUp() public {}

    function run() public {
        console.log(unicode"开始部署 Auction");
        string memory privateKeyStr = vm.envString("ETH_PRIVATE_KEY");
        // console.log("privateKeyStr = ", privateKeyStr);
        uint256 privateKeyInt = vm.parseUint(privateKeyStr);

        vm.startBroadcast(privateKeyInt);

        // 拍卖。
        AuctionContractV1 auctionV1 = new AuctionContractV1();
        address addrAuctionV1 = address(auctionV1);

        // 初始化。
        bytes memory funcData = abi.encodeWithSignature(
            "initialize(string)",
            "deploy V1"
        );

        // 配置代理。
        ERC1967Proxy proxy = new ERC1967Proxy(addrAuctionV1, funcData);
        console.log("proxy addr ", address(proxy));

        vm.stopBroadcast();
    }
}
