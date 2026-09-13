// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IAtomicArbitrageSolver} from "./interfaces/IAtomicArbitrageSolver.sol";
import {IDexRouter} from "./interfaces/IDexRouter.sol";
import {MevErrors} from "./errors/MevErrors.sol";
import {ProfitLib} from "./libraries/ProfitLib.sol";
import {CoinbaseTip} from "./libraries/CoinbaseTip.sol";
import {Route} from "./libraries/CalldataCodec.sol";

/**
 * @title AtomicArbitrageSolver
 * @notice Arbitraje 2-router atómico: swap A → swap B → tip coinbase → enforce `minProfit`.
 * @dev Solo `authorizedSearcher`. Capital en el contrato (tokens + ETH para tip).
 *      Si EV < `minProfit` o el tip falla, revierte todo (sin bribe residual).
 *      CEI + `ReentrancyGuard`; ERC-20 vía SafeERC20; tip vía `CoinbaseTip.payAssembly`.
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

        // Checks-Effects-Interactions: snapshot (check) → swaps/tip (interactions) → profit verify
        uint256 initial = ProfitLib.snapshot(route.tokenIn);

        address[] memory pathA = new address[](2);
        pathA[0] = route.tokenIn;
        pathA[1] = route.tokenOut;

        IERC20(route.tokenIn).forceApprove(route.routerA, amountIn);
        uint256 mid =
            IDexRouter(route.routerA).swapExactTokensForTokens(amountIn, route.amountOutMinA, pathA, address(this));
        IERC20(route.tokenIn).forceApprove(route.routerA, 0);

        if (mid == 0) revert MevErrors.InsufficientOutput();

        address[] memory pathB = new address[](2);
        pathB[0] = route.tokenOut;
        pathB[1] = route.tokenIn;

        IERC20(route.tokenOut).forceApprove(route.routerB, mid);
        IDexRouter(route.routerB).swapExactTokensForTokens(mid, route.amountOutMinB, pathB, address(this));
        IERC20(route.tokenOut).forceApprove(route.routerB, 0);

        CoinbaseTip.payAssembly(tipWei);

        uint256 final_ = ProfitLib.snapshot(route.tokenIn);
        ProfitLib.requireProfit(initial, final_, minProfit);
        profit = ProfitLib.netProfit(initial, final_);

        emit ArbitrageExecuted(msg.sender, route.tokenIn, amountIn, profit, tipWei);
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
