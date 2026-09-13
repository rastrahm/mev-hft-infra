# Documentación — Módulo 15: MEV & HFT Trading Infrastructure

Índice de diseño y planificación de la infraestructura de searcher MEV, bundles Flashbots y solvers atómicos.

| Archivo | Contenido |
|---------|-----------|
| [planificacion.md](./planificacion.md) | Fases de desarrollo, gates de autorización, alcance y criterios |
| [diagrama-de-clases.md](./diagrama-de-clases.md) | Estructura de contratos, libs e interfaces |
| [diagrama-de-flujo.md](./diagrama-de-flujo.md) | Flujos de decisión (arb, tip, profit, sandwich lab) |
| [flujograma.md](./flujograma.md) | Flujos actor–sistema e2e (searcher → bundle → on-chain) |
| [SWC-AUDIT.md](./SWC-AUDIT.md) | Matriz SWC (Fase 7) |
| [GAS.md](./GAS.md) | Benchmarks Yul vs Solidity (Fase 7) |

**Regla:** cada fase de implementación requiere autorización explícita antes de escribir código.

**Estado actual:** Fases **0–2** ✅. Fases **3–7** ⏳.
