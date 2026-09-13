# Diagrama de flujo — Solvers MEV, tips y profit checks

Flujos de decisión internos de los ejecutores atómicos (módulo 15, **v1 implementado**).

## 1. AtomicArbitrageSolver.execute / BackrunExecutor.backrun

```mermaid
flowchart TD
    A[Searcher: execute/backrun route, amountIn, minProfit, tipWei] --> B{¿msg.sender == authorizedSearcher?}
    B -->|No| Z1[Revert UnauthorizedSearcher]
    B -->|Sí| C{¿route válida y amountIn > 0?}
    C -->|No| Z2[Revert ZeroAddress / InvalidRoute / ZeroAmount]
    C -->|Sí| D[initial = ProfitLib.snapshot tokenIn]
    D --> E[MevSwapLib.swapRoundTrip: A luego B]
    E --> F{¿mid == 0?}
    F -->|Sí| Z3[Revert InsufficientOutput]
    F -->|No| G[CoinbaseTip.payAssembly tipWei]
    G --> H{¿tip OK o tipWei == 0?}
    H -->|No| Z4[Revert TipTransferFailed]
    H -->|Sí| I[profit = ProfitLib.takeProfit initial, final, minProfit]
    I --> J{¿EV OK?}
    J -->|No| Z5[Revert NegativeEV]
    J -->|Sí| K[Emit Executed / return profit]
    Z1 --> End([Fin — revert atómico])
    Z2 --> End
    Z3 --> End
    Z4 --> End
    Z5 --> End
    K --> Ok([Fin — OK])
```

> Atomicidad: cualquier revert deshace swaps **y** tip (sin bribe residual).  
> Slippage de hop: lo aplica el router/AMM (`MockAMM.SlippageExceeded`).

## 2. ProfitLib.takeProfit

```mermaid
flowchart TD
    A[initial, final_, minProfit] --> B{¿final_ >= initial?}
    B -->|No| C[Revert NegativeEV]
    B -->|Sí| D[profit = final_ - initial unchecked]
    D --> E{¿profit >= minProfit?}
    E -->|No| C
    E -->|Sí| F[return profit]
```

## 3. CoinbaseTip — pago al builder

```mermaid
flowchart TD
    A[pay / payAssembly tipWei] --> B{¿tipWei == 0?}
    B -->|Sí| C[return — no-op]
    B -->|No| D[ETH a block.coinbase]
    D --> E{¿success?}
    E -->|No| F[Revert TipTransferFailed]
    E -->|Sí| G[return]
```

> Producción: `payAssembly` (Yul). Tests comparan vs `pay` (`.call`) — ver [`GAS.md`](./GAS.md).

## 4. Backrun post-victim (bundle / test)

```mermaid
flowchart TD
    A[Bundle: victimTx luego backrunTx] --> B[Victim mueve precio del pool]
    B --> C[backrun: auth searcher]
    C --> D{¿autorizado?}
    D -->|No| R1[UnauthorizedSearcher]
    D -->|Sí| E[MevSwapLib + tip + takeProfit]
    E --> F{¿rentable?}
    F -->|No| R2[NegativeEV — tip revertido]
    F -->|Sí| H[Backrun OK]
    R1 --> End([Fin])
    R2 --> End
    H --> Ok([Fin — OK])
```

## 5. SandwichExecutor.sandwich (lab)

```mermaid
flowchart TD
    A[sandwich front, back, midHook, midData, minProfit, tipWei] --> B{¿authorizedSearcher?}
    B -->|No| Z[UnauthorizedSearcher]
    B -->|Sí| C[Front-run hop]
    C --> D{¿midHook != 0?}
    D -->|Sí| E[ISandwichMidHook.afterFront — victim lab]
    D -->|No| F[Sin victim — suele NegativeEV]
    E --> G[Back-run hop]
    F --> G
    G --> H[payAssembly tip]
    H --> I[takeProfit]
    I --> J{¿EV OK?}
    J -->|No| K[NegativeEV — todo revierte]
    J -->|Sí| L[Emit SandwichExecuted]
    Z --> End([Fin])
    K --> End
    L --> Ok([Fin — lab OK])
```

## 6. Guard de acceso transversal

```mermaid
flowchart TD
    A[execute / backrun / sandwich] --> B{msg.sender == authorizedSearcher?}
    B -->|No| C[UnauthorizedSearcher]
    B -->|Sí| D[Continuar lógica de negocio]
```

## 7. Simulación de bundle (off-chain)

```mermaid
flowchart TD
    A[Searcher detecta oportunidad] --> B[Armar route / amounts / tip]
    B --> C[forge script SimulateBundle / eth_callBundle]
    C --> D{¿simulación rentable?}
    D -->|No| E[Descartar]
    D -->|Sí| F[eth_sendBundle / mev_sendBundle target block]
    F --> G{¿incluido?}
    G -->|No| H[Re-simular próximo bloque]
    G -->|Sí| I[On-chain: takeProfit pasa]
```

## 8. Ciclo de estados — tx atómica

```mermaid
stateDiagram-v2
    [*] --> Auth: llamada externa
    Auth --> Rejected: UnauthorizedSearcher
    Auth --> Trading: auth OK
    Trading --> TipPending: MevSwapLib OK
    Trading --> Reverted: slippage / insufficient / invalid
    TipPending --> ProfitCheck: tip OK o tip=0
    TipPending --> Reverted: TipTransferFailed
    ProfitCheck --> Success: takeProfit OK
    ProfitCheck --> Reverted: NegativeEV
    Rejected --> [*]
    Reverted --> [*]: estado previo restaurado
    Success --> [*]
```

## 9. Orden de efectos (hot path)

```mermaid
flowchart LR
    A[1. Auth] --> B[2. Snapshot tokenIn]
    B --> C[3. Swaps MevSwapLib]
    C --> D[4. Tip payAssembly]
    D --> E[5. takeProfit]
    E --> F[6. Emit / return]
```
