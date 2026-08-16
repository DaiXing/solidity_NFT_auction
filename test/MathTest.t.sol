// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {FixedPointMathLib} from "lib/solmate/src/utils/FixedPointMathLib.sol";

import {Math } from "lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

contract MathTest is Test {

    using FixedPointMathLib for uint256;
    using Math for uint256;

    function setUp() public {
    }

    function testOzMath () public {
        console.log("\n    testOzMath");
        uint256 aa = 2;
        uint256 bb = 3;
        console.log("   min",Math.min(aa, bb));// min 2
        console.log("   max",Math.max(aa, bb));// max 3
        console.log("   average",Math.average(aa, bb));// average 2
    }

    function testFixedPointMathLib () public {
        console.log("\n    testFixedPointMathLib");
        uint256 aa = 3;
        uint256 rate = 231*1e17;

        // 乘法。（四舍五入）
        console.log("   mulWadDown",aa.mulWadDown(rate));// mulWadDown 69
        console.log("   mulWadUp",aa.mulWadUp(rate));// mulWadUp 70

        // 除法。（四舍五入）
        uint256 bb = 697;
        console.log("   divWadDown",bb.divWadDown(rate));// divWadDown 30
        console.log("   divWadUp",bb.divWadUp(rate));// divWadUp 31

        // 乘法+除法。
        uint256 e1 = 3;
        uint256 e2 = 4;
        uint256 e3 = 2;
        console.log("   mulDiv",e1.mulDiv(e2, e3));// mulDiv 6
    }

}