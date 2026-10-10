# Class Diagram — MEV & HFT Trading Infrastructure

Structural view of contracts, libraries, and interfaces (module 15, **v1 implemented**).

## Diagram (Mermaid)

```mermaid
classDiagram
    direction TB

    class IAtomicArbitrageSolver {
        <<interface>>
        +execute(route, amountIn, minProfit, tipWei) uint256 profit
        +authorizedSearcher() address
        +setSearcher(searcher)
        +withdraw(token, to, amount)
    }

    class IBackrunExecutor {
        <<interface>>
        +backrun(route, amountIn, minProfit, tipWei) uint256 profit
        +authorizedSearcher() address
        +setSearcher(searcher)
        +withdraw(token, to, amount)
    }

    class ISandwichExecutor {
        <<interface>>
        +sandwich(front, back, midHook, midData, minProfit, tipWei) uint256 profit
        +authorizedSearcher() address
        +setSearcher(searcher)
        +withdraw(token, to, amount)
    }

    class ISandwichMidHook {
        <<interface>>
        +afterFront(data)
    }

    class IDexRouter {
        <<interface>>
        +swapExactTokensForTokens(amountIn, amountOutMin, path, to) uint256
    }

    class ISimpleAMM {
        <<interface>>
        +swap(tokenIn, amountIn, minOut, to) uint256
        +getAmountOut(amountIn, tokenIn) uint256
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
        +takeProfit(initial, final_, minProfit) uint256
    }

    class CoinbaseTip {
        <<library>>
        +pay(tipWei)
        +payAssembly(tipWei)
    }

    class CalldataCodec {
        <<library>>
        +encodeRoute(r) bytes
        +decodeRoute(data) Route
        +encodeAmounts(amountIn, minProfit) bytes
        +decodeAmounts(data) uint256, uint256
    }

    class MevSwapLib {
        <<library>>
        +swapRoundTrip(tokenIn, tokenOut, routerA, routerB, amountIn, minA, minB) uint256 mid
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

    class SandwichLeg {
        <<struct>>
        +router address
        +tokenIn address
        +tokenOut address
        +amountIn uint256
        +amountOutMin uint256
    }

    class AtomicArbitrageSolver {
        <<contract>>
        +authorizedSearcher address
        +execute(...) profit
        +setSearcher(searcher)
        +withdraw(token, to, amount)
    }

    class BackrunExecutor {
        <<contract>>
        +authorizedSearcher address
        +backrun(...) profit
        +setSearcher(searcher)
        +withdraw(token, to, amount)
    }

    class SandwichExecutor {
        <<contract>>
        +authorizedSearcher address
        +sandwich(...) profit
        +setSearcher(searcher)
        +withdraw(token, to, amount)
    }

    class MockAMM {
        <<contract mock>>
        +reserve0 uint256
        +reserve1 uint256
        +setReserves(r0, r1)
        +swap(...) amountOut
    }

    class MockRouter {
        <<contract mock>>
        +amm ISimpleAMM
        +swapExactTokensForTokens(...)
    }

    class MockERC20 {
        <<contract mock>>
        +mint(to, amount)
    }

    class RejectETH {
        <<contract mock>>
    }

    IAtomicArbitrageSolver <|.. AtomicArbitrageSolver : implements
    IBackrunExecutor <|.. BackrunExecutor : implements
    ISandwichExecutor <|.. SandwichExecutor : implements
    IDexRouter <|.. MockRouter : implements
    ISimpleAMM <|.. MockAMM : implements

    AtomicArbitrageSolver ..> ProfitLib : takeProfit
    AtomicArbitrageSolver ..> CoinbaseTip : payAssembly
    AtomicArbitrageSolver ..> MevSwapLib : swapRoundTrip
    AtomicArbitrageSolver ..> MevErrors : reverts
    AtomicArbitrageSolver --> Route : calldata

    BackrunExecutor ..> ProfitLib : takeProfit
    BackrunExecutor ..> CoinbaseTip : payAssembly
    BackrunExecutor ..> MevSwapLib : swapRoundTrip
    BackrunExecutor ..> MevErrors : reverts

    SandwichExecutor ..> ProfitLib : takeProfit
    SandwichExecutor ..> CoinbaseTip : payAssembly
    SandwichExecutor ..> MevErrors : reverts
    SandwichExecutor --> SandwichLeg : front/back
    SandwichExecutor ..> ISandwichMidHook : afterFront lab

    MevSwapLib ..> IDexRouter : swaps
    CalldataCodec ..> Route : encode/decode
    MockRouter --> MockAMM : routes
```

## Key relationships

| Relationship | Reason |
|--------------|--------|
| Solver/Backrun → `MevSwapLib` | Gas-optimized 2-router round-trip |
| Solver/Executors → `ProfitLib.takeProfit` | Snapshot + `minProfit` in a single pass |
| Solver/Executors → `CoinbaseTip.payAssembly` | Yul tip to `block.coinbase` |
| Sandwich → `ISandwichMidHook` | Simulated victim in the lab (same tx) |
| `CalldataCodec` → `Route` | Packed 144 B for off-chain builders |
| AMM/Router/`RejectETH` mocks | Pool imbalance + failed tip in tests |

## Design decisions (v1)

- Three separate executors (arb / backrun / sandwich) to isolate attack surface and tests.
- `Ownable2Step` + `authorizedSearcher` per contract.
- Tip **inside** the same tx: if `takeProfit` fails, the tip is reverted too.
- Sandwich is **lab/fork only** via midHook; no mainnet runbook.
- No `forceApprove(0)` after swaps (gas tradeoff; trusted routers) — see [`GAS-EN.md`](./GAS-EN.md).
- Flashbots bundles are off-chain (`SimulateBundle.s.sol`); on-chain only executes.
- Next.js frontend: post-v1.
