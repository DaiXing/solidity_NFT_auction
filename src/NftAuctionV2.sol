// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AuctionContractV1} from "./NftAuctionV1.sol";

// 拍卖合约。 V2
contract AuctionContractV2 is AuctionContractV1 {
    // 增加字段。
    uint256 _counter;

    // 增加方法。
    function addCounter() public returns (uint256) {
        _counter++;
        return _counter;
    }
}
