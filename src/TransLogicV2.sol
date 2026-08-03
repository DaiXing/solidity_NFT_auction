// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {
    Initializable
} from "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "./TransLogicV1.sol";

// 透明代理的逻辑合约。
contract TransLogicV2 is TransLogicV1 {
    constructor() {
        _disableInitializers(); // 只能初始化1次。
    }

    // 还是需要这个。
    function initializeV2(string memory title_) public {
        title = title_;
    }

    function smileV2() public returns (string memory str) {
        str = "smileV2 function";
    }
}
