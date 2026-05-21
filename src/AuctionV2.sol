// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AuctionContractV1} from "./AuctionV1.sol";

// 拍卖合约。 V2
contract AuctionContractV2 is AuctionContractV1 {
    // 增加字段。
    uint256 _counter;

    // 增加方法。
    function addCounter() public returns (uint256) {
        _counter++;
        return _counter;
    }

    // 新方法。
    function upgradeV2(string memory desc) public {
        _desc = desc;
        _counter = 200;
    }
}
