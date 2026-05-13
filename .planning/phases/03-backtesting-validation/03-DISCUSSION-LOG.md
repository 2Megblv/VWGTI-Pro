# Phase 3: Backtesting & Validation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-13  
**Phase:** 03-backtesting-validation  
**Areas discussed:** Historical data selection, Backtest execution method, Success gate flexibility, Data source & verification, Failed gate handling, Trade type validation, Overfitting & robustness

---

## Area 1: Historical Data Period

**Gray Area:** Which 1-year window(s) to backtest?

| Option | Description | Selected |
|--------|-------------|----------|
| One continuous 2-year backtest (Jan 24 - Dec 25) | Single backtest run across both years combined; tests strategy stability over longer timeframe with more trades | |
| **Two separate 1-year backtests (2024, then 2025)** | Run 2024 separately, then 2025 separately; compare results to see if strategy is regime-dependent; shows robustness across different market conditions | ✓ |
| Rolling window within the 2-year period | Run multiple 12-month windows (e.g., Jan-Dec 24, then Feb 24-Jan 25, etc.) to test stability across different time slices | |

**User's choice:** Two separate 1-year backtests (2024 and 2025)

**Rationale:** Strategy robustness validation requires testing across different market regimes. 2024 and 2025 likely have different volatility/trending characteristics. If strategy works in 2024 but fails in 2025 (or vice versa), indicates regime-dependent weakness in Phase 2 code.

---

## Area 2: Backtest Execution Method

**Gray Area:** How will the backtest be run? MT5 native vs. external tool; real tick data vs. bar-open approximation?

| Option | Description | Selected |
|--------|-------------|----------|
| **Real tick data (Every tick)** | MT5 uses every historical tick for maximum accuracy; simulates real fills and slippage; slower backtest but most realistic | ✓ |
| Bar-open data (Open price) | MT5 opens orders only at bar close; faster backtest; less accurate for intrabar fills but sufficient for strategy validation | |

**User's choice:** Real tick data (Every Tick)

**Rationale:** Maximum accuracy for validation phase. Slower execution acceptable during backtesting (not production constraint). Real tick mode simulates actual intrabar fills and slippage, increasing confidence that Phase 3 results match Phase 4 live trading conditions.

**Supporting Decision:** MT5 Native Backtest (not external tool)

**Rationale:** Native MT5 backtester uses same order-execution logic as live trading. Consistent environment reduces risk of discrepancies between backtest and live performance.

---

## Area 3: Success Gate Flexibility

**Gray Area:** If Phase 3 backtest results fall slightly short of success gates, what should happen?

| Option | Description | Selected |
|--------|-------------|----------|
| **Hard gates — must meet all criteria to proceed to Phase 4** | If win rate <50%, PF <1.5, or DD >2%, stop and loop back to Phase 2 to fix code/logic before reattempting backtest | ✓ |
| Flexible gates — proceed to Phase 4 if close (>45% WR, >1.3 PF, <2.5% DD) | Accept results within 10% of targets; if slightly short, document the gap and proceed with live validation; Phase 4 live trading proves strategy works | |
| Conditional gates — depends on which metric is short | Hard stop on DD (can't exceed 2.5%); flexible on WR/PF (proceed if >45% WR and >1.3 PF); live testing will clarify | |

**User's choice:** Hard gates — must meet all criteria to proceed to Phase 4

**Rationale:** 50% win rate and 1.5 PF are the minimum thresholds for a viable strategy. Below these levels, strategy profitability is not proven. Non-negotiable validation gates before risking live capital.

---

## Area 4: Data Source & Verification

**Gray Area:** Where will historical tick data come from, and how will accuracy be verified?

| Option | Description | Selected |
|--------|-------------|----------|
| **Broker's built-in history (MT5 downloads from broker)** | Use MT5's native "Download Data" feature to pull tick history directly from your broker; quick but may have gaps or inaccuracies depending on broker | ✓ |
| External data provider (e.g., TickData, Dukascopy, FXCM) | Download pre-packaged tick data from a reputable provider; more expensive but cleaner and verified; compare against broker data if possible | |
| Broker data with manual spot-checks | Use broker history but manually verify accuracy by comparing calculated profiles against known reference points (chart analysis, alternative data sources) | |

**User's choice:** Broker's built-in history (MT5 downloads from broker)

**Verification Method:** Manual spot-checks comparing calculated profiles (POC, VAH, VAL) against known chart reference points to confirm data accuracy.

**Rationale:** Broker's native data is directly usable in MT5 without import/conversion overhead. Manual spot-checks catch obvious corruption or gaps. Cost-effective for MVP validation.

---

## Area 5: Failed Gate Handling

**Gray Area:** If Phase 3 backtest fails a gate (e.g., 48% WR instead of 50%), what is the consequence?

| Option | Description | Selected |
|--------|-------------|----------|
| **Stop and diagnose Phase 2 code (entry logic, Setup 1/2 detection may be wrong)** | Assume EA code has bugs; return to Phase 2 to fix entry/exit logic, then re-backtest | ✓ |
| Stop and re-examine backtest setup (data, parameters, calculation may be wrong) | Verify backtest settings are correct, tick data is accurate, EA parameters match locked values; may re-run on different data period | |
| Accept the result and document why, but proceed to Phase 4 live validation anyway | Hard gates enforced as stated; document the gap; DO NOT proceed to Phase 4 until gates met | |

**User's choice:** Stop and diagnose Phase 2 code

**Rationale:** Backtests are immutable historical data. If results don't match expectations, implementation has a flaw in entry detection, exit management, or risk enforcement. Fix code; don't change backtest approach.

---

## Area 6: Trade Type Validation

**Gray Area:** How will you verify that the backtest includes 50+ Setup 1 trades AND 50+ Setup 2 trades (not just 200+ total trades)?

| Option | Description | Selected |
|--------|-------------|----------|
| **MT5 Journal auto-categorizes trades by setup type; count categories after backtest** | Phase 2 logging includes 'setup_type' field; parse Journal, group trades by setup, count each. Simple and automated. | ✓ |
| Manual inspection of Journal entries; verify setup type for sample of trades | Read Journal entries, manually spot-check 20-30 trades to confirm setup categorization is correct; relies on journal accuracy and manual verification | |
| Post-backtest analysis script (parse .csv export, analyze trade details) | Export backtest results to .csv, write script to count trades by setup type, generate summary report; most reliable if export contains complete trade details | |

**User's choice:** MT5 Journal auto-categorizes trades by setup type

**Rationale:** Simplest validation method. Phase 2 EA already logs setup type for each trade. Automated counting from Journal is reliable and auditable.

---

## Area 7: Overfitting & Robustness Validation

**Gray Area:** How will the two-year backtest results validate strategy isn't curve-fitted?

| Option | Description | Selected |
|--------|-------------|----------|
| **Compare 2024 vs 2025 results; strategy is valid if both years meet gates (50% WR, 1.5 PF, 2% DD)** | If both years independently hit the gates, strategy is robust across market regimes (2024 trending, 2025 different). If 2024 hits but 2025 doesn't, strategy is regime-dependent. | ✓ |
| Average results across 2024 + 2025; require combined metrics to meet gates | Pool all trades from both years; calculate win rate, PF, DD on full sample. Shows overall stability but masks regime-specific weakness | |
| Require EACH year to meet gates separately AND combined average to meet gates | Strictest validation: both years individually strong, AND combined still strong. Proves strategy works in any condition | |

**User's choice:** Compare 2024 vs 2025 results; both must independently meet gates

**Supporting Question:** If 2024 hits gates but 2025 is weaker (e.g., 52% WR / 1.6 PF vs. 48% WR / 1.4 PF), what happens?

| Option | Description | Selected |
|--------|-------------|----------|
| Both must hit gates separately; if 2025 fails, stop and diagnose Phase 2 code | Regime variance indicates EA is over-tuned to 2024 market. Return to Phase 2 to improve robustness, then re-backtest. | |
| Accept the variance; document it; proceed to Phase 4 live with understanding that performance varies by market regime | Strategy works in 2024 (good); may struggle in 2025 (noted). Live trading will reveal how it performs in current regime; adjust if needed. | |
| **BOTH 2024 and 2025 must independently meet all gates (hard requirement)** | If either year fails any metric, STOP and return to Phase 2 to debug and fix. No proceeding to Phase 4 until both years validate. | ✓ |

**User's final choice (after clarification):** BOTH years must independently meet all gates

**Rationale:** Aligns with "Hard gates" decision. No flexibility. If 2024 works but 2025 doesn't, indicates Phase 2 code is over-tuned to 2024 market. Must fix and re-backtest before Phase 4 live deployment.

---

## Summary of Decisions Captured

| Decision | User's Choice |
|----------|---------------|
| **D-01: Historical Period** | Two separate 1-year backtests (2024 and 2025) |
| **D-02: Backtest Mode** | MT5 Native with Real Tick Data (Every Tick) |
| **D-03: Success Gates** | Hard gates (50% WR, 1.5 PF, 2% DD) — must meet ALL in BOTH years |
| **D-04: Failed Gate Handling** | Stop and diagnose Phase 2 code; fix and re-backtest |
| **D-05: Data Source** | Broker's built-in history (MT5 download) |
| **D-06: Trade Type Validation** | MT5 Journal auto-categorizes by setup type; count after backtest |
| **D-07: Regime Robustness** | Both 2024 and 2025 must independently meet all gates; no single-year pass |

---

## Claude's Discretion Areas

- **Manual Spot-Check Sampling:** 5–10 calculated profiles (POC, VAH, VAL) manually verified against chart reference points
- **Journal Parsing:** May export to CSV and script-analyze, or count manually; final counts must be verified
- **Data Anomalies:** If data has gaps or anomalies, document and investigate; may re-download or use alternative source
- **Regime Boundary Handling:** If market regime shifts mid-year (e.g., mid-2024 trend reversal), still enforce 1-year gate requirements per year

---

*Phase: 03-backtesting-validation*  
*Discussion Log Date: 2026-05-13*
