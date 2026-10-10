# 15 — MEV & HFT Trading Infrastructure

Low-latency MEV searcher infrastructure, private bundles (Flashbots Auction), and atomic on-chain arbitrage/backrun/sandwich solvers. Solidity `0.8.24` + Foundry.

**Status:** Phases **0–7** ✅ (module v1 closed).

## Docs

See [`doc/`](./doc/README-EN.md) — planning, diagrams, SWC-AUDIT and gas.  
Versión en español: [`README-ES.md`](./README-ES.md).

## Stack

| Layer | Technology |
|-------|------------|
| Contracts | Solidity `0.8.24` (fixed pragma) |
| Tooling | Foundry (`forge` / `cast` / `anvil`) |
| Libraries | OpenZeppelin Contracts v5.2, forge-std |
| Bundles | Flashbots / Builder API (`eth_sendBundle`, `eth_callBundle`) |
| Security | CEI, `block.coinbase` tip, `UnauthorizedSearcher`, atomic profit check |

## Setup

```bash
export PATH="$HOME/.foundry/bin:$PATH"

forge build
forge test
forge snapshot --match-contract MevGasTest
```

Dependencies (already in `lib/`; reinstall if needed):

```bash
forge install foundry-rs/forge-std@v1.16.2 --no-git --shallow
forge install OpenZeppelin/openzeppelin-contracts@v5.2.0 --no-git --shallow
```

Optional fork:

```bash
# In `.env` (copy from `.env.example`)
MAINNET_RPC_URL=https://...
forge test --match-path 'test/fork/*'
forge script script/SimulateBundle.s.sol:SimulateBundle --fork-url $MAINNET_RPC_URL -vvv
```

Bundle simulation (local):

```bash
forge script script/SimulateBundle.s.sol:SimulateBundle -vvv
```

## Local deploy

```bash
anvil   # another terminal
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Env: see `.env.example` (`PRIVATE_KEY`, `SEARCHER`, `MAINNET_RPC_URL`).
