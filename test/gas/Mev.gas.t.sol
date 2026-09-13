// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MevTestBase} from "../helpers/MevTestBase.sol";
import {CoinbaseTipHarness} from "../helpers/LibHarnesses.sol";
import {BackrunExecutor} from "../../src/BackrunExecutor.sol";

/**
 * @title MevGasTest
 * @notice Fase 7: tip Solidity vs Yul + hot paths arb/backrun (`forge snapshot`).
 */
contract MevGasTest is MevTestBase {
    CoinbaseTipHarness internal tipHarness;
    BackrunExecutor internal backrunEx;

    function setUp() public override {
        super.setUp();
        tipHarness = new CoinbaseTipHarness();
        vm.deal(address(tipHarness), 50 ether);

        backrunEx = new BackrunExecutor(searcher, owner);
        tokenIn.mint(address(backrunEx), 100 ether);
        vm.deal(address(backrunEx), 10 ether);
    }

    /// @notice Tip vía `.call` Solidity.
    function testGas_tip_pay() public {
        tipHarness.pay(0.1 ether);
    }

    /// @notice Tip vía Yul `call` + `coinbase` (path de producción).
    function testGas_tip_payAssembly() public {
        tipHarness.payAssembly(0.1 ether);
    }

    /// @notice Arbitraje rentable sin tip.
    function testGas_arb_execute_noTip() public {
        vm.prank(searcher);
        solver.execute(_profitableRoute(), AMOUNT_IN, 1, 0);
    }

    /// @notice Arbitraje rentable con tip assembly.
    function testGas_arb_execute_withTip() public {
        vm.prank(searcher);
        solver.execute(_profitableRoute(), AMOUNT_IN, 1, 0.05 ether);
    }

    /// @notice Backrun (mismo round-trip optimizado que arb).
    function testGas_backrun_execute_noTip() public {
        vm.prank(searcher);
        backrunEx.backrun(_profitableRoute(), AMOUNT_IN, 1, 0);
    }
}
