// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IDexRouter} from "../interfaces/IDexRouter.sol";
import {ISimpleAMM} from "../interfaces/ISimpleAMM.sol";
import {MevErrors} from "../errors/MevErrors.sol";

/**
 * @title MockRouter
 * @notice Adapter `IDexRouter` → `ISimpleAMM` (path de longitud 2).
 */
contract MockRouter is IDexRouter {
    using SafeERC20 for IERC20;

    /// @notice AMM subyacente.
    ISimpleAMM public immutable amm;

    /**
     * @notice Fija el AMM al que se delegan los swaps.
     * @param amm_ Pool `x*y=k` mock.
     */
    constructor(address amm_) {
        if (amm_ == address(0)) revert MevErrors.ZeroAddress();
        amm = ISimpleAMM(amm_);
    }

    /// @inheritdoc IDexRouter
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to
    ) external override returns (uint256 amountOut) {
        if (path.length != 2) revert MevErrors.InvalidRoute();
        if (amountIn == 0) revert MevErrors.ZeroAmount();
        if (to == address(0)) revert MevErrors.ZeroAddress();

        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(path[0]).forceApprove(address(amm), amountIn);
        amountOut = amm.swap(path[0], amountIn, amountOutMin, to);
        IERC20(path[0]).forceApprove(address(amm), 0);
    }
}
