# Phase 5: Volume Profile Dashboard — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-13
**Phase:** 05-volume-profile-dashboard-trade-data-visualisation-and-report
**Areas discussed:** Dashboard content, Report vs. live

---

## Gray Area Selection

| Option | Selected |
|--------|----------|
| Platform (MT5 panel vs. web vs. report) | |
| Data pipeline | |
| Dashboard content | ✓ |
| Report vs. live | ✓ |

**User skipped:** Platform and Data pipeline — these were resolved via the "Report vs. live" discussion (user chose MT5 chart panel, implicitly settling the platform question).

---

## Dashboard content

| Option | Description | Selected |
|--------|-------------|----------|
| Equity curve + P&L | Running account balance over time, daily/weekly P&L bars | ✓ |
| Win rate by setup type | Setup 1 vs Setup 2 win rates separately | |
| Drawdown chart | Max daily drawdown across sessions | |
| Trade log table | Sortable/filterable table of every trade | |

**User's choice:** Equity curve + P&L

---

**Secondary metrics**

| Option | Description | Selected |
|--------|-------------|----------|
| Summary stats | Win rate %, Profit Factor, Max DD, total trades | ✓ |
| Per-symbol breakdown | XAUUSD vs EURUSD performance split | ✓ |
| Session performance | Tokyo / London / NY session P&L | |
| Setup 1 vs Setup 2 | Side-by-side win rate, avg R:R, avg slippage per setup type | |

**User's choice:** Summary stats + Per-symbol breakdown

---

**Volume Profile visualisations**

| Option | Description | Selected |
|--------|-------------|----------|
| No — trade data only | Focus on P&L and trade metrics; VP visible in MT5 natively | ✓ |
| Yes — annotated chart | Trade entries annotated against VP levels | |
| You decide | Claude's discretion | |

**User's choice:** No — trade data only

---

## Report vs. live

**Dashboard format**

| Option | Description | Selected |
|--------|-------------|----------|
| Post-session report | Generate after session ends; HTML in browser | |
| Live real-time | Updates continuously while EA is running | ✓ |
| Both — live + report | Real-time + formal session-end report | |

**User's choice:** Live real-time

---

**Display location**

| Option | Description | Selected |
|--------|-------------|----------|
| MT5 chart panel | MQL5 ChartObject-based panel on MT5 chart | ✓ |
| Web browser (Python backend) | Python Flask server + browser charts | |
| MT5 + browser | Both — most work, crosses SCOPE.md | |

**User's choice:** MT5 chart panel (MQL5 ChartObject)
**Notes:** Stays within SCOPE.md MQL5 ONLY constraint. No external server required.

---

**Update cadence**

| Option | Description | Selected |
|--------|-------------|----------|
| New trade event | Refreshes on each trade entry/exit/limit trigger | |
| Every new candle (bar close) | Refreshes on each completed bar — aligned with zero-lag pattern | ✓ |
| Both — trade events + bar close | Refreshes on whichever comes first | |

**User's choice:** Every new candle (bar close)
**Notes:** Consistent with EA's zero-lag design principle.

---

## Claude's Discretion

- Panel layout, sizing, colour scheme, ChartObject type
- Data retrieval approach (HistorySelect vs. internal array reuse)
- Equity curve rendering technique within ChartObject constraints
- Panel session reset behaviour (per day vs. EA attach time)

## Deferred Ideas

- Post-session HTML/PDF report
- Session performance breakdown (Tokyo/London/NY)
- Setup 1 vs Setup 2 performance split
- Web browser dashboard (Python backend — deferred due to SCOPE.md)
