# Guía de entendimiento — Módulo 15 MEV & HFT

Documento para entender **qué se decidió**, **cómo fluye la lógica** y **dónde aún se puede ahorrar gas**.  
Complementa [`planificacion-ES.md`](./planificacion-ES.md), [`GAS-ES.md`](./GAS-ES.md) y [`diagrama-de-flujo-ES.md`](./diagrama-de-flujo-ES.md).

---

## 1. En una frase

Un searcher autorizado llama a un contrato que ya tiene tokens (y ETH para tip), hace un round-trip entre dos routers, paga un bribe al builder vía `block.coinbase` y **solo deja la tx como exitosa si el balance de `tokenIn` subió al menos `minProfit`**. Si no, todo revierte — incluyendo el tip.

---

## 2. Decisiones técnicas

### 2.1 Tres contratos en lugar de uno

| Contrato | Rol | Por qué separado |
|----------|-----|------------------|
| `AtomicArbitrageSolver` | Arb clásico 2-router | Superficie y tests claros |
| `BackrunExecutor` | Misma mecánica, semántica post-victim | Misma lib de swap; escenarios de test distintos |
| `SandwichExecutor` | Front → victim lab → back | **Solo lab/fork**; midHook simula la victim en la misma tx |

**Decisión:** no mezclar sandwich de producción con arb/backrun. El sandwich es pedagógico y acotado.

### 2.2 Capital en el contrato (no flash loan en v1)

El solver/executor **ya está fondeado** con `tokenIn` (y ETH para tips).  
No pedimos prestado en la misma tx (eso sería el módulo 08 / ERC-3156).

**Por qué:** el módulo 15 se centra en tip coinbase, auth de searcher y atomicidad de EV, no en el estándar flash loan.

**Tradeoff:** hay capital atado en el contrato; el owner puede `withdraw`.

### 2.3 Auth: un solo `authorizedSearcher`

Solo ese EOA/relayer puede llamar `execute` / `backrun` / `sandwich`.  
El `owner` (Ownable2Step) rota el searcher y retira fondos.

**Por qué:** en MEV real el bot firma; no queremos `execute` público que cualquiera dispare con tu capital.

### 2.4 Orden de la tx: swaps → tip → profit check

```
1. Auth + validar route/amount
2. Snapshot balance(tokenIn)
3. Swaps (MevSwapLib o legs sandwich)
4. Tip a block.coinbase (payAssembly)
5. takeProfit(snapshot, balanceFinal, minProfit)
6. Emit + return
```

**Decisión clave:** el tip se paga **antes** del check de profit, pero dentro de la **misma** transacción. Si `takeProfit` falla → `NegativeEV` → la EVM **deshace** el tip. Así no queda bribe pagado en un trade que no rindió.

### 2.5 Profit medido en `tokenIn` (ERC-20), tip en ETH

- **Profit:** delta de balance del token base del arb.  
- **Tip:** ETH nativo al coinbase.

**Por qué:** el builder cobra en ETH; el EV del trade se mide en el asset que el searcher quiere ganar. Hay que fondear **ambos**.

### 2.6 Tip en Yul (`CoinbaseTip.payAssembly`)

Producción usa assembly `call` + opcode `coinbase`, no `transfer`/`send`.  
Chequeo de `success` → `TipTransferFailed`.

**Por qué:** reglas del suite + ~215 gas menos vs `.call` en el harness (ver `GAS-ES.md`).

### 2.7 `MevSwapLib` compartida (arb + backrun)

Round-trip:

1. `tokenIn → tokenOut` en `routerA`  
2. `tokenOut → tokenIn` en `routerB`

Optimizaciones v1:

- Un solo `address[]` de path reutilizado  
- Sin `forceApprove(0)` después del swap (ahorro de SSTORE; allowance residual en routers **de confianza**)

### 2.8 Sandwich con `ISandwichMidHook`

Entre front y back se llama opcionalmente a un hook que, en tests, ejecuta el swap de la “victim”.  
En un bundle real esa victim sería **otra tx** en el medio; aquí se simula en una sola llamada para lab.

### 2.9 Custom errors + CEI + ReentrancyGuard

- Errores en `MevErrors` (no `require` con strings)  
- Guard `nonReentrant` en paths de ejecución y withdraw  
- SafeERC20 para tokens  

### 2.10 Bundles Flashbots = off-chain

On-chain solo ejecuta. Off-chain: detectar oportunidad, simular (`SimulateBundle.s.sol` / `eth_callBundle`), enviar bundle.  
El contrato **no** habla con el relay.

### 2.11 Pragma y toolchain fijos

- `pragma solidity 0.8.24`  
- Foundry, OZ v5, fuzz ≥ 1000, fork opcional  

---

## 3. Lógica que sigue el sistema

### 3.1 Vista searcher (ciclo completo)

```
Oportunidad (mempool / desbalance)
        │
        ▼
Simular (fork / SimulateBundle / eth_callBundle)
        │
        ├── EV malo ──► descartar (no enviar)
        │
        └── EV bueno ──► eth_sendBundle / mev_sendBundle
                                │
                                ▼
                    Builder incluye txs en el bloque
                                │
                                ▼
                    Contrato on-chain (execute / backrun / sandwich)
                                │
                                ├── OK ──► profit en contrato + tip al builder
                                └── revert ──► nada cambia (ni tip)
```

### 3.2 Vista on-chain — arbitraje / backrun

Mismo hot path (`MevSwapLib` + `takeProfit`):

1. ¿`msg.sender == authorizedSearcher`? Si no → `UnauthorizedSearcher`.  
2. ¿`amountIn > 0` y route sin ceros / tokens distintos?  
3. `initial = balanceOf(tokenIn)`.  
4. Swap A, luego swap B (salida intermedia `mid`; si `mid == 0` → `InsufficientOutput`).  
5. `payAssembly(tipWei)` (0 = no-op).  
6. `takeProfit(initial, balanceFinal, minProfit)` → si falla → `NegativeEV`.  
7. Evento + `return profit`.

**Backrun en tests:** primero una “victim” desbalancea un pool; luego el backrun compra en el pool barato y vende en el caro (routers cruzados en la `Route`).

### 3.3 Vista on-chain — sandwich lab

1. Auth + validar legs.  
2. Snapshot de `front.tokenIn`.  
3. Front-run (compra).  
4. Si hay `midHook` → `afterFront` (victim simulada).  
5. Back-run (vende; `amountIn == 0` = usar todo el balance del mid token).  
6. Tip + `takeProfit`.  

Sin victim (hook = 0) el round-trip suele perder por fees → `NegativeEV` (comportamiento esperado en tests).

### 3.4 Dónde vive cada pieza

| Pieza | Archivo |
|-------|---------|
| Auth + execute | `AtomicArbitrageSolver.sol` |
| Auth + backrun | `BackrunExecutor.sol` |
| Auth + sandwich | `SandwichExecutor.sol` |
| Swaps 2-hop | `libraries/MevSwapLib.sol` |
| Snapshot / EV | `libraries/ProfitLib.sol` |
| Tip ETH | `libraries/CoinbaseTip.sol` |
| Route packed | `libraries/CalldataCodec.sol` |
| Errores | `errors/MevErrors.sol` |

---

## 4. ¿Se puede mejorar el gas de lo que ya existe?

Sí. Lo de v1 ya bajó ~9k en el envelope del arb (test) y ~215 en el tip aislado. Abajo van mejoras **realistas** ordenadas por impacto vs complejidad.

### 4.1 Alto impacto / razonable para v2

| Idea | Qué ahorra | Costo / riesgo |
|------|------------|----------------|
| **Swap directo al pair** (Uniswap V2 `swap` + transfer) en lugar de router + `path[]` | Menos calldata, menos hops externos, sin array en memory | Hay que manejar `getReserves` / amounts; más acoplado al AMM |
| **`forceApprove` solo si allowance &lt; amount** (o Permit2 / approve max una vez) | Menos SSTORE de approve en cada execute | Allowance alto permanente al router |
| **`authorizedSearcher` immutable** (o rotación rara vía proxy) | 1 SLOAD menos por tx | Menos flexibilidad operativa |
| **Empaquetar params en calldata packed** (`CalldataCodec`) en la firma externa | Menos calldata caro | API menos legible; builders deben encodear |

### 4.2 Impacto medio

| Idea | Qué ahorra | Notas |
|------|------------|-------|
| Tip **después** de calcular profit off-chain y tip=0 on-chain si se usa solo `coinbase` vía builder payment otro mecanismo | Menos ETH transfer on-chain | Depende del builder (payment en bundle header, etc.) |
| Quitar `ReentrancyGuard` si se prueba que no hay callback al solver | ~un SSTORE de status | **No recomendado** sin auditoría fuerte; routers/hooks son externos |
| Unificar arb/backrun en un solo contrato | Menos bytecode deploy | Peor separación de tests/roles |
| `unchecked` en más aritmética ya acotada | Poco en este path | Ya se usa en `takeProfit` tras validar |

### 4.3 Bajo impacto / ya hecho o casi

| Idea | Estado |
|------|--------|
| Tip Yul vs `.call` | Hecho (`payAssembly`) |
| Path array único | Hecho |
| Sin `approve(0)` | Hecho (tradeoff documentado) |
| `takeProfit` una pasada | Hecho |
| Custom errors | Hecho |
| `via_ir` + `optimizer_runs = 10_000` | Hecho |

### 4.4 Lo que **no** conviene “optimizar” a ciegas

- Medir profit en un token y tippear ETH: son monedas distintas; no fusionar.  
- Sacar el profit check para ahorrar gas: rompe la garantía de EV del módulo.  
- Hacer `execute` público sin auth: ahorra un `if`, pierde el capital.  
- Sandwich en mainnet “porque es más gas-eficiente el envelope”: fuera de alcance ético/lab del v1.

### 4.5 Dónde está el gas de verdad en este diseño

El grueso del ~227k del test **no** es el tip ni el `if` de auth: son los **dos swaps** (transfers ERC-20 + lógica del AMM mock/router).  
Por eso la mejora gorda suele ser **menos abstracción en el swap** (pair directo / calldata mínimo), no micro-optimizar el tip otra vez.

---

## 5. Resumen mental

1. **Decisión de producto:** searcher privado + EV atómico + tip coinbase + sandwich solo lab.  
2. **Decisión de seguridad:** auth, ReentrancyGuard, SafeERC20, tip revertible con el EV.  
3. **Decisión de gas v1:** Yul tip, lib de swap magra, sin approve(0), takeProfit único.  
4. **Lógica:** simular off-chain → bundle → on-chain auth → swap → tip → takeProfit.  
5. **Siguiente salto de gas:** atacar el coste de los swaps (pair / approve / calldata), no el tip.

---

## 6. Lecturas relacionadas

| Doc | Para qué |
|-----|----------|
| [`GAS-ES.md`](./GAS-ES.md) | Números de snapshot y técnicas ya aplicadas |
| [`diagrama-de-flujo-ES.md`](./diagrama-de-flujo-ES.md) | Diagramas de decisión on-chain |
| [`flujograma-ES.md`](./flujograma-ES.md) | Ciclo searcher ↔ builder ↔ contrato |
| [`SWC-AUDIT-ES.md`](./SWC-AUDIT-ES.md) | Por qué esas decisiones también son de seguridad |
| [`planificacion-ES.md`](./planificacion-ES.md) | Fases 0–7 y arquitectura de archivos |
