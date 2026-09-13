// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {AtomicArbitrageSolver} from "../../src/AtomicArbitrageSolver.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MockAMM} from "../../src/mocks/MockAMM.sol";
import {MockRouter} from "../../src/mocks/MockRouter.sol";
import {Route} from "../../src/libraries/CalldataCodec.sol";

/**
 * @title MevTestBase
 * @notice Fixture compartida: dos pools desbalanceados + solver fondeado.
 * @dev Pool A: barato en tokenOut (más tokenOut por tokenIn).
 *      Pool B: caro en tokenOut (más tokenIn al vender tokenOut) → arb rentable.
 */
abstract contract MevTestBase is Test {
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

    uint256 internal constant AMOUNT_IN = 10 ether;

    function setUp() public virtual {
        owner = makeAddr("owner");
        searcher = makeAddr("searcher");
        builder = makeAddr("builder");
        vm.coinbase(builder);

        tokenIn = new MockERC20("Token In", "TIN");
        tokenOut = new MockERC20("Token Out", "TOUT");

        // token0 < token1 ordering not required by MockAMM; use deployment order
        ammA = new MockAMM(address(tokenIn), address(tokenOut));
        ammB = new MockAMM(address(tokenIn), address(tokenOut));
        routerA = new MockRouter(address(ammA));
        routerB = new MockRouter(address(ammB));

        solver = new AtomicArbitrageSolver(searcher, owner);

        _seedProfitablePools();
        _fundSolver(100 ether, 10 ether);
    }

    /**
     * @dev A: 100 TIN / 400 TOUT — B: 100 TIN / 100 TOUT (spread claro).
     */
    function _seedProfitablePools() internal {
        tokenIn.mint(address(ammA), 100 ether);
        tokenOut.mint(address(ammA), 400 ether);
        ammA.setReserves(100 ether, 400 ether);

        tokenIn.mint(address(ammB), 100 ether);
        tokenOut.mint(address(ammB), 100 ether);
        ammB.setReserves(100 ether, 100 ether);
    }

    function _fundSolver(uint256 tokenAmount, uint256 ethAmount) internal {
        tokenIn.mint(address(solver), tokenAmount);
        vm.deal(address(solver), ethAmount);
    }

    function _profitableRoute() internal view returns (Route memory) {
        return Route({
            tokenIn: address(tokenIn),
            tokenOut: address(tokenOut),
            routerA: address(routerA),
            routerB: address(routerB),
            amountOutMinA: 1,
            amountOutMinB: 1
        });
    }
}
