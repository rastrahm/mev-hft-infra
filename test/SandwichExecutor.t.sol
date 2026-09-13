// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {SandwichExecutor} from "../src/SandwichExecutor.sol";
import {ISandwichMidHook, SandwichLeg} from "../src/interfaces/ISandwichExecutor.sol";
import {ISandwichExecutor} from "../src/interfaces/ISandwichExecutor.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockAMM} from "../src/mocks/MockAMM.sol";
import {MockRouter} from "../src/mocks/MockRouter.sol";
import {RejectETH} from "../src/mocks/RejectETH.sol";
import {MevErrors} from "../src/errors/MevErrors.sol";

/**
 * @title VictimSwapHook
 * @notice Hook lab: ejecuta el swap de la victim entre front y back.
 */
contract VictimSwapHook is ISandwichMidHook {
    MockRouter public immutable router;
    MockERC20 public immutable tokenIn;
    MockERC20 public immutable tokenOut;
    address public immutable victim;

    constructor(MockRouter router_, MockERC20 tokenIn_, MockERC20 tokenOut_, address victim_) {
        router = router_;
        tokenIn = tokenIn_;
        tokenOut = tokenOut_;
        victim = victim_;
    }

    /// @inheritdoc ISandwichMidHook
    function afterFront(bytes calldata data) external override {
        uint256 amountIn = abi.decode(data, (uint256));
        // El hook corre en el contexto del executor call; la victim debe haber approveado al hook
        // o transferido tokens al hook. Aquí el hook usa allowance victim → hook → router.
        tokenIn.transferFrom(victim, address(this), amountIn);
        tokenIn.approve(address(router), amountIn);
        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);
        router.swapExactTokensForTokens(amountIn, 1, path, victim);
    }
}

/**
 * @title SandwichExecutorTest
 * @notice Fase 4 lab: sandwich rentable / no rentable / auth / tip atómico.
 * @dev Solo entorno de tests — no runbook de mainnet.
 */
contract SandwichExecutorTest is Test {
    MockERC20 internal tokenIn;
    MockERC20 internal tokenOut;
    MockAMM internal amm;
    MockRouter internal router;
    SandwichExecutor internal executor;
    VictimSwapHook internal hook;

    address internal owner;
    address internal searcher;
    address internal builder;
    address internal victim;

    uint256 internal constant FRONT_IN = 10 ether;
    uint256 internal constant VICTIM_IN = 50 ether;

    function setUp() public {
        owner = makeAddr("owner");
        searcher = makeAddr("searcher");
        builder = makeAddr("builder");
        victim = makeAddr("victim");
        vm.coinbase(builder);

        tokenIn = new MockERC20("Token In", "TIN");
        tokenOut = new MockERC20("Token Out", "TOUT");
        amm = new MockAMM(address(tokenIn), address(tokenOut));
        router = new MockRouter(address(amm));

        tokenIn.mint(address(amm), 500 ether);
        tokenOut.mint(address(amm), 500 ether);
        amm.setReserves(500 ether, 500 ether);

        executor = new SandwichExecutor(searcher, owner);
        hook = new VictimSwapHook(router, tokenIn, tokenOut, victim);

        tokenIn.mint(address(executor), 100 ether);
        vm.deal(address(executor), 10 ether);

        tokenIn.mint(victim, VICTIM_IN);
        vm.prank(victim);
        tokenIn.approve(address(hook), type(uint256).max);
    }

    function _front() internal view returns (SandwichLeg memory) {
        return SandwichLeg({
            router: address(router),
            tokenIn: address(tokenIn),
            tokenOut: address(tokenOut),
            amountIn: FRONT_IN,
            amountOutMin: 1
        });
    }

    function _back() internal view returns (SandwichLeg memory) {
        return SandwichLeg({
            router: address(router),
            tokenIn: address(tokenOut),
            tokenOut: address(tokenIn),
            amountIn: 0, // usar todo el mid balance
            amountOutMin: 1
        });
    }

    function test_sandwich_profitableWithVictimHook() public {
        uint256 initial = tokenIn.balanceOf(address(executor));

        vm.prank(searcher);
        uint256 profit = executor.sandwich(_front(), _back(), address(hook), abi.encode(VICTIM_IN), 1, 0);

        assertGt(profit, 0);
        assertEq(tokenIn.balanceOf(address(executor)), initial + profit);
    }

    function test_sandwich_withTip() public {
        uint256 tipWei = 0.03 ether;
        vm.prank(searcher);
        uint256 profit = executor.sandwich(_front(), _back(), address(hook), abi.encode(VICTIM_IN), 1, tipWei);
        assertGt(profit, 0);
        assertEq(builder.balance, tipWei);
    }

    function test_sandwich_withoutVictim_revertsNegativeEV() public {
        uint256 tipBefore = builder.balance;
        vm.prank(searcher);
        vm.expectRevert(MevErrors.NegativeEV.selector);
        executor.sandwich(_front(), _back(), address(0), "", 1, 0.01 ether);
        assertEq(builder.balance, tipBefore, "tip must not stick on revert");
    }

    function test_sandwich_unauthorized() public {
        vm.prank(makeAddr("stranger"));
        vm.expectRevert(MevErrors.UnauthorizedSearcher.selector);
        executor.sandwich(_front(), _back(), address(hook), abi.encode(VICTIM_IN), 0, 0);
    }

    function test_sandwich_zeroFrontAmount() public {
        SandwichLeg memory front = _front();
        front.amountIn = 0;
        vm.prank(searcher);
        vm.expectRevert(MevErrors.ZeroAmount.selector);
        executor.sandwich(front, _back(), address(0), "", 0, 0);
    }

    function test_sandwich_invalidBackTokens() public {
        SandwichLeg memory back = _back();
        back.tokenOut = address(tokenOut); // no cierra el ciclo a tokenIn
        vm.prank(searcher);
        vm.expectRevert(MevErrors.InvalidRoute.selector);
        executor.sandwich(_front(), back, address(hook), abi.encode(VICTIM_IN), 0, 0);
    }

    function test_sandwich_tipRevertsWhenCoinbaseRejects() public {
        RejectETH rejector = new RejectETH();
        vm.coinbase(address(rejector));
        vm.prank(searcher);
        vm.expectRevert(MevErrors.TipTransferFailed.selector);
        executor.sandwich(_front(), _back(), address(hook), abi.encode(VICTIM_IN), 1, 0.01 ether);
    }

    function test_sandwich_emitsSandwichExecuted() public {
        vm.prank(searcher);
        vm.expectEmit(true, true, false, false);
        emit ISandwichExecutor.SandwichExecuted(searcher, address(tokenIn), 0, 0);
        executor.sandwich(_front(), _back(), address(hook), abi.encode(VICTIM_IN), 1, 0);
    }

    function test_setSearcher_onlyOwner() public {
        address next = makeAddr("next");
        vm.prank(owner);
        executor.setSearcher(next);
        assertEq(executor.authorizedSearcher(), next);
    }
}
