# Auditoría SWC — MEV & HFT Trading Infrastructure

Verificación de solvers/executors MEV contra el [SWC Registry](https://swcregistry.io/) (EIP-1470) y principios del monorepo (custom errors, pragma fijo, CEI, SafeERC20, ReentrancyGuard, tip coinbase atómico).

> **Nota:** El SWC Registry no se mantiene activamente desde ~2020. Complementar con [SCSVS](https://github.com/ComposableSecurity/SCSVS) y [EEA EthTrust](https://entethalliance.org/specs/ethtrust/). Estilo alineado a [`14-amm-v3-concentrated-liquidity/doc/SWC-AUDIT.md`](../../14-amm-v3-concentrated-liquidity/doc/SWC-AUDIT.md).

**Contratos auditados (prod / core):**  
`src/AtomicArbitrageSolver.sol`, `src/BackrunExecutor.sol`, `src/SandwichExecutor.sol`,  
`src/libraries/{ProfitLib,CoinbaseTip,CalldataCodec,MevSwapLib}.sol`,  
`src/interfaces/{IAtomicArbitrageSolver,IBackrunExecutor,ISandwichExecutor,IDexRouter,ISimpleAMM}.sol`,  
`src/errors/MevErrors.sol`

**Dependencias de confianza (fuera de alcance de bugs propios):**  
OpenZeppelin Contracts v5.2.0 (`Ownable2Step`, `ReentrancyGuard`, `SafeERC20`, `IERC20`)

**Mocks (fuera de prod):** `MockERC20`, `MockAMM`, `MockRouter`, `RejectETH`  
**Fecha:** 2026-09-13  
**Referencia tests:** `test/*.t.sol`, `test/libraries/`, `test/fuzz/`, `test/fork/`, `test/gas/`  
**Índice docs:** [`README.md`](./README.md) · README módulo: [`../README.md`](../README.md)

---

## Resumen ejecutivo

| Estado | Cantidad |
|--------|----------|
| ✅ Mitigado / No aplicable | 31 |
| ⚠️ Informativo (diseño / trust / ops) | 5 |
| ❌ Vulnerable | 0 |

**Conclusión:** Sin vulnerabilidades SWC explotables en el alcance v1. Los ejecutores usan **`ReentrancyGuard`**, **`authorizedSearcher`**, **custom errors**, **pragma fijo `0.8.24`**, **SafeERC20**, tip a `block.coinbase` vía Yul con chequeo de success, y **`ProfitLib.takeProfit`** que revierte la tx completa (incl. tip) si EV &lt; `minProfit`. Riesgos informativos: MEV/orden de txs es el dominio del módulo; `SandwichExecutor` es **lab-only**; allowance residual en routers de confianza; `BundleExpired` reservado; ownership de withdraw.

**Principios del suite / módulo 15 verificados:**

| Principio | Estado |
|-----------|--------|
| Custom errors (no `require` strings) | ✅ `MevErrors` |
| Pragma fijo `0.8.24` | ✅ |
| CEI + `ReentrancyGuard` | ✅ |
| SafeERC20 + ETH `.call` / Yul (no `transfer`/`send`) | ✅ |
| Profit check atómico + tip sin residual en revert | ✅ |
| `UnauthorizedSearcher` | ✅ |
| Fuzz ≥ 1000 runs | ✅ `foundry.toml` + `test/fuzz/` |
| Fork opcional + SimulateBundle | ✅ Fase 6 |

---

## Matriz completa SWC-100 — SWC-136

| ID | Título | Aplica | Estado | Evidencia en MEV/HFT |
|----|--------|--------|--------|---------------------|
| SWC-100 | Function Default Visibility | Sí | ✅ | Visibilidad explícita en `src/` |
| SWC-101 | Integer Overflow and Underflow | Sí | ✅ | Solidity `0.8.24`; `unchecked` solo en deltas ya validados (`takeProfit` / `netProfit`) |
| SWC-102 | Outdated Compiler Version | Sí | ✅ | `pragma solidity 0.8.24` + `foundry.toml` |
| SWC-103 | Floating Pragma | Sí | ✅ | Pragma exacto (sin `^`) |
| SWC-104 | Unchecked Call Return Value | Sí | ✅ | Tip: chequeo `ok` → `TipTransferFailed`; withdraw ETH igual; SafeERC20 |
| SWC-105 | Unprotected Ether Withdrawal | Sí | ✅ | `withdraw` / `setSearcher` solo `onlyOwner` (`Ownable2Step`) |
| SWC-106 | Unprotected SELFDESTRUCT | No | N/A | Sin `selfdestruct` |
| SWC-107 | Reentrancy | Sí | ✅ | `nonReentrant` en `execute` / `backrun` / `sandwich` / `withdraw`; tip tras swaps |
| SWC-108 | State Variable Default Visibility | Sí | ✅ | `authorizedSearcher` `public` |
| SWC-109 | Uninitialized Storage Pointer | No | N/A | Sin punteros storage legacy |
| SWC-110 | Assert Violation | No | N/A | Sin `assert` de producción |
| SWC-111 | Deprecated Solidity Functions | Sí | ✅ | Sin `suicide` / `throw` / `tx.origin` / ETH `transfer`/`send` |
| SWC-112 | Delegatecall to Untrusted Callee | No | N/A | Sin `delegatecall` |
| SWC-113 | DoS with Failed Call | Parcial | ✅ | Tip/withdraw fallidos revierten; routers fallidos revierten el bundle tx |
| SWC-114 | Transaction Order Dependence | Sí | ⚠️ | Dominio MEV; ver riesgos |
| SWC-115 | Authorization through tx.origin | No | N/A | Auth por `msg.sender == authorizedSearcher` |
| SWC-116 | Block values as a proxy for time | Parcial | ✅ | `block.coinbase` es destino de tip (intencional), no proxy de tiempo |
| SWC-117 | Signature Malleability | No | N/A | Sin firmas on-chain |
| SWC-118 | Incorrect Constructor Name | No | N/A | `constructor` 0.8+ |
| SWC-119 | Shadowing State Variables | Sí | ✅ | Sin shadowing material |
| SWC-120 | Weak Sources of Randomness | No | N/A | Sin RNG |
| SWC-121 | Missing Protection against Signature Replay | No | N/A | Sin firmas |
| SWC-122 | Lack of Proper Signature Verification | No | N/A | Sin firmas |
| SWC-123 | Requirement Violation | Sí | ✅ | Custom errors + unit / revert-on-unprofitable / fuzz / unauthorized |
| SWC-124 | Write to Arbitrary Storage Location | Parcial | ✅ | Assembly en `CoinbaseTip` / `CalldataCodec` es `memory-safe` / calldata; sin SSTORE arbitrario |
| SWC-125 | Incorrect Inheritance Order | Sí | ✅ | Interface + Ownable2Step + ReentrancyGuard |
| SWC-126 | Insufficient Gas Griefing | Parcial | ⚠️ | `midHook` / routers maliciosos pueden gastar gas del searcher; ver riesgos |
| SWC-127 | Arbitrary Jump with Function Type Variable | No | N/A | Sin function types dinámicos |
| SWC-128 | DoS With Block Gas Limit | Parcial | ⚠️ | Responsabilidad del searcher (tamaño de trade / routers) |
| SWC-129 | Typographical Error | Sí | ✅ | Revisión + `forge build` / suite PASS |
| SWC-130 | Right-To-Left-Override | No | N/A | ASCII en `src/` |
| SWC-131 | Presence of unused variables | Parcial | ⚠️ | `BundleExpired` reservado (scripts/fork); sin dead code en hot paths |
| SWC-132 | Unexpected Ether balance | Parcial | ✅ | ETH solo para tips; `receive` + `withdraw` owner; tip no cuenta en snapshot ERC-20 |
| SWC-133 | Hash Collisions (var-length args) | No | N/A | Sin hashing de args variables en auth |
| SWC-134 | Message call with hardcoded gas | No | N/A | Tip usa `gas()` completo |
| SWC-135 | Code With No Effects | No | N/A | Tip `0` = no-op intencional |
| SWC-136 | Unencrypted Private Data On-Chain | Parcial | ✅ | Searcher/owner públicos; claves off-chain en `.gitignore` |

---

## Riesgos informativos

### SWC-114 — Orden de transacciones / MEV

El módulo **es** infraestructura MEV (arb, backrun, sandwich lab). Competencia de bundles y orden en el bloque es riesgo de dominio, no bypass de `NegativeEV` / auth. Mitigación: simulación previa (`eth_callBundle` / `SimulateBundle.s.sol`), `minProfit`, slippage mins.

### SWC-126 / SWC-128 — hooks y routers

- `SandwichExecutor.midHook` y routers externos son elegidos por el searcher. Un hook OOG afecta al caller, no rompe el guard de reentrancy.
- `MevSwapLib` no hace `forceApprove(0)` post-swap: allowance residual en routers **de confianza del searcher** (tradeoff de gas; ver `GAS.md`).

### SWC-131 — `BundleExpired`

Error reservado para deadlines off-chain / fork; no usado en hot path v1.

### Sandwich lab-only

`SandwichExecutor` está documentado como **LAB / FORK / TESTS**. No es runbook de explotación en mainnet.

### Centralización / trust post-deploy

| Tema | Riesgo | Tratamiento v1 |
|------|--------|----------------|
| `owner` | `setSearcher` / `withdraw` | `Ownable2Step` |
| `authorizedSearcher` | Ejecución privilegiada | Rotación solo owner; tests Unauthorized |
| Routers / midHook | Lógica externa | Searcher controla; lab mocks |
| Tip a coinbase | Builder recibe ETH | Solo si profit check pasa |

---

## Checklist principios monorepo (+ módulo 15)

| Principio | ¿Cumple? | Notas |
|-----------|----------|--------|
| Custom errors | ✅ | `UnauthorizedSearcher`, `NegativeEV`, `TipTransferFailed`, … |
| CEI + ReentrancyGuard | ✅ | Snapshot → swaps → tip → verify |
| SafeERC20 / ETH seguro | ✅ | Tip Yul + withdraw `.call` |
| NatSpec públicas/externas | ✅ | Solvers, libs, interfaces |
| Fuzz ≥ 1000 | ✅ | `Mev.fuzz.t.sol`, libs |
| Revert-on-unprofitable sin tip | ✅ | `RevertOnUnprofitable.t.sol` |
| Sin floating pragma | ✅ | `0.8.24` |
| Gas profiling tip Yul vs Solidity | ✅ | `doc/GAS.md` |

---

## Hallazgos de verificación (código)

### Mitigaciones confirmadas

1. **Auth:** `msg.sender != authorizedSearcher` → `UnauthorizedSearcher` en los tres ejecutores.
2. **Atomic EV:** `ProfitLib.takeProfit` tras tip; revert deshace tip (tests Fase 5).
3. **Tip:** `CoinbaseTip.payAssembly` con chequeo; `RejectETH` como coinbase → `TipTransferFailed`.
4. **Reentrancy:** `nonReentrant` en paths de ejecución y withdraw.
5. **Withdraw ETH/ERC-20:** solo owner; address(0) / amount 0 revertidos.
6. **CalldataCodec:** longitud fija 144/64; decode Yul `memory-safe`.
7. **Suite:** unit + unauthorized + revert-on-unprofitable + fuzz + fork skip + gas.

### Hardening Fase 7

| # | Cambio | Motivo |
|---|--------|--------|
| 1 | `MevSwapLib` + `takeProfit` | Menos gas en hot path |
| 2 | Sin `forceApprove(0)` post-swap | Ahorro SSTORE; routers trusted |
| 3 | `script/Deploy.s.sol` completo | Deploy local reproducible |
| 4 | `test/gas/Mev.gas.t.sol` + `.gas-snapshot` | Baseline tip/arb/backrun |
| 5 | `doc/SWC-AUDIT.md` / `doc/GAS.md` | Matriz SWC-100–136 + benchmarks |

### Observaciones no bloqueantes (v2)

| # | Observación | Severidad | Acción sugerida |
|---|-------------|---------|-----------------|
| 1 | Allowance residual en routers | Info | `forceApprove(0)` opcional o Permit2 |
| 2 | Sandwich solo lab | Info | Mantener fuera de prod |
| 3 | Sin flash-loan capital | Info | Integrar ERC-3156 (módulo 08) |
| 4 | `BundleExpired` sin uso | Info | Deadline on-chain en execute |
| 5 | Invariantes Foundry formales | Mejora | Handler sobre solvers |

---

## Mapeo SWC → tests

| SWC | Test(s) |
|-----|---------|
| SWC-101 | `ProfitLib.t.sol`, fuzz |
| SWC-103 | `forge build` pragma fijo |
| SWC-104 / tip | `CoinbaseTip.t.sol`, tip reject en solvers |
| SWC-105 | withdraw onlyOwner (arb/backrun tests) |
| SWC-107 | `nonReentrant` + paths e2e |
| SWC-114 / EV | `RevertOnUnprofitable.t.sol`, fuzz flat pools |
| SWC-115 / auth | `Unauthorized.t.sol` |
| SWC-123 | suite completa |
| Gas | `test/gas/Mev.gas.t.sol` |

---

## Resultado de ejecución

```text
forge test --summary
# 2026-09-13 Fase 7
# 71 PASS / 0 FAIL / 3 SKIP (fork sin MAINNET_RPC_URL)
```

---

## Referencias

- [SWC Registry](https://swcregistry.io/)
- [EIP-1470](https://eips.ethereum.org/EIPS/eip-1470)
- Módulo 14: [`14-amm-v3-concentrated-liquidity/doc/SWC-AUDIT.md`](../../14-amm-v3-concentrated-liquidity/doc/SWC-AUDIT.md)
- Gas: [`GAS.md`](./GAS.md)
- Plan: [`planificacion.md`](./planificacion.md)
