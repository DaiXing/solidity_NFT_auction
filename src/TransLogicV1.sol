// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {
    Initializable
} from "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

// 透明代理的逻辑合约。
contract TransLogicV1 is Initializable {
    string internal title;
    mapping(address => uint256) internal addrNumMap;

    constructor() {
        _disableInitializers(); // 只能初始化1次。
    }

    // 还是需要这个。
    // 只能调用1次。
    function initialize(string memory title_) public initializer {
        title = title_;
        addrNumMap[msg.sender] += 2000;
    }

    function info() public view returns (string memory title_, uint256 num) {
        title_ = title;
        num = addrNumMap[msg.sender];
    }
}
