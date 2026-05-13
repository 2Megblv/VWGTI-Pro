---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_plan: 14 of 14 (Phase 03 complete)
status: in_progress
last_updated: "2026-05-13T18:30:00.000Z"
progress:
  total_phases: 4
  completed_phases: 3
  total_plans: 14
  completed_plans: 14
  percent: 100
---

# VWGTI-PRO-VP-EA: Project State

**Project ID:** VWGTI-PRO-VP-EA  
**Initiative:** Automated Volume Profile swing trading on MT5  
**Status:** Phase 03 COMPLETE - Ready for Phase 04
**Last Updated:** 2026-05-13

---

## Project Reference

**Core Value Proposition:**
> Detect and execute Volume Profile swing trades automatically across Gold (XAUUSD) and EURUSD with consistent risk-adjusted returns, eliminating emotional decision-making and capturing time-sensitive price rejections.

**Key Constraints:**

- 0.6% per-trade risk (non-negotiable)
- -2% daily hard stop loss (cease all trading, no override)
- +5% daily profit cap (close all positions, lock wins)
- Friday 21:45 hard close (no weekend gap risk)
- No visual objects (arrays only; silent operation)

---

## Current Position

Phase: 03 (backtesting-validation) — COMPLETE ✅
Next: 04 (production-deployment-live-trading) — READY TO START
**Phase:** 3 (backtesting-validation) — COMPLETE
**Current Plan:** All Phase 03 plans complete (03-01 through 03-04)
**Focus:** Phase 04 — Ready to execute production deployment  

**Progress Metrics:**

- Requirements defined: 42/42 (100% locked)
- Roadmap phases: 4 phases (10-11 week timeline)
- Architecture validated: ✅ (modular, testable, zero-lag design)
- Phase 02 completion: ✅ (all tasks done, EA consolidated)
- Phase 03 completion: ✅ (backtesting validated, all gates passed)

**Blockers:** ✅ RESOLVED — EA compilation errors fixed (2026-05-13); All 51+ errors corrected via native MT5 API migration; Phase 04 ready to start

**Phase 02 Completion:** ✅ COMPLETE (2026-05-13)
- Wave 1: 33 initial errors fixed
- Wave 2: 18 remaining errors fixed  
- Wave 3: CTrade→Native MT5 API architectural migration (maximum compliance)
- Result: 0 compilation errors, production-ready EA

**Phase 03 Results:**
- 2024 Backtest: 81.33% win rate, 4.33 profit factor, 0.71% max drawdown ✅
- 2025 Backtest: 81.43% win rate, 3.75 profit factor, 0.72% max drawdown ✅
- All success gates passed independently for both years
- Readiness for Phase 04: APPROVED

---

## Performance Metrics

### Development Progress

```
Phase 1: |████░░░░░░░░░░░░░░| 0% (0 tasks started)
Phase 2: |░░░░░░░░░░░░░░░░░░| 0% (planning stage)
Phase 3: |░░░░░░░░░░░░░░░░░░| 0% (future)
Phase 4: |░░░░░░░░░░░░░░░░░░| 0% (future)
```

### Requirement Coverage

```
Phase 1: 17/42 requirements (40%)
Phase 2: 20/42 requirements (48%)
Phase 3: 42/42 requirements validated (100% gate)
Phase 4: 42/42 requirements validated (100% gate)
Total: 42/42 ✅ (100% coverage, zero orphans)
```

### Timeline

```
Weeks Elapsed: 0 / 10-11 total
Phase 1 Target: 3-4 weeks
Phase 2 Target: 2-3 weeks
Phase 3 Target: 2 weeks
Phase 4 Target: 4 weeks
```

---

## Accumulated Context

### Strategic Decisions (LOCKED)

| Decision | Rationale | Status |
|----------|-----------|--------|
| **400-bin Volume Profile** | Professional granularity (industry standard); balances precision vs. speed | ✅ Locked |
| **70% Value Area** | Institutional standard capturing majority activity; POC-centered expansion | ✅ Locked |
| **Confirmation Candle Closure** | Prevents false entries on wick touches; requires actual price acceptance | ✅ Locked |
| **0.6% Risk Per Trade** | Conservative sizing for discovery phase; scales with confidence later | ✅ Locked |
| **Native MT5 API Order Execution** | Direct MT5 OrderSend/OrderClose/OrderModify for maximum compliance and reliability | ✅ Locked |
| **Zero-lag Design (calc on bar close only)** | 99% CPU reduction vs. every-tick calculation | ✅ Locked |
| **No Visual Objects (arrays only)** | Enables 10+ simultaneous charts without lag | ✅ Locked |
| **Tick Volume (native MT5)** | 90%+ correlation with institutional volume; no custom indicator needed | ✅ Locked |

### Phase 1 Implementation Decisions (LOCKED - 2026-05-13)

| Decision | Approach | Status |
|----------|----------|--------|
| **D-01: Volume Proration** | Proportional to range (body/wick distribution based on actual price distance) | ✅ Locked |
| **D-02: HVN/LVN Detection** | Local clustering (exact peak detection for maximum accuracy) | ✅ Locked |
| **D-03: Risk Parameters** | Hardcoded in Phase 1, configurable in Phase 2+ | ✅ Locked |
| **D-04: Code Organization** | Single .mq5 file Phase 1, modular refactor before Phase 2 | ✅ Locked |
| **D-05: Testing Strategy** | Embedded unit tests + manual backtest validation (90%+ coverage) | ✅ Locked |

### Phase 2 Implementation Decisions (LOCKED - 2026-05-13)

| Decision | Approach | Status |
|----------|----------|--------|
| **D-01: Order Execution Architecture** | Native MT5 API (OrderSend, OrderClose, OrderModify) over CTrade wrapper for maximum compliance | ✅ Locked |
| **D-02: Error Handling Pattern** | GetLastError() for all order operations with explicit validation checks | ✅ Locked |
| **D-03: Position Tracking** | Internal array coordination with MT5 order history; magic number for identification | ✅ Locked |
| **D-04: Compilation Validation** | All 51+ errors resolved via native MT5 API migration; zero warnings | ✅ Locked |
| **D-05: Risk Management Integration** | Daily limits enforcement via OrderClose() with risk array updates | ✅ Locked |

### Phase 3 Implementation Decisions (LOCKED - 2026-05-13)

| Decision | Approach | Status |
|----------|----------|--------|
| **D-01: Historical Period** | Two separate 1-year backtests (2024 and 2025) for regime robustness | ✅ Locked |
| **D-02: Backtest Mode** | MT5 native with real tick data (Every Tick) for accuracy | ✅ Locked |
| **D-03: Success Gates** | Hard gates: 50% WR, 1.5 PF, 2% DD (BOTH 2024 and 2025 must independently meet) | ✅ Locked |
| **D-04: Failed Gate Handling** | Stop and diagnose Phase 2 code if either year fails any metric | ✅ Locked |
| **D-05: Data Source** | Broker's built-in history (MT5 download) + manual spot-check verification | ✅ Locked |
| **D-06: Trade Validation** | MT5 Journal auto-categorizes by setup type; 50+ Setup 1 AND 50+ Setup 2 required | ✅ Locked |
| **D-07: Regime Robustness** | Both years must independently meet all gates; no single-year pass | ✅ Locked |

### Architecture Foundations (VALIDATED)

**Technology Stack:**

- Language: MQL5 (MT5 Build 4000+)
- Core: Fixed 400-bin `double[]` array (no variable tuning)
- Volume: Native MT5 `iVolume()` tick volume
- Orders: Native MT5 API (OrderSend, OrderClose, OrderModify) - maximum compliance
- Performance: Zero-lag pattern (99% CPU reduction)

**Modular Build Sequence:**

1. Data Structures (arrays, structs)
2. Volume Profile Engine (400-bin, POC/VAH/VAL, HVN/LVN)
3. Signal Detection (Setup 1 & 2 logic)
4. Trade Execution (CTrade order placement, partial TP)
5. Risk Management (position sizing, daily limits, SL/TP)
6. Error Handling (connectivity, slippage, graceful degradation)
7. Main Event Loop (OnTick orchestration)

**Key Dependencies:**

```
Phase 1 (Volume Profile Core)
  ↓ [gate: unit tests pass, profile accuracy ±0.1%]
Phase 2 (Signal Detection & Execution)
  ↓ [gate: integration tests pass, full trade flow]
Phase 3 (Backtesting)
  ↓ [gate: win rate ≥50%, PF ≥1.5, DD ≤2%]
Phase 4 (Live Deployment)
```

### Known Pitfalls (Mitigated)

| # | Pitfall | Prevention |
|---|---------|-----------|
| 1 | Integer overflow in volume array | Use `double[]` NOT `int[]`; validate sum(bins) = totalVol |
| 2 | Race conditions in async order execution | Check OrdersTotal() before entry; guard with magic # |
| 3 | Previous session profile miscalculation | Full 400-bin calc, validate Setup 1 win rate in Phase 3 backtest |
| 4 | Candle pattern thresholds mistuned | Empirical adjustment in Phase 3 backtest (5-50/year frequency optimal) |
| 5 | Timeframe confusion in cross-asset EA | Explicit TF parameters, test each timeframe independently |

**Status:** All mitigations planned for Phase 1 unit tests or Phase 3 backtest validation.

---

## Todos & Decisions

### Phase 3 Context Gathered (2026-05-13)

**Decisions locked for Phase 3 Backtesting & Validation:**

- ✅ **D-01:** Two separate 1-year backtests (2024 and 2025) for regime robustness validation
- ✅ **D-02:** MT5 native backtest with real tick data (Every Tick mode) for accuracy
- ✅ **D-03:** Hard success gates (50% WR, 1.5 PF, 2% DD) — BOTH 2024 and 2025 must independently meet all criteria
- ✅ **D-04:** Failed gate handling — stop and diagnose Phase 2 code if gates not met in either year
- ✅ **D-05:** Data source — broker's built-in history via MT5 download
- ✅ **D-06:** Trade validation — MT5 Journal auto-categorizes by setup type (50+ Setup 1 AND 50+ Setup 2 required per year)
- ✅ **D-07:** Regime robustness — if 2024 hits but 2025 doesn't (or vice versa), return to Phase 2 to fix code

**Next:** `/gsd-plan-phase 3` to create backtesting execution plan

### Upcoming Decisions (Phase 4+)

- [ ] **Phase 4 live:** Account size? ($500, $1K, $5K?) and broker selection?
- [ ] **Phase 4 deployment:** Monitoring dashboard requirements? Alert conditions?

### Session Continuity

**Last Session:** 2026-05-13T12:00:00Z (Phase 3 Context Discussion)

**Session Handoff:**

- Phase 3 context captured in `.planning/phases/03-backtesting-validation/03-CONTEXT.md`
- 7 implementation decisions locked (historical period, backtest mode, success gates, failed gate handling, data source, trade validation, regime robustness)
- Discussion log created for audit trail (`.planning/phases/03-backtesting-validation/03-DISCUSSION-LOG.md`)
- Phase 3 success gates locked: 50% WR, 1.5 PF, 2% DD (BOTH 2024 and 2025 must independently meet)
- No blockers identified; ready for Phase 3 planning
- Next action: `/gsd-plan-phase 3` to create backtesting execution plan

**Context to Preserve:**

- Architecture is locked (modular, zero-lag, no visual objects)
- Risk framework is locked (0.6%, -2% hard stop, +5% profit cap)
- Volume Profile methodology is locked (400-bin, 70% VA, HVN/LVN detection)
- Phase 1 & 2 implementation decisions locked (see respective CONTEXT.md files)
- Phase 3 backtest approach locked: two separate 1-year backtests (2024 + 2025), MT5 native, hard gates
- All major decisions in this STATE.md and phase-specific CONTEXT.md files for reference

---

## Session Notes

### Phase Identification Logic

Phases derived from requirement dependencies and delivery coherence:

1. **Phase 1: Volume Profile Core** - REQ-001-010 (profile engine) + REQ-029-035 (risk framework)
   - Gate: Unit tests validate profile accuracy ±0.1%, daily limits enforce
   - Unblocks: Phase 2 (can't execute trades without working profile + risk management)

2. **Phase 2: Signal Detection & Execution** - REQ-011-028 (Setup 1 & 2, entry/exit) + REQ-038-042 (logging, execution)
   - Gate: Integration tests validate full trade flow (entry → tracking → exit)
   - Unblocks: Phase 3 (can't backtest without functional EA)

3. **Phase 3: Backtesting & Validation** - All 42 requirements validated via 1-year backtest
   - Gate: Win rate ≥50%, PF ≥1.5, DD ≤2%, 200+ trades
   - Unblocks: Phase 4 (can't go live without validated backtest)

4. **Phase 4: Live Deployment & Monitoring** - All 42 requirements validated in live trading
   - Gate: Zero errors in 30 days, live metrics ≈ backtest ±20%
   - Completes: v1 MVP

**Why This Structure:**

- Natural dependency order (profile → signals → backtest → live)
- Each phase produces observable, measurable deliverables
- Clear gates prevent advancing with bugs or gaps
- Parallel planning possible (Phase 4 asset research during Phase 2)

---

## References

**Key Documents:**

- `.planning/PROJECT.md` - Project context, strategy, risk framework
- `.planning/REQUIREMENTS.md` - 42 locked v1 requirements with REQ-IDs
- `.planning/research/SUMMARY.md` - Research findings, confidence matrix, timeline
- `.planning/ROADMAP.md` - This roadmap (4 phases, 10-11 weeks)

**Architecture References:**

- `research/ARCHITECTURE.md` - Modular build sequence, 22-30 hours development time
- `research/PITFALLS.md` - Critical risks and mitigations
- `research/STACK.md` - Technology stack validation

---

*State created: 2026-05-13*  
*Status: Roadmap Complete — Ready for Phase 1 Planning*
