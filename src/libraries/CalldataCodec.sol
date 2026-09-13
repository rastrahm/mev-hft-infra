// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MevErrors} from "../errors/MevErrors.sol";

/**
 * @title Route
 * @notice Parámetros de arbitraje 2-router (tokenIn → mid en A → tokenOut en B).
 */
struct Route {
    address tokenIn;
    address tokenOut;
    address routerA;
    address routerB;
    uint256 amountOutMinA;
    uint256 amountOutMinB;
}

/**
 * @title CalldataCodec
 * @notice Encode/decode compacto de `Route` y pares de amounts (Yul calldata).
 * @dev Layout `encodePacked` de Route (144 bytes):
 *      [0:20) tokenIn | [20:40) tokenOut | [40:60) routerA | [60:80) routerB
 *      | [80:112) amountOutMinA | [112:144) amountOutMinB
 *      Amounts (64 bytes): [0:32) amountIn | [32:64) minProfit
 *      Tradeoff: decode Yul evita `abi.decode` + copia a memory intermedia en hot path.
 */
library CalldataCodec {
    uint256 internal constant ROUTE_SIZE = 144;
    uint256 internal constant AMOUNTS_SIZE = 64;

    /**
     * @notice Empaqueta una `Route` en bytes packed (tests / off-chain builders).
     * @param r Ruta a serializar.
     * @return data Bytes de longitud `ROUTE_SIZE`.
     */
    function encodeRoute(Route memory r) internal pure returns (bytes memory data) {
        return abi.encodePacked(r.tokenIn, r.tokenOut, r.routerA, r.routerB, r.amountOutMinA, r.amountOutMinB);
    }

    /**
     * @notice Decodifica calldata packed a `Route` (assembly).
     * @param data Calldata de exactamente 144 bytes.
     * @return route Ruta decodificada.
     */
    function decodeRoute(bytes calldata data) internal pure returns (Route memory route) {
        if (data.length != ROUTE_SIZE) revert MevErrors.InvalidRoute();

        address tokenIn;
        address tokenOut;
        address routerA;
        address routerB;
        uint256 amountOutMinA;
        uint256 amountOutMinB;

        assembly ("memory-safe") {
            let p := data.offset
            tokenIn := shr(96, calldataload(p))
            tokenOut := shr(96, calldataload(add(p, 20)))
            routerA := shr(96, calldataload(add(p, 40)))
            routerB := shr(96, calldataload(add(p, 60)))
            amountOutMinA := calldataload(add(p, 80))
            amountOutMinB := calldataload(add(p, 112))
        }

        route = Route({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            routerA: routerA,
            routerB: routerB,
            amountOutMinA: amountOutMinA,
            amountOutMinB: amountOutMinB
        });
    }

    /**
     * @notice Empaqueta `amountIn` y `minProfit` (64 bytes).
     * @param amountIn Input del trade.
     * @param minProfit Profit mínimo exigido.
     * @return data Bytes packed.
     */
    function encodeAmounts(uint256 amountIn, uint256 minProfit) internal pure returns (bytes memory data) {
        return abi.encodePacked(amountIn, minProfit);
    }

    /**
     * @notice Decodifica `amountIn` y `minProfit` desde calldata (assembly).
     * @param data Calldata de exactamente 64 bytes.
     * @return amountIn Input del trade.
     * @return minProfit Profit mínimo.
     */
    function decodeAmounts(bytes calldata data) internal pure returns (uint256 amountIn, uint256 minProfit) {
        if (data.length != AMOUNTS_SIZE) revert MevErrors.InvalidRoute();

        assembly ("memory-safe") {
            amountIn := calldataload(data.offset)
            minProfit := calldataload(add(data.offset, 0x20))
        }
    }
}
