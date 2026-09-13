// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title SandwichLeg
 * @notice Un hop de sandwich (front o back) contra un `IDexRouter`.
 */
struct SandwichLeg {
    address router;
    address tokenIn;
    address tokenOut;
    uint256 amountIn;
    uint256 amountOutMin;
}

/**
 * @title ISandwichMidHook
 * @notice Hook lab entre front y back para simular la victim tx en la misma llamada.
 * @dev Solo tests/lab. En un bundle real la victim es una tx distinta en medio.
 */
interface ISandwichMidHook {
    /**
     * @notice Invocado por `SandwichExecutor` tras el front-run.
     * @param data Calldata libre (p. ej. encoded victim swap params).
     */
    function afterFront(bytes calldata data) external;
}

/**
 * @title ISandwichExecutor
 * @notice Sandwich atómico front → (hook victim) → back → tip → `minProfit`.
 * @dev **LAB / FORK ONLY.** No es un runbook de explotación en mainnet.
 */
interface ISandwichExecutor {
    /**
     * @notice Emitido tras un sandwich lab rentable.
     * @param searcher Caller autorizado.
     * @param profitToken Token en el que se mide el profit (`front.tokenIn`).
     * @param profit Beneficio neto.
     * @param tipWei Tip ETH a `block.coinbase`.
     */
    event SandwichExecuted(address indexed searcher, address indexed profitToken, uint256 profit, uint256 tipWei);

    /**
     * @notice Searcher EOA / relayer autorizado.
     * @return Dirección del searcher.
     */
    function authorizedSearcher() external view returns (address);

    /**
     * @notice Ejecuta sandwich lab: front → midHook opcional → back → tip → profit check.
     * @param front Leg de compra (típicamente base → asset).
     * @param back Leg de venta (típicamente asset → base); `amountIn=0` usa todo el balance de `tokenOut` del front.
     * @param midHook Contrato `ISandwichMidHook` o `address(0)` para omitir victim simulada.
     * @param midData Datos para `afterFront`.
     * @param minProfit Beneficio mínimo en `front.tokenIn`.
     * @param tipWei Bribe ETH (`0` = sin tip).
     * @return profit Beneficio neto en `front.tokenIn`.
     */
    function sandwich(
        SandwichLeg calldata front,
        SandwichLeg calldata back,
        address midHook,
        bytes calldata midData,
        uint256 minProfit,
        uint256 tipWei
    ) external returns (uint256 profit);

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
