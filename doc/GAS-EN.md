# Gas Optimization — MEV & HFT Trading Infrastructure

Regenerate:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract MevGasTest --gas-report
forge snapshot --match-contract MevGasTest
```

**Baseline date:** 2026-09-13 (Phase 7)  
**Snapshot:** `.gas-snapshot` (`test/gas/Mev.gas.t.sol`)  
**Optimizer:** `optimizer_runs = 10_000`, `via_ir = true`, solc `0.8.24`

---

## Operation baseline

Measurement = gas of the **Foundry test** (includes `MockRouter` / `MockAMM` hops). Orders of magnitude for comparing paths.

| Path | Gas (snapshot) | Notes |
|------|----------------|-------|
| `testGas_arb_execute_withTip` | **253 307** | Arb + assembly tip 0.05 ETH |
| `testGas_backrun_execute_noTip` | **227 684** | Same round-trip as arb |
| `testGas_arb_execute_noTip` | **227 631** | Production hot path without tip |
| `testGas_tip_pay` | **37 508** | `CoinbaseTip.pay` (`.call`) |
| `testGas_tip_payAssembly` | **37 293** | `CoinbaseTip.payAssembly` (Yul) |

### Reading

- **`payAssembly` vs `pay`:** ~**215 gas** in favor of Yul on the isolated tip (production path).
- **Arb noTip post-opt:** ~**227.6k** vs ~**236.7k** from the Phase 2 pre-opt unit test (`test_execute_profitable`) → savings of roughly **~9k gas** in the test envelope (same pool fixture).
- Tip + arb adds ~**25.7k** over the no-tip path (ETH payment + cold/warm coinbase).

---

## Optimizations applied (Phase 7)

| Technique | Where | Effect |
|-----------|-------|--------|
| `MevSwapLib.swapRoundTrip` | arb / backrun | Single reused `address[]`; fewer allocations |
| No `forceApprove(0)` after swap | `MevSwapLib`, sandwich | Avoids 2× allowance-to-zero SSTORE |
| `tokenIn` cached on the stack | solvers | Fewer repeated calldata reads / SLOADs |
| `ProfitLib.takeProfit` | hot path | Single pass vs `requireProfit` + `netProfit` |
| `CoinbaseTip.payAssembly` | production tip | Yul `call` + `coinbase` without extra wrapper |
| Custom errors | `MevErrors` | Cheaper than `require` strings |
| `optimizer_runs = 10_000` + `via_ir` | `foundry.toml` | Aggressive inlining |

### Tradeoff: residual allowance

Not clearing the allowance after the swap saves gas at the cost of leaving an approval on the router. Acceptable in v1 because the searcher controls the routers (mocks / own contracts). In v2: Permit2 or optional `forceApprove(0)`.

---

## Tip comparison (harness)

| Function | Test gas | Delta |
|----------|----------|-------|
| `pay` (Solidity `.call`) | 37 508 | baseline |
| `payAssembly` (Yul) | 37 293 | **−215** |

In the harness contract gas report: `pay` **53 315** vs `payAssembly` **53 254** (includes similar external-call overhead).

---

## Deploy

```bash
anvil   # another terminal
export PATH="$HOME/.foundry/bin:$PATH"
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Env: `PRIVATE_KEY`, `SEARCHER`. See `script/Deploy.s.sol` and `.env.example`.

Bundle sim: `forge script script/SimulateBundle.s.sol:SimulateBundle -vvv`

README: [`../README-EN.md`](../README-EN.md) · Docs index: [`README-EN.md`](./README-EN.md) · SWC: [`SWC-AUDIT-EN.md`](./SWC-AUDIT-EN.md)
