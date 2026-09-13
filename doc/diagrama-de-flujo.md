# Diagrama de flujo — Solvers MEV, tips y profit checks

Flujos de decisión internos de los ejecutores atómicos (módulo 15, **diseño v1**).

## 1. AtomicArbitrageSolver.execute

```mermaid
flowchart TD
    A[Searcher: execute route, amountIn, minProfit, tipWei] --> B{¿msg.sender == authorizedSearcher?}
    B -->|No| Z1[Revert UnauthorizedSearcher]
    B -->|Sí| C{¿route válida y amountIn > 0?}
    C -->|No| Z2[Revert InvalidRoute / ZeroAmount]
    C -->|Sí| D[initial = ProfitLib.snapshot tokenOut o base]
    D --> E[Swap A: tokenIn → mid en routerA]
    E --> F{¿amountOutA >= amountOutMinA?}
    F -->|No| Z3[Revert SlippageExceeded]
    F -->|Sí| G[Swap B: mid → tokenOut en routerB]
    G --> H{¿amountOutB >= amountOutMinB?}
    H -->|No| Z4[Revert InsufficientOutput]
    H -->|Sí| I{¿tipWei > 0?}
    I -->|Sí| J[CoinbaseTip.pay tipWei]
    I -->|No| K[Omitir tip]
    J --> L{¿success tip?}
    L -->|No| Z5[Revert TipTransferFailed]
    L -->|Sí| M[final = snapshot]
    K --> M
    M --> N{¿final >= initial + minProfit?}
    N -->|No| Z6[Revert NegativeEV]
    N -->|Sí| O[Emit Executed / return profit]
    Z1 --> End([Fin — revert])
    Z2 --> End
    Z3 --> End
    Z4 --> End
    Z5 --> End
    Z6 --> End
    O --> Ok([Fin — OK])
```

> Atomicidad: cualquier revert deshace swaps **y** tip (sin bribe residual).

## 2. Verificación de profit (ProfitLib)

```mermaid
flowchart TD
    A[initialBalance, finalBalance, minProfit] --> B{¿finalBalance >= initialBalance + minProfit?}
    B -->|No| C[Revert NegativeEV]
    B -->|Sí| D[return finalBalance - initialBalance]
```

## 3. CoinbaseTip — pago al builder

```mermaid
flowchart TD
    A[pay tipWei] --> B{¿tipWei == 0?}
    B -->|Sí| C[return — no-op]
    B -->|No| D[ETH call / assembly a block.coinbase]
    D --> E{¿success?}
    E -->|No| F[Revert TipTransferFailed]
    E -->|Sí| G[return]
```

## 4. BackrunExecutor.backrun

```mermaid
flowchart TD
    A[Bundle: victimTx luego backrunTx] --> B[Victim ejecuta — mueve precio del pool]
    B --> C[backrun: auth searcher]
    C --> D{¿autorizado?}
    D -->|No| R1[UnauthorizedSearcher]
    D -->|Sí| E[Snapshot → swap captura spread]
    E --> F[Tip coinbase opcional]
    F --> G{¿profit >= minProfit?}
    G -->|No| R2[NegativeEV — bundle tx revierte]
    G -->|Sí| H[Backrun OK — builder recibe tip]
    R1 --> End([Fin])
    R2 --> End
    H --> Ok([Fin — OK])
```

## 5. SandwichExecutor.sandwich (lab)

```mermaid
flowchart TD
    A[sandwich frontParams, backParams, minProfit, tipWei] --> B{¿authorizedSearcher?}
    B -->|No| Z[UnauthorizedSearcher]
    B -->|Sí| C[Front-run: comprar asset]
    C --> D[Victim tx — en bundle real; en unit se simula mid-price]
    D --> E[Back-run: vender asset]
    E --> F[Tip coinbase]
    F --> G{¿EV >= minProfit?}
    G -->|No| H[NegativeEV — todo revierte]
    G -->|Sí| I[Emit SandwichExecuted]
    Z --> End([Fin])
    H --> End
    I --> Ok([Fin — lab OK])
```

## 6. Guard de acceso transversal

```mermaid
flowchart TD
    A[Cualquier execute / backrun / sandwich] --> B{msg.sender == authorizedSearcher?}
    B -->|No| C[UnauthorizedSearcher]
    B -->|Sí| D[Continuar lógica de negocio]
```

## 7. Simulación de bundle (off-chain / Foundry script)

```mermaid
flowchart TD
    A[Searcher detecta oportunidad] --> B[Armar txs: victim?, executor, tip]
    B --> C[eth_callBundle / forge fork simulate]
    C --> D{¿simulación rentable?}
    D -->|No| E[Descartar — no enviar]
    D -->|Sí| F[eth_sendBundle / mev_sendBundle target block]
    F --> G{¿incluido en bloque?}
    G -->|No| H[Re-simular próximo bloque]
    G -->|Sí| I[On-chain: profit check pasa]
```

## 8. Ciclo de estados — tx atómica del solver

```mermaid
stateDiagram-v2
    [*] --> Auth: llamada externa
    Auth --> Rejected: UnauthorizedSearcher
    Auth --> Trading: auth OK
    Trading --> TipPending: swaps OK
    Trading --> Reverted: slippage / invalid route
    TipPending --> ProfitCheck: tip OK o tip=0
    TipPending --> Reverted: TipTransferFailed
    ProfitCheck --> Success: final >= initial + minProfit
    ProfitCheck --> Reverted: NegativeEV
    Rejected --> [*]
    Reverted --> [*]: estado previo restaurado
    Success --> [*]
```

## 9. Regla transversal — orden de efectos

```mermaid
flowchart LR
    A[1. Auth] --> B[2. Snapshot]
    B --> C[3. Swaps CEI]
    C --> D[4. Tip coinbase]
    D --> E[5. Profit verify]
    E --> F[6. Emit / return]
```
