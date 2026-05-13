# Phase 3 Backtesting & Validation — Gate Verification Checklist

**Purpose:** Verify that 2024 and 2025 backtests independently meet ALL success gates before proceeding to Phase 4.

**BOTH years must pass ALL gates. If either year fails any gate, STOP and return to Phase 2 for code diagnosis.**

---

## 2024 BACKTEST RESULTS

**Backtest Run Date:** ___________  
**Data Period:** 2024-01-01 through 2024-12-31  
**Symbols:** XAUUSD + EURUSD (combined)  
**Mode:** Every Tick (real tick data)  
**History Quality %:** ___________  

### Gate 1: Total Trade Count ≥200

- [ ] Total trades executed: ___________ (must be ≥200)
- [ ] Status: ✓ PASS / ✗ FAIL
- [ ] If FAIL: Investigate why fewer trades generated (possibly entry logic issue in Phase 2)

### Gate 2: Setup 1 & Setup 2 Distribution

- [ ] Setup 1 trades: ___________ (must be ≥50)
- [ ] Setup 2 trades: ___________ (must be ≥50)
- [ ] Status: ✓ PASS / ✗ FAIL
- [ ] If FAIL: Investigate Phase 2 signal detection (either Setup 1 or Setup 2 not firing correctly)

### Gate 3: Win Rate ≥50%

- [ ] Winning trades: ___________
- [ ] Total trades: ___________
- [ ] Win Rate: ___________% (calculated: winning_trades / total_trades × 100)
- [ ] Gate: ≥50% ✓ PASS / ✗ FAIL
- [ ] If FAIL: Strategy doesn't work. Return to Phase 2 for code diagnosis. Check:
  - Entry signal detection (false entries?)
  - Exit logic (premature exits or held-too-long positions?)
  - Daily limit enforcement (affecting win rate?)

### Gate 4: Profit Factor ≥1.5

- [ ] Sum of winning trade P&L: $___________
- [ ] Sum of losing trade P&L: $___________
- [ ] Profit Factor: ___________ (calculated: winning_sum / losing_sum)
- [ ] Gate: ≥1.5 ✓ PASS / ✗ FAIL
- [ ] If FAIL: Winners too small or losers too large. Return to Phase 2 for code diagnosis. Check:
  - TP target accuracy (hitting exact price or overshooting?)
  - SL placement (being hit too early, too often?)
  - Slippage validation (rejecting good trades, accepting bad ones?)

### Gate 5: Daily Drawdown ≤2%

- [ ] Maximum daily drawdown observed: ___________% (from backtest report)
- [ ] Days exceeding 2% limit: ___________ (should be 0)
- [ ] Daily hard stop enforcement verified: ✓ YES / ✗ NO
- [ ] Gate: ≤2% ✓ PASS / ✗ FAIL
- [ ] If FAIL: Daily hard stop logic not working. Return to Phase 2. Check:
  - Hard stop trigger condition (cumulative daily loss ≤-2%?)
  - Position closure on hard stop (all positions closed?)
  - Trading halt flag (new orders blocked until session reset?)

### 2024 Summary

- [ ] All 5 gates PASS: ✓ 2024 IS VALID
- [ ] Any gate FAIL: ✗ 2024 INVALID — Return to Phase 2

---

## 2025 BACKTEST RESULTS

**Backtest Run Date:** ___________  
**Data Period:** 2025-01-01 through 2025-12-31  
**Symbols:** XAUUSD + EURUSD (combined)  
**Mode:** Every Tick (real tick data)  
**History Quality %:** ___________  

### Gate 1: Total Trade Count ≥200

- [ ] Total trades executed: ___________ (must be ≥200)
- [ ] Status: ✓ PASS / ✗ FAIL

### Gate 2: Setup 1 & Setup 2 Distribution

- [ ] Setup 1 trades: ___________ (must be ≥50)
- [ ] Setup 2 trades: ___________ (must be ≥50)
- [ ] Status: ✓ PASS / ✗ FAIL

### Gate 3: Win Rate ≥50%

- [ ] Winning trades: ___________
- [ ] Total trades: ___________
- [ ] Win Rate: ___________% (calculated: winning_trades / total_trades × 100)
- [ ] Gate: ≥50% ✓ PASS / ✗ FAIL

### Gate 4: Profit Factor ≥1.5

- [ ] Sum of winning trade P&L: $___________
- [ ] Sum of losing trade P&L: $___________
- [ ] Profit Factor: ___________ (calculated: winning_sum / losing_sum)
- [ ] Gate: ≥1.5 ✓ PASS / ✗ FAIL

### Gate 5: Daily Drawdown ≤2%

- [ ] Maximum daily drawdown observed: ___________% (from backtest report)
- [ ] Days exceeding 2% limit: ___________ (should be 0)
- [ ] Daily hard stop enforcement verified: ✓ YES / ✗ NO
- [ ] Gate: ≤2% ✓ PASS / ✗ FAIL

### 2025 Summary

- [ ] All 5 gates PASS: ✓ 2025 IS VALID
- [ ] Any gate FAIL: ✗ 2025 INVALID — Return to Phase 2

---

## REGIME ROBUSTNESS COMPARISON

**CRITICAL DECISION:** Both 2024 AND 2025 must independently pass ALL gates.

| Metric | 2024 | 2025 | Status |
|--------|------|------|--------|
| Total Trades | ___ | ___ | ✓/✗ |
| Win Rate | ___% | ___% | ✓/✗ |
| Profit Factor | ___ | ___ | ✓/✗ |
| Max Daily DD | ___% | ___% | ✓/✗ |
| Setup 1 Count | ___ | ___ | ✓/✗ |
| Setup 2 Count | ___ | ___ | ✓/✗ |

### Regime Analysis

- [ ] Both 2024 AND 2025 metrics within ±10% of each other?
  - If YES: Strategy is robust across regimes → ✓ PROCEED TO PHASE 4
  - If NO: Metrics diverge >10% → Possible regime-dependent bug in Phase 2 → INVESTIGATE

- [ ] 2024 WR and PF strong, 2025 degraded? → Overfitting to 2024? Return to Phase 2.
- [ ] 2025 WR and PF strong, 2024 degraded? → Possible 2024 data quality issue. Verify tick data.
- [ ] Both years weak (<50% WR or <1.5 PF)? → Strategy fundamentally broken. Major Phase 2 revision needed.

---

## P&L VARIANCE CHECK (Overfitting Detection)

**Conservative Estimate (calculated before backtest):**
- Assumption: 200 trades/year × 50% WR × 1.5 PF × 0.6% risk per trade
- Estimated annual P&L: ~$300–400 (±20% range acceptable)

**2024 Actual P&L:** $___________  
**2024 Variance:** ___________% of estimate  
**Status:** ✓ PASS (within ±20%) / ✗ SUSPICIOUS (>120% estimate)

**2025 Actual P&L:** $___________  
**2025 Variance:** ___________% of estimate  
**Status:** ✓ PASS (within ±20%) / ✗ SUSPICIOUS (>120% estimate)

If actual P&L >> 120% of estimate: Possible curve-fitting. Investigate:
- Did market in 2024/2025 have unusual trending bias?
- Are parameters (1.3x volume, 70% VA, 0.6% risk) over-tuned to backtest period?
- Phase 4 live trading will be the true test.

---

## DATA QUALITY SPOT-CHECK

**Methodology:** After backtest, manually verify 5 random bars' POC/VAH/VAL calculations.

| Bar Date | Calculated POC | Expected POC (chart) | Diff | Status |
|----------|---|---|---|---|
| _________ | _________ | _________ | ___ pips | ✓/✗ |
| _________ | _________ | _________ | ___ pips | ✓/✗ |
| _________ | _________ | _________ | ___ pips | ✓/✗ |
| _________ | _________ | _________ | ___ pips | ✓/✗ |
| _________ | _________ | _________ | ___ pips | ✓/✗ |

**Acceptance:** All 5 spot-checks within ±2 pips (✓ DATA ACCURATE)  
**Investigation:** Any spot-check >5 pips off (✗ CHECK TICK DATA SOURCE)

---

## FRIDAY CLOSE VALIDATION

- [ ] Verify backtest journal shows NO open positions after Friday 21:45
- [ ] All Friday positions closed by 21:45 broker server time: ✓ YES / ✗ NO
- [ ] If any positions remain open through weekend: ✗ PHASE 2 CODE BUG (Friday close logic failed)

---

## FINAL DECISION

### IF ALL GATES PASS (Both 2024 AND 2025):

✓ **PROCEED TO PHASE 4: Live Deployment & Monitoring**

Summary:
- Strategy validated across 2 market regimes (2024 and 2025)
- Win rate ≥50% in both years
- Profit factor ≥1.5 in both years
- Daily drawdown ≤2% enforced
- 200+ trades per year with balanced Setup 1/2 distribution
- No overfitting signals detected (P&L within ±20% estimate)

**Ready for live trading with confidence that historical performance will translate.**

### IF ANY GATE FAILS (Either 2024 OR 2025):

✗ **RETURN TO PHASE 2: Diagnosis & Code Fix**

Failed Gate(s): ___________________________  
Hypothesis: ___________________________  
Next Steps: Investigate Phase 2 code, make fix, re-run backtest on same data to verify.

---

**Completed by:** ___________________________  
**Date:** ___________________________  
**Signature:** ___________________________
