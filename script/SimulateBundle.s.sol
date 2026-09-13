// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {AtomicArbitrageSolver} from "../src/AtomicArbitrageSolver.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockAMM} from "../src/mocks/MockAMM.sol";
import {MockRouter} from "../src/mocks/MockRouter.sol";
import {Route} from "../src/libraries/CalldataCodec.sol";

/**
 * @title SimulateBundle
 * @notice Simula un "bundle" Flashbots-style en Foundry (fork o Anvil local).
 * @dev Formato Builder / Flashbots Auction (alto nivel — off-chain el searcher firma y envía):
 *
 *      eth_callBundle / eth_sendBundle (JSON-RPC):
 *      {
 *        "jsonrpc": "2.0",
 *        "id": 1,
 *        "method": "eth_sendBundle",   // o "eth_callBundle" para simulación previa
 *        "params": [{
 *          "txs": ["0x...", "0x..."],   // RLP raw txs firmadas, ordenadas
 *          "blockNumber": "0x...",      // bloque objetivo (hex)
 *          "minTimestamp": 0,           // opcional
 *          "maxTimestamp": 0,           // opcional
 *          "revertingTxHashes": []      // opcional
 *        }]
 *      }
 *
 *      mev_sendBundle (MEV-Share / builders modernos) añade privacy hints / validity.
 *
 *      Este script NO habla con un relay real: despliega el stack, crea un imbalance
 *      simulado y ejecuta `solver.execute` como si el builder hubiera incluido el bundle
 *      en `block.number` (análogo a eth_callBundle sobre el estado forkeado).
 *
 * Uso:
 *   forge script script/SimulateBundle.s.sol:SimulateBundle -vvv
 *   forge script script/SimulateBundle.s.sol:SimulateBundle --fork-url $MAINNET_RPC_URL -vvv
 *
 * Env opcionales:
 * - PRIVATE_KEY — broadcaster / searcher demo (default Anvil #0)
 * - TIP_WEI — tip a coinbase (default 0.01 ether)
 * - AMOUNT_IN — input del arb (default 10 ether)
 */
contract SimulateBundle is Script {
    function run() external {
        uint256 pk =
            vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address searcher = vm.addr(pk);
        uint256 tipWei = vm.envOr("TIP_WEI", uint256(0.01 ether));
        uint256 amountIn = vm.envOr("AMOUNT_IN", uint256(10 ether));

        console2.log("=== SimulateBundle (Flashbots-style local sim) ===");
        console2.log("target blockNumber (analog)", block.number);
        console2.log("block.coinbase", block.coinbase);
        console2.log("searcher", searcher);

        vm.startBroadcast(pk);

        MockERC20 tokenIn = new MockERC20("Sim TIN", "STIN");
        MockERC20 tokenOut = new MockERC20("Sim TOUT", "STOUT");
        MockAMM ammA = new MockAMM(address(tokenIn), address(tokenOut));
        MockAMM ammB = new MockAMM(address(tokenIn), address(tokenOut));
        MockRouter routerA = new MockRouter(address(ammA));
        MockRouter routerB = new MockRouter(address(ammB));

        // Searcher = deployer para firmar execute en el mismo broadcast
        AtomicArbitrageSolver solver = new AtomicArbitrageSolver(searcher, searcher);

        tokenIn.mint(address(ammA), 100 ether);
        tokenOut.mint(address(ammA), 400 ether);
        ammA.setReserves(100 ether, 400 ether);
        tokenIn.mint(address(ammB), 100 ether);
        tokenOut.mint(address(ammB), 100 ether);
        ammB.setReserves(100 ether, 100 ether);

        tokenIn.mint(address(solver), 100 ether);
        // Fondeo tip vía cheatcode (script local / fork); en prod el searcher envía ETH on-chain
        vm.deal(address(solver), tipWei + 1 ether);

        Route memory route = Route({
            tokenIn: address(tokenIn),
            tokenOut: address(tokenOut),
            routerA: address(routerA),
            routerB: address(routerB),
            amountOutMinA: 1,
            amountOutMinB: 1
        });

        // Analog of bundle txs[] inclusion: single execution tx
        console2.log("--- eth_callBundle analog: solver.execute ---");
        uint256 coinbaseBefore = block.coinbase.balance;
        uint256 profit = solver.execute(route, amountIn, 1, tipWei);

        console2.log("profit (tokenIn)", profit);
        console2.log("tipWei", tipWei);
        console2.log("coinbase delta", block.coinbase.balance - coinbaseBefore);
        console2.log("solver", address(solver));
        console2.log("=== bundle sim OK ===");

        vm.stopBroadcast();
    }
}
