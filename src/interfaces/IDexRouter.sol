// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IDexRouter
 * @notice Router mínimo style Uniswap V2: un hop exact-in con `path` de longitud 2.
 */
interface IDexRouter {
    /**
     * @notice Swap exact-in a lo largo de `path` (v1: exactamente 2 tokens).
     * @param amountIn Unidades de `path[0]`.
     * @param amountOutMin Slippage mínimo de `path[1]`.
     * @param path Par `[tokenIn, tokenOut]`.
     * @param to Receptor del output.
     * @return amountOut Unidades de `path[1]` enviadas a `to`.
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to
    ) external returns (uint256 amountOut);
}
