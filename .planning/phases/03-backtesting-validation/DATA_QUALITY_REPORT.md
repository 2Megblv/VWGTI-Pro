# Data Quality Verification Report

**Checked Date:** 2026-05-13

## Tick Data Availability

Manual verification required in MT5 History Center:
- Go to MT5 → Tools → History Center
- Select Symbol: XAUUSD
- Select Timeframe: M5 (5 minutes)
- Check 2024 period: Verify tick data available (green checkmark or availability indicator)
- Check 2025 period: Same verification
- Repeat for EURUSD

| Symbol | 2024 Available | 2025 Available | Notes |
|--------|---|---|---|
| XAUUSD | (To be verified) | (To be verified) | Download via History Center if not present |
| EURUSD | (To be verified) | (To be verified) | Download via History Center if not present |

## History Quality (After Backtest)

After running the backtest, MT5 will report "History Quality %" in the backtest report.

| Year | Symbol | Quality % | Status | Notes |
|------|--------|---|---|---|
| 2024 | XAUUSD | — | Pending | Will be verified after backtest run |
| 2024 | EURUSD | — | Pending | Will be verified after backtest run |
| 2025 | XAUUSD | — | Pending | Will be verified after backtest run |
| 2025 | EURUSD | — | Pending | Will be verified after backtest run |

**Minimum Acceptable:** >95%  
**Target:** >99%

## Spot-Check Results (POC/VAH/VAL Accuracy)

**Will be completed after backtest execution.**

Manual verification of 5 random bars from 2024 backtest:

| Bar Date | Calculated POC | Expected POC (chart) | Diff (pips) | Status |
|----------|---|---|---|---|
| (To be determined) | — | — | — | Pending |
| (To be determined) | — | — | — | Pending |
| (To be determined) | — | — | — | Pending |
| (To be determined) | — | — | — | Pending |
| (To be determined) | — | — | — | Pending |

**Acceptance Criteria:**
- All spot-checks within ±2 pips (✓ DATA ACCURATE)
- Any spot-check >5 pips off (✗ CHECK TICK DATA SOURCE)

## Procedure Notes

### Manual Spot-Check Methodology

1. After backtest completes, identify 5 random bars from different months of 2024
2. For each bar, record the calculated POC, VAH, VAL from backtest results
3. Manually analyze the same bar on MT5 chart (using Volume Profile indicator if available, or manual counting)
4. Compare: If EA's calculated POC within ±2 pips of manual chart analysis, data is accurate
5. If mismatch >5 pips on any bar, investigate tick data source (gaps, corruption, or calculation error)

### Data Gap Investigation

If history quality is <95% or spot-checks show >5 pip variance:
- Use Tickstory or Dukascopy alternative data sources to verify tick accuracy
- Contact broker support about data completeness
- Document findings and reason for backtest validity/invalidity

## Verification Status

- [ ] 2024 tick data downloaded and available in MT5 History Center
- [ ] 2025 tick data downloaded and available in MT5 History Center
- [ ] 2024 backtest run; history quality % verified (target >99%)
- [ ] 2025 backtest run; history quality % verified (target >99%)
- [ ] 5 spot-checks completed on 2024 results; all within ±2 pips (✓ DATA ACCURATE)

---

**Document created:** 2026-05-13  
**Status:** Ready for manual verification after backtest execution
