---
phase: 05-volume-profile-dashboard-trade-data-visualisation-and-report
plan: "01"
subsystem: dashboard-metrics-engine
tags:
  - mql5
  - dashboard
  - metrics
  - historyselect
  - equity-curve
  - per-symbol
  - phase3-gates
dependency_graph:
  requires:
    - TradeExecution.mqh (PositionState struct)
    - RiskManager.mqh (constants reference)
    - Utils.mqh (utility functions)
  provides:
    - DashboardMetrics struct (all calculation data)
    - InitializeDashboard() (indicator OnInit)
    - RefreshDashboardMetrics() (bar-close orchestrator)
    - 6 calculation functions (equity, P&L, summary, per-symbol, max DD)
  affects:
    - Phase 5 Plan 02 (indicator lifecycle + ChartObject rendering)
    - Phase 5 Plan 03 (live EA integration)
tech_stack:
  added:
    - Dashboard.mqh (new MQL5 header file)
  patterns:
    - HistorySelect() + HistoryDealGetTicket/String/Double() for deal aggregation
    - Per-symbol string comparison (DEAL_SYMBOL field)
    - Ring buffer pattern for equity curve (bounded 500-entry array)
    - Shift-down pattern for daily P&L history (250-day cap)
key_files:
  created:
    - src/Include/Dashboard.mqh (505 lines)
  modified: []
decisions:
  - "Bar-close refresh cadence (D-06): RefreshDashboardMetrics() called once per bar, not per tick"
  - "Ring buffer for equity curve (T5-02): 500-entry cap prevents unbounded array growth"
  - "UTC midnight for daily reset: SGT refinement deferred to Phase 4"
  - "999.0 sentinel for infinite profit factor: used when sum of losses is zero"
metrics:
  duration_seconds: 139
  completed_date: "2026-05-13"
  tasks_completed: 3
  tasks_total: 3
  files_created: 1
  files_modified: 0
---

# Phase 05 Plan 01: Dashboard.mqh Core Metrics Calculation Engine Summary

**One-liner:** MQL5 dashboard metrics engine with HistorySelect() aggregation, per-symbol XAUUSD/EURUSD split, and Phase 3 success gate validation (WR>=50%, PF>=1.5, DD<=2%).

---

## What Was Built

`src/Include/Dashboard.mqh` — standalone MQL5 header file (505 lines) providing the core calculation engine for the Volume Profile Dashboard indicator.

### DashboardMetrics Struct

Aggregates all display-ready data in one struct:

- **Equity curve:** `equityTime[]`, `equityValues[]`, `equityCount` — bounded at 500 entries (ring buffer)
- **Daily P&L:** `dailyPnLDates[]`, `dailyPnLValues[]`, `dailyCount` — capped at 250 days
- **Summary stats:** `totalTrades`, `winningTrades`, `losingTrades`, `winRate`, `profitFactor`, `maxDailyDrawdown`
- **Account state:** `currentEquity`, `sessionStartEquity`, `totalRealizedPnL`
- **Per-symbol (D-04):** `symbolXAUUSD_*` and `symbolEURUSD_*` fields (trades, wins, totalPnL, winRate, profitFactor)

### Functions Implemented (7 total)

| Function | Purpose |
|----------|---------|
| `InitializeDashboard()` | Reset all metrics to zero/defaults on indicator init |
| `RefreshDashboardMetrics()` | Master orchestrator — calls all sub-functions (D-06 bar-close) |
| `UpdateEquityCurve()` | HistorySelect() 24h window, accumulate realizedPnL, append to bounded curve |
| `UpdateDailyPnL()` | HistorySelect() today's deals, aggregate per calendar day (UTC midnight) |
| `CalculateSummaryStats()` | Win rate and profit factor from deals; validates REQ-042 gates |
| `CalculatePerSymbolStats()` | DEAL_SYMBOL string comparison for XAUUSD vs EURUSD split |
| `CalculateMaxDrawdown()` | Peak-to-trough from equity curve values; logs if >2% gate exceeded |

### Phase 3 Success Gate Constants

```mql5
#define MIN_WIN_RATE 0.50           // 50% minimum (REQ-042)
#define MIN_PROFIT_FACTOR 1.5       // 1.5x minimum (REQ-042)
#define MAX_DAILY_DRAWDOWN 0.02     // 2% maximum (REQ-042)
#define EQUITY_CURVE_HISTORY 500    // Ring buffer cap
```

---

## Success Criteria Verification

| Criterion | Status |
|-----------|--------|
| Dashboard.mqh exists with 250+ lines | PASS — 505 lines |
| `struct DashboardMetrics` present | PASS |
| `void RefreshDashboardMetrics` present | PASS |
| All 6 calculation functions present | PASS |
| All HistorySelect() calls have error handling | PASS — 4 instances, each with `if (!HistorySelect(...)) { Print(...); return; }` |
| Phase 3 gate values present (0.50, 1.5, 0.02) | PASS — all 3 as `#define` constants |
| Per-symbol fields for XAUUSD and EURUSD | PASS — 6 fields each |
| No undefined references to external symbols | PASS — all references to TradeExecution.mqh, RiskManager.mqh, Utils.mqh which exist |
| Header guard correctly placed | PASS — `#ifndef __DASHBOARD_MQH__` ... `#endif` |

---

## Deviations from Plan

**None — plan executed exactly as written.**

The plan structured Tasks 1, 2, and 3 as sequential additions to the same file. Since the complete file (header + struct + functions + finalization) was created in one coherent pass, all three tasks were committed together in a single atomic commit. This is functionally equivalent to three sequential additions — the file content matches all task specifications exactly.

---

## Threat Surface Scan

No new network endpoints, auth paths, or external data transmission introduced. Dashboard.mqh is a read-only calculation module:
- Reads from MT5 HistorySelect() (local broker history)
- Reads from AccountInfoDouble() (local MT5 account state)
- Does NOT modify positions, orders, or limits
- Does NOT transmit data externally

T5-02 mitigation applied: ring buffer at 500 entries prevents unbounded array growth.

---

## Known Stubs

None. All functions are fully implemented. The following items are intentionally deferred to future plans (not stubs):

- **SGT timezone daily reset:** UTC midnight used for simplicity; SGT (UTC+8) refinement deferred to Phase 4 (documented in code comment)
- **Indicator lifecycle (OnInit, OnCalculate, OnDeinit):** Not in scope for Plan 01 — covered by Plan 02
- **ChartObject rendering:** Not in scope for Plan 01 — covered by Plan 02-03

---

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Tasks 1-3 (complete file) | f1d74ab | feat(05-01): create Dashboard.mqh core metrics calculation engine |

---

## Self-Check: PASSED

Files created:
- FOUND: src/Include/Dashboard.mqh

Commits:
- FOUND: f1d74ab
