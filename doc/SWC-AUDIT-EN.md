# SWC Audit — MEV & HFT Trading Infrastructure

Verification of the MEV solvers/executors against the [SWC Registry](https://swcregistry.io/) (EIP-1470) and monorepo principles (custom errors, fixed pragma, CEI, SafeERC20, ReentrancyGuard, atomic coinbase tip).

> **Note:** The SWC Registry has not been actively maintained since ~2020. Complement it with [SCSVS](https://github.com/ComposableSecurity/SCSVS) and [EEA EthTrust](https://entethalliance.org/specs/ethtrust/). Style aligned with [`14-amm-v3-concentrated-liquidity/doc/SWC-AUDIT-EN.md`](../../14-amm-v3-concentrated-liquidity/doc/SWC-AUDIT-EN.md).

**Audited contracts (prod / core):**  
`src/AtomicArbitrageSolver.sol`, `src/BackrunExecutor.sol`, `src/SandwichExecutor.sol`,  
`src/libraries/{ProfitLib,CoinbaseTip,CalldataCodec,MevSwapLib}.sol`,  
`src/interfaces/{IAtomicArbitrageSolver,IBackrunExecutor,ISandwichExecutor,IDexRouter,ISimpleAMM}.sol`,  
`src/errors/MevErrors.sol`

**Trusted dependencies (out of scope for own bugs):**  
OpenZeppelin Contracts v5.2.0 (`Ownable2Step`, `ReentrancyGuard`, `SafeERC20`, `IERC20`)

**Mocks (not production):** `MockERC20`, `MockAMM`, `MockRouter`, `RejectETH`  
**Date:** 2026-09-13  
**Test reference:** `test/*.t.sol`, `test/libraries/`, `test/fuzz/`, `test/fork/`, `test/gas/`  
**Docs index:** [`README-EN.md`](./README-EN.md) · Module README: [`../README-EN.md`](../README-EN.md)

---

## Executive summary

| Status | Count |
|--------|-------|
| ✅ Mitigated / Not applicable | 31 |
| ⚠️ Informational (design / trust / ops) | 5 |
| ❌ Vulnerable | 0 |

**Conclusion:** No exploitable SWC vulnerabilities in v1 scope. The executors use **`ReentrancyGuard`**, **`authorizedSearcher`**, **custom errors**, **fixed pragma `0.8.24`**, **SafeERC20**, a tip to `block.coinbase` via Yul with a success check, and **`ProfitLib.takeProfit`**, which reverts the whole tx (incl. tip) if EV &lt; `minProfit`. Informational risks: MEV/tx ordering is the module's domain; `SandwichExecutor` is **lab-only**; residual allowance on trusted routers; `BundleExpired` reserved; withdraw ownership.

**Suite / module 15 principles verified:**

| Principle | Status |
|-----------|--------|
| Custom errors (no `require` strings) | ✅ `MevErrors` |
| Fixed pragma `0.8.24` | ✅ |
| CEI + `ReentrancyGuard` | ✅ |
| SafeERC20 + ETH `.call` / Yul (no `transfer`/`send`) | ✅ |
| Atomic profit check + no residual tip on revert | ✅ |
| `UnauthorizedSearcher` | ✅ |
| Fuzz ≥ 1000 runs | ✅ `foundry.toml` + `test/fuzz/` |
| Optional fork + SimulateBundle | ✅ Phase 6 |

---

## Full matrix SWC-100 — SWC-136

| ID | Title | Applies | Status | Evidence in MEV/HFT |
|----|-------|---------|--------|---------------------|
| SWC-100 | Function Default Visibility | Yes | ✅ | Explicit visibility in `src/` |
| SWC-101 | Integer Overflow and Underflow | Yes | ✅ | Solidity `0.8.24`; `unchecked` only on already-validated deltas (`takeProfit` / `netProfit`) |
| SWC-102 | Outdated Compiler Version | Yes | ✅ | `pragma solidity 0.8.24` + `foundry.toml` |
| SWC-103 | Floating Pragma | Yes | ✅ | Exact pragma (no `^`) |
| SWC-104 | Unchecked Call Return Value | Yes | ✅ | Tip: `ok` check → `TipTransferFailed`; ETH withdraw likewise; SafeERC20 |
| SWC-105 | Unprotected Ether Withdrawal | Yes | ✅ | `withdraw` / `setSearcher` only `onlyOwner` (`Ownable2Step`) |
| SWC-106 | Unprotected SELFDESTRUCT | No | N/A | No `selfdestruct` |
| SWC-107 | Reentrancy | Yes | ✅ | `nonReentrant` on `execute` / `backrun` / `sandwich` / `withdraw`; tip after swaps |
| SWC-108 | State Variable Default Visibility | Yes | ✅ | `authorizedSearcher` is `public` |
| SWC-109 | Uninitialized Storage Pointer | No | N/A | No legacy storage pointers |
| SWC-110 | Assert Violation | No | N/A | No production `assert` |
| SWC-111 | Deprecated Solidity Functions | Yes | ✅ | No `suicide` / `throw` / `tx.origin` / ETH `transfer`/`send` |
| SWC-112 | Delegatecall to Untrusted Callee | No | N/A | No `delegatecall` |
| SWC-113 | DoS with Failed Call | Partial | ✅ | Failed tip/withdraw revert; failed routers revert the bundle tx |
| SWC-114 | Transaction Order Dependence | Yes | ⚠️ | MEV domain; see risks |
| SWC-115 | Authorization through tx.origin | No | N/A | Auth via `msg.sender == authorizedSearcher` |
| SWC-116 | Block values as a proxy for time | Partial | ✅ | `block.coinbase` is the tip destination (intentional), not a time proxy |
| SWC-117 | Signature Malleability | No | N/A | No on-chain signatures |
| SWC-118 | Incorrect Constructor Name | No | N/A | `constructor` 0.8+ |
| SWC-119 | Shadowing State Variables | Yes | ✅ | No material shadowing |
| SWC-120 | Weak Sources of Randomness | No | N/A | No RNG |
| SWC-121 | Missing Protection against Signature Replay | No | N/A | No signatures |
| SWC-122 | Lack of Proper Signature Verification | No | N/A | No signatures |
| SWC-123 | Requirement Violation | Yes | ✅ | Custom errors + unit / revert-on-unprofitable / fuzz / unauthorized |
| SWC-124 | Write to Arbitrary Storage Location | Partial | ✅ | Assembly in `CoinbaseTip` / `CalldataCodec` is `memory-safe` / calldata; no arbitrary SSTORE |
| SWC-125 | Incorrect Inheritance Order | Yes | ✅ | Interface + Ownable2Step + ReentrancyGuard |
| SWC-126 | Insufficient Gas Griefing | Partial | ⚠️ | Malicious `midHook` / routers can burn the searcher's gas; see risks |
| SWC-127 | Arbitrary Jump with Function Type Variable | No | N/A | No dynamic function types |
| SWC-128 | DoS With Block Gas Limit | Partial | ⚠️ | Searcher's responsibility (trade size / routers) |
| SWC-129 | Typographical Error | Yes | ✅ | Review + `forge build` / suite PASS |
| SWC-130 | Right-To-Left-Override | No | N/A | ASCII in `src/` |
| SWC-131 | Presence of unused variables | Partial | ⚠️ | `BundleExpired` reserved (scripts/fork); no dead code on hot paths |
| SWC-132 | Unexpected Ether balance | Partial | ✅ | ETH only for tips; `receive` + owner `withdraw`; tip not counted in the ERC-20 snapshot |
| SWC-133 | Hash Collisions (var-length args) | No | N/A | No hashing of variable-length args in auth |
| SWC-134 | Message call with hardcoded gas | No | N/A | Tip forwards full `gas()` |
| SWC-135 | Code With No Effects | No | N/A | Tip `0` = intentional no-op |
| SWC-136 | Unencrypted Private Data On-Chain | Partial | ✅ | Searcher/owner are public; keys off-chain in `.gitignore` |

---

## Informational risks

### SWC-114 — Transaction ordering / MEV

The module **is** MEV infrastructure (arb, backrun, sandwich lab). Bundle competition and in-block ordering are a domain risk, not a bypass of `NegativeEV` / auth. Mitigation: prior simulation (`eth_callBundle` / `SimulateBundle.s.sol`), `minProfit`, slippage minimums.

### SWC-126 / SWC-128 — hooks and routers

- `SandwichExecutor.midHook` and external routers are chosen by the searcher. An out-of-gas hook affects the caller; it does not break the reentrancy guard.
- `MevSwapLib` does not `forceApprove(0)` after the swap: residual allowance on routers **trusted by the searcher** (gas tradeoff; see `GAS-EN.md`).

### SWC-131 — `BundleExpired`

Error reserved for off-chain / fork deadlines; not used in the v1 hot path.

### Lab-only sandwich

`SandwichExecutor` is documented as **LAB / FORK / TESTS**. It is not a mainnet exploitation runbook.

### Centralization / post-deploy trust

| Topic | Risk | v1 treatment |
|-------|------|--------------|
| `owner` | `setSearcher` / `withdraw` | `Ownable2Step` |
| `authorizedSearcher` | Privileged execution | Rotation only by owner; Unauthorized tests |
| Routers / midHook | External logic | Searcher-controlled; lab mocks |
| Coinbase tip | Builder receives ETH | Only if the profit check passes |

---

## Monorepo principles checklist (+ module 15)

| Principle | Compliant? | Notes |
|-----------|------------|-------|
| Custom errors | ✅ | `UnauthorizedSearcher`, `NegativeEV`, `TipTransferFailed`, … |
| CEI + ReentrancyGuard | ✅ | Snapshot → swaps → tip → verify |
| SafeERC20 / safe ETH | ✅ | Yul tip + `.call` withdraw |
| NatSpec on public/external | ✅ | Solvers, libs, interfaces |
| Fuzz ≥ 1000 | ✅ | `Mev.fuzz.t.sol`, libs |
| Revert-on-unprofitable without tip | ✅ | `RevertOnUnprofitable.t.sol` |
| No floating pragma | ✅ | `0.8.24` |
| Yul vs Solidity tip gas profiling | ✅ | `doc/GAS-EN.md` |

---

## Verification findings (code)

### Confirmed mitigations

1. **Auth:** `msg.sender != authorizedSearcher` → `UnauthorizedSearcher` in all three executors.
2. **Atomic EV:** `ProfitLib.takeProfit` after the tip; revert undoes the tip (Phase 5 tests).
3. **Tip:** `CoinbaseTip.payAssembly` with check; `RejectETH` as coinbase → `TipTransferFailed`.
4. **Reentrancy:** `nonReentrant` on execution and withdraw paths.
5. **ETH/ERC-20 withdraw:** owner only; address(0) / amount 0 reverted.
6. **CalldataCodec:** fixed length 144/64; `memory-safe` Yul decode.
7. **Suite:** unit + unauthorized + revert-on-unprofitable + fuzz + fork skip + gas.

### Phase 7 hardening

| # | Change | Reason |
|---|--------|--------|
| 1 | `MevSwapLib` + `takeProfit` | Less gas on the hot path |
| 2 | No `forceApprove(0)` after swap | SSTORE savings; trusted routers |
| 3 | Complete `script/Deploy.s.sol` | Reproducible local deploy |
| 4 | `test/gas/Mev.gas.t.sol` + `.gas-snapshot` | Tip/arb/backrun baseline |
| 5 | `doc/SWC-AUDIT-EN.md` / `doc/GAS-EN.md` | SWC-100–136 matrix + benchmarks |

### Non-blocking observations (v2)

| # | Observation | Severity | Suggested action |
|---|-------------|----------|------------------|
| 1 | Residual allowance on routers | Info | Optional `forceApprove(0)` or Permit2 |
| 2 | Sandwich is lab-only | Info | Keep out of production |
| 3 | No flash-loan capital | Info | Integrate ERC-3156 (module 08) |
| 4 | `BundleExpired` unused | Info | On-chain deadline in execute |
| 5 | Formal Foundry invariants | Improvement | Handler over solvers |

---

## SWC → tests mapping

| SWC | Test(s) |
|-----|---------|
| SWC-101 | `ProfitLib.t.sol`, fuzz |
| SWC-103 | `forge build` fixed pragma |
| SWC-104 / tip | `CoinbaseTip.t.sol`, tip reject in solvers |
| SWC-105 | withdraw onlyOwner (arb/backrun tests) |
| SWC-107 | `nonReentrant` + e2e paths |
| SWC-114 / EV | `RevertOnUnprofitable.t.sol`, flat-pool fuzz |
| SWC-115 / auth | `Unauthorized.t.sol` |
| SWC-123 | full suite |
| Gas | `test/gas/Mev.gas.t.sol` |

---

## Execution result

```text
forge test --summary
# 2026-09-13 — docs sync post Phase 7
AtomicArbitrageSolverTest  12 PASS
BackrunExecutorTest         9 PASS
SandwichExecutorTest        9 PASS
UnauthorizedTest            3 PASS
RevertOnUnprofitableTest    5 PASS
MevFuzzTest                 4 PASS (1000 runs each)
MevGasTest                  5 PASS
ProfitLibTest              11 PASS
CoinbaseTipTest             7 PASS
CalldataCodecTest           6 PASS
ArbitrageForkTest           3 SKIP (no MAINNET_RPC_URL)
Total: 71 PASS / 0 FAIL / 3 SKIP
```

Gas snapshot (`.gas-snapshot`): arb noTip **227 631**; Yul tip **37 293** vs `.call` **37 508**.

---

## References

- [SWC Registry](https://swcregistry.io/)
- [EIP-1470](https://eips.ethereum.org/EIPS/eip-1470)
- Module 14: [`14-amm-v3-concentrated-liquidity/doc/SWC-AUDIT-EN.md`](../../14-amm-v3-concentrated-liquidity/doc/SWC-AUDIT-EN.md)
- Gas: [`GAS-EN.md`](./GAS-EN.md)
- Plan: [`planificacion-EN.md`](./planificacion-EN.md)
