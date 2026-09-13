# 15 — MEV & HFT Trading Infrastructure

Infraestructura de searcher MEV de baja latencia, bundles privados (Flashbots Auction) y solvers on-chain de arbitraje/backrun/sandwich atómicos. Solidity `0.8.24` + Foundry.

**Estado:** Fases **0–2** ✅ (setup + libs + AtomicArbitrageSolver). Fases **3–7** pendientes de autorización.

## Docs

Ver [`doc/`](./doc/README.md) — planificación, diagramas de clases/flujo y flujograma.

## Stack

| Capa | Tecnología |
|------|------------|
| Contratos | Solidity `0.8.24` (pragma fijo) |
| Tooling | Foundry (`forge` / `cast` / `anvil`) |
| Librerías | OpenZeppelin Contracts v5.2, forge-std |
| Bundles | Flashbots / Builder API (`eth_sendBundle`, `eth_callBundle`) |
| Seguridad | CEI, tip `block.coinbase`, `UnauthorizedSearcher`, profit check atómico |

## Setup

```bash
# Preferir Foundry de ~/.foundry/bin si el `forge` del PATH no es Foundry
export PATH="$HOME/.foundry/bin:$PATH"

forge build
forge test
```

Dependencias (ya instaladas en Fase 0; reinstalar si hace falta):

```bash
forge install foundry-rs/forge-std@v1.16.2 --no-git --shallow
forge install OpenZeppelin/openzeppelin-contracts@v5.2.0 --no-git --shallow
```

Fork opcional:

```bash
# En `.env` (copiar desde `.env.example`)
MAINNET_RPC_URL=https://...
forge test --match-path test/fork/
```

## Deploy local (stub Fase 0)

```bash
anvil   # otra terminal
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Env: ver `.env.example` (`PRIVATE_KEY`, `SEARCHER`, `MAINNET_RPC_URL`).

## Gobernanza de fases

No avanzar sin *“autorizo Fase N”*. Detalle en [`doc/planificacion.md`](./doc/planificacion.md).
