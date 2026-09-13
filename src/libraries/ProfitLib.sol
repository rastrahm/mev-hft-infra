// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MevErrors} from "../errors/MevErrors.sol";

/**
 * @title ProfitLib
 * @notice Snapshot de balance y enforce de profit mínimo (EV ≥ 0 tras `minProfit`).
 * @dev Pensado para solvers atómicos: llamar `snapshot` antes de swaps/tip y `requireProfit` al final.
 *      Si `final < initial + minProfit` → `NegativeEV` y la tx revierte (incl. tip).
 */
library ProfitLib {
    /**
     * @notice Lee el balance del caller de `token` (o ETH nativo si `token == address(0)`).
     * @param token ERC-20 a medir, o `address(0)` para `address(this).balance`.
     * @return bal Balance actual.
     */
    function snapshot(address token) internal view returns (uint256 bal) {
        if (token == address(0)) {
            return address(this).balance;
        }
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @notice Requiere que el delta de balance cubra `minProfit`.
     * @param initial Balance pre-ejecución.
     * @param final_ Balance post-ejecución.
     * @param minProfit Beneficio mínimo exigido (unidades del token medido).
     */
    function requireProfit(uint256 initial, uint256 final_, uint256 minProfit) internal pure {
        if (final_ < initial) revert MevErrors.NegativeEV();
        if (final_ - initial < minProfit) revert MevErrors.NegativeEV();
    }

    /**
     * @notice Delta `final_ - initial` si es no negativo; si no, `NegativeEV`.
     * @param initial Balance pre-ejecución.
     * @param final_ Balance post-ejecución.
     * @return profit Beneficio neto.
     */
    function netProfit(uint256 initial, uint256 final_) internal pure returns (uint256 profit) {
        if (final_ < initial) revert MevErrors.NegativeEV();
        unchecked {
            return final_ - initial;
        }
    }
}
