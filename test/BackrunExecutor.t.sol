// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {BackrunExecutor} from "../src/BackrunExecutor.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockAMM} from "../src/mocks/MockAMM.sol";
import {MockRouter} from "../src/mocks/MockRouter.sol";
import {RejectETH} from "../src/mocks/RejectETH.sol";
import {MevErrors} from "../src/errors/MevErrors.sol";
import {Route} from "../src/libraries/CalldataCodec.sol";
import {IBackrunExecutor} from "../src/interfaces/IBackrunExecutor.sol";

/**
 * @title BackrunExecutorTest
 * @notice Fase 3: victim desbalancea un pool → backrun captura spread + tip atómico.
 */
contract BackrunExecutorTest is Test {
    MockERC20 internal tokenIn;
    MockERC20 internal tokenOut;
    MockAMM internal ammA;
    MockAMM internal ammB;
    MockRouter internal routerA;
    MockRouter internal routerB;
    BackrunExecutor internal executor;

    address internal owner;
    address internal searcher;
    address internal builder;
    address internal victim;

    uint256 internal constant VICTIM_IN = 40 ether;
    uint256 internal constant BACKRUN_IN = 8 ether;

    function setUp() public {
        owner = makeAddr("owner");
        searcher = makeAddr("searcher");
        builder = makeAddr("builder");
        victim = makeAddr("victim");
        vm.coinbase(builder);

        tokenIn = new MockERC20("Token In", "TIN");
        tokenOut = new MockERC20("Token Out", "TOUT");

        ammA = new MockAMM(address(tokenIn), address(tokenOut));
        ammB = new MockAMM(address(tokenIn), address(tokenOut));
        routerA = new MockRouter(address(ammA));
        routerB = new MockRouter(address(ammB));

        executor = new BackrunExecutor(searcher, owner);

        _seedEqualPools();
        tokenIn.mint(address(executor), 100 ether);
        vm.deal(address(executor), 10 ether);

        tokenIn.mint(victim, VICTIM_IN);
    }

    /**
     * @dev Ambos pools 200/200 — sin spread hasta que la victim tradea en A.
     */
    function _seedEqualPools() internal {
        tokenIn.mint(address(ammA), 200 ether);
        tokenOut.mint(address(ammA), 200 ether);
        ammA.setReserves(200 ether, 200 ether);

        tokenIn.mint(address(ammB), 200 ether);
        tokenOut.mint(address(ammB), 200 ether);
        ammB.setReserves(200 ether, 200 ether);
    }

    /**
     * @dev Victim vende tokenIn→tokenOut en A: tokenOut sube de precio en A vs B.
     *      Backrun: compra tokenOut barato en B, vende caro en A.
     */
    function _simulateVictimBuyOnA() internal {
        vm.startPrank(victim);
        tokenIn.approve(address(routerA), VICTIM_IN);
        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);
        routerA.swapExactTokensForTokens(VICTIM_IN, 1, path, victim);
        vm.stopPrank();
    }

    function _backrunRoute() internal view returns (Route memory) {
        // Comprar mid en B (precio pre-victim), vender en A (encarecido por victim)
        return Route({
            tokenIn: address(tokenIn),
            tokenOut: address(tokenOut),
            routerA: address(routerB),
            routerB: address(routerA),
            amountOutMinA: 1,
            amountOutMinB: 1
        });
    }

    function test_backrun_afterVictim_profitable() public {
        _simulateVictimBuyOnA();

        uint256 initial = tokenIn.balanceOf(address(executor));
        Route memory route = _backrunRoute();

        vm.prank(searcher);
        uint256 profit = executor.backrun(route, BACKRUN_IN, 1, 0);

        assertGt(profit, 0);
        assertEq(tokenIn.balanceOf(address(executor)), initial + profit);
    }

    function test_backrun_afterVictim_withTip() public {
        _simulateVictimBuyOnA();
        uint256 tipWei = 0.05 ether;

        vm.prank(searcher);
        uint256 profit = executor.backrun(_backrunRoute(), BACKRUN_IN, 1, tipWei);

        assertGt(profit, 0);
        assertEq(builder.balance, tipWei);
    }

    function test_backrun_withoutVictim_revertsNegativeEV() public {
        // Sin victim: pools iguales → round-trip pierde por fees
        uint256 tipBefore = builder.balance;

        vm.prank(searcher);
        vm.expectRevert(MevErrors.NegativeEV.selector);
        executor.backrun(_backrunRoute(), BACKRUN_IN, 1, 0.02 ether);

        assertEq(builder.balance, tipBefore, "tip must not stick on revert");
    }

    function test_backrun_unauthorized() public {
        _simulateVictimBuyOnA();
        vm.prank(makeAddr("stranger"));
        vm.expectRevert(MevErrors.UnauthorizedSearcher.selector);
        executor.backrun(_backrunRoute(), BACKRUN_IN, 0, 0);
    }

    function test_backrun_zeroAmount() public {
        vm.prank(searcher);
        vm.expectRevert(MevErrors.ZeroAmount.selector);
        executor.backrun(_backrunRoute(), 0, 0, 0);
    }

    function test_backrun_tipRevertsWhenCoinbaseRejects() public {
        _simulateVictimBuyOnA();
        RejectETH rejector = new RejectETH();
        vm.coinbase(address(rejector));

        vm.prank(searcher);
        vm.expectRevert(MevErrors.TipTransferFailed.selector);
        executor.backrun(_backrunRoute(), BACKRUN_IN, 1, 0.01 ether);
    }

    function test_backrun_emitsBackrunExecuted() public {
        _simulateVictimBuyOnA();

        vm.prank(searcher);
        vm.expectEmit(true, true, false, false);
        emit IBackrunExecutor.BackrunExecuted(searcher, address(tokenIn), BACKRUN_IN, 0, 0);
        executor.backrun(_backrunRoute(), BACKRUN_IN, 1, 0);
    }

    function test_setSearcher_onlyOwner() public {
        address next = makeAddr("nextSearcher");
        vm.prank(owner);
        executor.setSearcher(next);
        assertEq(executor.authorizedSearcher(), next);
    }

    function test_withdraw_erc20() public {
        vm.prank(owner);
        executor.withdraw(address(tokenIn), owner, 3 ether);
        assertEq(tokenIn.balanceOf(owner), 3 ether);
    }
}
