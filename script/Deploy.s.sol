// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {AtomicArbitrageSolver} from "../src/AtomicArbitrageSolver.sol";
import {BackrunExecutor} from "../src/BackrunExecutor.sol";
import {SandwichExecutor} from "../src/SandwichExecutor.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockAMM} from "../src/mocks/MockAMM.sol";
import {MockRouter} from "../src/mocks/MockRouter.sol";

/**
 * @title Deploy
 * @notice Despliega solvers/executors + mocks demo (Fase 7).
 * @dev Ejemplo Anvil:
 *      `forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast`
 *
 * Env opcionales:
 * - `PRIVATE_KEY` — deployer (default Anvil #0)
 * - `SEARCHER` — EOA autorizada (default = deployer)
 */
contract Deploy is Script {
    function run() external {
        uint256 pk =
            vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(pk);
        address searcher = vm.envOr("SEARCHER", deployer);

        vm.startBroadcast(pk);

        MockERC20 tokenIn = new MockERC20("Deploy TIN", "DTIN");
        MockERC20 tokenOut = new MockERC20("Deploy TOUT", "DTOUT");
        MockAMM ammA = new MockAMM(address(tokenIn), address(tokenOut));
        MockAMM ammB = new MockAMM(address(tokenIn), address(tokenOut));
        MockRouter routerA = new MockRouter(address(ammA));
        MockRouter routerB = new MockRouter(address(ammB));

        AtomicArbitrageSolver arb = new AtomicArbitrageSolver(searcher, deployer);
        BackrunExecutor backrun = new BackrunExecutor(searcher, deployer);
        SandwichExecutor sandwich = new SandwichExecutor(searcher, deployer);

        // Liquidez demo desbalanceada
        tokenIn.mint(address(ammA), 100 ether);
        tokenOut.mint(address(ammA), 400 ether);
        ammA.setReserves(100 ether, 400 ether);
        tokenIn.mint(address(ammB), 100 ether);
        tokenOut.mint(address(ammB), 100 ether);
        ammB.setReserves(100 ether, 100 ether);

        tokenIn.mint(address(arb), 50 ether);
        tokenIn.mint(address(backrun), 50 ether);
        tokenIn.mint(address(sandwich), 50 ether);

        console2.log("tokenIn", address(tokenIn));
        console2.log("tokenOut", address(tokenOut));
        console2.log("routerA", address(routerA));
        console2.log("routerB", address(routerB));
        console2.log("AtomicArbitrageSolver", address(arb));
        console2.log("BackrunExecutor", address(backrun));
        console2.log("SandwichExecutor", address(sandwich));
        console2.log("searcher", searcher);

        vm.stopBroadcast();
    }
}
