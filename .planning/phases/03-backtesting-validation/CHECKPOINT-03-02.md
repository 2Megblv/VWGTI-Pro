# Phase 03 Plan 02: Checkpoint - Manual MT5 Backtest Execution Required

**Plan:** 03-02 (2024 Backtest Execution)  
**Date:** 2026-05-13  
**Status:** BLOCKED - Awaiting manual MT5 platform interaction

---

## Summary

Plan 03-02 consists of 3 tasks, with Tasks 1-2 requiring manual interaction with the MT5 Strategy Tester platform (not automatable via CLI). This checkpoint documents:
1. What has been prepared
2. Exact steps required in MT5
3. How Task 3 (sanity checks) will be automated once results are available

---

## Prepared Artifacts

✓ **Directory structure created:**
- `.planning/phases/03-backtesting-validation/results/` (ready to receive backtest outputs)

✓ **Backtest configuration locked:**
- `.planning/phases/03-backtesting-validation/backtest_config/2024_settings.json`
  - Symbol: XAUUSD, EURUSD
  - Timeframe: M5 (5-minute)
  - Model: Every Tick (real tick data mode)
  - Period: 2024-01-01 through 2024-12-31
  - Starting Balance: $1,000 USD
  - Spreads: 3 pips XAUUSD, 5 pips EURUSD
  - Slippage: 1 pip

✓ **Python automation scripts ready:**
- `.planning/phases/03-backtesting-validation/scripts/parse_journal.py` (journal parsing)
- `.planning/phases/03-backtesting-validation/scripts/calculate_metrics.py` (equity curve analysis)
- Both verified for syntax correctness
- Both dependencies installed (pandas 2.3.3, numpy 2.3.5)

✓ **Validation framework in place:**
- `.planning/phases/03-backtesting-validation/validation_checklist.md` (gate verification template)
- `.planning/phases/03-backtesting-validation/DATA_QUALITY_REPORT.md` (data quality procedures)

---

## Manual Execution Required: Task 1 & 2

### Task 1: Configure MT5 Strategy Tester for 2024 Backtest

**Steps (manual in MT5 Platform):**

1. **Launch MT5 Platform**
   - Open MetaTrader 5 client

2. **Open Strategy Tester**
   - Menu: View → Strategy Tester (or Ctrl+R)

3. **Load Expert Advisor**
   - In Strategy Tester window: Expert Advisor dropdown
   - Select: Phase 2 compiled EA binary (.ex5)
   - Expected file: `VolumeProfile_EA_v1.0.ex5` (or equivalent Phase 2 output)

4. **Configure Backtest Settings**
   - **Symbol:** XAUUSD
   - **Timeframe:** M5
   - **Model:** Every Tick (NOT "Bar Open" or "Open price only")
   - **Start Date:** 2024-01-01 00:00:00
   - **End Date:** 2024-12-31 23:59:59
   - **Starting Balance:** 1000
   - **Currency:** USD
   - **Deposit:** USD

5. **Add Second Symbol (EURUSD)**
   - If MT5 supports multi-symbol in single run: Add EURUSD
   - If not: Plan sequential runs (XAUUSD first, then EURUSD separately)

6. **Verify Settings**
   - Symbol(s): XAUUSD ✓, EURUSD ✓
   - Timeframe: M5 ✓
   - Model: Every Tick ✓
   - Dates: 2024 full year ✓
   - Balance: $1,000 ✓
   - Spreads: Broker's actual (3/5 pips) ✓

7. **Start Backtest**
   - Click "Start" button
   - Expected duration: 30 minutes to 2 hours (depending on system CPU and tick data volume)
   - Watch progress bar — do NOT interrupt mid-run

---

### Task 2: Execute Backtest & Capture Outputs

**During backtest execution:**
- Monitor progress in MT5 Strategy Tester
- Minor errors (trade rejections, order failures) are expected — logged to journal
- If EA crashes or hangs >5 minutes on single bar: stop and investigate EA compilation

**Upon backtest completion (when progress = 100%):**

1. **Save Backtest Report**
   - Right-click backtest result in tester history
   - Select "Save report" or "Export report"
   - **Save location:** `.planning/phases/03-backtesting-validation/results/2024_backtest_report.html`
   - **Expected content:** Total trades, Win rate %, Profit factor, Max drawdown %, History quality %

2. **Export Journal to CSV**
   - In MT5 Terminal: Tools → Journal
   - Filter/select all trades from 2024-01-01 to 2024-12-31 (from this backtest run)
   - Right-click → "Export to CSV" (or "Save as CSV")
   - **Save location:** `.planning/phases/03-backtesting-validation/results/2024_journal_export.csv`

3. **Capture Equity Curve Data**
   - From backtest report (HTML), extract daily equity values, OR
   - From MT5 Journal, calculate cumulative equity per day from trade P&L
   - **Save location:** `.planning/phases/03-backtesting-validation/results/2024_equity_curve.csv`
   - **Format:**
     ```
     Date,Equity
     2024-01-01,1000
     2024-01-02,1005
     ...
     2024-12-31,[final equity]
     ```

**Sanity checks after completion:**
- CSV loads without errors: `python3 -c "import pandas; pd.read_csv('.planning/phases/03-backtesting-validation/results/2024_journal_export.csv')"`
- Total trades reported: >100 (expecting 200+)
- History quality %: >95% (goal >99%)
- Equity curve exists and has data

---

## Automated Execution: Task 3 (Post-Backtest)

**Once the 3 CSV/HTML files are in place** (after manual MT5 execution above), Task 3 will run automatically:

```bash
cd .planning/phases/03-backtesting-validation

# Task 3: Quick Data Sanity Check
python3 scripts/parse_journal.py results/2024_journal_export.csv
python3 scripts/calculate_metrics.py results/2024_equity_curve.csv
```

**Expected output:**
- CSV loads: ✓ [N] trades
- SetupType format valid: ✓ (Setup 1, Setup 2)
- No data corruption: ✓ Missing values <5%
- Prices/P&L reasonable: ✓ No negative prices, no >±5000 P&L
- Files exist: ✓ report, journal CSV, equity curve

**Task 3 commits:**
- `chore(03-02): validate 2024 backtest data quality`

---

## What Happens Next

### After Task 3 Passes:
1. ✓ Backtest results committed
2. ✓ SUMMARY.md created for Plan 03-02
3. → Proceed to Plan 03-03 (2025 Backtest) or Plan 03-04 (Metrics Calculation & Gate Validation)

### If Task 3 Detects Data Issues:
- CSV doesn't load → Check export format in MT5 (encoding, special chars)
- Missing data >5% → Check backtest for incomplete tick history (history quality <95%)
- Prices/P&L anomalies → Data corruption concern; re-export journal from MT5

---

## Files Awaiting Creation

| File | Size | Content | Created By |
|------|------|---------|------------|
| `2024_backtest_report.html` | ~500 KB | MT5 native report | Manual MT5 export |
| `2024_journal_export.csv` | ~50-100 KB | Trade-by-trade data | Manual MT5 export |
| `2024_equity_curve.csv` | ~5-10 KB | Daily equity data | Manual extraction |

---

## Blockers & Dependencies

**Blocker 1: Phase 2 EA .ex5 binary not found**
- If `VolumeProfile_EA_v1.0.ex5` doesn't exist:
  - Check `.planning/phases/02-signal-detection-execution/` for compiled EA
  - Or compile from source: `src/VolumeProfile_EA_v1.0.mq5` via MT5 IDE (Tools → Compile)
  - Save .ex5 to accessible location for Strategy Tester

**Blocker 2: Tick data for 2024 missing in MT5**
- If History Center shows <95% history quality for XAUUSD or EURUSD:
  - MT5 → Tools → History Center
  - Download 2024 tick data for both symbols
  - Verify Quality % reaches >99% if possible (>95% minimum acceptable)

**Blocker 3: MT5 platform unavailable**
- This plan requires active MT5 client with network access to download tick data
- Alternative: Use Tickstory or Dukascopy for tick data, import to MT5 History

---

## Continuation Protocol

When backtest completes in MT5:

1. **Export 3 files** to `.planning/phases/03-backtesting-validation/results/`
2. **Run Task 3 sanity checks** (automated Python):
   ```bash
   python3 parse_journal.py results/2024_journal_export.csv
   ```
3. **If all checks pass:**
   - Commit: `chore(03-02): validate 2024 backtest data quality`
   - Create SUMMARY.md
   - Proceed to next plan (03-03 or 03-04)

4. **If checks fail:**
   - Investigate data in MT5
   - Re-export if needed
   - Retry Task 3

---

## Success Criteria for 03-02 Completion

After manual MT5 execution + automated Task 3:

- [ ] `2024_backtest_report.html` exists with metrics
- [ ] `2024_journal_export.csv` exists with 100+ trades
- [ ] `2024_equity_curve.csv` exists with 250+ date entries
- [ ] Python sanity checks pass (no data corruption, valid formats)
- [ ] History quality >95%
- [ ] All files committed to git

**Awaiting:** Manual MT5 backtest execution

---

*Checkpoint created: 2026-05-13*  
*Awaiting user action: Execute 2024 backtest in MT5 and export 3 result files*
