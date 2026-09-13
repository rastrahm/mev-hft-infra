// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IDexRouter} from "../interfaces/IDexRouter.sol";
import {MevErrors} from "../errors/MevErrors.sol";

/**
 * @title MevSwapLib
 * @notice Round-trip 2-router optimizado para hot path MEV (arb / backrun).
 * @dev Gas: un solo `address[]` reutilizado; cache de addresses en stack;
 *      sin `forceApprove(0)` post-swap (routers de confianza del searcher; allowance residual OK en lab).
 *      Tradeoff documentado en `doc/GAS.md`.
 */
library MevSwapLib {
    using SafeERC20 for IERC20;

    /**
     * @notice tokenIn → tokenOut en routerA, luego tokenOut → tokenIn en routerB.
     * @param tokenIn Token de entrada / medición de profit.
     * @param tokenOut Token intermedio.
     * @param routerA Primer `IDexRouter`.
     * @param routerB Segundo `IDexRouter`.
     * @param amountIn Input del primer hop.
     * @param amountOutMinA Slippage hop A.
     * @param amountOutMinB Slippage hop B.
     * @return mid Cantidad intermedia (`tokenOut`) tras hop A.
     */
    function swapRoundTrip(
        address tokenIn,
        address tokenOut,
        address routerA,
        address routerB,
        uint256 amountIn,
        uint256 amountOutMinA,
        uint256 amountOutMinB
    ) internal returns (uint256 mid) {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        IERC20(tokenIn).forceApprove(routerA, amountIn);
        mid = IDexRouter(routerA).swapExactTokensForTokens(amountIn, amountOutMinA, path, address(this));
        if (mid == 0) revert MevErrors.InsufficientOutput();

        path[0] = tokenOut;
        path[1] = tokenIn;
        IERC20(tokenOut).forceApprove(routerB, mid);
        IDexRouter(routerB).swapExactTokensForTokens(mid, amountOutMinB, path, address(this));
    }
}
