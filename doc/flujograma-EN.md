# Flowchart — Full MEV & HFT Infrastructure Cycle

End-to-end flow between actors, contracts, and relay/builder (module 15, **v1 implemented**).

## Actors

| Actor | Role |
|-------|------|
| Searcher EOA | Detects opportunities; signs and sends the bundle txs |
| AtomicArbitrageSolver | 2-router arb + `MevSwapLib` + tip + `takeProfit` |
| BackrunExecutor | Captures post-victim spread (same hot path) |
| SandwichExecutor | Front → midHook victim → back (lab/fork) |
| MevSwapLib / ProfitLib / CoinbaseTip | Swap, EV, and tip libraries |
| DEX / AMM (mocks) | Pools where the imbalance happens |
| Builder / Flashbots Relay | Private bundle; tip via `block.coinbase` |
| CI / Foundry | Unit, fuzz, fork, gas, `SimulateBundle` |

---

## Main flowchart — Deploy + authorization

```mermaid
flowchart TD
    Start([Start]) --> Dep[Deploy.s.sol: solvers + mocks]
    Dep --> Own[Owner: Ownable2Step]
    Own --> Auth[authorizedSearcher in constructor / setSearcher]
    Auth --> Fund[Fund tokens + ETH for tips]
    Fund --> Ready([Ready lab/fork/Anvil])
```

---

## Main flowchart — Searcher → bundle → on-chain

```mermaid
flowchart TD
    Start([Mempool / price event]) --> Detect[Searcher detects spread or victim]
    Detect --> Build[route, amountIn, minProfit, tipWei]
    Build --> Sim[SimulateBundle / eth_callBundle / forge fork]
    Sim --> OkSim{EV >= minProfit after tip?}
    OkSim -->|No| Drop[Discard]
    OkSim -->|Yes| Send[eth_sendBundle / mev_sendBundle]
    Send --> Incl{Builder includes it?}
    Incl -->|No| Retry[Re-evaluate next block]
    Incl -->|Yes| Exec[auth → MevSwapLib → payAssembly → takeProfit]
    Exec --> Profit{NegativeEV?}
    Profit -->|Yes| Rev[Revert — no residual tip]
    Profit -->|No| Done([Profit in the contract / searcher])
    Drop --> End([End])
    Retry --> Detect
    Rev --> End
    Done --> End
```

---

## Main flowchart — Atomic arbitrage

```mermaid
flowchart TD
    Start([Searcher: execute]) --> Auth{Authorized?}
    Auth -->|No| ErrU[UnauthorizedSearcher]
    Auth -->|Yes| Snap[snapshot tokenIn]
    Snap --> RT[MevSwapLib.swapRoundTrip]
    RT --> Tip[payAssembly tipWei]
    Tip --> Check[takeProfit]
    Check -->|fail| ErrN[NegativeEV]
    Check -->|ok| Ok([Emit + return profit])
    ErrU --> Fail([End — rejected])
    ErrN --> Fail
    Ok --> Success([End — OK])
```

---

## Main flowchart — Backrun after victim

```mermaid
flowchart TD
    Start([Ordered bundle]) --> V[Victim swap on AMM]
    V --> B[BackrunExecutor.backrun]
    B --> Auth{Searcher authorized?}
    Auth -->|No| Fail[UnauthorizedSearcher]
    Auth -->|Yes| Trade[MevSwapLib round-trip]
    Trade --> Tip[payAssembly]
    Tip --> EV[takeProfit]
    EV -->|No| Rev[NegativeEV]
    EV -->|Yes| Ok([Backrun + tip OK])
    Fail --> End([End])
    Rev --> End
    Ok --> End
```

---

## Flowchart — Revert-on-unprofitable (no bribe)

```mermaid
flowchart TD
    A[Price moves / flat pools] --> B[Swaps → EV < minProfit]
    B --> C[takeProfit fails]
    C --> D[Revert NegativeEV]
    D --> E[EVM undoes tip to coinbase]
    E --> F[Assert: builder.balance without tip]
```

---

## Flowchart — Typical attacks / misuse

```mermaid
flowchart TD
    A[Caller is not the searcher] --> B[UnauthorizedSearcher]
    C[minProfit too high] --> D[NegativeEV]
    E[Malformed router / path] --> F[ZeroAddress / InvalidRoute]
    G[Coinbase RejectETH] --> H[TipTransferFailed]
    I[amountIn = 0] --> J[ZeroAmount]
    K[Absurd amountOutMin] --> L[MockAMM.SlippageExceeded]
```

---

## Sequence — arbitrage happy path + tip

```mermaid
sequenceDiagram
    actor S as Searcher EOA
    participant Rel as Builder/Relay
    participant Sol as AtomicArbitrageSolver
    participant Lib as MevSwapLib
    participant CB as block.coinbase

    S->>S: Detect spread + SimulateBundle
    S->>Rel: eth_sendBundle([executeTx], targetBlock)
    Rel->>Sol: execute(route, amountIn, minProfit, tipWei)
    Sol->>Sol: require authorizedSearcher
    Sol->>Sol: snapshot(tokenIn)
    Sol->>Lib: swapRoundTrip(...)
    Lib-->>Sol: mid OK
    Sol->>CB: payAssembly(tipWei)
    Sol->>Sol: takeProfit(...)
    Sol-->>S: profit (event)
```

---

## Sequence — sandwich lab (midHook)

```mermaid
sequenceDiagram
    actor S as Searcher
    participant Ex as SandwichExecutor
    participant Hook as ISandwichMidHook
    participant Pool as MockAMM

    S->>Ex: sandwich(front, back, hook, victimData, minProfit, tip)
    Ex->>Pool: front-run
    Ex->>Hook: afterFront(victimData)
    Hook->>Pool: victim swap
    Ex->>Pool: back-run
    Ex->>Ex: payAssembly + takeProfit
    alt profitable
        Ex-->>S: profit
    else not profitable
        Ex-->>S: revert NegativeEV
    end
```

---

## Implementation governance

```mermaid
flowchart LR
    Doc[doc/ ✅] --> F0[Phase 0 Setup ✅]
    F0 --> F1[Phase 1 Libs ✅]
    F1 --> F2[Phase 2 AtomicArb ✅]
    F2 --> F3[Phase 3 Backrun ✅]
    F3 --> F4[Phase 4 Sandwich lab ✅]
    F4 --> F5[Phase 5 Fuzz / unprofitable ✅]
    F5 --> F6[Phase 6 Fork / SimulateBundle ✅]
    F6 --> F7[Phase 7 Gas / Deploy / SWC ✅]
    F7 --> Done([Module v1 closed ✅])
```

**Gate:** do not move to the next phase without *"I authorize Phase N"*. Details in [`planificacion-EN.md`](./planificacion-EN.md).  
**Status:** Phases **0–7** ✅ (module v1 closed).
