# Documentación — Módulo 15: MEV & HFT Trading Infrastructure

Índice de diseño, seguridad y gas del módulo (searcher MEV, bundles Flashbots, solvers atómicos).

| Archivo | Contenido | Estado |
|---------|-----------|--------|
| [planificacion-ES.md](./planificacion-ES.md) | Fases 0–7, arquitectura implementada, criterios | ✅ Cerrado |
| [ENTENDIMIENTO-ES.md](./ENTENDIMIENTO-ES.md) | Decisiones técnicas, lógica y mejoras de gas | ✅ |
| [diagrama-de-clases-ES.md](./diagrama-de-clases-ES.md) | UML: solvers, `MevSwapLib`, hooks, mocks | ✅ Actualizado |
| [diagrama-de-flujo-ES.md](./diagrama-de-flujo-ES.md) | Decisiones: auth → swap → tip → `takeProfit` | ✅ Actualizado |
| [flujograma-ES.md](./flujograma-ES.md) | E2E searcher → bundle → on-chain + sandwich lab | ✅ Actualizado |
| [SWC-AUDIT-ES.md](./SWC-AUDIT-ES.md) | Matriz SWC-100–136 (0 vulnerables) | ✅ |
| [GAS-ES.md](./GAS-ES.md) | Baseline tip Yul vs Solidity + hot paths | ✅ |

**Estado del módulo:** Fases **0–7** ✅ (v1 cerrado).  
**Suite:** `forge test` → **71 PASS / 3 SKIP** (fork sin RPC).

README del módulo: [`../README-ES.md`](../README-ES.md) · English: [`README-EN.md`](./README-EN.md).
