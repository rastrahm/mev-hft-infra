# Documentación — Módulo 15: MEV & HFT Trading Infrastructure

Índice de diseño, seguridad y gas del módulo (searcher MEV, bundles Flashbots, solvers atómicos).

| Archivo | Contenido | Estado |
|---------|-----------|--------|
| [planificacion.md](./planificacion.md) | Fases 0–7, arquitectura implementada, criterios | ✅ Cerrado |
| [diagrama-de-clases.md](./diagrama-de-clases.md) | UML: solvers, `MevSwapLib`, hooks, mocks | ✅ Actualizado |
| [diagrama-de-flujo.md](./diagrama-de-flujo.md) | Decisiones: auth → swap → tip → `takeProfit` | ✅ Actualizado |
| [flujograma.md](./flujograma.md) | E2E searcher → bundle → on-chain + sandwich lab | ✅ Actualizado |
| [SWC-AUDIT.md](./SWC-AUDIT.md) | Matriz SWC-100–136 (0 vulnerables) | ✅ |
| [GAS.md](./GAS.md) | Baseline tip Yul vs Solidity + hot paths | ✅ |

**Estado del módulo:** Fases **0–7** ✅ (v1 cerrado).  
**Suite:** `forge test` → **71 PASS / 3 SKIP** (fork sin RPC).

README del módulo: [`../README.md`](../README.md).
