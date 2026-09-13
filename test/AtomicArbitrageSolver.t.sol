// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MevErrors} from "../src/errors/MevErrors.sol";
import {RejectETH} from "../src/mocks/RejectETH.sol";
import {Route} from "../src/libraries/CalldataCodec.sol";
import {IAtomicArbitrageSolver} from "../src/interfaces/IAtomicArbitrageSolver.sol";
import {MevTestBase} from "./helpers/MevTestBase.sol";

/**
 * @title AtomicArbitrageSolverTest
 * @notice Unit tests Fase 2: arb rentable, NegativeEV, auth, tip, withdraw.
 */
contract AtomicArbitrageSolverTest is MevTestBase {
    function test_execute_profitable() public {
        Route memory route = _profitableRoute();
        uint256 initial = tokenIn.balanceOf(address(solver));

        vm.prank(searcher);
        uint256 profit = solver.execute(route, AMOUNT_IN, 1, 0);

        assertGt(profit, 0);
        assertEq(tokenIn.balanceOf(address(solver)), initial + profit);
        assertEq(builder.balance, 0);
    }

    function test_execute_profitableWithTip() public {
        Route memory route = _profitableRoute();
        uint256 tipWei = 0.1 ether;

        vm.prank(searcher);
        uint256 profit = solver.execute(route, AMOUNT_IN, 1, tipWei);

        assertGt(profit, 0);
        assertEq(builder.balance, tipWei);
    }

    function test_execute_unprofitable_revertsNegativeEV() public {
        // Flatten prices: round-trip loses to 0.3% fee each leg
        ammA.setReserves(200 ether, 200 ether);
        ammB.setReserves(200 ether, 200 ether);
        tokenIn.mint(address(ammA), 100 ether);
        tokenOut.mint(address(ammA), 0); // already has 400; reserves dictate pricing
        // Ensure enough inventory on both for the swap sizes
        tokenIn.mint(address(ammB), 100 ether);
        tokenOut.mint(address(ammB), 100 ether);

        Route memory route = _profitableRoute();
        uint256 tipBefore = builder.balance;

        vm.prank(searcher);
        vm.expectRevert(MevErrors.NegativeEV.selector);
        solver.execute(route, AMOUNT_IN, 1, 0.05 ether);

        // Tip no quedó pagado (atomic revert)
        assertEq(builder.balance, tipBefore);
    }

    function test_execute_unauthorized() public {
        Route memory route = _profitableRoute();
        vm.prank(makeAddr("stranger"));
        vm.expectRevert(MevErrors.UnauthorizedSearcher.selector);
        solver.execute(route, AMOUNT_IN, 0, 0);
    }

    function test_execute_zeroAmount() public {
        Route memory route = _profitableRoute();
        vm.prank(searcher);
        vm.expectRevert(MevErrors.ZeroAmount.selector);
        solver.execute(route, 0, 0, 0);
    }

    function test_execute_invalidRoute_sameTokens() public {
        Route memory route = _profitableRoute();
        route.tokenOut = route.tokenIn;
        vm.prank(searcher);
        vm.expectRevert(MevErrors.InvalidRoute.selector);
        solver.execute(route, AMOUNT_IN, 0, 0);
    }

    function test_execute_tipRevertsWhenCoinbaseRejects() public {
        RejectETH rejector = new RejectETH();
        vm.coinbase(address(rejector));

        Route memory route = _profitableRoute();
        vm.prank(searcher);
        vm.expectRevert(MevErrors.TipTransferFailed.selector);
        solver.execute(route, AMOUNT_IN, 1, 0.01 ether);
    }

    function test_execute_emitsArbitrageExecuted() public {
        Route memory route = _profitableRoute();

        vm.prank(searcher);
        vm.expectEmit(true, true, false, false);
        emit IAtomicArbitrageSolver.ArbitrageExecuted(searcher, address(tokenIn), AMOUNT_IN, 0, 0);
        solver.execute(route, AMOUNT_IN, 1, 0);
    }

    function test_setSearcher_onlyOwner() public {
        address next = makeAddr("nextSearcher");
        vm.prank(owner);
        solver.setSearcher(next);
        assertEq(solver.authorizedSearcher(), next);

        vm.prank(searcher);
        vm.expectRevert();
        solver.setSearcher(searcher);
    }

    function test_withdraw_erc20() public {
        uint256 amount = 5 ether;
        vm.prank(owner);
        solver.withdraw(address(tokenIn), owner, amount);
        assertEq(tokenIn.balanceOf(owner), amount);
    }

    function test_withdraw_eth() public {
        uint256 amount = 1 ether;
        uint256 beforeBal = owner.balance;
        vm.prank(owner);
        solver.withdraw(address(0), owner, amount);
        assertEq(owner.balance, beforeBal + amount);
    }

    function test_minProfitTooHigh_reverts() public {
        Route memory route = _profitableRoute();
        vm.prank(searcher);
        vm.expectRevert(MevErrors.NegativeEV.selector);
        solver.execute(route, AMOUNT_IN, type(uint128).max, 0);
    }
}
