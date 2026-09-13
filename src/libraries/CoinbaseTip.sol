// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MevErrors} from "../errors/MevErrors.sol";

/**
 * @title CoinbaseTip
 * @notice Pago de bribe ETH al builder/miner vía `block.coinbase`.
 * @dev `pay` usa `.call{value}`; `payAssembly` usa Yul `call` + opcode `coinbase`.
 *      Tradeoff: `payAssembly` evita el overhead del wrapper Solidity del call;
 *      medir en Fase 7 (`Mev.gas.t.sol`). Tip = 0 es no-op.
 *      Si `coinbase` revierte / rechaza ETH → `TipTransferFailed`.
 */
library CoinbaseTip {
    /**
     * @notice Transfiere `tipWei` ETH a `block.coinbase` con `.call`.
     * @param tipWei Cantidad en wei (`0` = no-op).
     */
    function pay(uint256 tipWei) internal {
        if (tipWei == 0) return;
        (bool ok,) = block.coinbase.call{value: tipWei}("");
        if (!ok) revert MevErrors.TipTransferFailed();
    }

    /**
     * @notice Transfiere `tipWei` ETH a coinbase vía assembly (sin returndata).
     * @param tipWei Cantidad en wei (`0` = no-op).
     * @dev Gas: un solo `call` Yul; no copia returndata. Preferible en hot path del solver.
     */
    function payAssembly(uint256 tipWei) internal {
        if (tipWei == 0) return;
        bool ok;
        assembly ("memory-safe") {
            // call(gas, addr, value, argsOffset, argsSize, retOffset, retSize)
            ok := call(gas(), coinbase(), tipWei, 0, 0, 0, 0)
        }
        if (!ok) revert MevErrors.TipTransferFailed();
    }
}
