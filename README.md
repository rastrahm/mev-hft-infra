# 15 — MEV & HFT Trading Infrastructure

Infraestructura de searcher MEV de baja latencia, bundles privados (Flashbots Auction) y solvers on-chain de arbitraje/backrun/sandwich atómicos. Solidity `0.8.24` + Foundry.

**Estado:** Fases **0–7** ✅ (módulo v1 cerrado).

## Docs

Ver [`doc/`](./doc/README.md) — planificación, diagramas, SWC-AUDIT y gas.

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
export PATH="$HOME/.foundry/bin:$PATH"

forge build
forge test
forge snapshot --match-contract MevGasTest
```

Dependencias (ya en `lib/`; reinstalar si hace falta):

```bash
forge install foundry-rs/forge-std@v1.16.2 --no-git --shallow
forge install OpenZeppelin/openzeppelin-contracts@v5.2.0 --no-git --shallow
```

Fork opcional:

```bash
# En `.env` (copiar desde `.env.example`)
MAINNET_RPC_URL=https://...
forge test --match-path 'test/fork/*'
forge script script/SimulateBundle.s.sol:SimulateBundle --fork-url $MAINNET_RPC_URL -vvv
```

Simulación de bundle (local):

```bash
forge script script/SimulateBundle.s.sol:SimulateBundle -vvv
```

## Deploy local

```bash
anvil   # otra terminal
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Env: ver `.env.example` (`PRIVATE_KEY`, `SEARCHER`, `MAINNET_RPC_URL`).
