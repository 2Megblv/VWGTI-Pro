# Domain Pitfalls — MT5 Volume Profile Trading EA

**Project:** VWGTI-PRO-VP-EA  
**Researched:** 2026-05-13  
**Confidence:** HIGH (extracted from MT5 spec, development roadmap, and Volume Profile literature)

---

## Critical Pitfalls

Mistakes that cause rewrites or major financial losses.

### Pitfall 1: Incorrect Volume Distribution (400-Bin Algorithm)

**What goes wrong:**
- Volume prorating across candles done incorrectly
- Bins weighted unevenly (some too high, some too low)
- Multi-level candles double-count volume
- Profile looks plausible but POC/VAL/VAH are wrong

**Why it happens:**
- Complex prorating logic (divide candle volume by # bins touched)
- Easy to off-by-one on bin indexing
- Float rounding errors accumulate over 150 bars

**Consequences:**
- Entry signals triggered at wrong price levels
- VAL/VAH off by 10-20 pips (huge miss)
- 80% Rule mean reversion fails because VA boundaries are wrong
- Setup 2 HVN/LVN zones misidentified

**Prevention:**
1. Unit test with known data (flat 150 bars at 1.2000 → POC=1.2000)
2. Validate manual calculation on first 10 bars vs. code output
3. Print intermediate values during development
4. Cross-check that sum of all bins ≈ total volume (allow ±1%)

**Detection:**
- POC wildly different from obvious high-volume area
- VAL/VAH outside recent price range (red flag)
- First 50 trades all losing (wrong entry levels)

### Pitfall 2: Previous Session Profile Not Isolated

**What goes wrong:**
- Setup 1 uses current day's data instead of previous day only
- Yesterday's VA = today's VA (no gap setup)
- Trades Setup 1 signals when market is already inside VA
- False entries; missing real gaps

**Why it happens:**
- Hard to isolate session boundaries
- Confusion between calendar day vs. trading session
- `iTime()` loops tricky with session start/end times

**Consequences:**
- Setup 1 generates 50% false signals
- Win rate collapses (should be 50%+, drops to 30%)
- Backtest shows promise; live trading disappoints

**Prevention:**
1. Separate profile calculations (current vs. previous session)
2. Verify session isolation in backtest (print previous VA every bar)
3. Check gap detection logic
4. Manual bar inspection: Pick 5 random days, verify previous VA isolation

**Detection:**
- Setup 1 triggers multiple times per day on same asset (wrong)
- Setup 1 trades within VA instead of at VA boundary (wrong)
- Historical trades cluster around support/resistance, not VA edges

### Pitfall 3: HVN/LVN Identification Using Wrong Threshold

**What goes wrong:**
- HVN threshold set to 1.5x average → catches half the market (useless)
- LVN threshold set to 0.5x average → no real vacuums
- HVN too strict (1.5x) → misses real volume nodes
- Resulting HVN/LVN arrays have 5 nodes instead of 10-15

**Why it happens:**
- 1.3x and 0.7x are empirically tuned, not obvious
- Temptation to "optimize" these constants (curve-fitting trap)

**Consequences:**
- Setup 2 signals trigger at random prices, not at HVN
- Volume spikes confuse algorithm
- Fewer Setup 2 trades; ones that execute are noise

**Prevention:**
1. Lock thresholds (1.3x HVN, 0.7x LVN) as constants
2. Validate HVN/LVN count (typical: 10-20 of each)
3. Backtest with threshold variations to verify no over-fitting
4. Visual inspection (print top 3 HVN levels every day)

**Detection:**
- Setup 2 trades triggered far from any obvious volume cluster
- HVN array count wildly different between days
- Win rate on Setup 2 significantly worse than Setup 1

---

## Moderate Pitfalls

### Pitfall 4: Position Size Calculation Error

**What goes wrong:**
- Pip value miscalculated for symbol (Gold vs. Forex different scales)
- Account balance not updated after first trade
- Slippage not accounted for in SL distance
- Lot size rounds down when should be 0.01 minimum

**Consequence:** Risking 3% instead of 0.6% per trade; drawdown accelerates.

**Prevention:**
- Verify pip value for each symbol
- Use AccountBalance() fresh each trade (not cached)
- Account for slippage in SL (add 3 pips buffer)

**Detection:**
- Actual risk per trade varies wildly (should be consistent 0.6%)
- Account balance dropping 1-2% per trade (should be 0.6%)
- Drawdown reached 15%+ before expected

### Pitfall 5: Hardcoded Session Times (Timezone Mismatch)

**What goes wrong:**
- Code hardcodes "23:00 GMT" but broker uses EST
- Trading window calculation off by 5 hours
- EA trades outside intended session (low liquidity, wide spreads)
- Orders placed during overnight Asian session (bad fills)

**Prevention:**
- Convert broker time to consistent timezone (UTC)
- Define session in UTC, convert back to broker time
- Print session times at startup for verification

**Detection:**
- EA trades when chart shows low volume/wide spreads
- London/NY overlap trades, but Tokyo trades too
- Frequent order rejections during certain hours

### Pitfall 6: Daily Loss Limit Not Persisting Across Sessions

**What goes wrong:**
- Daily loss limit checked only once per day
- If EA restarted, counter resets
- Trades through daily loss limit anyway

**Prevention:**
- Store daily stats in persistent structure
- Refresh from broker every tick (rescan OrdersHistoryTotal)
- Sum all closed trades since dayStart
- Compare cumulative to daily limit

**Detection:**
- Large loss days that exceeded limit but weren't halted
- Account balance dropped more than -2% single day

### Pitfall 7: Not Validating Signal SL/TP Before Entry

**What goes wrong:**
- Setup1Signal calculated with TP < Entry (backwards)
- Setup2Signal has SL outside HVN zone (makes no sense)
- OrderSend() rejects invalid SL/TP
- Trade never executed, signal wasted

**Prevention:**
- Validate all signals before entry (SL/TP logic correct)
- Check direction-specific constraints
- Verify R:R ratio >= 1.0

**Detection:**
- Backtest shows signals triggered but no trades executed
- Journal shows "VALIDATION_FAILED" repeatedly

---

## Minor Pitfalls

### Pitfall 8: Missing Error Logging
**Problem:** OrderSend() fails silently; can't debug why.
**Solution:** Log every error with GetLastError() code.

### Pitfall 9: Array Index Out of Bounds
**Problem:** Accessing volumeArray[400] when size is 400 (0-399).
**Solution:** Always use `if (i < 400)` checks in loops.

### Pitfall 10: Not Handling Partial Order Fills
**Problem:** OrderSend() fills 0.5 lots; code assumes full fill.
**Solution:** Check OrderOpenSize() after execution.

### Pitfall 11: Timezone Confusion (Broker vs. Local)
**Problem:** Live trading misaligned to backtest times.
**Solution:** All times in UTC; convert once for display only.

### Pitfall 12: Bid/Ask Reversal on Entry
**Problem:** Using Ask for SHORT entry (backwards).
**Solution:** Use Bid for exits (sell side), Ask for entries (buy side).

---

## Phase-Specific Warnings

| Phase | Likely Pitfall | Mitigation | Research Needed |
|-------|---------------|------------|-----------------|
| **Development (Week 1-2)** | Volume distribution algorithm wrong | Unit test with known data | LOW |
| **Development (Week 1-2)** | Session profile isolation broken | Inspect 5 random days manually | LOW |
| **Backtesting (Week 2-3)** | Win rate too high (curve-fitting) | Keep parameters fixed; don't optimize | MEDIUM |
| **Backtesting (Week 3-4)** | Drawdown limit enforcement fails | Simulate artificial losses, verify halt | MEDIUM |
| **Live Testing (Week 7+)** | Backtest-to-live gap (slippage/spreads) | Expect 20% worse performance initially | MEDIUM |
| **Multi-Asset (Phase 2)** | Different pip values break sizing | Validate for each asset | LOW |

---

## Red Flags During Development

### Code-Level Red Flags
- "Compile errors don't matter" → They will compound
- "I'll optimize the 400-bin algorithm after backtesting" → Too late
- "POC/VAL/VAH look reasonable, close enough" → Not good enough
- "I'm hardcoding session times for now" → Creates timezone bugs
- "Skip validation; order will be rejected if invalid" → Missing trades

### Backtesting Red Flags
- "Win rate 75%+ on 200 trades" → Unrealistic; likely curve-fitted
- "No losing months in 1-year backtest" → Impossible; real markets have choppy periods
- "Profit factor 5.0" → Suspicious; 1.5-2.0 is realistic
- "Drawdown never exceeded 5% on 2-year history" → Too good to be true

### Live Trading Red Flags
- "First 5 trades all losses" → Possible variance; investigate if continues
- "Account drawdown reached 20%" → Critical; halt EA immediately
- "Win rate below 40% after 20 live trades" → Below backtest; diagnose before continuing

---

## Confidence Summary

| Pitfall | Severity | Confidence | Why |
|---------|----------|-----------|-----|
| **Volume distribution** | CRITICAL | HIGH | Spec is detailed; easy to test |
| **Session isolation** | CRITICAL | HIGH | Setup 1 foundation |
| **HVN/LVN thresholds** | HIGH | HIGH | Empirically determined |
| **Position sizing** | HIGH | HIGH | Math is straightforward |
| **Risk limits** | HIGH | MEDIUM | Requires live testing for edge cases |
| **Timezone issues** | MEDIUM | MEDIUM | Broker-specific; varies by platform |
| **Order validation** | MEDIUM | HIGH | Prevent invalid orders |
| **Error recovery** | LOW | MEDIUM | Depends on connection stability |

---

Next phase: Full development implementation and backtesting per COMPLETE_DEVELOPMENT_ROADMAP.md.
