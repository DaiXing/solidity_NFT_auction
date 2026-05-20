// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// import "@openzeppelin/contracts22/token/ERC721/ERC721Upgradeable.sol";
// import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
// import "lib/openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";

contract BirdProxy is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    // 禁用构造函数。
    constructor() {
        _disableInitializers(); // 只能初始化1次。
    }

    // 初始化。
    function initialize() public initializer {
        // 调用者为owner。
        __Ownable_init(msg.sender);
        // __UUPs
    }

    // 授权升级。
    function _authorizeUpgrade(address newImpl) internal override onlyOwner {}
}
