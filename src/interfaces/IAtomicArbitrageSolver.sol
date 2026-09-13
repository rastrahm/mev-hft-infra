// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Route} from "../libraries/CalldataCodec.sol";

/**
 * @title IAtomicArbitrageSolver
 * @notice Solver de arbitraje 2-router atómico con tip coinbase y profit check.
 */
interface IAtomicArbitrageSolver {
    /**
     * @notice Emitido tras un execute rentable.
     * @param searcher Caller autorizado.
     * @param tokenIn Token en el que se mide el profit.
     * @param amountIn Input del primer swap.
     * @param profit Beneficio neto en `tokenIn`.
     * @param tipWei Tip ETH pagado a `block.coinbase`.
     */
    event ArbitrageExecuted(
        address indexed searcher, address indexed tokenIn, uint256 amountIn, uint256 profit, uint256 tipWei
    );

    /**
     * @notice Searcher EOA / relayer autorizado a ejecutar.
     * @return Dirección del searcher.
     */
    function authorizedSearcher() external view returns (address);

    /**
     * @notice Ejecuta arb tokenIn→tokenOut en routerA y tokenOut→tokenIn en routerB.
     * @param route Routers, tokens y mínimos de output.
     * @param amountIn Unidades de `route.tokenIn` a vender en A.
     * @param minProfit Beneficio mínimo exigido en `tokenIn` (post-tip ETH aparte).
     * @param tipWei Bribe ETH a `block.coinbase` (`0` = sin tip).
     * @return profit Beneficio neto en `tokenIn`.
     */
    function execute(Route calldata route, uint256 amountIn, uint256 minProfit, uint256 tipWei)
        external
        returns (uint256 profit);

    /**
     * @notice Rota el searcher autorizado (solo owner).
     * @param searcher Nueva dirección (`!= 0`).
     */
    function setSearcher(address searcher) external;

    /**
     * @notice Retira ERC-20 o ETH del solver (solo owner).
     * @param token ERC-20 o `address(0)` para ETH.
     * @param to Destinatario.
     * @param amount Cantidad.
     */
    function withdraw(address token, address to, uint256 amount) external;
}
