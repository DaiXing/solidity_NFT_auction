// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MySimpleNFT} from "../src/NftOnly.sol";

contract MyNftScript is Script {
    function setUp() public {}

    function run() public {
        console.log(unicode"开始部署 NFT");
        string memory privateKeyStr = vm.envString("ETH_PRIVATE_KEY");
        uint256 privateKeyInt = vm.parseUint(privateKeyStr);

        vm.startBroadcast(privateKeyInt);

        MySimpleNFT nft = new MySimpleNFT();
        console.log("nft addr ", address(nft));

        vm.stopBroadcast();
    }
}
