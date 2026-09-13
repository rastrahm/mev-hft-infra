# Flujograma — Ciclo completo MEV & HFT Infrastructure

Flujo extremo a extremo entre actores, contratos y relayer/builder (módulo 15, **diseño v1**).

## Actores

| Actor | Rol |
|-------|-----|
| Searcher EOA | Detecta oportunidades; firma y envía txs del bundle |
| AtomicArbitrageSolver | Ejecuta arb 2-pool atómico + tip + profit check |
| BackrunExecutor | Captura spread post-victim |
| SandwichExecutor | Front+back en lab/fork |
| DEX / AMM | Pools donde ocurre el desequilibrio |
| Builder / Flashbots Relay | Recibe bundle privado; ordena txs; cobra tip vía coinbase |
| CI / Foundry | Unit, fuzz, fork, gas, simulate bundle |

---

## Flujograma principal — Deploy + autorización

```mermaid
flowchart TD
    Start([Inicio]) --> Dep[Deploy solvers / executors]
    Dep --> Own[Owner: Ownable2Step]
    Own --> Auth[setSearcher searcherEOA]
    Auth --> Fund[Fondear solver con tokens / WETH si aplica]
    Fund --> Ready([Listo para bundles de lab/fork])
```

---

## Flujograma principal — Searcher → bundle → on-chain

```mermaid
flowchart TD
    Start([Mempool / evento de precio]) --> Detect[Searcher detecta spread o victim]
    Detect --> Build[Construir payload: route, amountIn, minProfit, tipWei]
    Build --> Sim[Simular: forge fork / eth_callBundle]
    Sim --> OkSim{¿EV >= minProfit tras tip?}
    OkSim -->|No| Drop[Descartar oportunidad]
    OkSim -->|Sí| Send[Enviar bundle al relay — block target]
    Send --> Incl{¿Builder incluye bundle?}
    Incl -->|No| Retry[Re-evaluar siguiente bloque]
    Incl -->|Sí| Exec[Contrato: auth → swaps → tip → profit]
    Exec --> Profit{¿NegativeEV?}
    Profit -->|Sí| Rev[Tx revierte — sin tip efectivo]
    Profit -->|No| Done([Profit al searcher / contrato])
    Drop --> End([Fin])
    Retry --> Detect
    Rev --> End
    Done --> End
```

---

## Flujograma principal — Arbitraje atómico

```mermaid
flowchart TD
    Start([Searcher llama execute]) --> Auth{¿authorized?}
    Auth -->|No| ErrU[UnauthorizedSearcher]
    Auth -->|Sí| Snap[Snapshot balance]
    Snap --> S1[Swap en pool A]
    S1 --> S2[Swap en pool B]
    S2 --> Tip[Tip a block.coinbase]
    Tip --> Check{final >= initial + minProfit?}
    Check -->|No| ErrN[NegativeEV]
    Check -->|Sí| Ok([Emit + return profit])
    ErrU --> Fail([Fin — rechazo])
    ErrN --> Fail
    Ok --> Success([Fin — OK])
```

---

## Flujograma principal — Backrun tras victim

```mermaid
flowchart TD
    Start([Bundle ordenado]) --> V[Tx victim: swap grande en AMM]
    V --> B[Tx backrun: BackrunExecutor.backrun]
    B --> Auth{¿searcher auth?}
    Auth -->|No| Fail[Revert auth]
    Auth -->|Sí| Trade[Swap en sentido contrario al imbalance]
    Trade --> Tip[Tip builder]
    Tip --> EV{¿rentable?}
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
    A[Precio se mueve / slippage alto] --> B[Swaps producen EV < minProfit]
    B --> C[ProfitLib.requireProfit falla]
    C --> D[Revert NegativeEV]
    D --> E[EVM deshace tip a coinbase]
    E --> F[Test: balance coinbase sin incremento por tip]
```

---

## Flujograma — Ataques / misuse típicos

```mermaid
flowchart TD
    A[Caller no es searcher] --> B[UnauthorizedSearcher]
    C[minProfit demasiado alto vs spread] --> D[NegativeEV]
    E[Router / path malformado] --> F[InvalidRoute]
    G[Tip con contrato coinbase que reverts] --> H[TipTransferFailed]
    I[amountIn = 0] --> J[ZeroAmount]
    K[Slippage min no alcanzado] --> L[SlippageExceeded / InsufficientOutput]
```

---

## Secuencia — camino feliz arbitraje + tip

```mermaid
sequenceDiagram
    actor S as Searcher EOA
    participant Rel as Builder/Relay
    participant Sol as AtomicArbitrageSolver
    participant RA as Router/Pool A
    participant RB as Router/Pool B
    participant CB as block.coinbase

    S->>S: Detectar spread + simular
    S->>Rel: eth_sendBundle([executeTx], targetBlock)
    Rel->>Sol: execute(route, amountIn, minProfit, tipWei)
    Sol->>Sol: require msg.sender == authorizedSearcher
    Sol->>Sol: snapshot initial
    Sol->>RA: swapExactIn
    RA-->>Sol: midToken
    Sol->>RB: swapExactIn
    RB-->>Sol: tokenOut
    Sol->>CB: tipWei (call/assembly)
    Sol->>Sol: require final >= initial + minProfit
    Sol-->>S: profit (evento / balance)
```

---

## Secuencia — backrun en bundle

```mermaid
sequenceDiagram
    actor Vic as Victim
    actor S as Searcher
    participant Rel as Builder
    participant Pool as AMM
    participant Ex as BackrunExecutor
    participant CB as coinbase

    S->>Rel: bundle[victimTx, backrunTx]
    Rel->>Vic: victimTx (orden 1)
    Vic->>Pool: swap grande
    Pool-->>Vic: amountOut
    Rel->>Ex: backrunTx (orden 2)
    Ex->>Pool: swap captura spread
    Ex->>CB: tip
    Ex->>Ex: profit check
    Ex-->>S: EV positivo o revert
```

---

## Secuencia — sandwich lab (solo tests)

```mermaid
sequenceDiagram
    actor S as Searcher
    participant Ex as SandwichExecutor
    participant Pool as MockAMM

    S->>Ex: sandwich(front, back, minProfit, tip)
    Ex->>Pool: front-run buy
    Note over Ex,Pool: Victim simulada (unit) o tx media en bundle
    Ex->>Pool: back-run sell
    Ex->>Ex: tip + NegativeEV check
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
    Doc[doc/ ✅] --> F0[Fase 0 Setup]
    F0 --> F1[Fase 1 Libs]
    F1 --> F2[Fase 2 AtomicArb]
    F2 --> F3[Fase 3 Backrun]
    F3 --> F4[Fase 4 Sandwich lab]
    F4 --> F5[Fase 5 Fuzz / unprofitable]
    F5 --> F6[Fase 6 Fork / SimulateBundle]
    F6 --> F7[Fase 7 Gas / Deploy / SWC]
    F7 --> Done([Módulo v1])
```

**Gate:** no avanzar de fase sin *“autorizo Fase N”*. Detalle en [`planificacion.md`](./planificacion.md).  
**Estado:** Fases **0–3** ✅. Fases **4–7** ⏳ pendientes de autorización.
