// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import "../src/TransLogicV1.sol";
import "../src/TransLogicV2.sol";
import {console} from "forge-std/console.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {
    ProxyAdmin
} from "lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    ERC1967Utils
} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol";

//  透明代理。
contract TransProxyTest is Test {
    TransLogicV1 logicV1; // 逻辑合约

    TransparentUpgradeableProxy proxy; // 透明代理
    address proxyAddr; // 透明代理

    address owner = address(0xA0001);

    address adminAddr; // 管理合约
    ProxyAdmin admin; // 管理合约

    function setUp() public {
        vm.startPrank(owner);

        // 逻辑合约。
        logicV1 = new TransLogicV1();
        address addrLogicV1 = address(logicV1);

        // 初始化
        bytes memory data = abi.encodeCall(logicV1.initialize, ("Logic V1 OK"));

        // 透明代理。
        proxy = new TransparentUpgradeableProxy(addrLogicV1, owner, data);
        proxyAddr = address(proxy);

        // 管理合约。
        // adminAddr = proxy._admin; // 错误。私有字段，看不到。
        // 因为 OZ v5 故意不把 admin 做成对外可见的 getter。
        // 生产里通常部署时就记下 ProxyAdmin 地址，不会事后去挖 slot。
        bytes32 val1 = vm.load(proxyAddr, ERC1967Utils.ADMIN_SLOT);
        adminAddr = address(uint160(uint256(val1)));
        admin = ProxyAdmin(adminAddr);

        vm.stopPrank();
        console.log("proxyAddr =", proxyAddr);
        console.log("adminAddr =", adminAddr);
    }

    // 升级。
    function testUpgrade() public {
        vm.startPrank(owner);

        // 升级前。
        TransLogicV1 logic = TransLogicV1(proxyAddr);
        (string memory title, uint256 num) = logic.info();

        console.log("before upgrade : ");
        console.log("   title = ", title);
        console.log("   num = ", num);

        // 升级
        TransLogicV2 logicV2 = new TransLogicV2();
        bytes memory data2 = abi.encodeCall(
            logicV2.initializeV2,
            ("Logic V2 BB")
        );
        admin.upgradeAndCall(
            // ITransparentUpgradeableProxy(proxy),// 报错。
            ITransparentUpgradeableProxy(address(proxy)), // 正确。
            address(logicV2),
            data2
        );

        // 升级后
        (string memory title2, uint256 num2) = logic.info();
        console.log("after upgrade : ");
        console.log("   title = ", title2);
        console.log("   num = ", num2);

        TransLogicV2 logicV2B = TransLogicV2(proxyAddr);
        string memory val2 = logicV2B.smileV2();
        console.log("   smileV2 = ", val2);

        vm.stopPrank();

        //   before upgrade :
        //      title =  Logic V1 OK
        //      num =  2000
        //   after upgrade :
        //      title =  Logic V2 BB
        //      num =  2000
        //      smileV2 =  smileV2 function
    }
}
