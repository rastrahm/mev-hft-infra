const I18N = {
  es: {
    'html.lang': 'es',
    'meta.title': 'MEV & HFT Infrastructure — Rolando Strahm',
    'meta.description':
      'Infraestructura MEV/HFT: solvers atómicos, tip coinbase Yul, gas documentado y auditoría SWC. Foundry · Solidity 0.8.24.',

    'nav.overview': 'Proyecto',
    'nav.pillars': 'Pilares',
    'nav.gas': 'Gas',
    'nav.swc': 'SWC',
    'nav.process': 'Proceso',
    'nav.attacks': 'Ataques',
    'nav.repos': 'Repos',
    'nav.close': '← Cerrar',

    'hero.tag': '// MÓDULO 15 · PORTFOLIO WEB3',
    'hero.title': 'MEV & HFT<br>TRADING INFRA',
    'hero.role': 'Solidity 0.8.24 · Foundry · Flashbots · Gas · SWC',
    'hero.sub':
      'Searcher MEV de baja latencia: arbitraje/backrun/sandwich lab atómicos, tip a block.coinbase en Yul y revert total si EV < minProfit. Gas documentado + matriz SWC-100–136.',
    'hero.cta1': 'Ver en GitHub',
    'hero.cta2': 'Ver en GitLab',

    'ov.eyebrow': '// 01 — CONTEXTO',
    'ov.title': 'Por qué este proyecto',
    'ov.lead':
      'Tras flash loans y AMM, construí la capa de <strong>searcher MEV</strong>: bundles estilo Flashbots, <strong>AtomicArbitrageSolver</strong>, <strong>BackrunExecutor</strong> y <strong>SandwichExecutor</strong> (lab). El foco es <strong>atomicidad</strong> (NegativeEV → revert sin tip residual), <strong>auth del searcher</strong>, <strong>gas Yul</strong> y <strong>SWC</strong> con tests que demuestran que el misuse falla.',

    'pi.eyebrow': '// 02 — TRES PILARES',
    'pi.title': 'Qué entrega el módulo',
    'p1.num': '// PILAR_01',
    'p1.title': 'Solvers atómicos',
    'p1.desc':
      'Arb 2-router, backrun post-victim y sandwich lab con midHook: snapshot → MevSwapLib → tip → takeProfit.',
    'p1.l1': 'UnauthorizedSearcher en los tres ejecutores',
    'p1.l2': 'NegativeEV → revert atómico (sin bribe residual)',
    'p1.l3': 'CEI + ReentrancyGuard + Ownable2Step',
    'p2.num': '// PILAR_02',
    'p2.title': 'Optimización de gas',
    'p2.desc':
      'MevSwapLib (path reutilizado), tip payAssembly Yul, takeProfit en una pasada y snapshot en doc/GAS-ES.md.',
    'p2.l1': 'Tip Yul −215 gas vs .call',
    'p2.l2': 'Arb noTip ~227.6k (~−9k vs pre-opt)',
    'p2.l3': '.gas-snapshot + optimizer 10k + via_ir',
    'p3.num': '// PILAR_03',
    'p3.title': 'Verificación SWC',
    'p3.desc':
      'Matriz SWC-100–136, Unauthorized, RevertOnUnprofitable, fuzz ≥ 1000 y fork opcional.',
    'p3.l1': '0 vulnerabilidades explotables',
    'p3.l2': '31 mitigados / N/A · 5 info',
    'p3.l3': '71 tests Foundry PASS · 3 SKIP fork',

    'gas.eyebrow': '// 03 — OPTIMIZACIÓN DE GAS',
    'gas.title': 'Hot path barato, tradeoffs claros',
    'gas.lead':
      'Fase 7: baseline en <code>doc/GAS-ES.md</code> y <code>.gas-snapshot</code>. Paths: <strong>arb noTip 227 631</strong>, <strong>arb+tip 253 307</strong>, <strong>tip Yul 37 293</strong> vs <strong>.call 37 508</strong>. Cada técnica tiene tradeoff explícito.',
    'gas.th1': 'Optimización',
    'gas.th2': 'Tradeoff / efecto',
    'gas.r1a': 'MevSwapLib.swapRoundTrip',
    'gas.r1b': 'Un solo address[] reutilizado; menos alloc en arb/backrun',
    'gas.r2a': 'Sin forceApprove(0) post-swap',
    'gas.r2b': 'Evita 2× SSTORE; allowance residual en routers trusted',
    'gas.r3a': 'ProfitLib.takeProfit',
    'gas.r3b': 'Una pasada vs requireProfit + netProfit',
    'gas.r4a': 'CoinbaseTip.payAssembly (Yul)',
    'gas.r4b': 'call + coinbase; −215 gas vs pay (.call)',
    'gas.r5a': 'Cache tokenIn en stack',
    'gas.r5b': 'Menos calldata / lecturas repetidas',
    'gas.r6a': 'Custom errors (MevErrors)',
    'gas.r6b': 'Reverts compactos vs require strings',
    'gas.r7a': 'optimizer_runs = 10_000 + via_ir',
    'gas.r7b': 'Inlining agresivo en hot path Foundry',

    'swc.eyebrow': '// 04 — VERIFICACIÓN SWC',
    'swc.title': 'SWC Registry · EIP-1470',
    'swc.lead':
      'Matriz <strong>SWC-100 → SWC-136</strong> sobre solvers, MevSwapLib, ProfitLib y CoinbaseTip. Informe: <code>doc/SWC-AUDIT-ES.md</code>. Conclusión: <strong>0 vulnerabilidades explotables</strong> en el alcance v1.',
    'swc.s1': 'Mitigados / N/A',
    'swc.s2': 'Informativos (diseño)',
    'swc.s3': 'Vulnerables',
    'swc.th1': 'SWC clave',
    'swc.th2': 'Mitigación en el contrato',
    'swc.r101': 'Overflow: Solidity 0.8.24; unchecked solo tras validar delta',
    'swc.r103': 'Floating pragma: pragma solidity 0.8.24 fijo',
    'swc.r104': 'Unchecked return: tip/withdraw chequean success → TipTransferFailed',
    'swc.r105': 'Ether withdrawal: withdraw / setSearcher solo Ownable2Step',
    'swc.r107': 'Reentrancy: nonReentrant en execute/backrun/sandwich/withdraw',
    'swc.r114': 'Tx order / MEV: dominio del módulo; minProfit + SimulateBundle',
    'swc.r123': 'Requirements: custom errors + unit/fuzz/unauthorized/unprofitable',
    'swc.info': 'INFORMATIVO',
    'swc.i1t': 'MEV / orden de bundles',
    'swc.i1d':
      'Competencia de inclusión es riesgo de dominio. Mitigación: eth_callBundle / SimulateBundle, minProfit, slippage mins.',
    'swc.i2t': 'Sandwich lab-only + midHook',
    'swc.i2d':
      'SandwichExecutor es solo lab/fork; midHook/routers los elige el searcher. No es runbook de mainnet.',

    'pr.eyebrow': '// 05 — PROCESO',
    'pr.title': 'Fases 0–7 cerradas',
    'pr.lead':
      'TDD por gates: Foundry setup, libs (Profit/Tip/Codec), AtomicArb, Backrun, Sandwich lab, revert-on-unprofitable + fuzz, fork + SimulateBundle, gas + Deploy + SWC.',
    'ph.01': 'Setup Foundry + libs (Profit · Tip · Codec)',
    'ph.23': 'AtomicArbitrageSolver + BackrunExecutor',
    'ph.45': 'Sandwich lab + Unauthorized + unprofitable/fuzz',
    'ph.6': 'Fork mainnet · SimulateBundle',
    'ph.7': 'Gas Yul · Deploy · SWC-AUDIT',
    'st.1': 'Fases',
    'st.2': 'Tests PASS',
    'st.3': 'SWC críticos',
    'st.4': 'SKIP fork',
    'term.label': 'rolando@strahm:~/15-mev-hft-infra',
    'term.1': 'forge test',
    'term.2': '[PASS] suite · 71 passed · 3 skipped (fork)',
    'term.3': 'cat doc/SWC-AUDIT-ES.md | head',
    'term.4': 'Vulnerable: 0 · Informativos: 5 · Mitigados/N/A: 31',
    'term.5': 'echo status',
    'term.6': 'MODULE_15_CLOSED · GAS_SWC_CLOSED',

    'at.eyebrow': '// 06 — CAMPAÑAS DEFENSIVAS',
    'at.title': 'Defensivo, no ofensivo',
    'at.lead':
      'Unauthorized, RevertOnUnprofitable, fuzz y tip reject: el “éxito” del misuse es que revierte y el tip no queda en coinbase. Sandwich solo lab. Sin PoCs de exploit.',
    'cA.t': 'Unauthorized',
    'cA.d': 'Caller ≠ searcher en arb/backrun/sandwich → UnauthorizedSearcher.',
    'cB.t': 'NegativeEV',
    'cB.d': 'Pools planos / price move → revert; tip no residual.',
    'cC.t': 'Tip reject',
    'cC.d': 'Coinbase RejectETH → TipTransferFailed; tx atómica.',
    'cD.t': 'Slippage',
    'cD.d': 'amountOutMin absurdo → MockAMM.SlippageExceeded sin tip.',
    'cE.t': 'Fuzz',
    'cE.d': 'Volumen, tip bps y flat pools ≥ 1000 runs.',

    're.eyebrow': '// 07 — CÓDIGO ABIERTO',
    're.title': 'Repositorios',
    're.lead':
      'Mismo código en GitHub y GitLab: contratos, tests, GAS, SWC-AUDIT (ES/EN), diagramas, Deploy y SimulateBundle.',
    're.cta': 'Contactar',
    're.linkedin': 'LinkedIn',

    'ft.left': 'ROLANDO STRAHM — MEV & HFT · Portfolio',
    'ft.right': 'FOUNDRY · SOLC 0.8.24 · FLASHBOTS · ALL_SYSTEMS_OPERATIONAL',
  },

  en: {
    'html.lang': 'en',
    'meta.title': 'MEV & HFT Infrastructure — Rolando Strahm',
    'meta.description':
      'MEV/HFT infrastructure: atomic solvers, Yul coinbase tip, documented gas, and SWC audit. Foundry · Solidity 0.8.24.',

    'nav.overview': 'Project',
    'nav.pillars': 'Pillars',
    'nav.gas': 'Gas',
    'nav.swc': 'SWC',
    'nav.process': 'Process',
    'nav.attacks': 'Attacks',
    'nav.repos': 'Repos',
    'nav.close': '← Close',

    'hero.tag': '// MODULE 15 · WEB3 PORTFOLIO',
    'hero.title': 'MEV & HFT<br>TRADING INFRA',
    'hero.role': 'Solidity 0.8.24 · Foundry · Flashbots · Gas · SWC',
    'hero.sub':
      'Low-latency MEV searcher stack: atomic arb/backrun/sandwich-lab, Yul tip to block.coinbase, full revert if EV < minProfit. Documented gas + SWC-100–136 matrix.',
    'hero.cta1': 'View on GitHub',
    'hero.cta2': 'View on GitLab',

    'ov.eyebrow': '// 01 — CONTEXT',
    'ov.title': 'Why this project',
    'ov.lead':
      'After flash loans and AMMs, I built the <strong>MEV searcher</strong> layer: Flashbots-style bundles, <strong>AtomicArbitrageSolver</strong>, <strong>BackrunExecutor</strong>, and lab-only <strong>SandwichExecutor</strong>. The point is <strong>atomicity</strong> (NegativeEV → revert with no residual tip), <strong>searcher auth</strong>, <strong>Yul gas</strong>, and <strong>SWC</strong> with tests that prove misuse fails.',

    'pi.eyebrow': '// 02 — THREE PILLARS',
    'pi.title': 'What the module ships',
    'p1.num': '// PILLAR_01',
    'p1.title': 'Atomic solvers',
    'p1.desc':
      '2-router arb, post-victim backrun, and sandwich lab with midHook: snapshot → MevSwapLib → tip → takeProfit.',
    'p1.l1': 'UnauthorizedSearcher on all three executors',
    'p1.l2': 'NegativeEV → atomic revert (no residual bribe)',
    'p1.l3': 'CEI + ReentrancyGuard + Ownable2Step',
    'p2.num': '// PILLAR_02',
    'p2.title': 'Gas optimization',
    'p2.desc':
      'MevSwapLib (reused path), Yul payAssembly tip, single-pass takeProfit, and a Foundry snapshot in doc/GAS-EN.md.',
    'p2.l1': 'Yul tip −215 gas vs .call',
    'p2.l2': 'Arb noTip ~227.6k (~−9k vs pre-opt)',
    'p2.l3': '.gas-snapshot + optimizer 10k + via_ir',
    'p3.num': '// PILLAR_03',
    'p3.title': 'SWC verification',
    'p3.desc':
      'SWC-100–136 matrix, Unauthorized, RevertOnUnprofitable, fuzz ≥ 1000, and optional fork.',
    'p3.l1': '0 exploitable vulnerabilities',
    'p3.l2': '31 mitigated / N/A · 5 info',
    'p3.l3': '71 Foundry tests PASS · 3 SKIP fork',

    'gas.eyebrow': '// 03 — GAS OPTIMIZATION',
    'gas.title': 'Cheap hot path, clear tradeoffs',
    'gas.lead':
      'Phase 7: baseline in <code>doc/GAS-EN.md</code> and <code>.gas-snapshot</code>. Paths: <strong>arb noTip 227 631</strong>, <strong>arb+tip 253 307</strong>, <strong>Yul tip 37 293</strong> vs <strong>.call 37 508</strong>. Every technique has an explicit tradeoff.',
    'gas.th1': 'Optimization',
    'gas.th2': 'Tradeoff / effect',
    'gas.r1a': 'MevSwapLib.swapRoundTrip',
    'gas.r1b': 'Single reused address[]; less alloc on arb/backrun',
    'gas.r2a': 'No forceApprove(0) after swap',
    'gas.r2b': 'Skips 2× SSTORE; residual allowance on trusted routers',
    'gas.r3a': 'ProfitLib.takeProfit',
    'gas.r3b': 'One pass vs requireProfit + netProfit',
    'gas.r4a': 'CoinbaseTip.payAssembly (Yul)',
    'gas.r4b': 'call + coinbase; −215 gas vs pay (.call)',
    'gas.r5a': 'Cache tokenIn on the stack',
    'gas.r5b': 'Fewer calldata / repeated reads',
    'gas.r6a': 'Custom errors (MevErrors)',
    'gas.r6b': 'Compact reverts vs require strings',
    'gas.r7a': 'optimizer_runs = 10_000 + via_ir',
    'gas.r7b': 'Aggressive inlining on the Foundry hot path',

    'swc.eyebrow': '// 04 — SWC VERIFICATION',
    'swc.title': 'SWC Registry · EIP-1470',
    'swc.lead':
      'Full matrix <strong>SWC-100 → SWC-136</strong> on solvers, MevSwapLib, ProfitLib, and CoinbaseTip. Report: <code>doc/SWC-AUDIT-EN.md</code>. Conclusion: <strong>0 exploitable vulnerabilities</strong> in v1 scope.',
    'swc.s1': 'Mitigated / N/A',
    'swc.s2': 'Informational (design)',
    'swc.s3': 'Vulnerable',
    'swc.th1': 'Key SWC',
    'swc.th2': 'Mitigation in the contract',
    'swc.r101': 'Overflow: Solidity 0.8.24; unchecked only after delta checks',
    'swc.r103': 'Floating pragma: fixed pragma solidity 0.8.24',
    'swc.r104': 'Unchecked return: tip/withdraw check success → TipTransferFailed',
    'swc.r105': 'Ether withdrawal: withdraw / setSearcher Ownable2Step-only',
    'swc.r107': 'Reentrancy: nonReentrant on execute/backrun/sandwich/withdraw',
    'swc.r114': 'Tx order / MEV: module domain; minProfit + SimulateBundle',
    'swc.r123': 'Requirements: custom errors + unit/fuzz/unauthorized/unprofitable',
    'swc.info': 'INFORMATIONAL',
    'swc.i1t': 'MEV / bundle ordering',
    'swc.i1d':
      'Inclusion competition is domain risk. Mitigation: eth_callBundle / SimulateBundle, minProfit, slippage mins.',
    'swc.i2t': 'Sandwich lab-only + midHook',
    'swc.i2d':
      'SandwichExecutor is lab/fork only; midHook/routers are chosen by the searcher. Not a mainnet exploit runbook.',

    'pr.eyebrow': '// 05 — PROCESS',
    'pr.title': 'Phases 0–7 closed',
    'pr.lead':
      'Gate-based TDD: Foundry setup, libs (Profit/Tip/Codec), AtomicArb, Backrun, Sandwich lab, revert-on-unprofitable + fuzz, fork + SimulateBundle, gas + Deploy + SWC.',
    'ph.01': 'Foundry setup + libs (Profit · Tip · Codec)',
    'ph.23': 'AtomicArbitrageSolver + BackrunExecutor',
    'ph.45': 'Sandwich lab + Unauthorized + unprofitable/fuzz',
    'ph.6': 'Mainnet fork · SimulateBundle',
    'ph.7': 'Yul gas · Deploy · SWC-AUDIT',
    'st.1': 'Phases',
    'st.2': 'Tests PASS',
    'st.3': 'Critical SWC',
    'st.4': 'SKIP fork',
    'term.label': 'rolando@strahm:~/15-mev-hft-infra',
    'term.1': 'forge test',
    'term.2': '[PASS] suite · 71 passed · 3 skipped (fork)',
    'term.3': 'cat doc/SWC-AUDIT-EN.md | head',
    'term.4': 'Vulnerable: 0 · Informational: 5 · Mitigated/N/A: 31',
    'term.5': 'echo status',
    'term.6': 'MODULE_15_CLOSED · GAS_SWC_CLOSED',

    'at.eyebrow': '// 06 — DEFENSIVE CAMPAIGNS',
    'at.title': 'Defensive, not offensive',
    'at.lead':
      'Unauthorized, RevertOnUnprofitable, fuzz, and tip reject: a successful “misuse” means it reverts and the tip never sticks on coinbase. Sandwich is lab-only. No exploit PoCs.',
    'cA.t': 'Unauthorized',
    'cA.d': 'Caller ≠ searcher on arb/backrun/sandwich → UnauthorizedSearcher.',
    'cB.t': 'NegativeEV',
    'cB.d': 'Flat pools / price move → revert; no residual tip.',
    'cC.t': 'Tip reject',
    'cC.d': 'RejectETH coinbase → TipTransferFailed; atomic tx.',
    'cD.t': 'Slippage',
    'cD.d': 'Absurd amountOutMin → MockAMM.SlippageExceeded, no tip.',
    'cE.t': 'Fuzz',
    'cE.d': 'Volume, tip bps, and flat pools ≥ 1000 runs.',

    're.eyebrow': '// 07 — OPEN SOURCE',
    're.title': 'Repositories',
    're.lead':
      'Same codebase on GitHub and GitLab: contracts, tests, GAS, SWC-AUDIT (ES/EN), diagrams, Deploy, and SimulateBundle.',
    're.cta': 'Contact',
    're.linkedin': 'LinkedIn',

    'ft.left': 'ROLANDO STRAHM — MEV & HFT · Portfolio',
    'ft.right': 'FOUNDRY · SOLC 0.8.24 · FLASHBOTS · ALL_SYSTEMS_OPERATIONAL',
  },
};

function setLanguage(lang) {
  const dict = I18N[lang] || I18N.es;
  document.documentElement.lang = dict['html.lang'];
  document.title = dict['meta.title'];

  const metaDesc = document.querySelector('meta[name="description"]');
  if (metaDesc && dict['meta.description']) {
    metaDesc.setAttribute('content', dict['meta.description']);
  }

  document.querySelectorAll('[data-i18n]').forEach((el) => {
    const key = el.getAttribute('data-i18n');
    const val = dict[key];
    if (val == null) return;
    if (el.hasAttribute('data-i18n-html')) el.innerHTML = val;
    else el.textContent = val;
  });

  document.querySelectorAll('.lang-btn').forEach((btn) => {
    btn.classList.toggle('active', btn.dataset.lang === lang);
  });

  localStorage.setItem('mev-portfolio-lang', lang);

  const url = new URL(window.location.href);
  url.searchParams.set('lang', lang);
  history.replaceState(null, '', url);
}

function initI18n() {
  const params = new URLSearchParams(window.location.search);
  const fromQuery = params.get('lang');
  const saved = localStorage.getItem('mev-portfolio-lang');
  const preferred =
    (fromQuery === 'en' || fromQuery === 'es' ? fromQuery : null) ||
    saved ||
    (navigator.language?.startsWith('en') ? 'en' : 'es');

  setLanguage(preferred);

  document.querySelectorAll('.lang-btn').forEach((btn) => {
    btn.addEventListener('click', () => setLanguage(btn.dataset.lang));
  });
}

document.addEventListener('DOMContentLoaded', initI18n);
