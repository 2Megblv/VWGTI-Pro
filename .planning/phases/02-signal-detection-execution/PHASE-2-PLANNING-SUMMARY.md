# Phase 2: Signal Detection & Execution - Planning Complete

**Phase:** 02-signal-detection-execution  
**Status:** Planning complete, 4 executable plans created  
**Created:** 2026-05-13  
**Plans:** 4 (5 waves total)

---

## Overview

Phase 2 implements complete end-to-end trade execution for both entry setups (Setup 1: 80% Rule Mean Reversion, Setup 2: HVN Edge Momentum) with multi-timeframe context (15M profile for direction bias), session filtering (grave hour + pre-Tokyo avoidance), liquidity validation, order placement with slippage protection, position state tracking, daily risk limits enforcement, complete journal logging, and reversal exit logic enabling position flips.

**Output:** 4 executable plans across 5 waves (Wave 0–3) decomposing all 20 Phase 2 requirements into modular, testable tasks.

---

## Requirements Coverage

**Total Requirements:** 20/20 ✅ (100% coverage)

### Setup 1 & 2 Detection (REQ-011–023)
- **REQ-011:** Balanced market detection (VA width < 0.6x recent range) — Wave 1, Task 1
- **REQ-012:** Gap detection (price opens outside previous VA) — Wave 1, Task 2
- **REQ-013:** Reclaim detection (price reclaims back into VA) — Wave 1, Task 2
- **REQ-014:** Confirmation candle (close fully inside VA, not wick touch) — Wave 1, Task 2
- **REQ-015:** LONG entry execution (Setup 1) — Wave 2, Task 1
- **REQ-016:** SHORT entry execution (Setup 1) — Wave 2, Task 1
- **REQ-017:** LVN sweep detection (price sweeps into low volume node) — Wave 1, Task 3
- **REQ-018:** HVN edge identification (price proximity to high volume node) — Wave 1, Task 3
- **REQ-019:** Trigger pattern recognition (Hammer, Shooting Star, Doji) — Wave 1, Task 3
- **REQ-020:** Volume spike confirmation (≥1.3x previous bar) — Wave 1, Task 3
- **REQ-021:** Closed candle requirement (full closure before entry) — Wave 1, Task 3
- **REQ-022:** LONG HVN entry (Setup 2) — Wave 2, Task 1
- **REQ-023:** SHORT HVN entry (Setup 2) — Wave 2, Task 1

### Exit & Position Management (REQ-024–028)
- **REQ-024:** Partial TP (65%) — Removed per D-03 (single unified TP instead)
- **REQ-025:** Remainder TP (35%) — Removed per D-03 (single unified TP instead)
- **REQ-026:** SL placement (below sweep low, not at VAL) — Wave 2, Task 1
- **REQ-027:** Partial execution tracking (position state machine with remaining lots) — Wave 2, Task 2
- **REQ-028:** Risk/Reward calculation (logged for every trade) — Wave 2, Task 4

### Risk Management & Execution (REQ-032–042, REQ-029–031 from Phase 1)
- **REQ-029:** Risk-based sizing (0.6% per trade) — Wave 0, extracted from Phase 1
- **REQ-030:** Fixed lot alternative — Wave 0, extracted from Phase 1
- **REQ-031:** Max 1 position per asset — Wave 0, inherited from Phase 1
- **REQ-032:** Daily hard stop loss (-2%) — Wave 3, Task 1
- **REQ-033:** Daily profit cap (+5%) — Wave 3, Task 1
- **REQ-034:** Friday hard close (21:45) — Wave 3, Task 2
- **REQ-035:** Drawdown tracking — Wave 0, extracted from Phase 1
- **REQ-036:** Gold XAUUSD support — All waves
- **REQ-037:** EURUSD support — All waves
- **REQ-038:** Journal logging (full audit trail) — Wave 3, Task 3
- **REQ-039:** Slippage tolerance (50-pip rejection) — Wave 2, Task 1
- **REQ-040:** Broker connectivity (IsConnected check) — Wave 0/3, Tasks throughout
- **REQ-041:** Error recovery (graceful degradation) — Wave 3, Task 3
- **REQ-042:** Metrics calculation (win rate, profit factor, max DD) — Wave 3, Task 3

---

## Plan Structure

### Wave 0: Code Refactoring (Plan 02-01)
**Objective:** Extract Phase 1 monolithic EA code into 3 modular header files (VolumeProfile.mqh, RiskManager.mqh, Utils.mqh) to enable clean Phase 2 signal detection layer.

**Tasks:**
1. Extract VolumeProfile.mqh (profile calculation engine)
2. Extract RiskManager.mqh (position sizing, daily limits, Friday close)
3. Extract Utils.mqh (constants, utility functions)
4. Refactor main EA file (orchestration via #include)
5. Unit test refactored code (verify Phase 1 functionality replicated)

**Output:** Modular code structure, no duplicate logic, Phase 1 functionality verified identical.

---

### Wave 1: Signal Detection (Plan 02-02)
**Objective:** Implement Setup 1 (gap/reclaim/confirmation) and Setup 2 (LVN/HVN/pattern/volume) signal detection with multi-timeframe context (15M profile for direction bias), session filtering (grave hour + pre-Tokyo), and liquidity validation.

**Tasks:**
1. Balanced market detection (VA width threshold)
2. Setup 1 signal detection (gap/reclaim/confirmation)
3. Setup 2 signal detection (LVN/HVN/pattern/volume)
4. 15M multi-timeframe context loading (direction bias validation)
5. Session filtering + liquidity validation (grave hour, pre-Tokyo, spread/volume checks)

**Output:** SignalDetection.mqh and MultiTimeframeContext.mqh, both integrated into OnTick with proper context switching and risk checks before signal processing.

---

### Wave 2: Order Execution (Plan 02-03)
**Objective:** Implement CTrade market order placement with post-execution slippage validation, position state tracking via remaining lots method, and TP/SL exit detection.

**Tasks:**
1. CTrade order placement with slippage validation (50-pip tolerance, reject > 50 pips)
2. Position state machine (remaining lots tracking, add/remove/update)
3. Position monitoring and TP/SL exit logic (every tick, immediate closure)
4. Risk/Reward ratio calculation (logged with entry)
5. Unit test order execution and position management

**Output:** TradeExecution.mqh with complete order flow, position state tracking, and exit logic. Main EA orchestrates order placement on signal trigger and position monitoring every tick.

---

### Wave 3: Risk Control & Logging (Plan 02-04)
**Objective:** Enforce daily risk limits (hard stop -2%, profit cap +5%, Friday 21:45 close), implement complete journal logging for audit trail, and add reversal detection + position flip logic.

**Tasks:**
1. Daily hard stop (-2%) and profit cap (+5%) enforcement
2. Friday hard close (21:45) execution
3. Journal logging (entry, exit, rejection, alert, error details)
4. Reversal exit & position flip logic (5M + 1M confirmation)
5. Unit test risk limits, logging, and reversal logic
6. Integration test full trade cycle (end-to-end verification)

**Output:** RiskLimits.mqh, JournalLogger.mqh, ReversalExit.mqh enabling complete risk enforcement, audit logging, and reversal trading. Phase 2 fully operational.

---

## Key Architectural Changes (vs. Previous Phase)

### Multi-Timeframe Context (D-14)
- 15M profile loaded every 15M bar close
- Direction bias validation before entry (prevent counter-trend trades)
- 50-pip conservative buffer applied to 15M VAL/VAH

### Session Filtering (D-14)
- Grave Hour Block: NY 16:00–17:00 (low liquidity, high volatility)
- Pre-Tokyo Block: Sun 23:00 – Mon 00:00 NY time (minimal liquidity)

### Liquidity Validation (D-14)
- Spread checks: ≤3 pips Gold (XAUUSD), ≤5 pips EURUSD
- Tick volume: ≥10 (minimum liquidity threshold)

### Reversal Exit Logic (D-15)
- 5M reversal candle detection (lower high for LONG, higher low for SHORT)
- 1M confirmation required (break of recent structure)
- Position flip execution: close current + enter opposite direction
- New position subject to same SL/TP logic

### TP Structure Clarification
- Single unified edge-to-edge TP (VAH for LONG, VAL for SHORT)
- NO partial TP exits at PoC (removed from original requirements)
- Full position rides to TP; no split targeting

---

## Dependency Graph

```
Wave 0 (Refactoring)
  └─→ VolumeProfile.mqh, RiskManager.mqh, Utils.mqh
  
Wave 1 (Signal Detection) — depends on Wave 0
  ├─→ SignalDetection.mqh (Setup 1 & 2)
  ├─→ MultiTimeframeContext.mqh (15M + session + liquidity)
  └─→ Integration into main EA OnTick

Wave 2 (Order Execution) — depends on Wave 1
  ├─→ TradeExecution.mqh (order placement, slippage, position state)
  └─→ Integration into main EA (order placement, position monitoring)

Wave 3 (Risk & Logging) — depends on Wave 2
  ├─→ RiskLimits.mqh (hard stop, profit cap, Friday close)
  ├─→ JournalLogger.mqh (complete audit trail)
  ├─→ ReversalExit.mqh (reversal detection + flip)
  └─→ Integration into main EA (comprehensive orchestration)
```

---

## File Modifications Summary

### Phase 2 Plan Files
- `.planning/phases/02-signal-detection-execution/02-01-PLAN.md` — Wave 0 refactoring
- `.planning/phases/02-signal-detection-execution/02-02-PLAN.md` — Wave 1 signal detection
- `.planning/phases/02-signal-detection-execution/02-03-PLAN.md` — Wave 2 order execution
- `.planning/phases/02-signal-detection-execution/02-04-PLAN.md` — Wave 3 risk & logging

### Phase 2 Source Code (to be created during execution)
- `src/Include/VolumeProfile.mqh` — Extracted from Phase 1
- `src/Include/RiskManager.mqh` — Extracted from Phase 1
- `src/Include/Utils.mqh` — Constants and utilities
- `src/Include/SignalDetection.mqh` — Setup 1 & 2 detection (NEW)
- `src/Include/MultiTimeframeContext.mqh` — 15M context + session + liquidity (NEW)
- `src/Include/TradeExecution.mqh` — Order placement + position state (NEW)
- `src/Include/RiskLimits.mqh` — Daily limits + Friday close (NEW)
- `src/Include/JournalLogger.mqh` — Complete logging (NEW)
- `src/Include/ReversalExit.mqh` — Reversal detection + flip (NEW)
- `src/VolumeProfile_EA_v1.0.mq5` — Main EA refactored (MODIFIED)
- `src/tests/test_*.mq5` — Unit and integration tests (NEW)

---

## Quality Gates

### Wave 0 Gate (Refactoring)
✅ All Phase 1 functions extracted to modules
✅ Main EA compiles and imports all headers cleanly
✅ Phase 1 functionality replicated exactly (±1 pip tolerance)
✅ Unit tests pass

### Wave 1 Gate (Signal Detection)
✅ Setup 1 & 2 signals trigger correctly on test data
✅ 15M profile loads every 15M bar close
✅ Session filtering blocks grave hour and pre-Tokyo
✅ Liquidity validation enforces spread and volume limits
✅ Unit tests pass

### Wave 2 Gate (Order Execution)
✅ Orders place via CTrade successfully
✅ Slippage validation rejects fills >50 pips
✅ Position state tracking working (remaining lots)
✅ TP/SL detection and closure working
✅ Risk/Reward calculation accurate
✅ Unit tests pass

### Wave 3 Gate (Risk & Logging)
✅ Hard stop (-2%) enforces and halts trading
✅ Profit cap (+5%) closes and adjusts SL
✅ Friday 21:45 hard close executes
✅ Journal logging captures all trade details
✅ Reversal detection and flip logic working
✅ Integration test passes (end-to-end)
✅ Phase 2 fully operational

---

## Execution Timeline

| Wave | Plan | Tasks | Estimate |
|------|------|-------|----------|
| 0 | 02-01 | 5 tasks | ~4–6 hours |
| 1 | 02-02 | 6 tasks | ~8–10 hours |
| 2 | 02-03 | 5 tasks | ~6–8 hours |
| 3 | 02-04 | 6 tasks | ~8–10 hours |
| **Total Phase 2** | **4 plans** | **22 tasks** | **~26–34 hours** |

---

## Risk Assessment

### Technical Risks
- **Multi-timeframe data sync:** 15M profile must load exactly on 15M bar close. Mitigation: explicit NewBar check on PERIOD_M15.
- **Session time conversion:** Grave hour and pre-Tokyo blocks depend on broker server time accuracy. Mitigation: hard-code broker's specific timezone after user confirmation.
- **Reversal false positives:** 5M candle pattern could be noise. Mitigation: require 1M confirmation + matching Setup signal before flip.

### Operational Risks
- **Order execution latency:** Slippage >50 pips causes fill rejection. Mitigation: post-execution validation catches bad fills; close immediately.
- **Daily P&L persistence:** OrdersHistoryTotal rescan every tick could miss trades if broker purges history. Mitigation: test on live account with month-old trades before deployment.

---

## Next Steps

After Phase 2 planning is complete:

1. **Execute Wave 0–3 in sequence** — Each wave depends on previous
2. **Run unit tests for each wave** — Verify quality gates pass
3. **Run integration test** — Validate end-to-end trade flow
4. **Deploy Phase 2 EA to test account** — Live validation on demo
5. **Proceed to Phase 3 (Backtesting & Validation)** — 1-year backtest on both symbols

---

## Sign-Off

**Phase:** 02-signal-detection-execution  
**Plans Created:** 4 ✅  
**Requirements Mapped:** 20/20 ✅  
**Status:** Ready for execution  
**Planning Date:** 2026-05-13

**Next Command:** `/gsd-execute-phase 02` to execute Wave 0–3 in sequence

---

*Phase 2 Planning Document*  
*VWGTI-PRO-VP-EA v1.0 MVP Project*
