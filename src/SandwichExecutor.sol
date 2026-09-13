// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ISandwichExecutor, ISandwichMidHook, SandwichLeg} from "./interfaces/ISandwichExecutor.sol";
import {IDexRouter} from "./interfaces/IDexRouter.sol";
import {MevErrors} from "./errors/MevErrors.sol";
import {ProfitLib} from "./libraries/ProfitLib.sol";
import {CoinbaseTip} from "./libraries/CoinbaseTip.sol";

/**
 * @title SandwichExecutor
 * @notice Sandwich lab atómico: front-run → hook victim → back-run → tip → `minProfit`.
 * @dev **SOLO LAB / FORK / TESTS.** No documenta ni habilita explotación en mainnet.
 *      El `midHook` simula la victim tx dentro de la misma llamada (en producción sería otra tx del bundle).
 *      Tip solo persiste si el profit check pasa. CEI + ReentrancyGuard.
 */
contract SandwichExecutor is ISandwichExecutor, Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @inheritdoc ISandwichExecutor
    address public override authorizedSearcher;

    /**
     * @notice Despliega el executor lab y fija el searcher inicial.
     * @param searcher_ EOA / relayer autorizado (`!= 0`).
     * @param owner_ Owner administrativo (`Ownable2Step`).
     */
    constructor(address searcher_, address owner_) Ownable(owner_) {
        if (searcher_ == address(0) || owner_ == address(0)) revert MevErrors.ZeroAddress();
        authorizedSearcher = searcher_;
    }

    /// @inheritdoc ISandwichExecutor
    function sandwich(
        SandwichLeg calldata front,
        SandwichLeg calldata back,
        address midHook,
        bytes calldata midData,
        uint256 minProfit,
        uint256 tipWei
    ) external override nonReentrant returns (uint256 profit) {
        if (msg.sender != authorizedSearcher) revert MevErrors.UnauthorizedSearcher();
        _validateLeg(front);
        _validateLegTokens(back);

        uint256 initial = ProfitLib.snapshot(front.tokenIn);

        // --- Front-run ---
        uint256 midBal = _swapLeg(front, front.amountIn);
        if (midBal == 0) revert MevErrors.InsufficientOutput();

        // --- Victim simulada (lab) ---
        if (midHook != address(0)) {
            ISandwichMidHook(midHook).afterFront(midData);
        }

        // --- Back-run ---
        uint256 backIn = back.amountIn == 0 ? IERC20(back.tokenIn).balanceOf(address(this)) : back.amountIn;
        if (backIn == 0) revert MevErrors.ZeroAmount();
        if (back.tokenIn != front.tokenOut || back.tokenOut != front.tokenIn) revert MevErrors.InvalidRoute();
        _swapLeg(back, backIn);

        CoinbaseTip.payAssembly(tipWei);

        uint256 final_ = ProfitLib.snapshot(front.tokenIn);
        ProfitLib.requireProfit(initial, final_, minProfit);
        profit = ProfitLib.netProfit(initial, final_);

        emit SandwichExecuted(msg.sender, front.tokenIn, profit, tipWei);
    }

    /// @inheritdoc ISandwichExecutor
    function setSearcher(address searcher) external override onlyOwner {
        if (searcher == address(0)) revert MevErrors.ZeroAddress();
        authorizedSearcher = searcher;
    }

    /// @inheritdoc ISandwichExecutor
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
     * @dev Ejecuta un hop vía `IDexRouter`.
     * @param leg Parámetros del hop.
     * @param amountIn Input efectivo.
     * @return amountOut Output recibido.
     */
    function _swapLeg(SandwichLeg calldata leg, uint256 amountIn) private returns (uint256 amountOut) {
        address[] memory path = new address[](2);
        path[0] = leg.tokenIn;
        path[1] = leg.tokenOut;

        IERC20(leg.tokenIn).forceApprove(leg.router, amountIn);
        amountOut = IDexRouter(leg.router).swapExactTokensForTokens(amountIn, leg.amountOutMin, path, address(this));
        IERC20(leg.tokenIn).forceApprove(leg.router, 0);
    }

    /**
     * @dev Valida front leg completo (incl. amountIn > 0).
     * @param leg Leg a validar.
     */
    function _validateLeg(SandwichLeg calldata leg) private pure {
        _validateLegTokens(leg);
        if (leg.amountIn == 0) revert MevErrors.ZeroAmount();
    }

    /**
     * @dev Valida routers/tokens de un leg (amountIn puede ser 0 en back = “usar todo”).
     * @param leg Leg a validar.
     */
    function _validateLegTokens(SandwichLeg calldata leg) private pure {
        if (leg.router == address(0) || leg.tokenIn == address(0) || leg.tokenOut == address(0)) {
            revert MevErrors.ZeroAddress();
        }
        if (leg.tokenIn == leg.tokenOut) revert MevErrors.InvalidRoute();
    }
}
