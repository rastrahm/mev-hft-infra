# Documentation — Module 15: MEV & HFT Trading Infrastructure

Design, security, and gas index for the module (MEV searcher, Flashbots bundles, atomic solvers).

| File | Content | Status |
|------|---------|--------|
| [planificacion-EN.md](./planificacion-EN.md) | Phases 0–7, implemented architecture, criteria | ✅ Closed |
| [ENTENDIMIENTO-EN.md](./ENTENDIMIENTO-EN.md) | Technical decisions, logic, and gas improvements | ✅ |
| [diagrama-de-clases-EN.md](./diagrama-de-clases-EN.md) | UML: solvers, `MevSwapLib`, hooks, mocks | ✅ Updated |
| [diagrama-de-flujo-EN.md](./diagrama-de-flujo-EN.md) | Decisions: auth → swap → tip → `takeProfit` | ✅ Updated |
| [flujograma-EN.md](./flujograma-EN.md) | E2E searcher → bundle → on-chain + sandwich lab | ✅ Updated |
| [SWC-AUDIT-EN.md](./SWC-AUDIT-EN.md) | SWC-100–136 matrix (0 vulnerable) | ✅ |
| [GAS-EN.md](./GAS-EN.md) | Yul vs Solidity tip baseline + hot paths | ✅ |

**Module status:** Phases **0–7** ✅ (v1 closed).  
**Suite:** `forge test` → **71 PASS / 3 SKIP** (fork without RPC).

Module README: [`../README-EN.md`](../README-EN.md) · Español: [`README-ES.md`](./README-ES.md).
