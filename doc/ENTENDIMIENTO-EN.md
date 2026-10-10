# Understanding Guide — Module 15 MEV & HFT

A document to understand **what was decided**, **how the logic flows**, and **where gas can still be saved**.  
Complements [`planificacion-EN.md`](./planificacion-EN.md), [`GAS-EN.md`](./GAS-EN.md), and [`diagrama-de-flujo-EN.md`](./diagrama-de-flujo-EN.md).

---

## 1. In one sentence

An authorized searcher calls a contract that already holds tokens (and ETH for the tip), performs a round-trip between two routers, pays a bribe to the builder via `block.coinbase`, and **only lets the tx succeed if the `tokenIn` balance grew by at least `minProfit`**. Otherwise everything reverts — including the tip.

---

## 2. Technical decisions

### 2.1 Three contracts instead of one

| Contract | Role | Why separate |
|----------|------|--------------|
| `AtomicArbitrageSolver` | Classic 2-router arb | Clear attack surface and tests |
| `BackrunExecutor` | Same mechanics, post-victim semantics | Same swap library; different test scenarios |
| `SandwichExecutor` | Front → lab victim → back | **Lab/fork only**; midHook simulates the victim in the same tx |

**Decision:** do not mix a production sandwich with arb/backrun. The sandwich is educational and scoped.

### 2.2 Capital in the contract (no flash loan in v1)

The solver/executor is **already funded** with `tokenIn` (and ETH for tips).  
We do not borrow within the same tx (that would be module 08 / ERC-3156).

**Why:** module 15 focuses on the coinbase tip, searcher auth, and EV atomicity, not on the flash-loan standard.

**Tradeoff:** capital is locked in the contract; the owner can `withdraw`.

### 2.3 Auth: a single `authorizedSearcher`

Only that EOA/relayer can call `execute` / `backrun` / `sandwich`.  
The `owner` (Ownable2Step) rotates the searcher and withdraws funds.

**Why:** in real MEV the bot signs; we do not want a public `execute` that anyone can trigger with your capital.

### 2.4 Tx order: swaps → tip → profit check

```
1. Auth + validate route/amount
2. Snapshot balance(tokenIn)
3. Swaps (MevSwapLib or sandwich legs)
4. Tip to block.coinbase (payAssembly)
5. takeProfit(snapshot, finalBalance, minProfit)
6. Emit + return
```

**Key decision:** the tip is paid **before** the profit check, but within the **same** transaction. If `takeProfit` fails → `NegativeEV` → the EVM **undoes** the tip. That way no bribe is left paid on a trade that did not pay off.

### 2.5 Profit measured in `tokenIn` (ERC-20), tip in ETH

- **Profit:** balance delta of the arb's base token.  
- **Tip:** native ETH to the coinbase.

**Why:** the builder gets paid in ETH; the trade's EV is measured in the asset the searcher wants to earn. **Both** must be funded.

### 2.6 Tip in Yul (`CoinbaseTip.payAssembly`)

Production uses an assembly `call` + the `coinbase` opcode, not `transfer`/`send`.  
`success` is checked → `TipTransferFailed`.

**Why:** suite rules + ~215 gas less than `.call` in the harness (see `GAS-EN.md`).

### 2.7 Shared `MevSwapLib` (arb + backrun)

Round-trip:

1. `tokenIn → tokenOut` on `routerA`  
2. `tokenOut → tokenIn` on `routerB`

v1 optimizations:

- A single reused path `address[]`  
- No `forceApprove(0)` after the swap (saves an SSTORE; residual allowance on **trusted** routers)

### 2.8 Sandwich with `ISandwichMidHook`

Between front and back, a hook is optionally called which, in tests, executes the "victim" swap.  
In a real bundle that victim would be **another tx** in the middle; here it is simulated in a single call for the lab.

### 2.9 Custom errors + CEI + ReentrancyGuard

- Errors in `MevErrors` (no `require` with strings)  
- `nonReentrant` guard on execution and withdraw paths  
- SafeERC20 for tokens  

### 2.10 Flashbots bundles = off-chain

On-chain only executes. Off-chain: detect the opportunity, simulate (`SimulateBundle.s.sol` / `eth_callBundle`), send the bundle.  
The contract does **not** talk to the relay.

### 2.11 Fixed pragma and toolchain

- `pragma solidity 0.8.24`  
- Foundry, OZ v5, fuzz ≥ 1000, optional fork  

---

## 3. System logic

### 3.1 Searcher view (full cycle)

```
Opportunity (mempool / imbalance)
        │
        ▼
Simulate (fork / SimulateBundle / eth_callBundle)
        │
        ├── Bad EV ──► discard (do not send)
        │
        └── Good EV ──► eth_sendBundle / mev_sendBundle
                                │
                                ▼
                    Builder includes txs in the block
                                │
                                ▼
                    On-chain contract (execute / backrun / sandwich)
                                │
                                ├── OK ──► profit in contract + tip to builder
                                └── revert ──► nothing changes (not even the tip)
```

### 3.2 On-chain view — arbitrage / backrun

Same hot path (`MevSwapLib` + `takeProfit`):

1. `msg.sender == authorizedSearcher`? If not → `UnauthorizedSearcher`.  
2. `amountIn > 0` and route without zero addresses / distinct tokens?  
3. `initial = balanceOf(tokenIn)`.  
4. Swap A, then swap B (intermediate output `mid`; if `mid == 0` → `InsufficientOutput`).  
5. `payAssembly(tipWei)` (0 = no-op).  
6. `takeProfit(initial, finalBalance, minProfit)` → on failure → `NegativeEV`.  
7. Event + `return profit`.

**Backrun in tests:** first a "victim" unbalances a pool; then the backrun buys in the cheap pool and sells in the expensive one (routers swapped in the `Route`).

### 3.3 On-chain view — sandwich lab

1. Auth + validate legs.  
2. Snapshot of `front.tokenIn`.  
3. Front-run (buy).  
4. If there is a `midHook` → `afterFront` (simulated victim).  
5. Back-run (sell; `amountIn == 0` = use the whole balance of the mid token).  
6. Tip + `takeProfit`.

Without a victim (hook = 0) the round-trip usually loses to fees → `NegativeEV` (expected behavior in tests).

### 3.4 Where each piece lives

| Piece | File |
|-------|------|
| Auth + execute | `AtomicArbitrageSolver.sol` |
| Auth + backrun | `BackrunExecutor.sol` |
| Auth + sandwich | `SandwichExecutor.sol` |
| 2-hop swaps | `libraries/MevSwapLib.sol` |
| Snapshot / EV | `libraries/ProfitLib.sol` |
| ETH tip | `libraries/CoinbaseTip.sol` |
| Packed route | `libraries/CalldataCodec.sol` |
| Errors | `errors/MevErrors.sol` |

---

## 4. Can the existing gas usage be improved?

Yes. v1 already cut ~9k in the arb envelope (test) and ~215 on the isolated tip. Below are **realistic** improvements ordered by impact vs complexity.

### 4.1 High impact / reasonable for v2

| Idea | What it saves | Cost / risk |
|------|---------------|-------------|
| **Direct swap on the pair** (Uniswap V2 `swap` + transfer) instead of router + `path[]` | Less calldata, fewer external hops, no memory array | Must handle `getReserves` / amounts; tighter coupling to the AMM |
| **`forceApprove` only if allowance &lt; amount** (or Permit2 / approve max once) | Fewer approve SSTOREs per execute | Permanent high allowance to the router |
| **Immutable `authorizedSearcher`** (or rare rotation via proxy) | One less SLOAD per tx | Less operational flexibility |
| **Pack params in packed calldata** (`CalldataCodec`) in the external signature | Less expensive calldata | Less readable API; builders must encode |

### 4.2 Medium impact

| Idea | What it saves | Notes |
|------|---------------|-------|
| Tip computed off-chain and tip=0 on-chain if the builder is paid through another mechanism | Fewer on-chain ETH transfers | Depends on the builder (payment in bundle header, etc.) |
| Remove `ReentrancyGuard` if it is proven there are no callbacks into the solver | ~one status SSTORE | **Not recommended** without a strong audit; routers/hooks are external |
| Merge arb/backrun into a single contract | Less deploy bytecode | Worse separation of tests/roles |
| `unchecked` on more already-bounded arithmetic | Little on this path | Already used in `takeProfit` after validation |

### 4.3 Low impact / already done or nearly

| Idea | Status |
|------|--------|
| Yul tip vs `.call` | Done (`payAssembly`) |
| Single path array | Done |
| No `approve(0)` | Done (tradeoff documented) |
| Single-pass `takeProfit` | Done |
| Custom errors | Done |
| `via_ir` + `optimizer_runs = 10_000` | Done |

### 4.4 What you should **not** "optimize" blindly

- Measuring profit in one token and tipping in ETH: they are different currencies; do not merge them.  
- Removing the profit check to save gas: breaks the module's EV guarantee.  
- Making `execute` public without auth: saves an `if`, loses the capital.  
- Sandwich on mainnet "because the envelope is more gas-efficient": out of v1's ethical/lab scope.

### 4.5 Where the real gas is in this design

Most of the ~227k in the test is **not** the tip or the auth `if`: it is the **two swaps** (ERC-20 transfers + mock AMM/router logic).  
That is why the big improvement is usually **less abstraction in the swap** (direct pair / minimal calldata), not micro-optimizing the tip again.

---

## 5. Mental summary

1. **Product decision:** private searcher + atomic EV + coinbase tip + lab-only sandwich.  
2. **Security decision:** auth, ReentrancyGuard, SafeERC20, tip reverted together with EV.  
3. **v1 gas decision:** Yul tip, lean swap lib, no approve(0), single takeProfit.  
4. **Logic:** simulate off-chain → bundle → on-chain auth → swap → tip → takeProfit.  
5. **Next gas leap:** attack the cost of the swaps (pair / approve / calldata), not the tip.

---

## 6. Related reading

| Doc | Purpose |
|-----|---------|
| [`GAS-EN.md`](./GAS-EN.md) | Snapshot numbers and techniques already applied |
| [`diagrama-de-flujo-EN.md`](./diagrama-de-flujo-EN.md) | On-chain decision diagrams |
| [`flujograma-EN.md`](./flujograma-EN.md) | Searcher ↔ builder ↔ contract cycle |
| [`SWC-AUDIT-EN.md`](./SWC-AUDIT-EN.md) | Why these decisions are also security decisions |
| [`planificacion-EN.md`](./planificacion-EN.md) | Phases 0–7 and file architecture |
