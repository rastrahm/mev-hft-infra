# Flujograma — Ciclo completo MEV & HFT Infrastructure

Flujo extremo a extremo entre actores, contratos y relayer/builder (módulo 15, **v1 implementado**).

## Actores

| Actor | Rol |
|-------|-----|
| Searcher EOA | Detecta oportunidades; firma y envía txs del bundle |
| AtomicArbitrageSolver | Arb 2-router + `MevSwapLib` + tip + `takeProfit` |
| BackrunExecutor | Captura spread post-victim (mismo hot path) |
| SandwichExecutor | Front → midHook victim → back (lab/fork) |
| MevSwapLib / ProfitLib / CoinbaseTip | Libs de swap, EV y tip |
| DEX / AMM (mocks) | Pools donde ocurre el desequilibrio |
| Builder / Flashbots Relay | Bundle privado; tip vía `block.coinbase` |
| CI / Foundry | Unit, fuzz, fork, gas, `SimulateBundle` |

---

## Flujograma principal — Deploy + autorización

```mermaid
flowchart TD
    Start([Inicio]) --> Dep[Deploy.s.sol: solvers + mocks]
    Dep --> Own[Owner: Ownable2Step]
    Own --> Auth[authorizedSearcher en constructor / setSearcher]
    Auth --> Fund[Fondear tokens + ETH tip]
    Fund --> Ready([Listo lab/fork/Anvil])
```

---

## Flujograma principal — Searcher → bundle → on-chain

```mermaid
flowchart TD
    Start([Mempool / evento de precio]) --> Detect[Searcher detecta spread o victim]
    Detect --> Build[route, amountIn, minProfit, tipWei]
    Build --> Sim[SimulateBundle / eth_callBundle / forge fork]
    Sim --> OkSim{¿EV >= minProfit tras tip?}
    OkSim -->|No| Drop[Descartar]
    OkSim -->|Sí| Send[eth_sendBundle / mev_sendBundle]
    Send --> Incl{¿Builder incluye?}
    Incl -->|No| Retry[Re-evaluar siguiente bloque]
    Incl -->|Sí| Exec[auth → MevSwapLib → payAssembly → takeProfit]
    Exec --> Profit{¿NegativeEV?}
    Profit -->|Sí| Rev[Revert — sin tip residual]
    Profit -->|No| Done([Profit en el contrato / searcher])
    Drop --> End([Fin])
    Retry --> Detect
    Rev --> End
    Done --> End
```

---

## Flujograma principal — Arbitraje atómico

```mermaid
flowchart TD
    Start([Searcher: execute]) --> Auth{¿authorized?}
    Auth -->|No| ErrU[UnauthorizedSearcher]
    Auth -->|Sí| Snap[snapshot tokenIn]
    Snap --> RT[MevSwapLib.swapRoundTrip]
    RT --> Tip[payAssembly tipWei]
    Tip --> Check[takeProfit]
    Check -->|fail| ErrN[NegativeEV]
    Check -->|ok| Ok([Emit + return profit])
    ErrU --> Fail([Fin — rechazo])
    ErrN --> Fail
    Ok --> Success([Fin — OK])
```

---

## Flujograma principal — Backrun tras victim

```mermaid
flowchart TD
    Start([Bundle ordenado]) --> V[Victim swap en AMM]
    V --> B[BackrunExecutor.backrun]
    B --> Auth{¿searcher auth?}
    Auth -->|No| Fail[UnauthorizedSearcher]
    Auth -->|Sí| Trade[MevSwapLib round-trip]
    Trade --> Tip[payAssembly]
    Tip --> EV[takeProfit]
    EV -->|No| Rev[NegativeEV]
    EV -->|Sí| Ok([Backrun + tip OK])
    Fail --> End([Fin])
    Rev --> End
    Ok --> End
```

---

## Flujograma — Revert-on-unprofitable (sin bribe)

```mermaid
flowchart TD
    A[Precio se mueve / pools planos] --> B[Swaps → EV < minProfit]
    B --> C[takeProfit falla]
    C --> D[Revert NegativeEV]
    D --> E[EVM deshace tip a coinbase]
    E --> F[Assert: builder.balance sin tip]
```

---

## Flujograma — Ataques / misuse típicos

```mermaid
flowchart TD
    A[Caller no es searcher] --> B[UnauthorizedSearcher]
    C[minProfit demasiado alto] --> D[NegativeEV]
    E[Router / path malformado] --> F[ZeroAddress / InvalidRoute]
    G[Coinbase RejectETH] --> H[TipTransferFailed]
    I[amountIn = 0] --> J[ZeroAmount]
    K[amountOutMin absurdo] --> L[MockAMM.SlippageExceeded]
```

---

## Secuencia — camino feliz arbitraje + tip

```mermaid
sequenceDiagram
    actor S as Searcher EOA
    participant Rel as Builder/Relay
    participant Sol as AtomicArbitrageSolver
    participant Lib as MevSwapLib
    participant CB as block.coinbase

    S->>S: Detectar spread + SimulateBundle
    S->>Rel: eth_sendBundle([executeTx], targetBlock)
    Rel->>Sol: execute(route, amountIn, minProfit, tipWei)
    Sol->>Sol: require authorizedSearcher
    Sol->>Sol: snapshot(tokenIn)
    Sol->>Lib: swapRoundTrip(...)
    Lib-->>Sol: mid OK
    Sol->>CB: payAssembly(tipWei)
    Sol->>Sol: takeProfit(...)
    Sol-->>S: profit (evento)
```

---

## Secuencia — sandwich lab (midHook)

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
    alt rentable
        Ex-->>S: profit
    else no rentable
        Ex-->>S: revert NegativeEV
    end
```

---

## Gobernanza de implementación

```mermaid
flowchart LR
    Doc[doc/ ✅] --> F0[Fase 0 Setup ✅]
    F0 --> F1[Fase 1 Libs ✅]
    F1 --> F2[Fase 2 AtomicArb ✅]
    F2 --> F3[Fase 3 Backrun ✅]
    F3 --> F4[Fase 4 Sandwich lab ✅]
    F4 --> F5[Fase 5 Fuzz / unprofitable ✅]
    F5 --> F6[Fase 6 Fork / SimulateBundle ✅]
    F6 --> F7[Fase 7 Gas / Deploy / SWC ✅]
    F7 --> Done([Módulo v1 cerrado ✅])
```

**Gate:** no avanzar de fase sin *“autorizo Fase N”*. Detalle en [`planificacion.md`](./planificacion.md).  
**Estado:** Fases **0–7** ✅ (módulo v1 cerrado).
