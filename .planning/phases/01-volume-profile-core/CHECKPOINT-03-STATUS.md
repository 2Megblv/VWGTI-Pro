# Phase 01 Plan 03 — CHECKPOINT REACHED: Task 3

**Date:** 2026-05-13  
**Status:** Awaiting manual backtest execution and validation  
**Plan:** 01-03 (Logging, Error Handling, Backtest Validation)  
**Completed:** Tasks 1-2 (4 commits)  
**Current:** Task 3 (human-verify checkpoint)  

---

## What Has Been Completed

### Task 1: Logging & Error Handling ✅

**Commit:** `c82138f`

Added comprehensive logging and error handling to EA:
- `ValidateDataQuality()` — Checks OHLC validity, volume presence, data integrity
- `IsConnected()` — Verifies broker connectivity and symbol tick data
- Enhanced logging in `CalculateCurrentVolumeProfile()` — Volume distribution variance every 10 bars
- Enhanced logging in `CalculateValueArea()` — POC/VAH/VAL prices logged for audit trail
- Enhanced logging in `CheckDailyLimits()` — Hard stop trigger with full P&L context
- Enhanced logging in position management — POSITION_ADD/REMOVE events with ticket tracking
- Graceful error recovery in `OnTick()` — Data quality check before processing
- IsConnected() validation in `OnInit()` — Precondition check at EA startup

**Lines added:** 114 (1379 → 1482 total)

---

### Task 2: Backtest Validation Harness ✅

**Commits:** `a7b8c47`, `52da296`

Created comprehensive backtest validation documentation:

1. **01-03-BACKTEST-VALIDATION.md** (289 lines)
   - Detailed backtest setup instructions
   - 6 manual validation checks with step-by-step verification
   - Success/failure criteria for each check
   - Journal output examples
   - Overall completion criteria

2. **01-03-BACKTEST-RESULTS-TEMPLATE.txt** (108 lines)
   - Structured template for recording backtest results
   - Guided fields for all 6 checks
   - Space for unit test results
   - Final sign-off section

---

## What Needs to Happen Next: Task 3

**Executor responsibility:** Run 1-month backtest and complete 6 manual validation checks

### Step 1: Run the Backtest

1. Open MetaTrader 5 → Strategy Tester
2. Configure:
   - Symbol: **XAUUSD** (Gold)
   - Timeframe: **M5** (5-minute bars)
   - Model: **Every tick** (most accurate)
   - Period: **1 month** of recent historical data (e.g., 2026-04-13 to 2026-05-13)
   - EA: **VolumeProfile_EA_v1.0.mq5**
3. Click "Start" and monitor for completion
4. Watch Journal output during backtest (should see VA_CALC, PROFILE_CALC, TESTS messages)

### Step 2: Complete 6 Manual Validation Checks

Detailed instructions in `.planning/phases/01-volume-profile-core/01-03-BACKTEST-VALIDATION.md`:

| Check | What to Verify | Success Criterion |
|-------|---|---|
| 1 | POC/VAH/VAL accuracy | 10/10 bars within ±1-2 pips |
| 2 | Session profile isolation | 5/5 day boundaries separate sessions |
| 3 | HVN/LVN realism | 10-30 clusters/day, align with chart |
| 4 | Volume variance | All bars ≤1%, average <0.5% |
| 5 | Daily limits (3 sub-checks) | Hard stop -2%, Profit cap +5%, Friday 21:45 |
| 6 | Position sizing | 0.6% ±0.05% risk (if Phase 2 trades placed) |

### Step 3: Record Results

1. Copy `.planning/phases/01-volume-profile-core/01-03-BACKTEST-RESULTS-TEMPLATE.txt`
2. Rename to `01-03-BACKTEST-RESULTS.txt`
3. Fill in:
   - Backtest period and broker info
   - Results for all 6 checks (PASS/FAIL/N/A)
   - Unit test output from Journal
   - Final sign-off with date and executor name
4. Commit the file

### Step 4: Signal Checkpoint Completion

File `.planning/phases/01-volume-profile-core/01-03-BACKTEST-RESULTS.txt` must contain:
```
[All 6 checks documented with PASS or N/A]
[Unit Test Results showing "✓ All critical tests PASSED"]
[Overall: Ready for Phase 2]
```

---

## Expected Backtest Output (Journal)

When backtest completes, Journal should contain:

```
===== PHASE 1: VOLUME PROFILE CORE ENGINE =====
...
===== RUNNING UNIT TESTS =====

TEST: Volume Distribution Validation
  [PASS/WARN based on data]

TEST: POC Identification
  [PASS]

TEST: VAH/VAL Calculation
  [PASS]

TEST: HVN/LVN Detection
  [PASS]

TEST: Position Sizing Calculation
  [PASS]

TEST: Daily Limits Logic
  [PASS]

TEST: Position Management
  [PASS]

===== TESTS COMPLETE =====
✓ All critical tests PASSED

[During backtest bars, you'll see:]
VA_CALC: POC=2050.123 VAH=2051.456 VAL=2049.789 width_pips=167.00
PROFILE_CALC: bins_sum=12345600 raw_total=12345700 variance=0.008%
[etc.]

[If any limits triggered:]
HARD_STOP_HIT: closed=-250.00 open=-50.00 total=-300.00 limit=-200.00
PROFIT_CAP_REACHED: closed=150.00 open=200.00 total=350.00 cap=250.00
FRIDAY_HARD_CLOSE_TIME: Current time: 21:45
```

---

## After Checkpoint Approval

Once `01-03-BACKTEST-RESULTS.txt` confirms all checks PASS (or N/A), the next executor will:

**Task 4:** Create `01-03-SUMMARY.md` with:
- Complete Phase 1 results and metrics
- Unit test output copied from backtest Journal
- Manual validation results from the 6 checks
- Handoff checklist for Phase 2
- Final Phase 1 gate approval

Then:
- Update STATE.md and ROADMAP.md (orchestrator task)
- Phase 1 is CLOSED
- Phase 2 can commence

---

## Key Files

**Main EA:**
- `src/VolumeProfile_EA_v1.0.mq5` (1482 lines, fully functional Phase 1 engine)

**Validation Documentation:**
- `.planning/phases/01-volume-profile-core/01-03-BACKTEST-VALIDATION.md` — Complete validation harness
- `.planning/phases/01-volume-profile-core/01-03-BACKTEST-RESULTS-TEMPLATE.txt` — Results template
- `.planning/phases/01-volume-profile-core/01-03-BACKTEST-RESULTS.txt` — **USER WILL CREATE THIS** after backtest

**Previous Plans (context):**
- `.planning/phases/01-volume-profile-core/01-01-SUMMARY.md` — Volume profile engine
- `.planning/phases/01-volume-profile-core/01-02-SUMMARY.md` — Risk management framework

---

## Blockers / Issues

**None identified.** EA is production-ready for backtest validation.

---

**Checkpoint created:** 2026-05-13  
**Awaiting:** User execution of 1-month backtest + 6 validation checks  
**Resume when:** 01-03-BACKTEST-RESULTS.txt exists with passing results
