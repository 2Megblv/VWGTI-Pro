# VWGTI-PRO-VP-EA: v1 MVP Requirements

**Project:** MT5 Volume Profile Swing Trading Expert Advisor  
**Version:** 1.0 (Minimal Viable Product)  
**Status:** ✅ LOCKED (2026-05-13)  
**Assets:** Gold (XAUUSD) + EURUSD  
**Timeframes:** 5M setup, 1M confirmation  
**Risk Framework:** 0.6% per trade, -2% daily hard stop, +5% daily profit cap, Friday 21:45 close

---

## Requirements by Category

### VOLUME PROFILE CALCULATION (10 requirements)

| REQ-ID | Requirement | Description | Validation |
|--------|-------------|-------------|-----------|
| **REQ-001** | 400-bin distribution | Calculate price volume distribution across 400 discrete price levels from 150-bar lookback period | Unit test: sum(bins) = total volume ±0.1% |
| **REQ-002** | POC identification | Identify Point of Control as single price level with highest accumulated volume | Unit test: POC price within 1 pip of manual chart |
| **REQ-003** | VAH calculation | Calculate Value Area High as upper bound of 70% cumulative volume expanding from POC | Unit test: VAH = POC + expansion, 70% ≤ vol ≤ 75% |
| **REQ-004** | VAL calculation | Calculate Value Area Low as lower bound of 70% cumulative volume expanding from POC | Unit test: VAL = POC - expansion, 70% ≤ vol ≤ 75% |
| **REQ-005** | HVN detection | Identify High Volume Nodes as local volume peaks > 85th percentile of distribution | Unit test: HVN detection on injected data |
| **REQ-006** | LVN detection | Identify Low Volume Nodes as local volume valleys < 25th percentile of distribution | Unit test: LVN detection on injected data |
| **REQ-007** | Session profile isolation | Store previous session's volume profile separately from current session profile | Code review: two distinct profile arrays |
| **REQ-008** | Multi-level proration | Distribute candle volume proportionally when candle spans multiple price levels (body 60%, wicks 40%) | Unit test: multi-level candle distribution |
| **REQ-009** | Volume validation | Validate volume distribution integrity (sum of all bins ≈ total accumulated volume) | Backtest: every bar validate sum = total |
| **REQ-010** | Tick volume support | Use MT5 native Tick Volume (`iVolume()`) for Forex/CFD pairs (Gold, EURUSD) | Integration test: `iVolume()` returns expected values |

### SETUP 1: 80% RULE MEAN REVERSION (6 requirements)

| REQ-ID | Requirement | Description | Validation |
|--------|-------------|-------------|-----------|
| **REQ-011** | Balanced market detection | Detect balanced/consolidating market state when Value Area width < 0.5x average recent range | Unit test: VA width / ATR ratio calculation |
| **REQ-012** | Gap detection | Identify price opening outside previous session's Value Area boundaries | Backtest: manual inspection of 5 gap scenarios |
| **REQ-013** | Reclaim detection | Identify price reclaiming into Value Area after opening outside boundaries | Backtest: confirm reclaim signals on 10 random bars |
| **REQ-014** | Confirmation candle | Validate confirmation candle closure inside Value Area (not wick touch) | Backtest: compare wick-only vs. closure-only win rates |
| **REQ-015** | LONG entry execution | Execute BUY entry after confirmation candle closes inside VA | Integration test: entry at correct price + volume |
| **REQ-016** | SHORT entry execution | Execute SELL entry after confirmation candle closes inside VA | Integration test: entry at correct price + volume |

### SETUP 2: HVN EDGE MOMENTUM (7 requirements)

| REQ-ID | Requirement | Description | Validation |
|--------|-------------|-------------|-----------|
| **REQ-017** | LVN sweep detection | Identify price sweeping into Low Volume Node (liquidity vacuum) | Backtest: LVN sweep on 5 example bars |
| **REQ-018** | HVN edge identification | Identify price proximity to HVN (High Volume Node cluster edge) | Unit test: distance-to-HVN calculation |
| **REQ-019** | Trigger pattern recognition | Recognize candle patterns: Hammer (long), Shooting Star (short), Doji (both) | Unit test: pattern detection on sample candles |
| **REQ-020** | Volume spike confirmation | Validate trigger candle volume ≥ 1.3x previous candle volume (30% minimum increase) | Unit test: volume ratio calculation (1.3x threshold) |
| **REQ-021** | Closed candle requirement | Require full candle closure before entry execution (no front-running on open) | Code review: entry on Close[1] not Close[0] |
| **REQ-022** | LONG HVN entry | Execute BUY at HVN edge after trigger candle closes with volume confirmation | Integration test: entry at HVN price level |
| **REQ-023** | SHORT HVN entry | Execute SELL at HVN edge after trigger candle closes with volume confirmation | Integration test: entry at HVN price level |

### EXIT & POSITION MANAGEMENT (5 requirements)

| REQ-ID | Requirement | Description | Validation |
|--------|-------------|-------------|-----------|
| **REQ-024** | Partial TP (65%) | Close 65% of position at first identified resistance level (within 20-50 pips of entry) | Backtest: partial TP execution on 10 trades |
| **REQ-025** | Remainder TP (35%) | Close remaining 35% of position at Value Area opposite extreme (VAH for LONG, VAL for SHORT) | Backtest: remainder TP execution on 10 trades |
| **REQ-026** | SL placement | Place stop loss BELOW sweep low, NOT at VAL (prevents whipsaw stops during liquidity grabs) | Backtest: SL placement 5-15 pips below sweep |
| **REQ-027** | Partial execution tracking | Track partial TP execution separately; maintain position state until both TPs hit or SL triggered | Code review: position state machine |
| **REQ-028** | Risk/Reward calculation | Calculate R:R ratio for every trade (risk vs. target reward distance) | Backtest: R:R logged for every trade |

### POSITION SIZING & RISK MANAGEMENT (7 requirements)

| REQ-ID | Requirement | Description | Validation |
|--------|-------------|-------------|-----------|
| **REQ-029** | Risk-based sizing | Calculate lot size: (Account Balance × 0.6%) / (SL distance × Point value) | Unit test: lot size formula on sample inputs |
| **REQ-030** | Fixed lot alternative | Support fixed lot size (e.g., 0.1 per trade) as alternative to risk percentage | Code review: input toggle for sizing method |
| **REQ-031** | Max 1 position per asset | Enforce maximum 1 open position per asset class (Gold OR EURUSD, not both simultaneous) | Backtest: no overlapping positions on same asset |
| **REQ-032** | Daily hard stop loss | Enforce -2% account loss limit; cease ALL trading immediately when breached (non-negotiable) | Backtest: daily loss limit enforcement |
| **REQ-033** | Daily profit cap | Enforce +5% account gain limit; close ALL open positions when reached (lock daily wins) | Backtest: daily profit cap enforcement |
| **REQ-034** | Friday hard close | Force close all open positions Friday 21:45 broker server time (no weekend gap risk) | Integration test: time-based close execution |
| **REQ-035** | Drawdown tracking | Track cumulative daily loss and enforce daily limits with non-override logic | Code review: drawdown persistence + audit trail |

### EXECUTION & MONITORING (7 requirements)

| REQ-ID | Requirement | Description | Validation |
|--------|-------------|-------------|-----------|
| **REQ-036** | Gold XAUUSD support | Support trading Gold on 5M/1M timeframes | Backtest: Gold symbol initialized correctly |
| **REQ-037** | EURUSD support | Support trading EURUSD on 5M/1M timeframes | Backtest: EURUSD symbol initialized correctly |
| **REQ-038** | Journal logging | Log all trades to MT5 Journal: entry time, price, size, setup type, exit time, P&L | Backtest: sample journal output reviewed |
| **REQ-039** | Slippage tolerance | Accept order fills within 50-point slippage tolerance; reject beyond threshold | Integration test: order fill validation |
| **REQ-040** | Broker connectivity | Validate broker connection before order execution; skip trade if disconnected | Code review: IsConnected() check before OrderSend() |
| **REQ-041** | Error recovery | Implement graceful degradation (skip trade) vs. system crash on errors | Code review: try-catch + error logging |
| **REQ-042** | Metrics calculation | Calculate and display: win rate %, profit factor, max daily drawdown, P&L | Backtest: metrics accuracy on sample trades |

---

## Requirement Traceability to Roadmap (2026-05-13)

### Phase Mappings

| REQ-ID | Requirement | Phase | Status |
|--------|-------------|-------|--------|
| REQ-001 | 400-bin distribution | Phase 1 | Pending |
| REQ-002 | POC identification | Phase 1 | Pending |
| REQ-003 | VAH calculation | Phase 1 | Pending |
| REQ-004 | VAL calculation | Phase 1 | Pending |
| REQ-005 | HVN detection | Phase 1 | Pending |
| REQ-006 | LVN detection | Phase 1 | Pending |
| REQ-007 | Session profile isolation | Phase 1 | Pending |
| REQ-008 | Multi-level proration | Phase 1 | Pending |
| REQ-009 | Volume validation | Phase 1 | Pending |
| REQ-010 | Tick volume support | Phase 1 | Pending |
| REQ-011 | Balanced market detection | Phase 2 | Pending |
| REQ-012 | Gap detection | Phase 2 | Pending |
| REQ-013 | Reclaim detection | Phase 2 | Pending |
| REQ-014 | Confirmation candle | Phase 2 | Pending |
| REQ-015 | LONG entry execution | Phase 2 | Pending |
| REQ-016 | SHORT entry execution | Phase 2 | Pending |
| REQ-017 | LVN sweep detection | Phase 2 | Pending |
| REQ-018 | HVN edge identification | Phase 2 | Pending |
| REQ-019 | Trigger pattern recognition | Phase 2 | Pending |
| REQ-020 | Volume spike confirmation | Phase 2 | Pending |
| REQ-021 | Closed candle requirement | Phase 2 | Pending |
| REQ-022 | LONG HVN entry | Phase 2 | Pending |
| REQ-023 | SHORT HVN entry | Phase 2 | Pending |
| REQ-024 | Partial TP (65%) | Phase 2 | Pending |
| REQ-025 | Remainder TP (35%) | Phase 2 | Pending |
| REQ-026 | SL placement | Phase 2 | Pending |
| REQ-027 | Partial execution tracking | Phase 2 | Pending |
| REQ-028 | Risk/Reward calculation | Phase 2 | Pending |
| REQ-029 | Risk-based sizing | Phase 1 | Pending |
| REQ-030 | Fixed lot alternative | Phase 1 | Pending |
| REQ-031 | Max 1 position per asset | Phase 1 | Pending |
| REQ-032 | Daily hard stop loss | Phase 1 | Pending |
| REQ-033 | Daily profit cap | Phase 1 | Pending |
| REQ-034 | Friday hard close | Phase 1 | Pending |
| REQ-035 | Drawdown tracking | Phase 1 | Pending |
| REQ-036 | Gold XAUUSD support | Phase 1 | Pending |
| REQ-037 | EURUSD support | Phase 1 | Pending |
| REQ-038 | Journal logging | Phase 2 | Pending |
| REQ-039 | Slippage tolerance | Phase 2 | Pending |
| REQ-040 | Broker connectivity | Phase 2 | Pending |
| REQ-041 | Error recovery | Phase 2 | Pending |
| REQ-042 | Metrics calculation | Phase 2 | Pending |

**Coverage Summary:**
- Phase 1: 17 requirements (Profile engine + Risk framework)
- Phase 2: 20 requirements (Signal detection + Execution + Logging)
- Phase 3: 42 requirements (Backtest validation)
- Phase 4: 42 requirements (Live deployment validation)
- **Total Mapped: 42/42 (100%)**

---

## V2+ Deferred Requirements (Explicitly Out of Scope)

| Requirement | Why Deferred | Target Phase |
|-------------|-------------|--------------|
| Multi-timeframe confirmation (1H/4H alignment) | Adds complexity; validate single-TF first | Phase 2 enhancement |
| Adaptive strategy selection (auto balanced/imbalanced) | Requires live data; validate hardcoded rules first | Phase 2 enhancement |
| News event filtering | Not in scope for MVP; adds external dependency | Phase 3 enhancement |
| Performance dashboard | No trader-facing UI needed; Journal logging sufficient | Phase 3 |
| Backtesting framework | Manual backtest sufficient for v1; built-in framework v2+ | Phase 4 |
| Multi-asset expansion (Oil, GBPJPY, DAX, Nasdaq) | Requires v1 validation on Gold/EURUSD first | Phase 4 |
| Parameter optimization | Fixes 400-bin, 70% VA, 1.3x threshold; no tuning in v1 | Phase 4+ |

---

## Anti-Requirements (Explicitly NOT Building)

| What NOT to Build | Why | Consequence if Attempted |
|------------------|-----|------------------------|
| Visual chart objects (VAL/VAH lines, POC markers) | CPU overhead; breaks multi-chart silent operation | Performance degradation at 5+ charts |
| Custom Volume Profile indicator (separate file) | Unnecessary; calculations embedded in EA | Maintenance burden, duplication |
| Trailing stops | Out of scope; partial TP structure sufficient | Feature creep, complexity |
| Grid trading / martingale | Violates 0.6% risk discipline | Account blowup risk |
| ML/black-box optimization | Violates deterministic rules philosophy | Unexplainable signals |
| Unlimited position stacking | Conflicts with risk management (max 1/asset) | Uncontrolled risk exposure |

---

## Success Criteria for v1 MVP

**Functional Acceptance:**
- ✅ EA compiles without errors on MT5 Build 4000+
- ✅ All 42 requirements implemented and unit-tested
- ✅ No visual objects (arrays only)
- ✅ Journal logging functional and auditable

**Performance Acceptance (Phase 2 Backtest):**
- ✅ Win rate ≥ 50% (both Setup 1 and Setup 2 combined)
- ✅ Profit Factor ≥ 1.5 (total profit / total loss)
- ✅ Maximum daily drawdown ≤ 2% (enforced by daily hard stop)
- ✅ 200+ trades on 1-year backtest (both XAUUSD + EURUSD combined)
- ✅ Backtest P&L vs. live performance within ±20% (validation gate)

**Operational Acceptance (Phase 3 Live):**
- ✅ All trades execute within 50-point slippage tolerance
- ✅ Daily hard stops enforced on live account (no override)
- ✅ Zero system errors in 30 days of continuous operation
- ✅ Live win rate within ±20% of backtest results

---

## Requirement Status Tracking

| Status | Count | Details |
|--------|-------|---------|
| **LOCKED** | 42 | All v1 MVP requirements finalized and approved |
| **DEFERRED** | 7 | V2+ features (multi-TF, news filtering, dashboard, etc.) |
| **OUT OF SCOPE** | 6 | Anti-requirements (visualization, ML, grid trading, etc.) |
| **TOTAL SCOPE** | 55 | 42 locked + 7 deferred + 6 explicitly excluded |

---

*Requirements locked: 2026-05-13*  
*Traceability added: 2026-05-13*  
*Status: Ready for Phase 1 Development*
