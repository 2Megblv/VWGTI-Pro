# Phase 1 Manual Backtest Validation Harness

**Purpose:** Document the 6 manual checks required to validate Phase 1 EA functionality before Phase 2 begins.

**Executor:** Run this validation after the 1-month backtest completes. This document guides systematic verification of all 9 success criteria.

---

## Backtest Setup Instructions

1. **Open MetaTrader 5 → Strategy Tester**
2. **Symbol:** XAUUSD (Gold)
3. **Timeframe:** M5 (5-minute bars)
4. **Model:** Every tick (most accurate)
5. **Period:** 1 month of recent historical data (e.g., 2025-04-13 to 2025-05-13)
6. **EA:** VolumeProfile_EA_v1.0.mq5
7. **Click "Start"** to run backtest
8. **After completion:** Review Journal output for all 6 checks below

---

## CHECK 1: Profile Accuracy (POC/VAH/VAL ±1-2 pips)

**Verification Steps:**

1. In Journal output, search for lines starting with `VA_CALC:` (logged every bar)
2. Select 10 random bars spread across the month (e.g., every ~2000 bars = every ~1 week)
3. For each bar, note the timestamps and POC/VAH/VAL prices from Journal
4. Open MT5 chart (XAUUSD M5, same date/time as each backtest bar)
5. Manually identify highest-volume price level on chart (should match POC within ±1 pip)
6. Manually identify 70% value area boundaries (should match VAH/VAL within ±1-2 pips)
7. Compare Journal values to manual chart inspection

**Success Criteria:**

- [ ] POC matches chart within ±1 pip on all 10/10 bars
- [ ] VAH matches chart within ±1-2 pips on all 10/10 bars
- [ ] VAL matches chart within ±1-2 pips on all 10/10 bars
- [ ] No POC/VAH/VAL calculations failed (no ERROR messages for these bars)

**Failure Criterion:** Any bar with >2 pip deviation indicates calculation error.

**Example Journal Output to Search For:**
```
VA_CALC: POC=2050.123 VAH=2051.456 VAL=2049.789 width_pips=167.00
```

---

## CHECK 2: Session Profile Isolation (Previous session VA separate from current)

**Verification Steps:**

1. Search Journal for date changes (new calendar day markers)
2. Find 5 random day boundaries throughout the month
3. For each day boundary, verify that previous session data is separate from current session
4. Check that previousSessionProfile.VAH is from yesterday, not today
5. Check that previousSessionProfile.VAL is from yesterday, not today
6. Verify no overlap between previous day's VA and current day's prices

**Success Criteria:**

- [ ] previousSessionProfile.VAH is from previous day, not current day
- [ ] previousSessionProfile.VAL is from previous day, not current day
- [ ] All 5 day boundaries show correct session isolation
- [ ] No price bleed-over between sessions (previous VA prices are distinct)

**Failure Criterion:** If any day shows VAH/VAL from current session instead of previous, session calculation is broken.

**Note:** If Phase 1 uses currentProfile for intraday only and defers previousSessionProfile to Phase 2, this may be marked N/A.

---

## CHECK 3: HVN/LVN Realism (Clusters align with visual volume, 10-30/day typical)

**Verification Steps:**

1. Search Journal for HVN/LVN cluster counts (logged in IdentifyVolumeNodes output)
2. Collect HVN cluster counts from first 5 trading days
3. Collect LVN cluster counts from first 5 trading days
4. Calculate average HVN and LVN counts per day
5. Verify counts are in realistic range (expect 5-30 clusters per day)
6. For the first day, manually inspect top 3 HVN price levels:
   - Open XAUUSD M5 chart at that date
   - Confirm HVN price levels align with obvious volume concentrations on chart
   - Check that HVN prices correspond to visual bars with heavy trading activity

**Success Criteria:**

- [ ] Average HVN cluster count: 5-30/day (across 5-day sample)
- [ ] Average LVN cluster count: 5-30/day (across 5-day sample)
- [ ] Top 3 HVN levels on first day align with chart volume concentrations (visual check)
- [ ] No spurious clusters at random prices (clusters should correspond to actual volume)
- [ ] All 5 spot-check days show realistic counts

**Failure Criterion:** If HVN count >50 or <0, or if top HVN prices don't match chart concentrations, detection logic is broken.

---

## CHECK 4: Volume Distribution Integrity (±0.1% variance, sum = total)

**Verification Steps:**

1. Search Journal for variance logs (logged every 10 bars by PROFILE_CALC messages)
2. Collect variance percentages for all logged checkpoints across entire month
3. Calculate:
   - Average variance across all checkpoints
   - Maximum variance encountered
   - Minimum variance encountered
   - Count of bars with variance >1% (should be 0 or very few)
4. Verify variance metrics meet tolerance

**Success Criteria:**

- [ ] All variance values ≤ 1% on every logged checkpoint
- [ ] Average variance < 0.5% (typical for good proration algorithm)
- [ ] Zero volume distribution failures in entire 1-month backtest
- [ ] No ERROR messages related to volume bin sums or totals

**Failure Criterion:** Any single bar with variance >1% indicates volume proration or bin summation error.

**Example Journal Output to Search For:**
```
PROFILE_CALC: bins_sum=12345600 raw_total=12345700 variance=0.008%
```

---

## CHECK 5: Daily Risk Limits (Hard stop -2%, Profit cap +5%, Friday close)

### Sub-Check 5A: Hard Stop (-2%)

**Verification Steps:**

1. Search Journal for `HARD_STOP_HIT` entries
2. For each hard stop entry found, record:
   - Date of trigger
   - Daily loss amount (should be < -2% of account)
   - Expected -2% limit value
3. For each hard stop day, verify NO trades are placed after the flag was set
4. If no -2% loss days occurred in backtest, note as "Not triggered in backtest"

**Success Criteria:**

- [ ] Hard stop triggers at exactly -2% account loss (±$5 tolerance for rounding)
- [ ] Flag persists (no new trades after HARD_STOP_HIT on that day)
- [ ] If no -2% loss days, mark as "Not triggered in backtest (still valid)"

**Example Journal Output:**
```
HARD_STOP_HIT: closed=-250.00 open=-50.00 total=-300.00 limit=-200.00
```

### Sub-Check 5B: Profit Cap (+5%)

**Verification Steps:**

1. Search Journal for `PROFIT_CAP_REACHED` entries
2. For each profit cap entry, record:
   - Date of trigger
   - Daily gain amount (should be > +5% of account)
   - Expected +5% limit value
3. Verify all open positions are marked for closure (Phase 2 will handle actual closure)

**Success Criteria:**

- [ ] Profit cap triggers at exactly +5% account gain (±$5 tolerance)
- [ ] If no +5% gain days, mark as "Not triggered in backtest (still valid)"

**Example Journal Output:**
```
PROFIT_CAP_REACHED: closed=150.00 open=200.00 total=350.00 cap=250.00
```

### Sub-Check 5C: Friday Hard Close (21:45)

**Verification Steps:**

1. Search Journal for `FRIDAY_HARD_CLOSE_TIME` entries
2. For each Friday close entry, verify:
   - Correct day of week (Friday, day_of_week == 5)
   - Correct time (21:45 ± 1 minute broker server time)
3. Verify no Friday close flags are set on non-Friday days

**Success Criteria:**

- [ ] All Friday close flags set at 21:45 ± 1 minute
- [ ] Flag only set on Friday (never on other days)
- [ ] If backtest doesn't include Friday bars, mark as "N/A"

**Example Journal Output:**
```
FRIDAY_HARD_CLOSE_TIME
  Current time: 21:45
```

---

## CHECK 6: Position Sizing Accuracy (0.6% risk, both XAUUSD + EURUSD correct)

**Verification Steps (if Phase 2 positions placed in backtest):**

1. In Journal, search for `POSITION_ADD:` entries (logged when positions are opened)
2. For each position entry, record:
   - Entry price
   - Stop loss distance (pips)
   - Lot size
   - Current account balance at time of entry
3. For each position, calculate:
   - Risk amount = (account balance) × (SL distance in pips) × (pip value for symbol)
   - Expected lot = 0.6% of balance / (SL distance × pip value)
4. Compare calculated lot to logged lot
5. Verify calculation works for both XAUUSD (micro lots) and EURUSD (standard)

**Success Criteria:**

- [ ] All position lots calculate to 0.6% ±0.05% risk
- [ ] If XAUUSD positions placed: verify micro lot sizing correct
- [ ] If EURUSD positions placed: verify standard lot sizing correct
- [ ] If no positions in Phase 1 backtest: mark as "N/A - Phase 2 execution" (still valid)

**Example Journal Output:**
```
POSITION_ADD: symbol=XAUUSD ticket=123456 entry=2050.123 sl=2045.000 lots=0.05 count=1/3
```

---

## Overall Backtest Success Criteria

**Backtest Completion:**

- [ ] Backtest completes without crashes or EA deinit errors
- [ ] Journal logs all 4 required event types (hard stop, profit cap, Friday close, position tracking)
- [ ] Zero exceptions or assertions failed during entire month
- [ ] No infinite loops or calculation timeouts

**Validation Results:**

- [ ] **Check 1 (POC/VAH/VAL):** PASS or N/A
- [ ] **Check 2 (Session isolation):** PASS or N/A
- [ ] **Check 3 (HVN/LVN realism):** PASS or N/A
- [ ] **Check 4 (Volume variance):** PASS or N/A
- [ ] **Check 5 (Daily limits):** PASS or N/A
- [ ] **Check 6 (Position sizing):** PASS or N/A

**Overall Decision:**

- [ ] All checks PASS or N/A → Phase 1 COMPLETE, ready for Phase 2
- [ ] Any check FAIL → Document failure reason, fix, re-run backtest

---

## Recording Results

After completing all 6 checks, save results in `.planning/phases/01-volume-profile-core/01-03-BACKTEST-RESULTS.txt` with format:

```
Backtest Validation Complete
=============================

Backtest Period: [Date range]
Symbol: XAUUSD
Timeframe: M5
Duration: 1 month
EA Version: VolumeProfile_EA_v1.0.mq5

Check Results:
- Check 1 (POC/VAH/VAL): PASS (10/10 bars within ±1-2 pips)
- Check 2 (Session isolation): PASS (5/5 day boundaries verified)
- Check 3 (HVN/LVN realism): PASS (avg HVN X/day, LVN Y/day)
- Check 4 (Volume variance): PASS (avg variance X%, max Y%)
- Check 5 (Daily limits): PASS (hard stop/profit cap/Friday close verified)
- Check 6 (Position sizing): N/A (Phase 2 execution)

Unit Test Results:
[COPY EXACT LINE FROM JOURNAL showing "TESTS COMPLETE" status]

Overall: READY FOR PHASE 2

Validation Date: [Date]
Executor: [Name]
```

---

*Document created: 2026-05-13*  
*Purpose: Manual backtest validation harness for Phase 1 completion*  
*Next: Execute backtest and complete 6 checks, then record results in 01-03-BACKTEST-RESULTS.txt*
