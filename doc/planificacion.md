# Planificación — Módulo 15: MEV & HFT Trading Infrastructure

**Estado:** Fases **0–7** ✅ completadas (módulo v1 cerrado).  
**Regla de avance:** cada fase requiere **autorización explícita** del responsable antes de empezar (*“autorizo Fase N”* o equivalente).

---

## 1. Objetivo

Construir infraestructura de **searcher MEV de baja latencia** y contratos de ejecución atómica que permitan:

- Simular y enviar **bundles privados** al estilo Flashbots Auction (`eth_sendBundle` / `mev_sendBundle` / `eth_callBundle`).
- Ejecutar **backrun** y **sandwich** on-chain con tip directo a `block.coinbase`.
- Resolver **arbitraje atómico** con capital de riesgo cero: la tx **revierte por completo** si el beneficio neto (tras tip + gas) no alcanza `minProfit`.
- Restringir la ejecución a un **searcher EOA autorizado** o relayer de confianza.
- Optimizar gas con **Yul/assembly** en parsing de calldata y tips ETH.

Stack: **Foundry + Solidity `0.8.24`** (pragma fijo). Frontend Next.js queda **fuera de alcance v1**.

---

## 2. Alcance

| Incluido (v1) | Excluido (v1) |
|---------------|---------------|
| `AtomicArbitrageSolver` — swaps A↔B atómicos + profit check | Path finder multi-hop off-chain en producción |
| `BackrunExecutor` — tip coinbase + ejecución post-victim | Sandwich agresivo en mainnet real (solo lab/fork) |
| `SandwichExecutor` — front + victim + back (lab) con guards | Builder/relayer propio tipo PBS |
| Access control: `authorizedSearcher` + `UnauthorizedSearcher` | Keystore / signing infra en cloud |
| Tip builder vía `block.coinbase` (assembly o `.call`) | Frontend Next.js de monitoreo |
| Scripts Foundry: simulación de bundle / fork mainnet | Integración live Flashbots Protect en CI |
| Libs: profit math, calldata decode Yul, tip helper | Cross-chain MEV / L2 sequencers |
| Tests: fork, revert-on-unprofitable, gas, fuzz tip/slippage | Oráculos Chainlink para “fair price” |

---

## 3. Stack y restricciones técnicas

### Suite (`evm-smart-contracts-suite`)

- Solidity **exacto** `0.8.24` (sin floating pragma).
- OpenZeppelin Contracts v5.x (`ReentrancyGuard`, `Ownable2Step`, `SafeERC20`).
- Foundry: unit + fuzz (`runs >= 1000`) + fork tests + gas reports.
- **Custom errors** (preferir sobre `require` con strings; el módulo exige check de profit con mensaje `"Negative EV"` en el diseño de negocio — implementar como custom error `NegativeEV()` y, si se necesita compatibilidad de tests, alias documentado).
- CEI estricto; ERC-20 vía SafeERC20; ETH vía `.call{value: ...}("")` o assembly controlado hacia `coinbase`.
- NatSpec en toda API pública/externa.
- Layout: Interfaces → Libraries → Contracts → State → Events → Errors → Modifiers → Functions.

### Módulo 15 (MEV / HFT)

- Bundles: formato Builder/Flashbots con `blockNumber` target y simulación previa.
- Ejecución atómica: `require(finalBalance >= initialBalance + minProfit)` → revert total si EV negativo.
- Tip: transferencia directa a `block.coinbase` **solo si** el trade es rentable (orden: trade → tip → verify profit, o tip dentro del envelope que revierte si falla verify).
- Guard: `msg.sender == authorizedSearcher` (o relayer whitelist) → `UnauthorizedSearcher()`.
- Gas: decode de rutas/amounts en assembly; tip en Yul donde aporte ROI de gas medible.

### Next.js (`nextjs.cursorrules`) — post-v1

- Si se añade dashboard: App Router, Zod, Vitest + RTL, JSDoc, sin `any`.
- No forma parte de las fases 0–7.

---

## 4. Arquitectura (propuesta v1)

```
15-mev-hft-infra/
├── README.md
├── doc/
│   ├── planificacion.md
│   ├── diagrama-de-clases.md
│   ├── diagrama-de-flujo.md
│   └── flujograma.md
├── src/
│   ├── AtomicArbitrageSolver.sol      # Arbitraje 2-pool atómico + tip + profit
│   ├── BackrunExecutor.sol            # Backrun de victim tx + tip coinbase
│   ├── SandwichExecutor.sol           # Front/back sandwich (lab) + guards
│   ├── interfaces/
│   │   ├── IAtomicArbitrageSolver.sol
│   │   ├── IBackrunExecutor.sol
│   │   ├── ISandwichExecutor.sol
│   │   ├── IDexRouter.sol             # swapExactIn mínimo
│   │   └── IUniswapV2Pair.sol         # opcional para swap directo
│   ├── libraries/
│   │   ├── ProfitLib.sol              # balance delta / minProfit check
│   │   ├── CoinbaseTip.sol            # tip seguro a block.coinbase
│   │   └── CalldataCodec.sol          # decode Yul de rutas/params
│   ├── errors/
│   │   └── MevErrors.sol
│   └── mocks/
│       ├── MockERC20.sol
│       ├── MockAMM.sol                # x*y=k, reservas seteables
│       └── MockRouter.sol
├── test/
│   ├── helpers/MevTestBase.sol
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
│   └── SimulateBundle.s.sol           # eth_callBundle / fork simulate
├── foundry.toml
├── remappings.txt
├── .env.example
└── .gas-snapshot
```

### Contratos y responsabilidades

| Artefacto | Responsabilidad |
|-----------|-----------------|
| `AtomicArbitrageSolver` | Orquesta swaps entre 2+ pools; tip; verifica `minProfit` |
| `BackrunExecutor` | Ejecuta trade después de una victim tx simulada; tip builder |
| `SandwichExecutor` | Front-run + back-run atómicos en lab; mismos guards de profit |
| `ProfitLib` | Snapshot de balance, delta, `NegativeEV` |
| `CoinbaseTip` | Pago ETH a `block.coinbase` sin reentrancy leak |
| `CalldataCodec` | Parse calldata compacto en Yul |
| `MevErrors` | Custom errors del módulo |
| `MockAMM` / `MockRouter` | Desequilibrio artificial para unit tests |
| `SimulateBundle.s.sol` | Script de simulación de bundle en fork |

---

## 5. Errores custom (módulo)

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

> Nota de diseño: el `.cursorrules` del módulo menciona `require(..., "Negative EV")`. En la suite se implementa como `error NegativeEV()` (custom error) manteniendo la semántica de EV negativo.

---

## 6. Gobernanza de fases (autorización obligatoria)

| Regla | Detalle |
|-------|---------|
| **Gate** | No se escribe código de una fase hasta: *“autorizo Fase N”*. |
| **Entrega** | Al cerrar: checklist de aceptación + archivos tocados. |
| **Bloqueo** | Alcance nuevo → documentar y esperar nueva autorización. |
| **TDD** | En fases de contratos: tests primero, luego implementación. |

### Tablero de fases

| Fase | Nombre | Estado | Autorización |
|------|--------|--------|--------------|
| 0 | Setup Foundry + estructura + deps | ✅ Completada | ✅ Autorizada |
| 1 | Errors + libs (`ProfitLib`, `CoinbaseTip`, `CalldataCodec`) | ✅ Completada | ✅ Autorizada |
| 2 | `AtomicArbitrageSolver` (unit + mocks) | ✅ Completada | ✅ Autorizada |
| 3 | `BackrunExecutor` + tip coinbase | ✅ Completada | ✅ Autorizada |
| 4 | `SandwichExecutor` (lab) + Unauthorized | ✅ Completada | ✅ Autorizada |
| 5 | Revert-on-unprofitable + fuzz tip/slippage/volume | ✅ Completada | ✅ Autorizada |
| 6 | Fork mainnet + `SimulateBundle` | ✅ Completada | ✅ Autorizada |
| 7 | Gas Yul vs Solidity + Deploy + NatSpec / SWC | ✅ Completada | ✅ Autorizada |

---

## 7. Detalle por fase

### Fase 0 — Setup Foundry ✅

**Objetivo:** repo compilable con tooling de la suite.

1. Scaffold Foundry (`foundry.toml`: solc `0.8.24`, optimizer, fuzz `runs >= 1000`, `[rpc_endpoints].mainnet`).
2. Dependencias: `forge-std`, OpenZeppelin v5.
3. Carpetas `src/{interfaces,libraries,errors,mocks}`, `test/{helpers,fuzz,fork,gas}`, `script/`, `doc/`.
4. Stub mínimo + smoke test; `.env.example` (RPC, searcher pk **solo local**).

**Criterio de salida:** `forge build` y `forge test` en verde.

**Hecho (2026-09-13):**
- `foundry.toml` (solc `0.8.24`, Cancun, optimizer `10_000`, `via_ir`, fuzz `runs = 1000`, `[rpc_endpoints].mainnet`).
- `remappings.txt`: `forge-std/`, `@openzeppelin/contracts/`.
- Dependencias en `lib/` (gitignored): `forge-std` **v1.16.2**, OpenZeppelin **v5.2.0** (copiadas del módulo 14; `forge install` a GitHub no disponible en el entorno).
- Carpetas `src/{interfaces,libraries,errors,mocks}`, `test/{helpers,fuzz,fork,gas}`, `script/`.
- Stub `src/Placeholder.sol` + `test/Placeholder.t.sol` (ping + remapping IERC20).
- Stub `script/Deploy.s.sol` (Fase 7), `.env.example`, `README.md`, `doc/README.md`.
- `forge build` OK; `forge test` → **3 PASS**.

---

### Fase 1 — Errors + libraries ✅

**Objetivo:** primitives reutilizables de profit, tip y decode.

1. Tests TDD: `ProfitLib` (delta, `NegativeEV`), `CoinbaseTip` (pago a coinbase mockeado), decode calldata.
2. Implementación Yul donde el gas report lo justifique.
3. Documentar tradeoffs de gas en comentarios `@dev`.

**Criterio de salida:** libs en verde; tip falla → `TipTransferFailed`.

**Hecho (2026-09-13):**
- `src/errors/MevErrors.sol` — custom errors del módulo (incl. `UnauthorizedSearcher`, `NegativeEV`, `TipTransferFailed`).
- `src/libraries/ProfitLib.sol` — `snapshot` (ERC-20 / ETH), `requireProfit`, `netProfit`.
- `src/libraries/CoinbaseTip.sol` — `pay` (`.call`) + `payAssembly` (Yul `call` + `coinbase`); tip `0` no-op.
- `src/libraries/CalldataCodec.sol` — `Route` + encode/decode packed 144 B / amounts 64 B en Yul.
- Mocks: `MockERC20`, `RejectETH` (coinbase que rechaza ETH).
- Tests: `test/libraries/{ProfitLib,CoinbaseTip,CalldataCodec}.t.sol` + harnesses; fuzz ≥ 1000.
- Stub `Placeholder` eliminado.
- **`forge test` → 22 PASS**.

---

### Fase 2 — AtomicArbitrageSolver ✅

**Objetivo:** arbitraje 2-AMM atómico con capital de riesgo cero.

1. Tests: spread rentable → profit ≥ `minProfit`; spread cerrado → revert `NegativeEV`.
2. Auth: solo `authorizedSearcher`.
3. Flujo: snapshot balance → swaps → tip opcional → verify → CEI.

**Criterio de salida:** unit + unauthorized en verde.

**Hecho (2026-09-13):**
- Interfaces: `IAtomicArbitrageSolver`, `IDexRouter`, `ISimpleAMM`.
- Mocks: `MockAMM` (x*y=k 0.3%), `MockRouter` (path len 2).
- `AtomicArbitrageSolver`: Ownable2Step + ReentrancyGuard; `execute` / `setSearcher` / `withdraw`.
- Flujo: auth → snapshot `tokenIn` → swap A → swap B → `CoinbaseTip.payAssembly` → `requireProfit`.
- Tests: rentable, tip, NegativeEV (sin tip residual), unauthorized, zero amount, tip reject, withdraw, events.
- **`forge test` → 34 PASS**.

---

### Fase 3 — BackrunExecutor ✅

**Objetivo:** ejecutar backrun post-victim con tip al builder.

1. Tests: victim mueve precio → backrun captura spread → tip a coinbase.
2. Sin tip si la tx revierte (atomicidad).
3. Integración con mocks de pool desbalanceado por victim.

**Criterio de salida:** tip solo en path rentable; revert limpio si no.

**Hecho (2026-09-13):**
- `IBackrunExecutor` + `BackrunExecutor` (Ownable2Step, ReentrancyGuard, `backrun` / `setSearcher` / `withdraw`).
- Flujo: auth → snapshot → swap A/B → `payAssembly` tip → `requireProfit`.
- Tests: victim buy en pool A → backrun compra en B / vende en A; tip; NegativeEV sin victim (sin bribe residual); unauthorized; tip reject.
- **`forge test` → 43 PASS**.

---

### Fase 4 — SandwichExecutor (lab) ✅

**Objetivo:** front + back en una sola envelope atómica (solo tests/lab).

1. Tests: sandwich rentable; sandwich no rentable → revert sin tip.
2. Guards idénticos de searcher + `minProfit`.
3. Documentar riesgos éticos/legales: **solo fork/lab**, no runbook de ataque en mainnet.

**Criterio de salida:** suite Unauthorized + sandwich lab en verde.

**Hecho (2026-09-13):**
- `ISandwichExecutor` / `SandwichLeg` / `ISandwichMidHook` + `SandwichExecutor` (lab only en NatSpec).
- Flujo: front → `midHook.afterFront` (victim simulada) → back → tip → `requireProfit`.
- `test/SandwichExecutor.t.sol`: rentable+victim, tip, NegativeEV sin victim (sin bribe), auth, tip reject.
- `test/Unauthorized.t.sol`: `UnauthorizedSearcher` en arb / backrun / sandwich.
- **`forge test` → 55 PASS**.

---

### Fase 5 — Revert-on-unprofitable + fuzz ✅

**Objetivo:** cumplir matriz de testing del `.cursorrules` del módulo.

| Tipo | Qué valida |
|------|------------|
| Revert-on-unprofitable | Movimiento de precio invalida EV → revert; **sin** tip pagado |
| Fuzz | Slippage, tip %, volumen de trade |
| Auth | Caller no autorizado → `UnauthorizedSearcher` |

**Criterio de salida:** fuzz ≥ 1000; asserts de no-tip en revert.

**Hecho (2026-09-13):**
- `test/RevertOnUnprofitable.t.sol`: arb flat / price-move / minProfit alto; backrun sin imbalance; sandwich sin victim — todos con assert `builder.balance` sin tip.
- `test/fuzz/Mev.fuzz.t.sol`: volumen+tip bps rentable; slippage alto sin tip; flat pools siempre `NegativeEV`; tip bps en path rentable (1000 runs c/u).
- Auth ya cubierto en `Unauthorized.t.sol` (Fase 4).
- **`forge test` → 64 PASS**.

---

### Fase 6 — Fork + SimulateBundle ✅

**Objetivo:** validar contra mainnet fork con imbalance simulado.

1. `Arbitrage.fork.t.sol` (skip si no hay `MAINNET_RPC_URL`).
2. `SimulateBundle.s.sol`: arma txs estilo bundle y simula en fork.
3. Documentar formato Flashbots (`blockNumber`, `txs[]`) a alto nivel en script comments.

**Criterio de salida:** fork pass opcional; script documentado.

**Hecho (2026-09-13):**
- `test/fork/Arbitrage.fork.t.sol`: arb+tip, NegativeEV sin tip, backrun post-victim; `vm.skip` sin `MAINNET_RPC_URL`.
- `script/SimulateBundle.s.sol`: docs `eth_sendBundle` / `eth_callBundle` / `mev_sendBundle`; sim local OK (profit + tip).
- **`forge test` → 64 PASS + 3 SKIP** (fork sin RPC). Script: `forge script script/SimulateBundle.s.sol:SimulateBundle -vvv`.

---

### Fase 7 — Gas + Deploy + hardening ✅

1. `Deploy.s.sol` (solver + executor + mocks demo).
2. `test/gas/Mev.gas.t.sol`: path assembly vs Solidity estándar.
3. NatSpec completo; `doc/SWC-AUDIT.md` y `doc/GAS.md`.

**Criterio de salida:** deploy local + docs seguridad/gas.

**Hecho (2026-09-13):**
- Optimización: `MevSwapLib` (path reutilizado, sin `approve(0)`), `ProfitLib.takeProfit`, tip `payAssembly`.
- `test/gas/Mev.gas.t.sol` + `.gas-snapshot` (tip Yul −215 vs `.call`; arb noTip ~227.6k).
- `script/Deploy.s.sol` — arb + backrun + sandwich + mocks fondeados.
- `doc/SWC-AUDIT.md` — matriz SWC-100–136 (estilo módulo 14), **0 vulnerables**, 5 informativos.
- `doc/GAS.md` — baseline + tradeoffs.
- **`forge test` → 71 PASS + 3 SKIP**.

---

## 8. Matriz de pruebas (objetivo v1)

| Caso | Qué valida | Fase |
|------|------------|------|
| Arb rentable | profit ≥ minProfit; tip opcional | 2 |
| Arb no rentable | `NegativeEV`; sin tip | 2, 5 |
| Unauthorized caller | `UnauthorizedSearcher` | 2–4 |
| Backrun post-victim | captura spread + tip coinbase | 3 |
| Sandwich lab OK / fail | atomicidad front+back | 4 |
| Fuzz tip % / slippage / volume | bounds y reverts | 5 |
| Fork imbalance | e2e en mainnet fork | 6 |
| Gas Yul vs Solidity | overhead documentado | 7 |

---

## 9. Seguridad (checklist vivo)

- [x] CEI en solvers/executors; `ReentrancyGuard` donde hay callbacks externos.
- [x] SafeERC20; ETH a coinbase vía `.call` o assembly con chequeo de success.
- [x] Custom errors del módulo (`UnauthorizedSearcher`, `NegativeEV`, …).
- [x] Profit check **después** de trades y **antes** de considerar la tx exitosa; tip no queda pagado si revierte.
- [x] Solo searcher/relayer autorizado.
- [x] Sin floating pragma; NatSpec en APIs públicas.
- [x] Fuzz de tip, slippage y volúmenes.
- [x] Tests de revert-on-unprofitable sin bribe residual.
- [x] (Fase 7) SWC-AUDIT + gas.
- [x] Nunca versionar claves privadas / keystores (ver `.gitignore`).

---

## 10. Entregables de documentación (`doc/`)

| Archivo | Contenido | Estado |
|---------|-----------|--------|
| `planificacion.md` | Este documento | ✅ |
| `diagrama-de-clases.md` | Estructura y relaciones | ✅ |
| `diagrama-de-flujo.md` | Flujos de decisión | ✅ |
| `flujograma.md` | Flujos actor–sistema e2e | ✅ |
| `SWC-AUDIT.md` | Matriz SWC (Fase 7) | ✅ |
| `GAS.md` | Benchmarks (Fase 7) | ✅ |
| `README.md` | Índice del módulo | ✅ |

---

## 11. Criterios de aceptación del módulo

1. [x] Compila con `pragma solidity 0.8.24`.
2. [x] Solvers atómicos: EV negativo → revert total.
3. [x] Tip a `block.coinbase` solo en path exitoso.
4. [x] Guard `UnauthorizedSearcher` en ejecución.
5. [x] Fork test de arbitraje con imbalance simulado.
6. [x] Fuzz de tip %, slippage y volúmenes.
7. [x] Gas profiling assembly vs Solidity.
8. [x] Custom errors + NatSpec.
9. [x] `doc/SWC-AUDIT.md` sin vulnerabilidades en alcance v1.

---

## 12. Próximo paso

**Módulo v1 cerrado.** Extensiones opcionales (v2): Permit2 / clear approve, flash-loan capital (ERC-3156), deadline `BundleExpired`, invariantes Foundry.

**Nota:** usar `~/.foundry/bin/forge` (o anteponer `$HOME/.foundry/bin` al `PATH`); el `forge` de nvm/npm no es Foundry.
