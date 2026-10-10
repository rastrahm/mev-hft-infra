# Flow Diagram — MEV Solvers, Tips, and Profit Checks

Internal decision flows of the atomic executors (module 15, **v1 implemented**).

## 1. AtomicArbitrageSolver.execute / BackrunExecutor.backrun

```mermaid
flowchart TD
    A[Searcher: execute/backrun route, amountIn, minProfit, tipWei] --> B{msg.sender == authorizedSearcher?}
    B -->|No| Z1[Revert UnauthorizedSearcher]
    B -->|Yes| C{Valid route and amountIn > 0?}
    C -->|No| Z2[Revert ZeroAddress / InvalidRoute / ZeroAmount]
    C -->|Yes| D[initial = ProfitLib.snapshot tokenIn]
    D --> E[MevSwapLib.swapRoundTrip: A then B]
    E --> F{mid == 0?}
    F -->|Yes| Z3[Revert InsufficientOutput]
    F -->|No| G[CoinbaseTip.payAssembly tipWei]
    G --> H{Tip OK or tipWei == 0?}
    H -->|No| Z4[Revert TipTransferFailed]
    H -->|Yes| I[profit = ProfitLib.takeProfit initial, final, minProfit]
    I --> J{EV OK?}
    J -->|No| Z5[Revert NegativeEV]
    J -->|Yes| K[Emit Executed / return profit]
    Z1 --> End([End — atomic revert])
    Z2 --> End
    Z3 --> End
    Z4 --> End
    Z5 --> End
    K --> Ok([End — OK])
```

> Atomicity: any revert undoes the swaps **and** the tip (no residual bribe).  
> Per-hop slippage: enforced by the router/AMM (`MockAMM.SlippageExceeded`).

## 2. ProfitLib.takeProfit

```mermaid
flowchart TD
    A[initial, final_, minProfit] --> B{final_ >= initial?}
    B -->|No| C[Revert NegativeEV]
    B -->|Yes| D[profit = final_ - initial unchecked]
    D --> E{profit >= minProfit?}
    E -->|No| C
    E -->|Yes| F[return profit]
```

## 3. CoinbaseTip — payment to the builder

```mermaid
flowchart TD
    A[pay / payAssembly tipWei] --> B{tipWei == 0?}
    B -->|Yes| C[return — no-op]
    B -->|No| D[ETH to block.coinbase]
    D --> E{success?}
    E -->|No| F[Revert TipTransferFailed]
    E -->|Yes| G[return]
```

> Production: `payAssembly` (Yul). Tests compare it against `pay` (`.call`) — see [`GAS-EN.md`](./GAS-EN.md).

## 4. Post-victim backrun (bundle / test)

```mermaid
flowchart TD
    A[Bundle: victimTx then backrunTx] --> B[Victim moves the pool price]
    B --> C[backrun: searcher auth]
    C --> D{Authorized?}
    D -->|No| R1[UnauthorizedSearcher]
    D -->|Yes| E[MevSwapLib + tip + takeProfit]
    E --> F{Profitable?}
    F -->|No| R2[NegativeEV — tip reverted]
    F -->|Yes| H[Backrun OK]
    R1 --> End([End])
    R2 --> End
    H --> Ok([End — OK])
```

## 5. SandwichExecutor.sandwich (lab)

```mermaid
flowchart TD
    A[sandwich front, back, midHook, midData, minProfit, tipWei] --> B{authorizedSearcher?}
    B -->|No| Z[UnauthorizedSearcher]
    B -->|Yes| C[Front-run hop]
    C --> D{midHook != 0?}
    D -->|Yes| E[ISandwichMidHook.afterFront — lab victim]
    D -->|No| F[No victim — usually NegativeEV]
    E --> G[Back-run hop]
    F --> G
    G --> H[payAssembly tip]
    H --> I[takeProfit]
    I --> J{EV OK?}
    J -->|No| K[NegativeEV — everything reverts]
    J -->|Yes| L[Emit SandwichExecuted]
    Z --> End([End])
    K --> End
    L --> Ok([End — lab OK])
```

## 6. Cross-cutting access guard

```mermaid
flowchart TD
    A[execute / backrun / sandwich] --> B{msg.sender == authorizedSearcher?}
    B -->|No| C[UnauthorizedSearcher]
    B -->|Yes| D[Continue business logic]
```

## 7. Bundle simulation (off-chain)

```mermaid
flowchart TD
    A[Searcher detects opportunity] --> B[Build route / amounts / tip]
    B --> C[forge script SimulateBundle / eth_callBundle]
    C --> D{Profitable simulation?}
    D -->|No| E[Discard]
    D -->|Yes| F[eth_sendBundle / mev_sendBundle target block]
    F --> G{Included?}
    G -->|No| H[Re-simulate next block]
    G -->|Yes| I[On-chain: takeProfit passes]
```

## 8. State cycle — atomic tx

```mermaid
stateDiagram-v2
    [*] --> Auth: external call
    Auth --> Rejected: UnauthorizedSearcher
    Auth --> Trading: auth OK
    Trading --> TipPending: MevSwapLib OK
    Trading --> Reverted: slippage / insufficient / invalid
    TipPending --> ProfitCheck: tip OK or tip=0
    TipPending --> Reverted: TipTransferFailed
    ProfitCheck --> Success: takeProfit OK
    ProfitCheck --> Reverted: NegativeEV
    Rejected --> [*]
    Reverted --> [*]: previous state restored
    Success --> [*]
```

## 9. Order of effects (hot path)

```mermaid
flowchart LR
    A[1. Auth] --> B[2. Snapshot tokenIn]
    B --> C[3. MevSwapLib swaps]
    C --> D[4. payAssembly tip]
    D --> E[5. takeProfit]
    E --> F[6. Emit / return]
```
