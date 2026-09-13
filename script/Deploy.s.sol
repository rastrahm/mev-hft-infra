// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";

/**
 * @title Deploy
 * @notice Stub de deploy (Fase 0). Se completa en Fase 7 con solvers/executors.
 * @dev Ejemplo Anvil:
 *      `forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast`
 *
 * Env opcionales:
 * - `PRIVATE_KEY` — deployer (default Anvil #0)
 * - `SEARCHER` — EOA autorizada del searcher
 */
contract Deploy is Script {
    function run() external {
        uint256 pk =
            vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(pk);
        address searcher = vm.envOr("SEARCHER", deployer);

        vm.startBroadcast(pk);
        // Fase 7: deploy AtomicArbitrageSolver, BackrunExecutor, mocks, setSearcher(searcher)
        console2.log("Deployer", deployer);
        console2.log("Searcher (planned)", searcher);
        console2.log("Deploy stub - completar en Fase 7");
        vm.stopBroadcast();
    }
}
