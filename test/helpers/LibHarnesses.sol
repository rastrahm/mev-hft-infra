// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ProfitLib} from "../../src/libraries/ProfitLib.sol";
import {CoinbaseTip} from "../../src/libraries/CoinbaseTip.sol";
import {CalldataCodec, Route} from "../../src/libraries/CalldataCodec.sol";

/**
 * @title ProfitLibHarness
 * @notice Expone `ProfitLib` para unit tests (balance del harness).
 */
contract ProfitLibHarness {
    function snapshot(address token) external view returns (uint256) {
        return ProfitLib.snapshot(token);
    }

    function requireProfit(uint256 initial, uint256 final_, uint256 minProfit) external pure {
        ProfitLib.requireProfit(initial, final_, minProfit);
    }

    function netProfit(uint256 initial, uint256 final_) external pure returns (uint256) {
        return ProfitLib.netProfit(initial, final_);
    }

    receive() external payable {}
}

/**
 * @title CoinbaseTipHarness
 * @notice Expone `CoinbaseTip.pay` / `payAssembly`; debe tener ETH.
 */
contract CoinbaseTipHarness {
    function pay(uint256 tipWei) external {
        CoinbaseTip.pay(tipWei);
    }

    function payAssembly(uint256 tipWei) external {
        CoinbaseTip.payAssembly(tipWei);
    }

    receive() external payable {}
}

/**
 * @title CalldataCodecHarness
 * @notice Expone decode calldata (requiere `calldata` externo).
 */
contract CalldataCodecHarness {
    function encodeRoute(Route memory r) external pure returns (bytes memory) {
        return CalldataCodec.encodeRoute(r);
    }

    function decodeRoute(bytes calldata data) external pure returns (Route memory) {
        return CalldataCodec.decodeRoute(data);
    }

    function encodeAmounts(uint256 amountIn, uint256 minProfit) external pure returns (bytes memory) {
        return CalldataCodec.encodeAmounts(amountIn, minProfit);
    }

    function decodeAmounts(bytes calldata data) external pure returns (uint256 amountIn, uint256 minProfit) {
        return CalldataCodec.decodeAmounts(data);
    }
}
