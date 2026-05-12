# VWGTI-PRO-VP-EA: v1 MVP Roadmap

**Project:** MT5 Volume Profile Swing Trading Expert Advisor  
**Version:** 1.0 (Minimal Viable Product)  
**Last Updated:** 2026-05-13  
**Status:** Ready for Phase 1 Development

---

## Phases

- [ ] **Phase 1: Volume Profile Core** - Foundation volume profile engine + risk framework (XAUUSD/EURUSD ready to trade)
- [ ] **Phase 2: Signal Detection & Execution** - Setup 1 & 2 entry logic + execution + partial TP + logging (trading fully operational)
- [ ] **Phase 3: Backtesting & Validation** - 1-year backtest on both symbols; win rate/profit factor validation
- [ ] **Phase 4: Live Deployment & Monitoring** - Live account validation; 30 days zero-error operation

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

**Plans:** TBD

---

### Phase 2: Signal Detection & Execution

**Goal:** Both entry setups execute trades end-to-end with proper exit management; trader sees orders placed at correct prices, partial TPs execute in correct sequence, and Journal logs all activity.

**Depends on:** Phase 1 (requires volume profile + risk framework working)

**Requirements:** REQ-011 through REQ-028 (Setup 1 & 2 detection, entry/exit logic, partial TP), REQ-038 through REQ-042 (Logging, execution monitoring)

**Success Criteria** (what must be TRUE when this phase completes):
  1. Setup 1 (balanced market detection + confirmation candle closure inside VA) triggers entries on reclaims into Value Area
  2. Setup 2 (LVN sweep + HVN edge identification + trigger candle pattern + 1.3x volume spike) triggers entries at HVN cluster edges
  3. Partial TP structure executes (65% at first resistance, 35% at Value Area opposite extreme); position state tracked until both TPs hit or SL triggered
  4. Journal logs all trades: entry time/price/size, setup type (Setup 1 or 2), exit time/reason, realized P&L
  5. Order fills validated for slippage; trades rejected if fill price >50 pips from order price

**Plans:** TBD

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

**Plans:** TBD

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

**Plans:** TBD

---

## Progress Tracking

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Volume Profile Core | 0/7 | Not started | - |
| 2. Signal Detection & Execution | 0/8 | Not started | - |
| 3. Backtesting & Validation | 0/5 | Not started | - |
| 4. Live Deployment & Monitoring | 0/5 | Not started | - |

---

## Requirement Traceability

| Phase | Requirement IDs | Count | Coverage |
|-------|---|---|---|
| Phase 1 | REQ-001–010, REQ-029–037 | 17 | Volume Profile + Risk Framework |
| Phase 2 | REQ-011–028, REQ-038–042 | 20 | Signal Detection + Execution |
| Phase 3 | All 42 (backtest validation) | 42 | Historical performance validation |
| Phase 4 | All 42 (live validation) | 42 | Production stability validation |

**Total Coverage:** 42/42 requirements mapped (100%)

---

## Timeline & Dependencies

```
Phase 1 (3-4 weeks)
  ├─ Deliverable: Compiled EA with volume profile + risk limits
  ├─ Gate: Unit tests pass (profile accuracy ±0.1%, daily limits enforce)
  └─ Unblocks: Phase 2
  
Phase 2 (2-3 weeks)
  ├─ Deliverable: Entry/exit logic + full trade execution
  ├─ Gate: Integration tests pass (order flow end-to-end)
  └─ Unblocks: Phase 3
  
Phase 3 (2 weeks)
  ├─ Deliverable: 1-year backtest results
  ├─ Gate: Win rate ≥50%, PF ≥1.5, DD ≤2%
  └─ Unblocks: Phase 4
  
Phase 4 (4 weeks)
  ├─ Deliverable: 30 days live trading, zero errors
  ├─ Gate: Live metrics ≈ backtest ±20%
  └─ Completes: v1 MVP
  
Total: 10-11 weeks (5-6 weeks minimum with no rework)
```

---

## Architecture Alignment

Build sequence (from ARCHITECTURE.md):

1. **Data Structures** (Phase 1 - Part A): Arrays, structs for profiles/signals/positions
2. **Volume Profile Engine** (Phase 1 - Part B): 400-bin, POC/VAH/VAL, HVN/LVN detection
3. **Signal Detection** (Phase 2 - Part A): Setup 1 & 2 logic
4. **Trade Execution** (Phase 2 - Part B): CTrade order placement, magic #, partial TP
5. **Risk Management** (Phase 1 - Part C): Position sizing, daily limits, SL/TP placement
6. **Error Handling** (Phase 2 - Part C): Connectivity checks, slippage tolerance, logging
7. **Main Event Loop** (Phase 2 - Part D): OnTick orchestration, zero-lag bar-close trigger

Each phase delivers logically cohesive, unit-testable components that gate into the next phase.

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-05-13 | Initial roadmap; 4 phases, 42 requirements, 10-11 week timeline |

---

*Roadmap created: 2026-05-13*  
*Status: Ready for Phase 1 Planning*
