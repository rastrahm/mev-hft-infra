# Diagrama de clases — MEV & HFT Trading Infrastructure

Vista estructural de contratos, librerías e interfaces (módulo 15, **diseño v1**).

## Diagrama (Mermaid)

```mermaid
classDiagram
    direction TB

    class IAtomicArbitrageSolver {
        <<interface>>
        +execute(route, amountIn, minProfit, tipWei) uint256 profit
        +authorizedSearcher() address
        +setSearcher(searcher)
    }

    class IBackrunExecutor {
        <<interface>>
        +backrun(route, amountIn, minProfit, tipWei) uint256 profit
    }

    class ISandwichExecutor {
        <<interface>>
        +sandwich(front, back, minProfit, tipWei) uint256 profit
    }

    class IDexRouter {
        <<interface>>
        +swapExactTokensForTokens(amountIn, amountOutMin, path, to) amounts
    }

    class MevErrors {
        <<errors>>
        +UnauthorizedSearcher()
        +NegativeEV()
        +ZeroAddress()
        +InvalidRoute()
        +TipTransferFailed()
        +InsufficientOutput()
        +SlippageExceeded()
        +BundleExpired()
        +ZeroAmount()
    }

    class ProfitLib {
        <<library>>
        +snapshot(token) uint256
        +requireProfit(initial, final_, minProfit)
        +netProfit(initial, final_) uint256
    }

    class CoinbaseTip {
        <<library>>
        +pay(tipWei)
        +payAssembly(tipWei)
    }

    class CalldataCodec {
        <<library>>
        +decodeRoute(data) Route
        +decodeAmounts(data) uint256, uint256
    }

    class Route {
        <<struct>>
        +tokenIn address
        +tokenOut address
        +routerA address
        +routerB address
        +amountOutMinA uint256
        +amountOutMinB uint256
    }

    class AtomicArbitrageSolver {
        <<contract>>
        +owner address
        +authorizedSearcher address
        +execute(route, amountIn, minProfit, tipWei) profit
        +setSearcher(searcher)
        +withdraw(token, to, amount)
    }

    class BackrunExecutor {
        <<contract>>
        +authorizedSearcher address
        +backrun(route, amountIn, minProfit, tipWei) profit
    }

    class SandwichExecutor {
        <<contract>>
        +authorizedSearcher address
        +sandwich(frontParams, backParams, minProfit, tipWei) profit
    }

    class MockAMM {
        <<contract mock>>
        +reserve0 uint256
        +reserve1 uint256
        +setReserves(r0, r1)
        +swap(amountIn, tokenIn) amountOut
    }

    class MockRouter {
        <<contract mock>>
        +swapExactTokensForTokens(...)
    }

    class MockERC20 {
        <<contract mock>>
        +mint(to, amount)
        +burn(from, amount)
    }

    IAtomicArbitrageSolver <|.. AtomicArbitrageSolver : implements
    IBackrunExecutor <|.. BackrunExecutor : implements
    ISandwichExecutor <|.. SandwichExecutor : implements
    IDexRouter <|.. MockRouter : implements

    AtomicArbitrageSolver ..> ProfitLib : uses
    AtomicArbitrageSolver ..> CoinbaseTip : uses
    AtomicArbitrageSolver ..> CalldataCodec : uses
    AtomicArbitrageSolver ..> MevErrors : reverts
    AtomicArbitrageSolver --> IDexRouter : swaps

    BackrunExecutor ..> ProfitLib : uses
    BackrunExecutor ..> CoinbaseTip : uses
    BackrunExecutor ..> MevErrors : reverts
    BackrunExecutor --> IDexRouter : swaps

    SandwichExecutor ..> ProfitLib : uses
    SandwichExecutor ..> CoinbaseTip : uses
    SandwichExecutor ..> MevErrors : reverts
    SandwichExecutor --> IDexRouter : front/back

    CalldataCodec ..> Route : decodes
    MockRouter --> MockAMM : routes
    AtomicArbitrageSolver --> MockERC20 : balances
```

## Relaciones clave

| Relación | Motivo |
|----------|--------|
| Solver/Executors → `ProfitLib` | Snapshot y enforce de `minProfit` / `NegativeEV` |
| Solver/Executors → `CoinbaseTip` | Bribe al builder vía `block.coinbase` |
| Solver/Executors → `IDexRouter` | Swaps atómicos contra pools/routers |
| `CalldataCodec` → `Route` | Params compactos decodeados en Yul |
| Mocks AMM/Router | Simular imbalance sin mainnet |

## Decisiones de diseño (v1)

- Tres ejecutores separados (arb / backrun / sandwich) para aislar superficie de ataque y tests.
- Un solo `authorizedSearcher` por contrato (Ownable2Step puede rotarlo).
- Tip **dentro** de la misma tx atómica: si falla el profit check, revierte también el tip.
- Sandwich limitado a **lab/fork**; no se documenta runbook de explotación en mainnet.
- Bundles Flashbots viven off-chain (scripts Foundry); on-chain solo la ejecución tipada.
- Frontend Next.js: post-v1.
