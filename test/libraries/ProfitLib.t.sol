// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {MevErrors} from "../../src/errors/MevErrors.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {ProfitLibHarness} from "../helpers/LibHarnesses.sol";

/**
 * @title ProfitLibTest
 * @notice Unit tests de snapshot / requireProfit / netProfit.
 */
contract ProfitLibTest is Test {
    ProfitLibHarness internal harness;
    MockERC20 internal token;

    function setUp() public {
        harness = new ProfitLibHarness();
        token = new MockERC20("Mock", "MCK");
    }

    function test_snapshot_erc20() public {
        token.mint(address(harness), 1_000 ether);
        assertEq(harness.snapshot(address(token)), 1_000 ether);
    }

    function test_snapshot_eth() public {
        vm.deal(address(harness), 5 ether);
        assertEq(harness.snapshot(address(0)), 5 ether);
    }

    function test_requireProfit_ok() public view {
        harness.requireProfit(100, 150, 50);
        harness.requireProfit(100, 200, 50);
        harness.requireProfit(0, 0, 0);
    }

    function test_requireProfit_revertsWhenFinalBelowInitial() public {
        vm.expectRevert(MevErrors.NegativeEV.selector);
        harness.requireProfit(100, 99, 0);
    }

    function test_requireProfit_revertsWhenBelowMinProfit() public {
        vm.expectRevert(MevErrors.NegativeEV.selector);
        harness.requireProfit(100, 149, 50);
    }

    function test_netProfit_ok() public view {
        assertEq(harness.netProfit(100, 175), 75);
        assertEq(harness.netProfit(50, 50), 0);
    }

    function test_netProfit_revertsOnLoss() public {
        vm.expectRevert(MevErrors.NegativeEV.selector);
        harness.netProfit(100, 90);
    }

    function testFuzz_requireProfit(uint128 initial, uint128 delta, uint128 minProfit) public view {
        uint256 final_ = uint256(initial) + uint256(delta);
        if (delta >= minProfit) {
            harness.requireProfit(initial, final_, minProfit);
        }
    }

    function testFuzz_requireProfit_reverts(uint128 initial, uint128 minProfit) public {
        minProfit = uint128(bound(minProfit, 1, type(uint128).max));
        uint256 final_ = uint256(initial) + uint256(minProfit) - 1;
        vm.expectRevert(MevErrors.NegativeEV.selector);
        harness.requireProfit(initial, final_, minProfit);
    }
}
