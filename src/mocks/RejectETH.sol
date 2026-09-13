// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title RejectETH
 * @notice Contrato sin `receive`/`fallback` payable: cualquier tip ETH falla.
 * @dev Usado para assertar `TipTransferFailed` al setearlo como `block.coinbase`.
 */
contract RejectETH {
    // Intencionalmente vacío: no acepta ETH.
}
