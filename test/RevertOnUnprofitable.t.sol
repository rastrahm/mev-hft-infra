// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {AtomicArbitrageSolver} from "../src/AtomicArbitrageSolver.sol";
import {BackrunExecutor} from "../src/BackrunExecutor.sol";
import {SandwichExecutor} from "../src/SandwichExecutor.sol";
import {SandwichLeg} from "../src/interfaces/ISandwichExecutor.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockAMM} from "../src/mocks/MockAMM.sol";
import {MockRouter} from "../src/mocks/MockRouter.sol";
import {MevErrors} from "../src/errors/MevErrors.sol";
import {Route} from "../src/libraries/CalldataCodec.sol";

/**
 * @title RevertOnUnprofitableTest
 * @notice Fase 5: EV inválido → revert total y **sin** tip residual en coinbase.
 * @dev Cubre arb, backrun y sandwich lab ante movimiento de precio / pools planos.
 */
contract RevertOnUnprofitableTest is Test {
    MockERC20 internal tokenIn;
    MockERC20 internal tokenOut;
    MockAMM internal ammA;
    MockAMM internal ammB;
    MockRouter internal routerA;
    MockRouter internal routerB;

    AtomicArbitrageSolver internal arb;
    BackrunExecutor internal backrunEx;
    SandwichExecutor internal sandwichEx;

    address internal owner;
    address internal searcher;
    address internal builder;

    uint256 internal constant TIP = 0.1 ether;
    uint256 internal constant AMOUNT = 10 ether;

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

        arb = new AtomicArbitrageSolver(searcher, owner);
        backrunEx = new BackrunExecutor(searcher, owner);
        sandwichEx = new SandwichExecutor(searcher, owner);

        _seedFlatPools();
        _fund(address(arb));
        _fund(address(backrunEx));
        _fund(address(sandwichEx));
    }

    function _seedFlatPools() internal {
        tokenIn.mint(address(ammA), 200 ether);
        tokenOut.mint(address(ammA), 200 ether);
        ammA.setReserves(200 ether, 200 ether);

        tokenIn.mint(address(ammB), 200 ether);
        tokenOut.mint(address(ammB), 200 ether);
        ammB.setReserves(200 ether, 200 ether);
    }

    function _fund(address who) internal {
        tokenIn.mint(who, 100 ether);
        vm.deal(who, 5 ether);
    }

    function _route() internal view returns (Route memory) {
        return Route({
            tokenIn: address(tokenIn),
            tokenOut: address(tokenOut),
            routerA: address(routerA),
            routerB: address(routerB),
            amountOutMinA: 1,
            amountOutMinB: 1
        });
    }

    function test_arb_flatPools_revertsWithoutTip() public {
        uint256 tipBefore = builder.balance;
        uint256 ethBefore = address(arb).balance;

        vm.prank(searcher);
        vm.expectRevert(MevErrors.NegativeEV.selector);
        arb.execute(_route(), AMOUNT, 1, TIP);

        assertEq(builder.balance, tipBefore, "coinbase must not receive tip");
        assertEq(address(arb).balance, ethBefore, "solver ETH restored on revert");
    }

    function test_arb_priceMoveInvalidatesSpread_revertsWithoutTip() public {
        // Spread inicial rentable
        ammA.setReserves(100 ether, 400 ether);
        tokenOut.mint(address(ammA), 200 ether);
        ammB.setReserves(100 ether, 100 ether);

        // "Movimiento de precio" cierra el spread antes del execute
        ammA.setReserves(200 ether, 200 ether);
        ammB.setReserves(200 ether, 200 ether);

        uint256 tipBefore = builder.balance;
        vm.prank(searcher);
        vm.expectRevert(MevErrors.NegativeEV.selector);
        arb.execute(_route(), AMOUNT, 1, TIP);
        assertEq(builder.balance, tipBefore);
    }

    function test_arb_minProfitTooHigh_revertsWithoutTip() public {
        ammA.setReserves(100 ether, 400 ether);
        tokenIn.mint(address(ammA), 0);
        tokenOut.mint(address(ammA), 200 ether);
        // Ensure inventory
        if (tokenIn.balanceOf(address(ammA)) < 100 ether) {
            tokenIn.mint(address(ammA), 100 ether);
        }
        ammB.setReserves(100 ether, 100 ether);

        uint256 tipBefore = builder.balance;
        vm.prank(searcher);
        vm.expectRevert(MevErrors.NegativeEV.selector);
        arb.execute(_route(), AMOUNT, type(uint128).max, TIP);
        assertEq(builder.balance, tipBefore);
    }

    function test_backrun_noImbalance_revertsWithoutTip() public {
        uint256 tipBefore = builder.balance;
        vm.prank(searcher);
        vm.expectRevert(MevErrors.NegativeEV.selector);
        backrunEx.backrun(_route(), AMOUNT, 1, TIP);
        assertEq(builder.balance, tipBefore);
    }

    function test_sandwich_noVictim_revertsWithoutTip() public {
        SandwichLeg memory front = SandwichLeg({
            router: address(routerA),
            tokenIn: address(tokenIn),
            tokenOut: address(tokenOut),
            amountIn: AMOUNT,
            amountOutMin: 1
        });
        SandwichLeg memory back = SandwichLeg({
            router: address(routerA),
            tokenIn: address(tokenOut),
            tokenOut: address(tokenIn),
            amountIn: 0,
            amountOutMin: 1
        });

        uint256 tipBefore = builder.balance;
        vm.prank(searcher);
        vm.expectRevert(MevErrors.NegativeEV.selector);
        sandwichEx.sandwich(front, back, address(0), "", 1, TIP);
        assertEq(builder.balance, tipBefore);
    }
}
