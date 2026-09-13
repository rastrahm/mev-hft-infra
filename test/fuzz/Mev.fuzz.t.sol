// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {AtomicArbitrageSolver} from "../../src/AtomicArbitrageSolver.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MockAMM} from "../../src/mocks/MockAMM.sol";
import {MockRouter} from "../../src/mocks/MockRouter.sol";
import {MevErrors} from "../../src/errors/MevErrors.sol";
import {Route} from "../../src/libraries/CalldataCodec.sol";

/**
 * @title MevFuzzTest
 * @notice Fase 5: fuzz de volumen, tip (bps del ETH del solver) y slippage.
 */
contract MevFuzzTest is Test {
    MockERC20 internal tokenIn;
    MockERC20 internal tokenOut;
    MockAMM internal ammA;
    MockAMM internal ammB;
    MockRouter internal routerA;
    MockRouter internal routerB;
    AtomicArbitrageSolver internal solver;

    address internal owner;
    address internal searcher;
    address internal builder;

    uint256 internal constant SOLVER_ETH = 10 ether;
    uint256 internal constant SOLVER_TOKENS = 200 ether;

    function setUp() public {
        owner = makeAddr("owner");
        searcher = makeAddr("searcher");
        builder = makeAddr("builder");
        vm.coinbase(builder);

        tokenIn = new MockERC20("TIN", "TIN");
        tokenOut = new MockERC20("TOUT", "TOUT");

        ammA = new MockAMM(address(tokenIn), address(tokenOut));
        ammB = new MockAMM(address(tokenIn), address(tokenOut));
        routerA = new MockRouter(address(ammA));
        routerB = new MockRouter(address(ammB));

        solver = new AtomicArbitrageSolver(searcher, owner);

        tokenIn.mint(address(ammA), 500 ether);
        tokenOut.mint(address(ammA), 2000 ether);
        ammA.setReserves(500 ether, 2000 ether);

        tokenIn.mint(address(ammB), 500 ether);
        tokenOut.mint(address(ammB), 500 ether);
        ammB.setReserves(500 ether, 500 ether);

        tokenIn.mint(address(solver), SOLVER_TOKENS);
        vm.deal(address(solver), SOLVER_ETH);
    }

    function _route(uint256 minA, uint256 minB) internal view returns (Route memory) {
        return Route({
            tokenIn: address(tokenIn),
            tokenOut: address(tokenOut),
            routerA: address(routerA),
            routerB: address(routerB),
            amountOutMinA: minA,
            amountOutMinB: minB
        });
    }

    /**
     * @notice Volumen de trade en rango seguro: execute rentable con tip = tipBps/10000 del ETH.
     * @param amountInRaw Input fuzzed.
     * @param tipBps Tip en basis points del balance ETH del solver (0–5000 = 0–50%).
     */
    function testFuzz_volumeAndTip_profitable(uint256 amountInRaw, uint16 tipBps) public {
        uint256 amountIn = bound(amountInRaw, 0.1 ether, 40 ether);
        tipBps = uint16(bound(tipBps, 0, 5000));
        uint256 tipWei = (SOLVER_ETH * uint256(tipBps)) / 10_000;

        uint256 builderBefore = builder.balance;

        vm.prank(searcher);
        uint256 profit = solver.execute(_route(1, 1), amountIn, 1, tipWei);

        assertGt(profit, 0);
        assertEq(builder.balance, builderBefore + tipWei);
    }

    /**
     * @notice Slippage imposible en hop A → revert; tip no se paga.
     * @param amountInRaw Input fuzzed.
     * @param tipWeiRaw Tip fuzzed (acotado al ETH del solver).
     */
    function testFuzz_slippageTooHigh_revertsWithoutTip(uint256 amountInRaw, uint256 tipWeiRaw) public {
        uint256 amountIn = bound(amountInRaw, 0.1 ether, 40 ether);
        uint256 tipWei = bound(tipWeiRaw, 0, SOLVER_ETH);
        uint256 builderBefore = builder.balance;

        // amountOutMinA absurdo → MockAMM.SlippageExceeded
        Route memory route = _route(type(uint128).max, 1);

        vm.prank(searcher);
        vm.expectRevert(MockAMM.SlippageExceeded.selector);
        solver.execute(route, amountIn, 0, tipWei);

        assertEq(builder.balance, builderBefore);
    }

    /**
     * @notice Pools planos: cualquier volumen + tip → NegativeEV sin bribe residual.
     * @param amountInRaw Input fuzzed.
     * @param tipWeiRaw Tip fuzzed.
     * @param minProfitRaw minProfit fuzzed (≥1).
     */
    function testFuzz_flatPools_alwaysNegativeEV_noTip(uint256 amountInRaw, uint256 tipWeiRaw, uint256 minProfitRaw)
        public
    {
        ammA.setReserves(500 ether, 500 ether);
        ammB.setReserves(500 ether, 500 ether);

        uint256 amountIn = bound(amountInRaw, 0.1 ether, 40 ether);
        uint256 tipWei = bound(tipWeiRaw, 0, SOLVER_ETH);
        uint256 minProfit = bound(minProfitRaw, 1, type(uint64).max);
        uint256 builderBefore = builder.balance;

        vm.prank(searcher);
        vm.expectRevert(MevErrors.NegativeEV.selector);
        solver.execute(_route(1, 1), amountIn, minProfit, tipWei);

        assertEq(builder.balance, builderBefore);
    }

    /**
     * @notice Tip bps alto pero oportunidad rentable: tip se paga y profit ≥ minProfit.
     * @param tipBps Basis points 0–9000 del ETH del solver.
     */
    function testFuzz_tipBps_onProfitablePath(uint16 tipBps) public {
        tipBps = uint16(bound(tipBps, 0, 9000));
        uint256 tipWei = (SOLVER_ETH * uint256(tipBps)) / 10_000;
        uint256 amountIn = 5 ether;

        vm.prank(searcher);
        uint256 profit = solver.execute(_route(1, 1), amountIn, 1, tipWei);
        assertGt(profit, 0);
        assertEq(builder.balance, tipWei);
    }
}
