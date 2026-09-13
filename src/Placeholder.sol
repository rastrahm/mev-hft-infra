// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title Placeholder
 * @notice Stub de Fase 0 para validar toolchain Foundry + remappings.
 * @dev Se elimina en Fase 1 al introducir libs/errores reales del módulo.
 */
contract Placeholder {
    /// @notice Valor de smoke test.
    uint256 public constant PING = 15;

    /**
     * @notice Devuelve el ping del módulo.
     * @return Valor constante `15` (módulo MEV/HFT).
     */
    function ping() external pure returns (uint256) {
        return PING;
    }
}
