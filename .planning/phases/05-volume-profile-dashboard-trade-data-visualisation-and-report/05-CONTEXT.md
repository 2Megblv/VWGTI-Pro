# Phase 5: Volume Profile Dashboard — trade data visualisation and reporting - Context

**Gathered:** 2026-05-13
**Status:** Ready for planning

<domain>
## Phase Boundary

**Live MT5 Performance Panel (MQL5 ChartObject)**

This phase delivers a real-time performance dashboard drawn directly onto an MT5 chart using MQL5 ChartObject primitives. The panel displays live equity curve, P&L metrics, summary statistics, and per-symbol performance breakdown — updating on every completed candle bar. It surfaces the same metrics used in Phase 3 backtesting gates (win rate, profit factor, max daily drawdown) now showing live trading results from Phase 4.

**In Scope:**
- MQL5 ChartObject-based panel drawn on a dedicated MT5 chart
- Equity curve: running account balance over time
- P&L display: daily/weekly P&L bars
- Summary stats: win rate %, profit factor, max daily drawdown, total trades
- Per-symbol breakdown: XAUUSD vs EURUSD performance split
- Panel updates on every new completed candle (bar close) — aligned with EA's zero-lag pattern
- Reads trade data from JournalLogger records (existing MT5 Print() logging infrastructure)

**Out of Scope:**
- Volume Profile visualisations (POC, VAH, VAL zone overlays) — VP levels already visible natively in MT5
- Web browser dashboard (Python backend / Vue frontend) — MQL5 ONLY per SCOPE.md
- Post-session HTML/PDF report export
- Session-level performance breakdown (Tokyo/London/NY split)
- Setup 1 vs Setup 2 performance split
- Real-time streaming to external systems

</domain>

<decisions>
## Implementation Decisions

### Display Platform

- **D-01: MQL5 ChartObject panel** — Dashboard rendered using MT5 native ChartObject primitives (labels, rectangles, lines). No Python, no web server, no external dependencies. Satisfies SCOPE.md "Language Standard: MQL5 ONLY" constraint. Panel lives on a dedicated MT5 chart window.

### Dashboard Content

- **D-02: Primary visualisation — Equity curve + P&L** — Running account balance plotted over time as the headline view. Daily/weekly P&L bars shown alongside. This is the first thing a trader checks after a session.

- **D-03: Secondary metrics — Summary stats** — Live display of:
  - Win rate % (trades won / total trades)
  - Profit Factor (sum of winning trades / sum of losing trades)
  - Max daily drawdown (validates -2% hard stop is holding)
  - Total trades executed this session

- **D-04: Per-symbol breakdown** — XAUUSD and EURUSD displayed separately. Side-by-side performance split to identify if one asset is underperforming. Aligns with Phase 3 validation requirement of 200+ combined trades but separate symbol tracking.

- **D-05: No Volume Profile overlays** — VP levels (POC, VAH, VAL) are already visible in MT5's native charting. The dashboard focuses on trade outcome data only. No duplication of what MT5 already provides.

### Update Behaviour

- **D-06: Bar-close refresh cadence** — Panel updates on every completed candle bar close. Consistent with the EA's zero-lag design principle (all calculations triggered on bar close, not every tick). Avoids tick-level CPU overhead on multi-chart setups.

### Claude's Discretion

- **Panel layout** — Exact positioning, sizing, colour scheme, and ChartObject type (CChartObjectLabel vs. CChartObjectText vs. bitmap rendering) — reasonable engineering choice during implementation.
- **Data retrieval approach** — How the dashboard reads trade history (HistorySelect() + HistoryDealGet*() vs. internal position tracking array from TradeExecution.mqh) — choose whichever avoids re-querying MT5 order history on every bar if a cached array is already maintained.
- **Equity curve rendering** — Whether to use ChartObjectTrend lines or a series of CChartObjectLabel objects to approximate a line — implementation detail given MQL5 ChartObject constraints.
- **Panel reset on new session** — Whether the panel resets per trading day or accumulates from EA attach time — reasonable choice based on what provides the most useful view.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope Constraint
- `.planning/SCOPE.md` — Language Standard: MQL5 ONLY. Dashboard must be MQL5 ChartObject only. No Python, JavaScript, or any other language.

### Existing EA Infrastructure
- `src/Include/JournalLogger.mqh` — Trade logging structures and Print() output. TradeJournalRecord struct defines all available fields (entry/exit time, price, lot size, setup type, exit reason, P&L pips, P&L currency, slippage, R:R).
- `src/Include/TradeExecution.mqh` — Position tracking implementation. May have internal arrays usable by dashboard without re-querying MT5.
- `src/Include/RiskManager.mqh` — Daily P&L limits and drawdown tracking. Source of daily hard stop and profit cap state.
- `src/VolumeProfile_EA_v1.0.mq5` — Main EA file. Dashboard module integrates here via OnCalculate() or OnChartEvent().

### Phase 3 Success Gates (live metrics target same thresholds)
- `.planning/phases/03-backtesting-validation/03-CONTEXT.md` §D-03 — Win rate ≥50%, Profit Factor ≥1.5, Max daily drawdown ≤2%. These same gates are what the live dashboard should display and validate.

### Project Context
- `.planning/PROJECT.md` — No visual objects rule applies to the EA only (silent operation). Dashboard is a separate chart window.

No external docs required — all metric definitions and thresholds are captured in the phase contexts above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `JournalLogger.mqh` → TradeJournalRecord struct: full trade data available (entryTime, symbol, direction, entryPrice, lotSize, setupType, stopLoss, takeProfit, riskRewardRatio, exitTime, exitPrice, exitReason, pnlPips, pnlCurrency, slippage)
- `RiskManager.mqh` → Daily P&L tracking already in place; can expose dailyPnL, dailyTradeCount, dailyMaxDrawdown without recalculating
- `RiskLimits.mqh` → Hard stop and profit cap enforcement state — dashboard can read current session state

### Established Patterns
- **Zero-lag pattern:** All EA calculations on bar close (OnCalculate / new-bar detection). Dashboard refresh follows same pattern — do not use OnTick for panel updates.
- **No visual objects in EA:** The "no chart objects" rule is for the main trading EA to prevent lag. The dashboard is a *separate* indicator/EA on a *dedicated* chart window — ChartObjects are appropriate here.
- **MQL5 modular architecture:** Phases 1–2 refactored into .mqh includes. Dashboard should follow same pattern — create `Dashboard.mqh` include file, call from dedicated `Dashboard_EA.mq5` or as a separate indicator.

### Integration Points
- Dashboard reads from MT5 account history (HistorySelect / HistoryDealGetInteger / HistoryDealGetDouble) OR from a shared data structure maintained by the trading EA
- Panel attaches to a dedicated chart window (not the trading chart) to avoid interfering with the EA's zero-lag signal detection

</code_context>

<specifics>
## Specific Ideas

- Equity curve as the primary visual — running balance line is the headline
- Summary stats block: 4 numbers visible at a glance (win rate, profit factor, max DD, total trades)
- XAUUSD / EURUSD columns side by side — same stats per symbol
- Panel updates every bar close — no tick overhead
- Separate chart window, not overlaid on trading chart — keeps trading EA charts clean

</specifics>

<deferred>
## Deferred Ideas

- **Post-session HTML/PDF report** — Mentioned as alternative to live panel; user chose live panel instead. Could be added as Phase 6 if periodic reports are needed for record-keeping.
- **Session performance breakdown (Tokyo/London/NY)** — Not selected but could add meaningful edge analysis; deferred to future enhancement.
- **Setup 1 vs Setup 2 split** — Not selected for Phase 5; add as dashboard enhancement once baseline metrics are working.
- **Web browser dashboard** — Existing Python backend has `dashboard.py` route; not used in Phase 5 due to SCOPE.md MQL5 constraint. Option for a Phase 6 if cross-platform reporting is needed.

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 05-volume-profile-dashboard-trade-data-visualisation-and-report*
*Context gathered: 2026-05-13*
