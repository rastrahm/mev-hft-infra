// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IAtomicArbitrageSolver} from "./interfaces/IAtomicArbitrageSolver.sol";
import {MevErrors} from "./errors/MevErrors.sol";
import {ProfitLib} from "./libraries/ProfitLib.sol";
import {CoinbaseTip} from "./libraries/CoinbaseTip.sol";
import {MevSwapLib} from "./libraries/MevSwapLib.sol";
import {Route} from "./libraries/CalldataCodec.sol";

/**
 * @title AtomicArbitrageSolver
 * @notice Arbitraje 2-router atómico: swap A → swap B → tip coinbase → enforce `minProfit`.
 * @dev Solo `authorizedSearcher`. Capital en el contrato (tokens + ETH para tip).
 *      Si EV < `minProfit` o el tip falla, revierte todo (sin bribe residual).
 *      CEI + `ReentrancyGuard`; tip `payAssembly`; round-trip vía `MevSwapLib` (path reutilizado).
 */
contract AtomicArbitrageSolver is IAtomicArbitrageSolver, Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @inheritdoc IAtomicArbitrageSolver
    address public override authorizedSearcher;

    /**
     * @notice Despliega el solver y fija el searcher inicial.
     * @param searcher_ EOA / relayer autorizado (`!= 0`).
     * @param owner_ Owner administrativo (`Ownable2Step`).
     */
    constructor(address searcher_, address owner_) Ownable(owner_) {
        if (searcher_ == address(0) || owner_ == address(0)) revert MevErrors.ZeroAddress();
        authorizedSearcher = searcher_;
    }

    /// @inheritdoc IAtomicArbitrageSolver
    function execute(Route calldata route, uint256 amountIn, uint256 minProfit, uint256 tipWei)
        external
        override
        nonReentrant
        returns (uint256 profit)
    {
        if (msg.sender != authorizedSearcher) revert MevErrors.UnauthorizedSearcher();
        if (amountIn == 0) revert MevErrors.ZeroAmount();
        _validateRoute(route);

        address tokenIn = route.tokenIn;
        uint256 initial = ProfitLib.snapshot(tokenIn);

        MevSwapLib.swapRoundTrip(
            tokenIn,
            route.tokenOut,
            route.routerA,
            route.routerB,
            amountIn,
            route.amountOutMinA,
            route.amountOutMinB
        );

        CoinbaseTip.payAssembly(tipWei);

        profit = ProfitLib.takeProfit(initial, ProfitLib.snapshot(tokenIn), minProfit);
        emit ArbitrageExecuted(msg.sender, tokenIn, amountIn, profit, tipWei);
    }

    /// @inheritdoc IAtomicArbitrageSolver
    function setSearcher(address searcher) external override onlyOwner {
        if (searcher == address(0)) revert MevErrors.ZeroAddress();
        authorizedSearcher = searcher;
    }

    /// @inheritdoc IAtomicArbitrageSolver
    function withdraw(address token, address to, uint256 amount) external override onlyOwner nonReentrant {
        if (to == address(0)) revert MevErrors.ZeroAddress();
        if (amount == 0) revert MevErrors.ZeroAmount();

        if (token == address(0)) {
            (bool ok,) = to.call{value: amount}("");
            if (!ok) revert MevErrors.TipTransferFailed();
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    /**
     * @notice Permite fondear ETH para tips al builder.
     */
    receive() external payable {}

    /**
     * @dev Valida direcciones de la ruta (sin zeros; tokens distintos).
     * @param route Ruta a validar.
     */
    function _validateRoute(Route calldata route) private pure {
        if (
            route.tokenIn == address(0) || route.tokenOut == address(0) || route.routerA == address(0)
                || route.routerB == address(0)
        ) {
            revert MevErrors.ZeroAddress();
        }
        if (route.tokenIn == route.tokenOut) revert MevErrors.InvalidRoute();
    }
}
