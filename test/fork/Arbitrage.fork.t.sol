// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {AtomicArbitrageSolver} from "../../src/AtomicArbitrageSolver.sol";
import {BackrunExecutor} from "../../src/BackrunExecutor.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MockAMM} from "../../src/mocks/MockAMM.sol";
import {MockRouter} from "../../src/mocks/MockRouter.sol";
import {MevErrors} from "../../src/errors/MevErrors.sol";
import {Route} from "../../src/libraries/CalldataCodec.sol";

/**
 * @title ArbitrageForkTest
 * @notice Fase 6: ejecuta solvers sobre fork de mainnet si hay `MAINNET_RPC_URL`.
 * @dev Sin RPC la suite se salta (`vm.skip`). Despliega mocks en el fork (imbalance simulado;
 *      no depende de pools Uniswap live). Equivale a simular el estado post-mempool en una EVM forkeada.
 */
contract ArbitrageForkTest is Test {
    bool internal forked;

    MockERC20 internal tokenIn;
    MockERC20 internal tokenOut;
    MockAMM internal ammA;
    MockAMM internal ammB;
    MockRouter internal routerA;
    MockRouter internal routerB;
    AtomicArbitrageSolver internal solver;
    BackrunExecutor internal backrunEx;

    address internal owner;
    address internal searcher;
    address internal builder;
    address internal victim;

    uint256 internal constant AMOUNT_IN = 10 ether;
    uint256 internal constant VICTIM_IN = 40 ether;

    function setUp() public {
        string memory rpc;
        try vm.envString("MAINNET_RPC_URL") returns (string memory url) {
            rpc = url;
        } catch {
            return;
        }
        if (bytes(rpc).length == 0) {
            return;
        }

        vm.createSelectFork(rpc);
        forked = true;

        owner = makeAddr("owner");
        searcher = makeAddr("searcher");
        builder = makeAddr("builder");
        victim = makeAddr("victim");
        vm.coinbase(builder);

        tokenIn = new MockERC20("Fork TIN", "FTIN");
        tokenOut = new MockERC20("Fork TOUT", "FTOUT");

        ammA = new MockAMM(address(tokenIn), address(tokenOut));
        ammB = new MockAMM(address(tokenIn), address(tokenOut));
        routerA = new MockRouter(address(ammA));
        routerB = new MockRouter(address(ammB));

        solver = new AtomicArbitrageSolver(searcher, owner);
        backrunEx = new BackrunExecutor(searcher, owner);

        _seedImbalance();
        tokenIn.mint(address(solver), 100 ether);
        tokenIn.mint(address(backrunEx), 100 ether);
        vm.deal(address(solver), 5 ether);
        vm.deal(address(backrunEx), 5 ether);
        tokenIn.mint(victim, VICTIM_IN);
    }

    function _skipIfNoFork() internal {
        if (!forked) {
            vm.skip(true);
        }
    }

    /**
     * @dev Spread artificial en el fork: A barato en TOUT, B caro.
     */
    function _seedImbalance() internal {
        tokenIn.mint(address(ammA), 100 ether);
        tokenOut.mint(address(ammA), 400 ether);
        ammA.setReserves(100 ether, 400 ether);

        tokenIn.mint(address(ammB), 100 ether);
        tokenOut.mint(address(ammB), 100 ether);
        ammB.setReserves(100 ether, 100 ether);
    }

    function _arbRoute() internal view returns (Route memory) {
        return Route({
            tokenIn: address(tokenIn),
            tokenOut: address(tokenOut),
            routerA: address(routerA),
            routerB: address(routerB),
            amountOutMinA: 1,
            amountOutMinB: 1
        });
    }

    /**
     * @notice En fork: arbitraje rentable con tip a coinbase del bloque forkeado.
     */
    function testFork_arb_profitableWithTip() public {
        _skipIfNoFork();

        uint256 tipWei = 0.05 ether;
        uint256 initial = tokenIn.balanceOf(address(solver));

        vm.prank(searcher);
        uint256 profit = solver.execute(_arbRoute(), AMOUNT_IN, 1, tipWei);

        assertGt(profit, 0);
        assertEq(tokenIn.balanceOf(address(solver)), initial + profit);
        assertEq(builder.balance, tipWei);
    }

    /**
     * @notice En fork: cerrar spread → NegativeEV y tip no residual.
     */
    function testFork_arb_unprofitable_noTip() public {
        _skipIfNoFork();

        ammA.setReserves(200 ether, 200 ether);
        ammB.setReserves(200 ether, 200 ether);

        uint256 tipBefore = builder.balance;
        vm.prank(searcher);
        vm.expectRevert(MevErrors.NegativeEV.selector);
        solver.execute(_arbRoute(), AMOUNT_IN, 1, 0.02 ether);
        assertEq(builder.balance, tipBefore);
    }

    /**
     * @notice En fork: victim desbalancea A → backrun captura vs B.
     */
    function testFork_backrun_afterVictim() public {
        _skipIfNoFork();

        // Pools iguales primero
        ammA.setReserves(200 ether, 200 ether);
        ammB.setReserves(200 ether, 200 ether);
        tokenIn.mint(address(ammA), 100 ether);
        tokenOut.mint(address(ammA), 0);
        tokenIn.mint(address(ammB), 100 ether);
        tokenOut.mint(address(ammB), 100 ether);

        // Victim en A
        vm.startPrank(victim);
        tokenIn.approve(address(routerA), VICTIM_IN);
        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);
        routerA.swapExactTokensForTokens(VICTIM_IN, 1, path, victim);
        vm.stopPrank();

        Route memory route = Route({
            tokenIn: address(tokenIn),
            tokenOut: address(tokenOut),
            routerA: address(routerB),
            routerB: address(routerA),
            amountOutMinA: 1,
            amountOutMinB: 1
        });

        vm.prank(searcher);
        uint256 profit = backrunEx.backrun(route, 8 ether, 1, 0.01 ether);
        assertGt(profit, 0);
        assertEq(builder.balance, 0.01 ether);
    }
}
