// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title MevErrors
 * @notice Custom errors del módulo 15 (MEV & HFT).
 * @dev Preferidos sobre `require` con strings (suite). Semántica de `"Negative EV"` → `NegativeEV()`.
 */
library MevErrors {
    /// @notice Caller no es el searcher EOA / relayer autorizado.
    error UnauthorizedSearcher();

    /// @notice Beneficio neto insuficiente tras tip/gas (`final < initial + minProfit`).
    error NegativeEV();

    /// @notice Dirección cero donde se exige un contrato o EOA válido.
    error ZeroAddress();

    /// @notice Ruta de swap / calldata de route inválida o malformada.
    error InvalidRoute();

    /// @notice Falló la transferencia ETH a `block.coinbase`.
    error TipTransferFailed();

    /// @notice Output del swap por debajo del mínimo esperado.
    error InsufficientOutput();

    /// @notice Slippage: `amountOut` < `amountOutMin`.
    error SlippageExceeded();

    /// @notice Bundle / deadline fuera de ventana (reservado para scripts/fork).
    error BundleExpired();

    /// @notice Cantidad de entrada o tip inválida (cero donde no se permite).
    error ZeroAmount();
}
