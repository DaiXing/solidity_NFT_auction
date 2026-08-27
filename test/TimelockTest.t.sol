// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {
    TimelockController
} from "lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {SomeBiz} from "../src/TimeLockUser.sol";

contract TimelockTest is Test {
    TimelockController timelock; // timelock 独立合约。 admin
    SomeBiz someBiz; // 业务合约。 把 timelock 当前 admin 。

    address userJack = address(0xA001); // timelock 的提案人。

    function setUp() public {
        // 设置timelock合约的角色。
        address[] memory proposers = new address[](1);
        proposers[0] = userJack; // 某些人 可以提出提案。
        address[] memory executors = new address[](1);
        executors[0] = address(0); // 任何人。可以执行。

        // 独立部署一个timelock合约。作为admin。
        timelock = new TimelockController(
            1 days, // min延迟
            proposers, // 提案人
            executors, // 执行人
            userJack // 创建人。
        );

        // 业务合约。 把timelock合约作为admin。
        someBiz = new SomeBiz(address(timelock));
    }

    // 改参数。
    function testSetParam() public {
        console.log("\n testSetParam  ");

        address target = address(someBiz); // 目标合约。
        uint256 value = 0; // 转账金额
        bytes memory data = abi.encodeCall(someBiz.setBorrowRate, (666)); // 调用函数
        bytes32 predecessor = bytes32(0); // 前一个操作的id
        bytes32 salt = bytes32(0); // 盐
        uint256 delay = 3 days; // 延迟时间。必须 >= minDelay

        // 生成操作ID。 keccak256
        bytes32 opId = timelock.hashOperation(
            target,
            value,
            data,
            predecessor,
            salt
        );
        console.log("opId = ", vm.toString(opId));

        // 发起一个提案。 调用setBorrowRate函数。 参数是666。 延迟2天执行。
        vm.prank(userJack); // 必须是 提案人。
        timelock.schedule(
            target, // 目标合约。
            value, // 转账金额
            data, // 调用函数
            predecessor, // 前一个操作的id
            salt, // 盐
            delay // 延迟时间。必须 >= minDelay
        );
        console.log("schedule success ");

        // 现在立刻执行。时间还没有到。执行会失败。
        vm.expectRevert();
        // 执行提案。 和schedule的参数一样。
        timelock.execute(target, value, data, predecessor, salt);
        console.log("time not match. so execute fail ");

        uint256 oldRate = someBiz.borrowRate();

        // 时间到了。可以执行了。
        vm.warp(block.timestamp + 5 days);
        timelock.execute(target, value, data, predecessor, salt);
        console.log("time OK , so execute success ");

        uint256 newRate = someBiz.borrowRate();
        console.log("oldRate = ", oldRate);
        console.log("newRate = ", newRate);

        // 已经执行了。不能取消了。
        vm.prank(userJack); // 提案人才能取消。
        vm.expectRevert();
        timelock.cancel(opId);
        console.log("execute done . so cancel fail ");
    }
}
