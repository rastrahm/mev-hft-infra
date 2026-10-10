# Planning — Module 15: MEV & HFT Trading Infrastructure

**Status:** Phases **0–7** ✅ completed (module v1 closed).  
**Progress rule:** each phase requires **explicit authorization** from the owner before starting (*"I authorize Phase N"* or equivalent).

---

## 1. Objective

Build **low-latency MEV searcher** infrastructure and atomic execution contracts that allow you to:

- Simulate and send **private bundles** in the Flashbots Auction style (`eth_sendBundle` / `mev_sendBundle` / `eth_callBundle`).
- Execute on-chain **backruns** and **sandwiches** with a direct tip to `block.coinbase`.
- Solve **atomic arbitrage** with zero capital risk: the tx **reverts entirely** if the net profit (after tip + gas) does not reach `minProfit`.
- Restrict execution to an **authorized searcher EOA** or trusted relayer.
- Optimize gas with **Yul/assembly** for calldata parsing and ETH tips.

Stack: **Foundry + Solidity `0.8.24`** (fixed pragma). A Next.js frontend is **out of scope for v1**.

---

## 2. Scope

| Included (v1) | Excluded (v1) |
|---------------|---------------|
| `AtomicArbitrageSolver` — atomic A↔B swaps + profit check | Production off-chain multi-hop path finder |
| `BackrunExecutor` — coinbase tip + post-victim execution | Aggressive sandwich on real mainnet (lab/fork only) |
| `SandwichExecutor` — front + victim + back (lab) with guards | Own PBS-style builder/relayer |
| Access control: `authorizedSearcher` + `UnauthorizedSearcher` | Cloud keystore / signing infra |
| Builder tip via `block.coinbase` (assembly or `.call`) | Next.js monitoring frontend |
| Foundry scripts: bundle simulation / mainnet fork | Live Flashbots Protect integration in CI |
| Libs: `ProfitLib`, `CoinbaseTip`, `CalldataCodec`, `MevSwapLib` | Cross-chain MEV / L2 sequencers |
| Tests: fork, revert-on-unprofitable, gas, tip/slippage fuzz | Chainlink oracles for "fair price" |

---

## 3. Stack and technical constraints

### Suite (`evm-smart-contracts-suite`)

- **Exact** Solidity `0.8.24` (no floating pragma).
- OpenZeppelin Contracts v5.x (`ReentrancyGuard`, `Ownable2Step`, `SafeERC20`).
- Foundry: unit + fuzz (`runs >= 1000`) + fork tests + gas reports.
- **Custom errors** (preferred over `require` with strings; the module requires a profit check with the message `"Negative EV"` in the business design — implemented as the custom error `NegativeEV()` and, if test compatibility is needed, a documented alias).
- Strict CEI; ERC-20 via SafeERC20; ETH via `.call{value: ...}("")` or controlled assembly towards `coinbase`.
- NatSpec on every public/external API.
- Layout: Interfaces → Libraries → Contracts → State → Events → Errors → Modifiers → Functions.

### Module 15 (MEV / HFT)

- Bundles: Builder/Flashbots format with a target `blockNumber` and prior simulation.
- Atomic execution: `ProfitLib.takeProfit` → full revert if EV is negative (`NegativeEV`).
- Tip: `CoinbaseTip.payAssembly` to `block.coinbase` **before** the profit check (if EV fails, the tip is reverted).
- Guard: `msg.sender == authorizedSearcher` → `UnauthorizedSearcher()`.
- Gas: `MevSwapLib` + Yul tip + `takeProfit` (see [`GAS-EN.md`](./GAS-EN.md)).

### Next.js (`nextjs.cursorrules`) — post-v1

- If a dashboard is added: App Router, Zod, Vitest + RTL, JSDoc, no `any`.
- Not part of phases 0–7.

---

## 4. Architecture (v1 implemented)

```
15-mev-hft-infra/
├── README.md                      # language index
├── README-ES.md / README-EN.md
├── doc/
│   ├── README.md                  # language index
│   ├── README-{ES,EN}.md
│   ├── planificacion-{ES,EN}.md
│   ├── ENTENDIMIENTO-{ES,EN}.md
│   ├── diagrama-de-clases-{ES,EN}.md
│   ├── diagrama-de-flujo-{ES,EN}.md
│   ├── flujograma-{ES,EN}.md
│   ├── SWC-AUDIT-{ES,EN}.md
│   └── GAS-{ES,EN}.md
├── src/
│   ├── AtomicArbitrageSolver.sol
│   ├── BackrunExecutor.sol
│   ├── SandwichExecutor.sol
│   ├── interfaces/
│   │   ├── IAtomicArbitrageSolver.sol
│   │   ├── IBackrunExecutor.sol
│   │   ├── ISandwichExecutor.sol      # + SandwichLeg, ISandwichMidHook
│   │   ├── IDexRouter.sol
│   │   └── ISimpleAMM.sol
│   ├── libraries/
│   │   ├── ProfitLib.sol              # snapshot / requireProfit / netProfit / takeProfit
│   │   ├── CoinbaseTip.sol            # pay + payAssembly (Yul)
│   │   ├── CalldataCodec.sol          # packed Route 144 B / amounts 64 B
│   │   └── MevSwapLib.sol             # 2-router round-trip (hot path)
│   ├── errors/
│   │   └── MevErrors.sol
│   └── mocks/
│       ├── MockERC20.sol
│       ├── MockAMM.sol
│       ├── MockRouter.sol
│       └── RejectETH.sol
├── test/
│   ├── helpers/{MevTestBase,LibHarnesses}.sol
│   ├── libraries/{ProfitLib,CoinbaseTip,CalldataCodec}.t.sol
│   ├── AtomicArbitrageSolver.t.sol
│   ├── BackrunExecutor.t.sol
│   ├── SandwichExecutor.t.sol
│   ├── Unauthorized.t.sol
│   ├── RevertOnUnprofitable.t.sol
│   ├── fuzz/Mev.fuzz.t.sol
│   ├── fork/Arbitrage.fork.t.sol
│   └── gas/Mev.gas.t.sol
├── script/
│   ├── Deploy.s.sol
│   └── SimulateBundle.s.sol
├── foundry.toml
├── remappings.txt
├── .env.example
└── .gas-snapshot
```

### Contracts and responsibilities

| Artifact | Responsibility |
|----------|----------------|
| `AtomicArbitrageSolver` | Atomic 2-router arb; tip; `takeProfit` |
| `BackrunExecutor` | Post-victim backrun; same hot path as arb |
| `SandwichExecutor` | Front → midHook victim → back (lab); tip; profit |
| `MevSwapLib` | Gas-optimized round-trip (reused path; no approve(0)) |
| `ProfitLib` | Snapshot + `takeProfit` / `requireProfit` / `netProfit` |
| `CoinbaseTip` | ETH tip to `block.coinbase` (Yul in prod) |
| `CalldataCodec` | Packed encode/decode of `Route` and amounts |
| `MevErrors` | Module custom errors |
| `MockAMM` / `MockRouter` / `RejectETH` | Tests, imbalance / failed tip |
| `SimulateBundle.s.sol` | Local `eth_callBundle`-style simulation |

---

## 5. Custom errors (module)

```solidity
error UnauthorizedSearcher();
error NegativeEV();
error ZeroAddress();
error InvalidRoute();
error TipTransferFailed();
error InsufficientOutput();
error SlippageExceeded();
error BundleExpired();
error ZeroAmount();
```

> Design note: the module's `.cursorrules` mentions `require(..., "Negative EV")`. The suite implements it as `error NegativeEV()` (custom error) while keeping the negative-EV semantics.

---

## 6. Phase governance (mandatory authorization)

| Rule | Detail |
|------|--------|
| **Gate** | No code for a phase is written until: *"I authorize Phase N"*. |
| **Delivery** | On close: acceptance checklist + files touched. |
| **Blocking** | New scope → document and wait for new authorization. |
| **TDD** | In contract phases: tests first, then implementation. |

### Phase board

| Phase | Name | Status | Authorization |
|-------|------|--------|---------------|
| 0 | Foundry setup + structure + deps | ✅ Completed | ✅ Authorized |
| 1 | Errors + libs (`ProfitLib`, `CoinbaseTip`, `CalldataCodec`) | ✅ Completed | ✅ Authorized |
| 2 | `AtomicArbitrageSolver` (unit + mocks) | ✅ Completed | ✅ Authorized |
| 3 | `BackrunExecutor` + coinbase tip | ✅ Completed | ✅ Authorized |
| 4 | `SandwichExecutor` (lab) + Unauthorized | ✅ Completed | ✅ Authorized |
| 5 | Revert-on-unprofitable + tip/slippage/volume fuzz | ✅ Completed | ✅ Authorized |
| 6 | Mainnet fork + `SimulateBundle` | ✅ Completed | ✅ Authorized |
| 7 | Yul vs Solidity gas + Deploy + NatSpec / SWC | ✅ Completed | ✅ Authorized |

---

## 7. Phase details

### Phase 0 — Foundry setup ✅

**Objective:** a repo that compiles with the suite's tooling.

1. Foundry scaffold (`foundry.toml`: solc `0.8.24`, optimizer, fuzz `runs >= 1000`, `[rpc_endpoints].mainnet`).
2. Dependencies: `forge-std`, OpenZeppelin v5.
3. Folders `src/{interfaces,libraries,errors,mocks}`, `test/{helpers,fuzz,fork,gas}`, `script/`, `doc/`.
4. Minimal stub + smoke test; `.env.example` (RPC, searcher pk **local only**).

**Exit criterion:** `forge build` and `forge test` green.

**Done (2026-09-13):**
- `foundry.toml` (solc `0.8.24`, Cancun, optimizer `10_000`, `via_ir`, fuzz `runs = 1000`, `[rpc_endpoints].mainnet`).
- `remappings.txt`: `forge-std/`, `@openzeppelin/contracts/`.
- Dependencies in `lib/` (gitignored): `forge-std` **v1.16.2**, OpenZeppelin **v5.2.0** (copied from module 14; `forge install` from GitHub not available in the environment).
- Folders `src/{interfaces,libraries,errors,mocks}`, `test/{helpers,fuzz,fork,gas}`, `script/`.
- Stub `src/Placeholder.sol` + `test/Placeholder.t.sol` (ping + IERC20 remapping).
- Stub `script/Deploy.s.sol` (Phase 7), `.env.example`, `README.md`, `doc/README.md`.
- `forge build` OK; `forge test` → **3 PASS**.

---

### Phase 1 — Errors + libraries ✅

**Objective:** reusable primitives for profit, tip, and decoding.

1. TDD tests: `ProfitLib` (delta, `NegativeEV`), `CoinbaseTip` (payment to mocked coinbase), calldata decode.
2. Yul implementation where the gas report justifies it.
3. Document gas tradeoffs in `@dev` comments.

**Exit criterion:** libs green; failed tip → `TipTransferFailed`.

**Done (2026-09-13):**
- `src/errors/MevErrors.sol` — module custom errors (incl. `UnauthorizedSearcher`, `NegativeEV`, `TipTransferFailed`).
- `src/libraries/ProfitLib.sol` — `snapshot` (ERC-20 / ETH), `requireProfit`, `netProfit`.
- `src/libraries/CoinbaseTip.sol` — `pay` (`.call`) + `payAssembly` (Yul `call` + `coinbase`); tip `0` is a no-op.
- `src/libraries/CalldataCodec.sol` — `Route` + packed encode/decode 144 B / amounts 64 B in Yul.
- Mocks: `MockERC20`, `RejectETH` (coinbase that rejects ETH).
- Tests: `test/libraries/{ProfitLib,CoinbaseTip,CalldataCodec}.t.sol` + harnesses; fuzz ≥ 1000.
- `Placeholder` stub removed.
- **`forge test` → 22 PASS**.

---

### Phase 2 — AtomicArbitrageSolver ✅

**Objective:** atomic 2-AMM arbitrage with zero capital risk.

1. Tests: profitable spread → profit ≥ `minProfit`; closed spread → revert `NegativeEV`.
2. Auth: only `authorizedSearcher`.
3. Flow: balance snapshot → swaps → optional tip → verify → CEI.

**Exit criterion:** unit + unauthorized green.

**Done (2026-09-13):**
- Interfaces: `IAtomicArbitrageSolver`, `IDexRouter`, `ISimpleAMM`.
- Mocks: `MockAMM` (x*y=k 0.3%), `MockRouter` (path len 2).
- `AtomicArbitrageSolver`: Ownable2Step + ReentrancyGuard; `execute` / `setSearcher` / `withdraw`.
- Flow: auth → snapshot `tokenIn` → swap A → swap B → `CoinbaseTip.payAssembly` → `requireProfit`.
- Tests: profitable, tip, NegativeEV (no residual tip), unauthorized, zero amount, tip reject, withdraw, events.
- **`forge test` → 34 PASS**.

---

### Phase 3 — BackrunExecutor ✅

**Objective:** execute a post-victim backrun with a tip to the builder.

1. Tests: victim moves price → backrun captures the spread → tip to coinbase.
2. No tip if the tx reverts (atomicity).
3. Integration with pool mocks unbalanced by the victim.

**Exit criterion:** tip only on the profitable path; clean revert otherwise.

**Done (2026-09-13):**
- `IBackrunExecutor` + `BackrunExecutor` (Ownable2Step, ReentrancyGuard, `backrun` / `setSearcher` / `withdraw`).
- Flow: auth → snapshot → swap A/B → `payAssembly` tip → `requireProfit`.
- Tests: victim buy on pool A → backrun buys on B / sells on A; tip; NegativeEV without victim (no residual bribe); unauthorized; tip reject.
- **`forge test` → 43 PASS**.

---

### Phase 4 — SandwichExecutor (lab) ✅

**Objective:** front + back in a single atomic envelope (tests/lab only).

1. Tests: profitable sandwich; unprofitable sandwich → revert without tip.
2. Same searcher + `minProfit` guards.
3. Document ethical/legal risks: **fork/lab only**, no mainnet attack runbook.

**Exit criterion:** Unauthorized suite + sandwich lab green.

**Done (2026-09-13):**
- `ISandwichExecutor` / `SandwichLeg` / `ISandwichMidHook` + `SandwichExecutor` (lab only in NatSpec).
- Flow: front → `midHook.afterFront` (simulated victim) → back → tip → `requireProfit`.
- `test/SandwichExecutor.t.sol`: profitable+victim, tip, NegativeEV without victim (no bribe), auth, tip reject.
- `test/Unauthorized.t.sol`: `UnauthorizedSearcher` on arb / backrun / sandwich.
- **`forge test` → 55 PASS**.

---

### Phase 5 — Revert-on-unprofitable + fuzz ✅

**Objective:** satisfy the testing matrix of the module's `.cursorrules`.

| Type | What it validates |
|------|-------------------|
| Revert-on-unprofitable | Price movement invalidates EV → revert; **no** tip paid |
| Fuzz | Slippage, tip %, trade volume |
| Auth | Unauthorized caller → `UnauthorizedSearcher` |

**Exit criterion:** fuzz ≥ 1000; no-tip asserts on revert.

**Done (2026-09-13):**
- `test/RevertOnUnprofitable.t.sol`: arb flat / price-move / high minProfit; backrun without imbalance; sandwich without victim — all with a `builder.balance` no-tip assert.
- `test/fuzz/Mev.fuzz.t.sol`: profitable volume+tip bps; high slippage without tip; flat pools always `NegativeEV`; tip bps on profitable path (1000 runs each).
- Auth already covered in `Unauthorized.t.sol` (Phase 4).
- **`forge test` → 64 PASS**.

---

### Phase 6 — Fork + SimulateBundle ✅

**Objective:** validate against a mainnet fork with simulated imbalance.

1. `Arbitrage.fork.t.sol` (skip if there is no `MAINNET_RPC_URL`).
2. `SimulateBundle.s.sol`: builds bundle-style txs and simulates them on a fork.
3. Document the Flashbots format (`blockNumber`, `txs[]`) at a high level in script comments.

**Exit criterion:** optional fork pass; documented script.

**Done (2026-09-13):**
- `test/fork/Arbitrage.fork.t.sol`: arb+tip, NegativeEV without tip, post-victim backrun; `vm.skip` without `MAINNET_RPC_URL`.
- `script/SimulateBundle.s.sol`: docs for `eth_sendBundle` / `eth_callBundle` / `mev_sendBundle`; local sim OK (profit + tip).
- **`forge test` → 64 PASS + 3 SKIP** (fork without RPC). Script: `forge script script/SimulateBundle.s.sol:SimulateBundle -vvv`.

---

### Phase 7 — Gas + Deploy + hardening ✅

1. `Deploy.s.sol` (solver + executor + demo mocks).
2. `test/gas/Mev.gas.t.sol`: assembly path vs standard Solidity.
3. Full NatSpec; `doc/SWC-AUDIT-EN.md` and `doc/GAS-EN.md`.

**Exit criterion:** local deploy + security/gas docs.

**Done (2026-09-13):**
- Optimization: `MevSwapLib` (reused path, no `approve(0)`), `ProfitLib.takeProfit`, `payAssembly` tip.
- `test/gas/Mev.gas.t.sol` + `.gas-snapshot` (Yul tip −215 vs `.call`; arb noTip ~227.6k).
- `script/Deploy.s.sol` — arb + backrun + sandwich + funded mocks.
- `doc/SWC-AUDIT-EN.md` — SWC-100–136 matrix (module 14 style), **0 vulnerable**, 5 informational.
- `doc/GAS-EN.md` — baseline + tradeoffs.
- **`forge test` → 71 PASS + 3 SKIP**.

---

## 8. Test matrix (v1 target)

| Case | What it validates | Phase |
|------|-------------------|-------|
| Profitable arb | profit ≥ minProfit; optional tip | 2 |
| Unprofitable arb | `NegativeEV`; no tip | 2, 5 |
| Unauthorized caller | `UnauthorizedSearcher` | 2–4 |
| Post-victim backrun | captures spread + coinbase tip | 3 |
| Sandwich lab OK / fail | front+back atomicity | 4 |
| Fuzz tip % / slippage / volume | bounds and reverts | 5 |
| Fork imbalance | e2e on mainnet fork | 6 |
| Yul vs Solidity gas | documented overhead | 7 |

---

## 9. Security (living checklist)

- [x] CEI in solvers/executors; `ReentrancyGuard` where there are external callbacks.
- [x] SafeERC20; ETH to coinbase via `.call` or assembly with a success check.
- [x] Module custom errors (`UnauthorizedSearcher`, `NegativeEV`, …).
- [x] Profit check **after** trades and **before** considering the tx successful; tip is not left paid if it reverts.
- [x] Only authorized searcher/relayer.
- [x] No floating pragma; NatSpec on public APIs.
- [x] Tip, slippage, and volume fuzzing.
- [x] Revert-on-unprofitable tests with no residual bribe.
- [x] (Phase 7) SWC-AUDIT + gas.
- [x] Never commit private keys / keystores (see `.gitignore`).

---

## 10. Documentation deliverables (`doc/`)

| File | Content | Status |
|------|---------|--------|
| `planificacion-EN.md` | This document | ✅ |
| `ENTENDIMIENTO-EN.md` | Decisions, logic, and gas | ✅ |
| `diagrama-de-clases-EN.md` | Structure and relationships | ✅ |
| `diagrama-de-flujo-EN.md` | Decision flows | ✅ |
| `flujograma-EN.md` | Actor–system e2e flows | ✅ |
| `SWC-AUDIT-EN.md` | SWC matrix (Phase 7) | ✅ |
| `GAS-EN.md` | Benchmarks (Phase 7) | ✅ |
| `README-EN.md` | Documentation index | ✅ |

Each file has its Spanish original with the `-ES.md` suffix; `README.md` is the language index.

---

## 11. Module acceptance criteria

1. [x] Compiles with `pragma solidity 0.8.24`.
2. [x] Atomic solvers: negative EV → full revert.
3. [x] Tip to `block.coinbase` only on the successful path.
4. [x] `UnauthorizedSearcher` guard on execution.
5. [x] Arbitrage fork test with simulated imbalance.
6. [x] Tip %, slippage, and volume fuzzing.
7. [x] Assembly vs Solidity gas profiling.
8. [x] Custom errors + NatSpec.
9. [x] `doc/SWC-AUDIT-EN.md` with no vulnerabilities in v1 scope.

---

## 12. Next step

**Module v1 closed.** Optional extensions (v2): Permit2 / clear approve, flash-loan capital (ERC-3156), `BundleExpired` deadline, Foundry invariants.

**Note:** use `~/.foundry/bin/forge` (or prepend `$HOME/.foundry/bin` to `PATH`); the nvm/npm `forge` is not Foundry.
