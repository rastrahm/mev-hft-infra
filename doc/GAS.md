# Optimización de gas — MEV & HFT Trading Infrastructure

Regenerar:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract MevGasTest --gas-report
forge snapshot --match-contract MevGasTest
```

**Fecha baseline:** 2026-09-13 (Fase 7)  
**Snapshot:** `.gas-snapshot` (`test/gas/Mev.gas.t.sol`)  
**Optimizer:** `optimizer_runs = 10_000`, `via_ir = true`, solc `0.8.24`

---

## Baseline operaciones

Medición = gas del **test Foundry** (incluye hops de `MockRouter` / `MockAMM`). Órdenes de magnitud para comparar paths.

| Path | Gas (snapshot) | Notas |
|------|----------------|-------|
| `testGas_arb_execute_withTip` | **253 307** | Arb + tip assembly 0.05 ETH |
| `testGas_backrun_execute_noTip` | **227 684** | Mismo round-trip que arb |
| `testGas_arb_execute_noTip` | **227 631** | Hot path producción sin tip |
| `testGas_tip_pay` | **37 508** | `CoinbaseTip.pay` (`.call`) |
| `testGas_tip_payAssembly` | **37 293** | `CoinbaseTip.payAssembly` (Yul) |

### Lectura

- **`payAssembly` vs `pay`:** ~**215 gas** a favor de Yul en el tip aislado (path de producción).
- **Arb noTip post-opt:** ~**227.6k** vs ~**236.7k** del unit test Fase 2 pre-opt (`test_execute_profitable`) → ahorro del orden de **~9k gas** en el envelope del test (mismo fixture de pools).
- Tip + arb añade ~**25.7k** respecto al path sin tip (pago ETH + cold/warm coinbase).

---

## Optimizaciones aplicadas (Fase 7)

| Técnica | Dónde | Efecto |
|---------|-------|--------|
| `MevSwapLib.swapRoundTrip` | arb / backrun | Un solo `address[]` reutilizado; menos alloc |
| Sin `forceApprove(0)` post-swap | `MevSwapLib`, sandwich | Evita 2× SSTORE de allowance a cero |
| Cache `tokenIn` en stack | solvers | Menos calldata/SLOAD repetidos |
| `ProfitLib.takeProfit` | hot path | Una pasada vs `requireProfit` + `netProfit` |
| `CoinbaseTip.payAssembly` | tip producción | Yul `call` + `coinbase` sin wrapper extra |
| Custom errors | `MevErrors` | Más barato que `require` strings |
| `optimizer_runs = 10_000` + `via_ir` | `foundry.toml` | Inlining agresivo |

### Tradeoff: allowance residual

No limpiar el allowance tras el swap ahorra gas a costa de dejar aprobación en el router. Aceptable en v1 porque el searcher controla routers (mocks / contratos propios). En v2: Permit2 o `forceApprove(0)` opcional.

---

## Comparativa tip (harness)

| Función | Gas test | Delta |
|---------|----------|-------|
| `pay` (Solidity `.call`) | 37 508 | baseline |
| `payAssembly` (Yul) | 37 293 | **−215** |

En el gas-report del contrato harness: `pay` **53 315** vs `payAssembly` **53 254** (incluye overhead de llamada externa similar).

---

## Deploy

```bash
anvil   # otra terminal
export PATH="$HOME/.foundry/bin:$PATH"
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Env: `PRIVATE_KEY`, `SEARCHER`. Ver `script/Deploy.s.sol` y `.env.example`.

Sim bundle: `forge script script/SimulateBundle.s.sol:SimulateBundle -vvv`

README: [`../README.md`](../README.md) · Índice docs: [`README.md`](./README.md) · SWC: [`SWC-AUDIT.md`](./SWC-AUDIT.md)
