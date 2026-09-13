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
 * @title UnauthorizedTest
 * @notice Fase 4: callers no autorizados revierten en los tres ejecutores.
 */
contract UnauthorizedTest is Test {
    AtomicArbitrageSolver internal arb;
    BackrunExecutor internal backrun;
    SandwichExecutor internal sandwich;

    MockERC20 internal tokenIn;
    MockERC20 internal tokenOut;
    MockRouter internal router;

    address internal owner = address(0xA11CE);
    address internal searcher = address(0x5EA);
    address internal stranger = address(0xBAD);

    function setUp() public {
        tokenIn = new MockERC20("TIN", "TIN");
        tokenOut = new MockERC20("TOUT", "TOUT");
        MockAMM amm = new MockAMM(address(tokenIn), address(tokenOut));
        router = new MockRouter(address(amm));

        arb = new AtomicArbitrageSolver(searcher, owner);
        backrun = new BackrunExecutor(searcher, owner);
        sandwich = new SandwichExecutor(searcher, owner);
    }

    function _route() internal view returns (Route memory) {
        return Route({
            tokenIn: address(tokenIn),
            tokenOut: address(tokenOut),
            routerA: address(router),
            routerB: address(router),
            amountOutMinA: 0,
            amountOutMinB: 0
        });
    }

    function test_arb_unauthorized() public {
        vm.prank(stranger);
        vm.expectRevert(MevErrors.UnauthorizedSearcher.selector);
        arb.execute(_route(), 1 ether, 0, 0);
    }

    function test_backrun_unauthorized() public {
        vm.prank(stranger);
        vm.expectRevert(MevErrors.UnauthorizedSearcher.selector);
        backrun.backrun(_route(), 1 ether, 0, 0);
    }

    function test_sandwich_unauthorized() public {
        SandwichLeg memory front = SandwichLeg({
            router: address(router),
            tokenIn: address(tokenIn),
            tokenOut: address(tokenOut),
            amountIn: 1 ether,
            amountOutMin: 0
        });
        SandwichLeg memory back = SandwichLeg({
            router: address(router),
            tokenIn: address(tokenOut),
            tokenOut: address(tokenIn),
            amountIn: 0,
            amountOutMin: 0
        });
        vm.prank(stranger);
        vm.expectRevert(MevErrors.UnauthorizedSearcher.selector);
        sandwich.sandwich(front, back, address(0), "", 0, 0);
    }
}
