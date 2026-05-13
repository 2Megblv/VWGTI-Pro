---
phase: 05-volume-profile-dashboard-trade-data-visualisation-and-report
plan: "02"
subsystem: dashboard-indicator
tags: [mql5, dashboard, indicator, bar-close, lifecycle]
dependency_graph:
  requires:
    - "05-01 (Dashboard.mqh — created as Rule 3 prerequisite in this plan)"
    - "src/Include/TradeExecution.mqh (PositionState struct)"
    - "src/Include/JournalLogger.mqh (TradeJournalRecord struct)"
    - "src/Include/RiskManager.mqh (daily P&L constants)"
  provides:
    - "src/Dashboard_Indicator.mq5 — dedicated indicator entry point"
    - "src/Include/Dashboard.mqh — core metrics calculation engine"
  affects:
    - "05-03 (ChartObject rendering reads g_metrics from this indicator)"
tech_stack:
  added:
    - "MQL5 indicator #property indicator_separate_window"
    - "HistorySelect() / HistoryDealGetTicket() / HistoryDealGetDouble() aggregation"
    - "DashboardMetrics struct (equity, P&L, win rate, profit factor, max DD, per-symbol)"
  patterns:
    - "Bar-close detection: if (time[0] != g_lastBarTime) (D-06)"
    - "Ring buffer for equity curve history (DASHBOARD_MAX_EQUITY_POINTS = 500)"
    - "Phase 3 gate constants: GATE_MIN_WIN_RATE=0.50, GATE_MIN_PROFIT_FACTOR=1.50, GATE_MAX_DAILY_DD=0.02"
key_files:
  created:
    - "src/Dashboard_Indicator.mq5 (202 lines)"
    - "src/Include/Dashboard.mqh (550 lines)"
  modified: []
decisions:
  - "D-06 bar-close refresh cadence implemented exactly per RESEARCH.md Pattern 1 — time[0] != g_lastBarTime guards all HistorySelect() calls"
  - "Dashboard.mqh created in this plan as Rule 3 deviation (Plan 01 ran in same wave; unresolved dependency)"
  - "indicator_separate_window property ensures no interference with trading EA chart"
  - "DashboardMetrics uses ring buffer (DASHBOARD_MAX_EQUITY_POINTS=500) to avoid unbounded array growth"
metrics:
  duration: "~15 minutes"
  completed: "2026-05-13"
  tasks_completed: 3
  tasks_total: 3
  files_created: 2
  files_modified: 0
  lines_written: 752
---

# Phase 05 Plan 02: Dashboard Indicator Lifecycle and Bar-Close Orchestration — Summary

**One-liner:** Dedicated MQL5 indicator with bar-close detection, DashboardMetrics struct, and HistorySelect() aggregation engine for the Volume Profile live performance panel.

---

## What Was Built

Plan 02 creates the dedicated `Dashboard_Indicator.mq5` — the MT5 indicator that orchestrates all dashboard updates. It runs on a separate chart window (not the trading EA chart), detects bar close via the `time[0]` array pattern, and calls `RefreshDashboardMetrics()` exactly once per completed bar.

A prerequisite `src/Include/Dashboard.mqh` was also created (see Deviations) containing the full metrics calculation engine: `DashboardMetrics` struct, `InitializeDashboard()`, `RefreshDashboardMetrics()`, and five sub-functions for equity, daily P&L, summary stats, per-symbol breakdown, and max drawdown.

---

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 (+ Rule 3) | ec8fb60 | Dashboard_Indicator header + OnInit + Dashboard.mqh prerequisite |
| Task 2 | 686faa9 | OnCalculate bar-close detection (D-06) + UpdateDashboard + LogDashboardState |
| Task 3 | cc51f78 | OnDeinit + extern linkages + compilation checklist |

---

## Files Created

| File | Lines | Purpose |
|------|-------|---------|
| `src/Dashboard_Indicator.mq5` | 202 | Dedicated indicator entry point — lifecycle + bar-close orchestration |
| `src/Include/Dashboard.mqh` | 550 | Core metrics calculation engine — DashboardMetrics struct + 6 functions |

---

## Success Criteria Results

| Criterion | Result |
|-----------|--------|
| Dashboard_Indicator.mq5 exists (min 150 lines) | PASS — 202 lines |
| #property indicator_separate_window | PASS |
| int OnInit() present | PASS |
| int OnCalculate() with time[] parameter | PASS |
| if (time[0] != g_lastBarTime) bar-close detection | PASS |
| void UpdateDashboard() present | PASS |
| RefreshDashboardMetrics(g_metrics) call | PASS |
| void OnDeinit() present | PASS |
| void LogDashboardState() present | PASS |
| #include "Include/Dashboard.mqh" | PASS |
| #include "Include/TradeExecution.mqh" | PASS |
| DashboardMetrics g_metrics global | PASS |
| static datetime g_lastBarTime | PASS |
| Bar-close pattern matches RESEARCH.md Pattern 1 | PASS |

All 14 success criteria satisfied.

---

## Functions Implemented

### Dashboard_Indicator.mq5
| Function | Signature | Role |
|----------|-----------|------|
| OnInit | `int OnInit()` | Sets indicator name, initializes DashboardMetrics, resets bar-close detector |
| OnCalculate | `int OnCalculate(rates_total, prev_calculated, time[], ...)` | Bar-close detection (D-06) → calls UpdateDashboard() once per bar |
| UpdateDashboard | `void UpdateDashboard()` | Calls RefreshDashboardMetrics(), then LogDashboardState() |
| LogDashboardState | `void LogDashboardState()` | Outputs equity, win rate, PF, max DD to MT5 Journal |
| OnDeinit | `void OnDeinit(const int reason)` | Logs deinit reason; ChartObject cleanup deferred to Plan 03 |

### Dashboard.mqh
| Function | Role |
|----------|------|
| InitializeDashboard | Resets all DashboardMetrics fields to defaults, snapshots starting balance |
| RefreshDashboardMetrics | Master orchestrator: calls all 5 sub-functions in order |
| UpdateEquityCurve | Snapshots current equity; appends to ring buffer |
| CalculateDailyPnL | Queries today's HistorySelect() deals; resets on day change |
| CalculateSummaryStats | Aggregates all-time win rate, profit factor, average win/loss |
| CalculatePerSymbolStats | Splits stats by XAUUSD and EURUSD separately |
| CalculateMaxDrawdown | Computes running peak drawdown across all closed deals |
| ValidatePhase3Gates | Sets gate flags: WR>=50%, PF>=1.5, max DD<=2% |

---

## Bar-Close Detection (D-06)

Implemented exactly as RESEARCH.md Pattern 1:

```mql5
if (time[0] != g_lastBarTime)
{
    g_lastBarTime = time[0];
    UpdateDashboard();
}
```

This ensures `HistorySelect()` (called inside `RefreshDashboardMetrics()`) fires at most once per bar close — not every tick. Directly mitigates RESEARCH.md Pitfall 1.

---

## Update Frequency

- **OnCalculate fires:** Every tick
- **UpdateDashboard fires:** Once per completed bar (bar close)
- **HistorySelect fires:** Once per bar close (not every tick)
- **g_metrics populated:** Once per bar close

D-06 constraint fully satisfied.

---

## Integration Points

| From | To | Via |
|------|----|-----|
| Dashboard_Indicator.mq5 | Dashboard.mqh | RefreshDashboardMetrics(g_metrics) |
| Dashboard_Indicator.mq5 | TradeExecution.mqh | #include (PositionState struct available) |
| Dashboard.mqh | JournalLogger.mqh | #include (TradeJournalRecord struct) |
| Dashboard.mqh | TradeExecution.mqh | #include (PositionState, positionCount) |
| Dashboard.mqh | RiskManager.mqh | #include (RISK_PERCENT, DAILY_LOSS_LIMIT) |
| Plan 03 | g_metrics (global) | ChartObject rendering reads DashboardMetrics |

**Extern linkage for live position data from EA:** Documented as commented-out code. Dashboard functions without it via HistorySelect(); uncomment when EA exposes PositionState[] in Phase 4.

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking Dependency] Dashboard.mqh created in Plan 02 (not available from Plan 01)**

- **Found during:** Task 1 setup — `#include "Include/Dashboard.mqh"` in Dashboard_Indicator.mq5 requires the file to exist
- **Issue:** Plans 05-01 and 05-02 are both wave 1 (parallel execution). Dashboard.mqh was not yet created when this agent started
- **Fix:** Created complete `src/Include/Dashboard.mqh` (550 lines) with DashboardMetrics struct, InitializeDashboard(), RefreshDashboardMetrics(), and all 5 sub-calculation functions — satisfying both Plan 01's requirements AND Plan 02's dependency
- **Files created:** `src/Include/Dashboard.mqh`
- **Commit:** ec8fb60
- **Impact:** If Plan 01 agent also creates Dashboard.mqh, a merge conflict will need resolution. The Plan 01 agent should win if different (its task is the canonical source); this version is functionally complete.

---

## Known Stubs

None. All functions are fully implemented with real HistorySelect() aggregation logic. No placeholder data or hardcoded values flow to display.

Note: `UpdateDashboard()` contains a comment "Step 3: Update ChartObjects (handled in Plan 03)" — this is intentional scope deferral per plan specification, not a stub. The data is real; only the rendering is deferred.

---

## Threat Flags

No new network endpoints, auth paths, or trust boundary changes introduced.

Dashboard reads from MT5 native account APIs (AccountInfoDouble, HistorySelect) — already in the T5-05/T5-06/T5-07 threat register from the plan's threat model. No new surface added.

---

## Self-Check

### Files exist:
- `src/Dashboard_Indicator.mq5` — FOUND (202 lines)
- `src/Include/Dashboard.mqh` — FOUND (550 lines)

### Commits exist:
- ec8fb60 — FOUND
- 686faa9 — FOUND
- cc51f78 — FOUND

## Self-Check: PASSED
