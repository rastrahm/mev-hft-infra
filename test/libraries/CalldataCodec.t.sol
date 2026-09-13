// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {MevErrors} from "../../src/errors/MevErrors.sol";
import {Route} from "../../src/libraries/CalldataCodec.sol";
import {CalldataCodecHarness} from "../helpers/LibHarnesses.sol";

/**
 * @title CalldataCodecTest
 * @notice Unit tests de encode/decode packed de Route y amounts (Yul).
 */
contract CalldataCodecTest is Test {
    CalldataCodecHarness internal harness;

    function setUp() public {
        harness = new CalldataCodecHarness();
    }

    function test_encodeDecodeRoute_roundtrip() public view {
        Route memory r = Route({
            tokenIn: address(0xA11),
            tokenOut: address(0xB0B),
            routerA: address(0xAAA1),
            routerB: address(0xBBB2),
            amountOutMinA: 1_000,
            amountOutMinB: 2_000
        });

        bytes memory encoded = harness.encodeRoute(r);
        assertEq(encoded.length, 144);

        Route memory decoded = harness.decodeRoute(encoded);
        assertEq(decoded.tokenIn, r.tokenIn);
        assertEq(decoded.tokenOut, r.tokenOut);
        assertEq(decoded.routerA, r.routerA);
        assertEq(decoded.routerB, r.routerB);
        assertEq(decoded.amountOutMinA, r.amountOutMinA);
        assertEq(decoded.amountOutMinB, r.amountOutMinB);
    }

    function test_decodeRoute_revertsOnBadLength() public {
        bytes memory bad = hex"dead";
        vm.expectRevert(MevErrors.InvalidRoute.selector);
        harness.decodeRoute(bad);
    }

    function test_encodeDecodeAmounts_roundtrip() public view {
        bytes memory encoded = harness.encodeAmounts(123 ether, 1 ether);
        assertEq(encoded.length, 64);
        (uint256 amountIn, uint256 minProfit) = harness.decodeAmounts(encoded);
        assertEq(amountIn, 123 ether);
        assertEq(minProfit, 1 ether);
    }

    function test_decodeAmounts_revertsOnBadLength() public {
        bytes memory bad = hex"01";
        vm.expectRevert(MevErrors.InvalidRoute.selector);
        harness.decodeAmounts(bad);
    }

    function testFuzz_routeRoundtrip(
        address tokenIn,
        address tokenOut,
        address routerA,
        address routerB,
        uint256 amountOutMinA,
        uint256 amountOutMinB
    ) public view {
        Route memory r = Route({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            routerA: routerA,
            routerB: routerB,
            amountOutMinA: amountOutMinA,
            amountOutMinB: amountOutMinB
        });
        Route memory decoded = harness.decodeRoute(harness.encodeRoute(r));
        assertEq(decoded.tokenIn, tokenIn);
        assertEq(decoded.tokenOut, tokenOut);
        assertEq(decoded.routerA, routerA);
        assertEq(decoded.routerB, routerB);
        assertEq(decoded.amountOutMinA, amountOutMinA);
        assertEq(decoded.amountOutMinB, amountOutMinB);
    }

    function testFuzz_amountsRoundtrip(uint256 amountIn, uint256 minProfit) public view {
        (uint256 a, uint256 m) = harness.decodeAmounts(harness.encodeAmounts(amountIn, minProfit));
        assertEq(a, amountIn);
        assertEq(m, minProfit);
    }
}
