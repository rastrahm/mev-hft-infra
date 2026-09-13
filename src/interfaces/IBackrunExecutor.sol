// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Route} from "../libraries/CalldataCodec.sol";

/**
 * @title IBackrunExecutor
 * @notice Ejecutor de backrun post-victim: captura spread → tip coinbase → `minProfit`.
 * @dev Pensado para ir en el mismo bundle *después* de la victim tx (lab/fork).
 */
interface IBackrunExecutor {
    /**
     * @notice Emitido tras un backrun rentable.
     * @param searcher Caller autorizado.
     * @param tokenIn Token en el que se mide el profit.
     * @param amountIn Input del primer swap del backrun.
     * @param profit Beneficio neto en `tokenIn`.
     * @param tipWei Tip ETH pagado a `block.coinbase`.
     */
    event BackrunExecuted(
        address indexed searcher, address indexed tokenIn, uint256 amountIn, uint256 profit, uint256 tipWei
    );

    /**
     * @notice Searcher EOA / relayer autorizado.
     * @return Dirección del searcher.
     */
    function authorizedSearcher() external view returns (address);

    /**
     * @notice Ejecuta el backrun (arb 2-router) tras el imbalance de la victim.
     * @param route Routers/tokens; típicamente comprar en el pool no tocado y vender en el de la victim.
     * @param amountIn Unidades de `route.tokenIn` para el primer hop.
     * @param minProfit Beneficio mínimo en `tokenIn`.
     * @param tipWei Bribe ETH a `block.coinbase` (`0` = sin tip).
     * @return profit Beneficio neto en `tokenIn`.
     */
    function backrun(Route calldata route, uint256 amountIn, uint256 minProfit, uint256 tipWei)
        external
        returns (uint256 profit);

    /**
     * @notice Rota el searcher autorizado (solo owner).
     * @param searcher Nueva dirección (`!= 0`).
     */
    function setSearcher(address searcher) external;

    /**
     * @notice Retira ERC-20 o ETH (solo owner).
     * @param token ERC-20 o `address(0)` para ETH.
     * @param to Destinatario.
     * @param amount Cantidad.
     */
    function withdraw(address token, address to, uint256 amount) external;
}
