// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {
    TimelockController
} from "lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";

contract SomeBiz {
    uint256 public borrowRate; // 某个关键参数。

    address public admin; // 管理员。 timelock合约。 【核心】

    constructor(address admin_) {
        admin = admin_;
        borrowRate = 1;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    // 修改关键参数。
    function setBorrowRate(uint256 borrowRate_) public onlyAdmin {
        borrowRate = borrowRate_;
    }

    // 关键函数。
    function settle() public onlyAdmin returns (uint256 ret) {
        ret = 3000;
    }
}
