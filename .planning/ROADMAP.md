# VWGTI-PRO-VP-EA: v1 MVP Roadmap

**Project:** MT5 Volume Profile Swing Trading Expert Advisor  
**Version:** 1.0 (Minimal Viable Product)  
**Last Updated:** 2026-05-13  
**Status:** Phase 5 Planning Complete

---

## Phases

- [x] **Phase 1: Volume Profile Core** — Foundation volume profile engine + risk framework (XAUUSD/EURUSD ready to trade)
  - **Plans:** 01-01, 01-02, 01-03 (3 plans complete)
  - **Status:** Planning complete → Ready for execution
- [x] **Phase 2: Signal Detection & Execution** - Setup 1 & 2 entry logic + execution + single TP + logging (trading fully operational)
  - **Plans:** 02-01, 02-02, 02-03, 02-04 (4 plans complete)
  - **Status:** Planning complete → Ready for execution
- [x] **Phase 3: Backtesting & Validation** - 1-year backtest on both symbols; win rate/profit factor validation
  - **Plans:** 03-01, 03-02, 03-03, 03-04 (4 plans complete)
  - **Status:** Planning complete → Ready for execution
- [ ] **Phase 4: Live Deployment & Monitoring** - Live account validation; 30 days zero-error operation
  - **Plans:** 0 plans (pending Phase 3 completion)
  - **Status:** Not yet planned
- [x] **Phase 5: Volume Profile Dashboard** — Real-time performance panel with equity curve, P&L metrics, win rate, profit factor, max drawdown
  - **Plans:** 05-01, 05-02, 05-03 (3 plans complete)
  - **Status:** Planning complete → Ready for execution

---

## Phase Details

### Phase 1: Volume Profile Core

**Goal:** Enable the EA to calculate Volume Profile accurately and enforce position sizing + daily risk limits; trader can attach EA to XAUUSD/EURUSD charts and see correct position sizing and daily limit enforcement.

**Depends on:** Nothing (first phase)

**Requirements:** REQ-001 through REQ-010 (Profile engine), REQ-029 through REQ-035 (Risk framework), REQ-036, REQ-037 (Symbol support)

**Success Criteria** (what must be TRUE when this phase completes):
  1. 400-bin volume profile calculates from 150-bar lookback; POC/VAH/VAL match manual chart analysis within 1 pip
  2. HVN (local volume peaks > 85th percentile) and LVN (valleys < 25th percentile) detect correctly on injected test data
  3. Daily hard stop loss (-2% account limit) cannot be overridden; stops ALL trading when breached
  4. Daily profit cap (+5% account limit) closes ALL open positions when reached
  5. Position sizing formula (lot = [balance × 0.6%] / [SL distance × point value]) calculates correctly for $1K+ accounts

**Plans:** 3 plans

| Plan | Objective | Tasks |
|------|-----------|-------|
| 01-01-PLAN.md | Volume Profile Calculation Engine | 5 tasks |
| 01-02-PLAN.md | Risk Management Framework | 5 tasks |
| 01-03-PLAN.md | Logging, Error Handling, Backtest Validation | 4 tasks |

**Wave Structure:**
- **Wave 1:** Plan 01-01 (Volume Profile Engine) — data structures, profile calculation, POC/VAH/VAL, HVN/LVN, unit tests
- **Wave 2:** Plan 01-02 (Risk Management) — position sizing, daily limits, position tracking (depends on Wave 1)
- **Wave 3:** Plan 01-03 (Validation) — logging, error handling, backtest validation (depends on Waves 1 & 2)

---

### Phase 2: Signal Detection & Execution

**Goal:** Both entry setups execute trades end-to-end with proper exit management; trader sees orders placed at correct prices, single TP targets opposite profile edge, and Journal logs all activity.

**Depends on:** Phase 1 (requires volume profile + risk framework working)

**Requirements:** REQ-011–028 (Setup 1 & 2 detection, entry/exit logic, TP), REQ-038–042 (Logging, execution monitoring)

**Success Criteria** (what must be TRUE when this phase completes):
  1. Setup 1 (balanced market detection + confirmation candle closure inside VA) triggers entries on reclaims into Value Area
  2. Setup 2 (LVN sweep + HVN edge identification + trigger candle pattern + 1.3x volume spike) triggers entries at HVN cluster edges
  3. Single unified TP structure executes (opposite profile edge: VAH for LONG, VAL for SHORT); position state tracked until TP or SL triggered
  4. Journal logs all trades: entry time/price/size, setup type (Setup 1 or 2), exit time/reason, realized P&L, slippage
  5. Order fills validated for slippage; trades rejected if fill price >50 pips from order price
  6. Daily hard stop (-2%) and profit cap (+5%) enforced; Friday 21:45 hard close executes

**Plans:** 4 plans

| Plan | Objective | Tasks | Wave |
|------|-----------|-------|------|
| 02-01-PLAN.md | Phase 1 Refactoring into Modular Headers | 5 tasks | 0 |
| 02-02-PLAN.md | Signal Detection (Setup 1 & 2) and Market Context Switching | 5 tasks | 1 |
| 02-03-PLAN.md | Order Placement, Slippage Validation, and Position State Tracking | 5 tasks | 2 |
| 02-04-PLAN.md | Daily Risk Limits, Journal Logging, and Audit Trail | 6 tasks | 3 |

**Wave Structure:**
- **Wave 0:** Plan 02-01 (Refactor Phase 1 into modules) — VolumeProfile.mqh, RiskManager.mqh, Utils.mqh, verification
- **Wave 1:** Plan 02-02 (Signal Detection) — IsBalancedMarket(), DetectSetup1Signal(), DetectSetup2Signal(), TP/SL calculation (depends on Wave 0)
- **Wave 2:** Plan 02-03 (Order Execution) — CTrade order placement, slippage validation, position state tracking (depends on Wave 1)
- **Wave 3:** Plan 02-04 (Risk Control & Logging) — Daily limits, Friday close, journal logging, error handling (depends on Wave 2)

---

### Phase 3: Backtesting & Validation

**Goal:** Historical backtest (1 year on XAUUSD + EURUSD) validates that EA rules work across 200+ trades; win rate ≥50%, profit factor ≥1.5, drawdown ≤2% daily.

**Depends on:** Phase 2 (requires fully functional EA with all entry/exit logic)

**Requirements:** All 42 v1 requirements validated through backtest scenarios (200+ trades, multiple market regimes)

**Success Criteria** (what must be TRUE when this phase completes):
  1. Win rate ≥50% on combined Setup 1 + Setup 2 trade sample (50+ trades of each type across both symbols)
  2. Profit Factor ≥1.5 (sum of winning trades / sum of losing trades)
  3. Maximum daily drawdown ≤2% (enforced by daily -2% hard stop; backtest shows zero violations)
  4. 200+ trades executed in 1-year backtest across XAUUSD + EURUSD combined
  5. Backtest projected P&L within ±20% of conservative estimate (validates calculation accuracy, no overfitting)

**Plans:** 4 plans

| Plan | Objective | 
|------|-----------|
| 03-01-PLAN.md | Backtest Setup & Data Preparation |
| 03-02-PLAN.md | Historical Run (2024 data) |
| 03-03-PLAN.md | Historical Run (2025 data) |
| 03-04-PLAN.md | Results Analysis & Gate Validation |

---

### Phase 4: Live Deployment & Monitoring

**Goal:** EA runs 24/5 on live trading account ($500-1K) with real capital; validates strategy performance matches backtest and system stability under production conditions.

**Depends on:** Phase 3 (requires backtest validation gate passed; win rate ≥50%, PF ≥1.5)

**Requirements:** All 42 v1 requirements validated in live trading environment (real broker slippage, connection stability, order execution latency)

**Success Criteria** (what must be TRUE when this phase completes):
  1. Zero system errors in 30 days of continuous 24/5 operation (no EA crashes, no missed closes, no orphaned trades)
  2. All trades execute within 50-point slippage tolerance; no fill rejections due to excessive slip
  3. Live win rate within ±20% of backtest results (validates strategy logic under real market conditions)
  4. Friday 21:45 hard close executes reliably; all open positions closed before weekend gap risk
  5. Broker connectivity validated before each trade; graceful degradation if disconnected (skip trade vs. error state)

**Plans:** TBD (pending Phase 3 completion)

---

### Phase 5: Volume Profile Dashboard — Trade Data Visualisation and Reporting

**Goal:** Live MT5 performance panel displaying real-time equity curve, daily/weekly P&L breakdown, summary statistics (win rate, profit factor, max drawdown), and per-symbol performance (XAUUSD vs EURUSD). Panel runs on dedicated chart window; updates on every bar close without interfering with trading EA zero-lag constraint.

**Depends on:** Phase 4 (requires live trading to have data to visualize)

**Requirements:** REQ-042 (Metrics calculation and display)

**Success Criteria** (what must be TRUE when this phase completes):
  1. Dashboard indicator attaches to dedicated MT5 chart window (separate_window mode)
  2. Equity curve displays running account balance in real-time
  3. Daily/weekly P&L bars show daily profit/loss breakdown
  4. Summary stats display: win rate %, profit factor, max daily drawdown, total trades executed
  5. Phase 3 success gates validated and displayed: win rate ≥50% ✓, profit factor ≥1.5 ✓, max DD ≤2% ✓
  6. Per-symbol breakdown shows XAUUSD and EURUSD performance split separately
  7. Dashboard updates exactly once per completed bar (bar-close trigger; not every tick)
  8. Zero CPU overhead on trading EA; both EA and dashboard operate independently

**Plans:** 3 plans

| Plan | Objective | Wave |
|------|-----------|------|
| 05-01-PLAN.md | Dashboard.mqh core metrics calculation engine | 1 |
| 05-02-PLAN.md | Dashboard_Indicator.mq5 indicator lifecycle + bar-close orchestration | 1 |
| 05-03-PLAN.md | ChartObject rendering + visual validation + integration | 2 |

**Wave Structure:**
- **Wave 1:** Plans 05-01 & 05-02 (parallel) — Dashboard.mqh (metrics engine) and Dashboard_Indicator.mq5 (indicator lifecycle)
  - 05-01: DashboardMetrics struct, HistorySelect() aggregation, win rate/PF/max DD calculation, per-symbol breakdown
  - 05-02: OnInit (init), OnCalculate (bar-close detection), UpdateDashboard (orchestration), OnDeinit (cleanup)
- **Wave 2:** Plan 05-03 (depends on Wave 1) — RenderDashboard(), UpdateDashboardLabel(), visual panel layout, Phase 3 gate display

---

## Progress Tracking

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Volume Profile Core | 3/3 ✅ | Planning complete | 2026-05-13 |
| 2. Signal Detection & Execution | 4/4 ✅ | Planning complete | 2026-05-13 |
| 3. Backtesting & Validation | 4/4 ✅ | Planning complete | 2026-05-13 |
| 4. Live Deployment & Monitoring | 0/? | Not yet planned | — |
| 5. Volume Profile Dashboard | 3/3 ✅ | Planning complete | 2026-05-13 |

---

## Requirement Traceability

| Phase | Requirement IDs | Count | Coverage |
|-------|---|---|---|
| Phase 1 | REQ-001–010, REQ-029–037 | 17 | Volume Profile + Risk Framework |
| Phase 2 | REQ-011–028, REQ-038–042 | 20 | Signal Detection + Execution |
| Phase 3 | All 42 (backtest validation) | 42 | Historical performance validation |
| Phase 4 | All 42 (live validation) | 42 | Production stability validation |
| Phase 5 | REQ-042 | 1 | Metrics calculation & display |

**Total Coverage:** 42/42 requirements mapped + 1 additional (REQ-042 refined in Phase 5)

---

## Timeline & Dependencies

```
Phase 1 (3-4 weeks) [PLANNING COMPLETE 2026-05-13]
  ├─ Deliverable: Compiled EA with volume profile + risk limits
  ├─ Gate: Unit tests pass (profile accuracy ±0.1%, daily limits enforce)
  ├─ 3 plans (01-01, 01-02, 01-03) ready for execution
  └─ Unblocks: Phase 2
  
Phase 2 (2-3 weeks) [PLANNING COMPLETE 2026-05-13]
  ├─ Deliverable: Entry/exit logic + full trade execution + audit logging
  ├─ Gate: Integration tests pass (order flow end-to-end, daily limits enforced)
  ├─ 4 plans (02-01, 02-02, 02-03, 02-04) ready for execution
  └─ Unblocks: Phase 3
  
Phase 3 (2 weeks) [PLANNING COMPLETE 2026-05-13]
  ├─ Deliverable: 1-year backtest results (2024 + 2025)
  ├─ Gate: Win rate ≥50%, PF ≥1.5, DD ≤2% (BOTH years)
  ├─ 4 plans (03-01, 03-02, 03-03, 03-04) ready for execution
  └─ Unblocks: Phase 4 & Phase 5
  
Phase 5 (1-2 weeks) [PLANNING COMPLETE 2026-05-13]
  ├─ Deliverable: Live dashboard indicator with equity curve, P&L, summary stats, per-symbol breakdown
  ├─ Gate: Phase 3 gates (50%, 1.5, 2%) displayed correctly in live trading
  ├─ 3 plans (05-01, 05-02, 05-03) ready for execution
  ├─ Runs parallel with Phase 4 (dashboard on Phase 4 live trading data)
  └─ Completes: Trader visibility into live performance
  
Phase 4 (4 weeks) [NOT YET PLANNED]
  ├─ Deliverable: 30 days live trading, zero errors
  ├─ Gate: Live metrics ≈ backtest ±20%
  └─ Completes: v1 MVP
  
Total: 10-12 weeks (5-6 weeks minimum with no rework)
```

---

## Architecture Alignment

Phase 5 provides visualization for Phases 1-4:

1. **Data Structures** (Phase 1 - 01-01): Arrays, structs ✅
2. **Volume Profile Engine** (Phase 1 - 01-01): 400-bin, POC/VAH/VAL, HVN/LVN ✅
3. **Signal Detection** (Phase 2 - 02-02): Setup 1 & 2 logic ✅
4. **Trade Execution** (Phase 2 - 02-03): Order placement, position tracking ✅
5. **Risk Management** (Phase 1-2): Position sizing, daily limits ✅
6. **Error Handling** (Phase 2 - 02-04): Logging, connectivity checks ✅
7. **Main Event Loop** (Phase 2 - 02-04): OnTick orchestration ✅
8. **Backtesting Validation** (Phase 3): Historical performance gates ✅
9. **Live Monitoring Dashboard** (Phase 5) — NEW: Real-time equity, P&L, metrics, per-symbol breakdown ✅

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-05-13 | Phase 1 & Phase 2 planning complete; 7 plans total ready for execution |
| 1.1 | 2026-05-13 | Phase 3 planning complete; 4 backtesting plans added (03-01 through 03-04) |
| 1.2 | 2026-05-13 | Phase 5 planning complete; 3 dashboard plans added (05-01 through 05-03); Phase 4 deferred pending Phase 3 execution |

---

*Roadmap updated: 2026-05-13*  
*Status: Phase 5 Planning Complete — 11 total plans ready for execution (Phases 1-3, 5)*
