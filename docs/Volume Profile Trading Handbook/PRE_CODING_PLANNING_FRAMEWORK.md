# Pre-Coding Planning Framework
## Volume Profile Trading EA - Master Planning Document

**Status:** 🔴 MUST COMPLETE BEFORE CODING  
**Estimated Planning Time:** 4-6 hours  
**Criticality:** HIGH - These decisions impact entire EA architecture

---

## SECTION 1: MARKET & INSTRUMENT SPECIFICATIONS

### 1.1 Primary Markets to Trade
**Decision Required:** Select your initial target market(s)

```
Choose based on:
□ Forex (Tick Volume proxy) - Most accessible, 24/5
□ Stocks (Real Volume) - Direct volume data, market hours
□ Futures (Real Volume) - High leverage, volume transparency
□ Cryptos (Tick Volume proxy) - 24/7, growing volume data

RECOMMENDATION for Volume Profile:
Primary: Forex Major Pairs (EURUSD, GBPUSD, USDJPY)
Secondary: Stock Indices (ES, NQ, DAX)
Why: Clear volume profile patterns, adequate liquidity, 24/5 accessibility
```

**Action Item:** List your target instruments
```
INSTRUMENT LIST:
1. _________________  (Market Type: _______)
2. _________________  (Market Type: _______)
3. _________________  (Market Type: _______)
```

### 1.2 Minimum Liquidity Requirements
**Critical:** Low liquidity kills volume profile edge

```
Parameter Definitions:
- Average Daily Volume: Avg tick/real volume over 20 days
- Bid-Ask Spread: Average spread during trading hours
- Slippage Tolerance: Max acceptable deviation from entry

MINIMUM THRESHOLDS:
Forex:     Avg Daily Volume > 1M ticks,   Spread < 2 pips
Stocks:    Avg Daily Volume > 10M shares, Spread < 1 cent
Futures:   Avg Daily Volume > 100K contracts, Spread < 1 tick
Cryptos:   Avg Daily Volume > 100M units, Spread variable
```

**Your Specifications:**
```
Instrument: _________________
Avg Daily Volume: ___________
Typical Bid-Ask Spread: _____
Max Acceptable Slippage: ____
```

### 1.3 Account Type & Leverage
**Decision Required:** This affects position sizing and drawdown

```
Account Type Options:
□ Micro Account (1:100 leverage, $100-1000)
□ Mini Account (1:200 leverage, $1000-5000)
□ Standard Account (1:400 leverage, $5000-50000)
□ Professional Account (1:500+ leverage, $50000+)

KNOWLEDGE BASE ALIGNMENT:
Your EA uses sophisticated math (400 bins, auction theory)
Recommend: Standard or Professional (need sufficient capital for proper risk sizing)
Why: Micro/Mini accounts force excessive leverage → higher drawdown risk
```

**Your Decision:**
```
Account Size: $__________
Leverage Available: 1:_____
Risk Per Trade: _____%
Max Daily Risk: _____%
```

---

## SECTION 2: TIMEFRAME STRATEGY ALLOCATION

### 2.1 Timeframe Selection Matrix
**Critical:** Different setups optimize on different timeframes

```
From Knowledge Base Analysis:

Setup 1 (80% Rule - Value Area Migration):
✓ OPTIMAL: Daily (D), 4-Hour (H4)
✓ GOOD: 1-Hour (H1)
✗ NOT RECOMMENDED: Below 15-min
Why: Requires clear session structure, overnight gaps, session opens
Characteristics: Fewer trades, higher accuracy, wider stops needed

Setup 2 (HVN Edge Trading):
✓ OPTIMAL: 15-min (M15), 1-Hour (H1), 5-min (M5)
✓ GOOD: 4-Hour (H4)
✗ NOT RECOMMENDED: Below M5
Why: Captures intraday reversals, noise manageable with volume confirmation
Characteristics: More trades, tighter stops, requires volume spike confirmation

COMBINED STRATEGY:
Timeframe 1 (Setup 1): _________ (Daily or 4H for mean reversion)
Timeframe 2 (Setup 2): _________ (M15 or H1 for HVN trades)
Timeframe 3 (Optional): _________ (Higher TF confirmation)
```

### 2.2 Trade Frequency Allocation
**Decision:** How many trades per day/week do you want?

```
CONSERVATIVE (Lower frequency, higher conviction):
- Setup 1 Only: 0-1 trades/day (DAILY TF)
- Setup 2 Only: 1-2 trades/day (H1 TF)
- Combined: 1-2 trades/day
- Lookback: 150+ bars (captures fuller profile)

MODERATE (Balanced approach):
- Setup 1: 1 trade/day (4H TF)
- Setup 2: 2-3 trades/day (M15-H1 TF)
- Combined: 3-4 trades/day
- Lookback: 150 bars

AGGRESSIVE (Higher frequency):
- Setup 1: 1-2 trades/session (H1 TF)
- Setup 2: 3-5 trades/day (M5-M15 TF)
- Combined: 5+ trades/day
- Lookback: 100 bars
- WARNING: More slippage impact, need tight discipline
```

**Your Choice:**
```
Frequency Target: _________ trades per day
Max Positions Simultaneously: _________
Setup 1 Allocation: _________ trades/session
Setup 2 Allocation: _________ trades/session
Daily Trade Limit Hard Stop: _________
```

### 2.3 Timeframe Lookback Recommendations
**Decision:** How many bars to analyze for volume profile?

```
CALCULATION METHOD:
Lookback = How many bars to capture adequate market structure

DEFAULTS BY TIMEFRAME:
Daily (D):        100-150 bars (5-7 weeks of data)
4-Hour (H4):      150-200 bars (4-5 weeks of data)
1-Hour (H1):      150-200 bars (1 week of data)
15-min (M15):     150-200 bars (2-3 days of data)
5-min (M5):       150-200 bars (10+ hours of data)

TESTING RECOMMENDATION:
Your spec uses 150 bars default - KEEP THIS for initial development
After backtesting 50+ trades, optimize:
- Increase if: False signals, missing setup conditions
- Decrease if: Lagging behind price action

Your Lookback Selections:
Setup 1 TF (_____): _____ bars
Setup 2 TF (_____): _____ bars
```

---

## SECTION 3: SESSION MANAGEMENT & CONTEXT

### 3.1 Define Session Timing for Setup 1
**CRITICAL for Setup 1:** Must distinguish sessions properly

```
SESSION TYPES (Choose based on market):

FOR FOREX:
□ RTH (Regular Trading Hours) - NY Session only
   Open: 8:30 AM ET, Close: 5:00 PM ET
   Profile resets daily at 8:30 AM ET

□ 24h Rolling - Volume profile continuous, resets every 24h
   Open: 5:00 PM ET Sunday, Close: 5:00 PM ET Friday
   
□ LONDON-NY Overlap - Most liquid
   Open: 8:00 AM GMT, Close: 1:00 PM ET

FOR STOCKS:
□ RTH (Regular Trading Hours) - Exchange hours only
   Open: 9:30 AM ET, Close: 4:00 PM ET
   
□ Extended Hours - Include pre-market + after-hours
   Open: 4:00 AM ET, Close: 8:00 PM ET

FOR FUTURES:
□ RTH (Exchange hours)
□ Continuous (Pit hours when market open)
```

**Your Session Definition:**
```
Primary Market: ________________
Session Type: ________________
Session Open Time: ________________
Session Close Time: ________________
Timezone: ________________

Example for EURUSD:
Market: Forex
Session: London-NY Overlap
Open: 08:00 GMT
Close: 13:00 ET
Timezone: Use UTC/GMT internally, convert for display
```

### 3.2 Previous Session Reference Period
**Required for Setup 1:** Define how to capture yesterday's VA

```
DECISION: How to calculate "previous session" profile?

OPTION A: Previous Calendar Day (Simplest)
- Lookback: Previous 24 hours
- Reset: Daily at market open
- Benefit: Simple to implement
- Risk: May not align with true session structure

OPTION B: Previous RTH Session (Most Accurate)
- Lookback: Previous session's trading hours only
- Reset: At current session open
- Benefit: Matches actual market structure
- Risk: More complex, requires time zone handling

RECOMMENDATION: 
For Forex: OPTION A (daily reset at 5 PM ET Sunday-Friday)
For Stocks: OPTION B (RTH 9:30 AM - 4:00 PM ET)
For Futures: OPTION B (RTH per exchange)
```

**Your Selection:**
```
Previous Session Calculation Method: ________________
Previous Session Data Source: □ Daily TF  □ Session-specific
Session Data Lookback: _________ bars
Data Storage: □ Persistent across days  □ Fresh each day
```

### 3.3 Session Overlap & Gap Handling
**Critical Edge Case:** What happens at session boundaries?

```
SCENARIOS TO HANDLE:

Scenario 1: OVERNIGHT GAP (Price opens far from previous close)
Example: Friday close $100, Monday open $102 (gap $2)
Setup 1 Trigger: YES - Price opened outside previous VA
Action: 
- Identify new session profile starting at $102
- Use previous session's VA as reference
- Setup triggered when price re-enters $100-$102 range

Scenario 2: WEEKEND GAPS (Forex Friday-Sunday gap)
Example: Friday NY close $1.0850, Sunday Tokyo open $1.0900
Setup 1 Trigger: YES - Outside previous session
Action:
- Treat Sunday open same as Monday open
- Previous session = Friday RTH only
- Current session = Sunday-Friday

Scenario 3: NEWS/ECONOMIC RELEASES
Example: NFP Friday 8:30 AM causes $200 pip gap
Setup 1 Response: 
- Hold if already in trade (SL manages risk)
- Skip NEW entries for 30 min post-release
- Resume after volatility settles

Your Gap Handling Rules:
Overnight Gap: ________________
Weekend Gap: ________________
News/Release Gap: ________________
Holiday Gap: ________________
```

---

## SECTION 4: POSITION MANAGEMENT RULES

### 4.1 Simultaneous Position Rules
**Decision:** Can EA open multiple positions?

```
OPTION A: ONE POSITION MAXIMUM
- Only 1 open trade at a time
- Simpler risk management
- Lower capital requirements
- Recommended for beginners/small accounts

OPTION B: MULTIPLE POSITIONS (Same instrument)
- Up to N positions simultaneously on same pair/stock
- Different setups can overlap
- Example: Setup 1 LONG + Setup 2 SHORT at same time
- Risk: Complex position management, SL/TP conflicts
- Requires: Clear position tracking

OPTION C: HEDGING ALLOWED
- Setup 1 and Setup 2 can open opposite positions
- Example: Setup 1 LONG entry, then Setup 2 SHORT entry
- Both active simultaneously
- Risk: Slippage on both sides, complex accounting
- Benefit: Capture both mean reversion and breakout
```

**Your Choice:**
```
Position Rules:
□ One position maximum (RECOMMENDED for v1.0)
□ Multiple positions allowed
   Max simultaneous: ___________
□ Hedging allowed (opposite directions)

Conflict Resolution (if multiple signals):
□ First signal wins (ignore subsequent)
□ Highest probability signal wins (prioritize Setup 1 or 2)
□ Both executed (hedging mode)
```

### 4.2 Position Entry Queueing
**Decision:** What if Setup conditions are met while in trade?

```
SCENARIO: In trade, new Setup signal triggers

OPTION A: SKIP NEW ENTRY
- Only 1 trade at a time
- Don't queue anything
- Simpler logic

OPTION B: QUEUE ENTRY
- Store signal details
- Execute when current trade closes
- Risk: Delayed execution, price may move away

OPTION C: REPLACE POSITION
- Close current trade if new signal has higher confidence
- Risk: Exit winners early, lock in losses

RECOMMENDATION: Start with OPTION A (Skip)
After 100 trades, review if you're missing good setups
```

**Your Rule:**
```
Multiple Setup Condition Handling:
□ Skip new signal (focus on current trade)
□ Queue for next entry (after current closes)
□ Replace current (if new signal higher quality)
```

### 4.3 Trade Duration Rules
**Decision:** How long do trades stay open?

```
DEFAULTS:

Setup 1 (Mean Reversion):
- Target: Opposite extreme (VAH or VAL)
- Timeframe: Multiple days possible (daily/4h trades)
- Max Duration: 5-10 days
- Action if max duration hit: Close at market

Setup 2 (HVN Edge):
- Target: Opposite profile edge
- Timeframe: Hours to 1-2 days
- Max Duration: 2-3 days
- Action if max duration hit: Close at market

REASONING:
- Mean reversion has longer holding period
- HVN trades are faster reversal trades
- Max duration prevents stuck/stale trades
```

**Your Specification:**
```
Setup 1 Max Hold Time: _________ (hours/days)
Setup 2 Max Hold Time: _________ (hours/days)
Action at Max Duration: □ Close at market  □ Keep open  □ Trailing SL

Time-Based Exit Rule:
□ Use time limit (above)
□ No time limit (hold to TP/SL)
```

---

## SECTION 5: RISK MANAGEMENT FRAMEWORK

### 5.1 Risk Per Trade Calculation
**Decision:** How much money to risk per trade?

```
YOUR CURRENT SPEC:
□ Risk Percentage: 1% per trade (CONSERVATIVE)
□ Fixed Lot Size: Specify size

SIZING FORMULA (Risk-Based):
1. Account Balance: $10,000
2. Risk Percentage: 1%
3. Account Risk: $10,000 × 1% = $100 per trade
4. Stop Loss Distance: 50 pips
5. Pip Value: $0.10 per pip (varies by symbol)
6. Max Loss per trade: 50 pips × $0.10 = $5 per pip
7. Lot Size = $100 ÷ $5 = 0.20 lots

RISK PERCENTAGE GUIDELINES:
Conservative (Starting):     0.5% - 1.0% per trade
Moderate (Proven edge):      1.0% - 2.0% per trade
Aggressive (Professional):   2.0% - 3.0% per trade
WARNING: Above 3% risks ruin with string of losses

KELLY CRITERION (Math optimal):
If Win Rate = 60%, Average Win = 100 pips, Average Loss = 50 pips
Kelly % = (0.60 × 100 - 0.40 × 50) / 100 = 0.40 = 40%
Risk = 40% / 4 = 10% (fractional Kelly safer)
```

**Your Decision:**
```
Risk Model: □ Risk Percentage  □ Fixed Lot Size

If Risk Percentage:
  Risk per trade: _____%
  Account Balance: $_______
  Calculated Max Loss: $_______

If Fixed Lot Size:
  Lot Size: _______ (0.01 micro lots? Standard lots?)
  Max Loss Assumption: $_______
```

### 5.2 Daily & Weekly Loss Limits
**Critical:** Prevent "revenge trading" after bad days

```
DAILY LOSS LIMIT:
Definition: Maximum total loss allowed in one day
Calculation: Risk% × Account × Max Daily Trades
Example: 1% × $10,000 × 3 trades = $300 max loss/day

RECOMMENDATION:
Conservative: 2% of account per day
Moderate: 3% of account per day
Aggressive: 5% of account per day

WHEN LIMIT HIT:
- STOP all trading immediately
- Walk away from screens
- Review what went wrong
- Resume next trading day

WEEKLY LOSS LIMIT:
Definition: Maximum loss allowed Monday-Friday
Calculation: Usually 2x daily limit
Example: $300/day × 5 days = $1,500/week max
```

**Your Limits:**
```
Daily Loss Limit: ____% or $_______
Weekly Loss Limit: ____% or $_______
Action When Hit: ________________
Reset Time: □ Daily  □ Weekly  □ Calendar based
```

### 5.3 Drawdown Management
**Decision:** How deep can equity drawdown go?

```
MAXIMUM DRAWDOWN LIMITS:

Equity Drawdown: Peak equity decline from recent high
Example: Account went $10,000 → $9,000 → $9,500
Drawdown = $1,000 or 10%

TIER 1 ALERT (Stop loss placement review):
Drawdown reaches 10% of account
Action: Review last 10 trades, check for bias or system failure

TIER 2 WARNING (Reduce position size):
Drawdown reaches 15% of account
Action: Cut all lot sizes by 50%, focus on recovery

TIER 3 CRITICAL (Pause trading):
Drawdown reaches 20% of account
Action: STOP all trading, rebuild slowly with micro lots

BEYOND 20%:
Strongly consider: System not working as expected
Action: Full audit, backtesting review, rules revision

RECOMMENDED MAXIMUM: 15-20% (0.5% risk/trade allows 20%+ drawdown)
```

**Your Drawdown Rules:**
```
Tier 1 Alert (Review): ____% drawdown
Tier 2 Warning (Reduce): ____% drawdown
  Action: Reduce position size to ____% normal
Tier 3 Critical (Stop): ____% drawdown
  Action: Pause trading, review system
```

---

## SECTION 6: TRADING HOURS & FILTERS

### 6.1 Market Session Filters
**Decision:** When should EA trade?

```
FOREX SESSIONS:
□ TOKYO (21:00-06:00 UTC) - Lower volume, tight spreads
□ LONDON (08:00-17:00 UTC) - Most volatile, best volume
□ NY (13:00-22:00 UTC) - Most liquid, trending
□ PACIFIC (Overlap) - Good volume, fewer gaps

STOCK MARKET:
□ Pre-market (04:00-09:30 ET) - Low volume, skip
□ Regular Hours (09:30-16:00 ET) - Primary
□ After-hours (16:00-20:00 ET) - Low volume, skip
□ Earnings Season - Consider skipping (high volatility)

FUTURES:
□ Pit Hours (09:30-16:15 ET) - Primary volume
□ Globex Hours (17:00-16:15 next day) - Secondary
□ Pre-market (04:00-09:30 ET) - Skip or secondary

RECOMMENDATION:
Focus on highest volume, most liquid sessions first
Setup 1: All sessions (captures overnight gaps)
Setup 2: Focus on London-NY overlap (best volume)
```

**Your Selection:**
```
Setup 1 Trading Hours: ________________
Setup 2 Trading Hours: ________________
Exclude Periods:
  □ Pre-market
  □ After-hours
  □ Low liquidity (specify which)
  □ News releases (which ones?)
```

### 6.2 News & Event Filters
**Decision:** Avoid or trade around news events?

```
HIGH IMPACT EVENTS (Usually skip):
- Central Bank Policy Decisions
- Employment Reports (NFP, jobless claims)
- Inflation Data (CPI, PPI)
- GDP Releases
- Interest Rate Decisions
- Major Earnings (stocks)

MEDIUM IMPACT (Caution, wider stops):
- Manufacturing PMI
- Consumer Confidence
- Housing Data
- Trade Data

LOW IMPACT (Can trade):
- Secondary inflation
- Regional economic data
- Corporate guidance

RECOMMENDED APPROACH:
Option A: SKIP ALL NEWS
- No trades 30 min before/after economic calendar events
- Simplest implementation
- May miss some good setups

Option B: TRADE WITH WIDER STOPS
- Add +50% to stop loss distance during news
- Increase slippage tolerance
- More trades, but riskier

Option C: SELECTIVE TRADING
- Skip only highest-impact events
- Trade medium/low impact normally
- Requires calendar integration
```

**Your Choice:**
```
News Filter: □ Skip all  □ Trade with wider stops  □ Selective

If Selective:
High Impact Events: SKIP
Medium Impact Events: ________________
Low Impact Events: TRADE NORMALLY

Pre-Event Buffer: _____ minutes
Post-Event Buffer: _____ minutes
```

### 6.3 Calendar-Based Exclusions
**Decision:** Skip certain days/times?

```
COMMON CALENDAR FILTERS:

MONTHLY:
□ Last Friday (FOMC minutes due)
□ First Friday (NFP released)
□ Mondays (stronger gaps/trends)

WEEKLY:
□ Fridays (weekend gap risk)
□ Monday morning (gap trades)
□ Wednesday (mid-week reversal)

SEASONAL:
□ December (holiday, low volume)
□ Summer (vacation periods, thin trading)
□ Earnings season (for stocks)

SPECIAL DAYS:
□ New Year's Day
□ Easter
□ Thanksgiving
□ Christmas
□ Central bank holidays
```

**Your Exclusions:**
```
Days to Skip Entirely:
□ Mondays  □ Fridays  □ Specific date ________
□ Holidays: ___________, ___________, ___________

Reduced Activity Days:
□ Last Friday (wider stops)
□ Before major holidays (reduce size)
□ Summer months (skip or reduce)

High Activity Focus Days:
□ FOMC announcement day
□ NFP Friday
□ Specific events you like
```

---

## SECTION 7: EDGE CASE HANDLING

### 7.1 Gap & Slippage Scenarios
**Decision:** How to handle unexpected conditions?

```
SCENARIO 1: OVERNIGHT GAP BEYOND EXPECTATIONS
Example: Forex opens 200+ pips away from close
Your SL might get hit at worse price

HANDLING OPTIONS:
□ Cancel limit orders if gap > 100 pips
□ Accept market order at market price
□ Hold for re-entry opportunity

SCENARIO 2: EXTREME SLIPPAGE (10+ pips vs entry)
Example: Entry signal at 1.0850, fill at 1.0865

HANDLING OPTIONS:
□ Reject trade, don't execute (reject slippage > threshold)
□ Execute but increase TP distance (compensate)
□ Accept as cost of trading

SCENARIO 3: LIQUIDITY CRASH (Spread widens 10x)
Example: Normal spread 1.5 pips, becomes 15 pips

HANDLING OPTIONS:
□ Skip trading during liquidity crises
□ Detect low liquidity, increase stops
□ Pause until liquidity returns
```

**Your Rules:**
```
Gap Handling:
Gap beyond _____ pips: □ Cancel  □ Execute at market
SL Adjustment: ____________

Slippage Handling:
Max acceptable slippage: _____ pips
If exceeded: □ Reject  □ Execute  □ Widen stops

Liquidity Crisis:
Spread exceeds _____ pips: □ Skip trading  □ Execute
Min volume requirement: ____________
```

### 7.2 System Failure & Recovery
**Decision:** What if your system fails during trading?

```
SCENARIOS:

1. TERMINAL DISCONNECT
   - Lost connection to broker
   - Missing market data
   Recovery: Auto-reconnect, don't re-execute trades
   
2. PLATFORM CRASH
   - MT5 crashes mid-trade
   Recovery: Reconnect, check open positions, verify SL/TP
   
3. ORDER REJECTION
   - Broker rejects your order (various reasons)
   Recovery: Log error, notify you, pause trading
   
4. TRADE EXECUTION FAILURE
   - Order sent but not confirmed
   Recovery: Query broker API, verify position, reconcile
   
5. DATA CORRUPTION
   - Volume data becomes invalid/unusual spike
   Recovery: Skip that candle, continue with next

RECOMMENDED ACTIONS:
- Log all failures with timestamp and details
- Alert you immediately (email/SMS optional)
- Automatically pause trading on critical errors
- Require manual restart after critical error
```

**Your Recovery Rules:**
```
Critical Errors (Stop Trading):
□ Terminal disconnect
□ Platform crash
□ Order rejected (repeat)

Non-Critical (Log & Continue):
□ Unusual volume spike
□ Temporary data lag
□ Minor slippage

Alert You:
□ Every error
□ Only critical
□ Only daily summary
```

### 7.3 Data Quality Issues
**Decision:** What if volume/price data is bad?

```
ISSUES TO WATCH:

1. TICK VOLUME ANOMALY
   Example: Normal candle = 5000 ticks, suddenly 500,000 ticks
   Cause: Data error or huge volume spike
   Response: Validate against previous 20 candles

2. PRICE SPIKE REVERSAL
   Example: Price spikes to 1.1000, immediately reverses to 1.0900
   Cause: Flash crash, data error, liquidity event
   Response: Check volume - if low, likely error

3. MISSING DATA
   Example: No data for 5 minutes on H1 chart
   Cause: Server lag, connection issue
   Response: Retry data load, don't trade until data fresh

4. DUPLICATE CANDLES
   Example: Same candle appears twice
   Cause: Data feed glitch
   Response: Reload chart, validate before trading
```

**Your Data Quality Rules:**
```
Tick Volume Check:
If current candle > _____ × average: □ Skip  □ Validate

Price Spike Check:
If H-L > _____ pips AND volume < threshold: Skip

Missing Data:
Wait _____ minutes to recover data before trading

Duplicate Candle:
Reload and verify before execution
```

---

## SECTION 8: BACKTESTING STRATEGY

### 8.1 Backtesting Framework
**Decision:** How to properly test before live trading?

```
PHASE 1: DATA VALIDATION (Week 1)
- Backtest 2-4 weeks historical data
- Verify volume profile calculations
- Check for data errors
- Expected outcome: System runs without crashes

PHASE 2: SETUP SEPARATION (Week 2-3)
- Test Setup 1 only on daily/4H
- Test Setup 2 only on intraday
- Identify which setups work on which TF
- Target: 50+ trades minimum per setup

PHASE 3: COMBINED TESTING (Week 3-4)
- Run both setups simultaneously
- Test position management rules
- Verify risk calculations
- Test edge case scenarios
- Target: 100+ combined trades

PHASE 4: EXTENDED HISTORY (Week 4-6)
- Backtest 1-2 years of data
- Test through different market conditions (bull, bear, range)
- Verify drawdown limits
- Check win rate consistency
- Target: 200-500 trades across timeframes

ACCEPTANCE CRITERIA FOR LIVE:
✓ Win rate: > 45% (higher is better)
✓ Risk/Reward ratio: > 1:1.5
✓ Drawdown: < 15% (Tier 2 alert level)
✓ Profit factor: > 1.3 (gross profit ÷ gross loss)
✓ Consecutive losses: < 6 in a row
✓ No major anomalies or errors
```

**Your Backtest Plan:**
```
Phase 1 Data: _____ to _____ (weeks)
Phase 2 Duration: _____ weeks
Phase 3 Duration: _____ weeks  
Phase 4 History: _____ years

Minimum Trade Counts:
Setup 1: _____ trades
Setup 2: _____ trades
Combined: _____ trades

Success Thresholds:
Win Rate: ____% minimum
Risk/Reward: 1:_____ minimum
Max Drawdown: ____% acceptable
```

### 8.2 Performance Metrics to Track
**Decision:** What metrics matter most?

```
ESSENTIAL METRICS:

1. Win Rate (% of winning trades)
   Target: > 45%
   Formula: (# winning trades ÷ total trades) × 100

2. Risk/Reward Ratio (Average win ÷ average loss)
   Target: > 1.5
   Example: Avg win $150, avg loss $100 = 1.5:1

3. Profit Factor (Gross profit ÷ gross loss)
   Target: > 1.3
   Example: Total profit $3,900, total loss $3,000 = 1.3

4. Expectancy (Average profit/loss per trade)
   Target: Positive
   Formula: (Win rate × avg win) - ((1-win rate) × avg loss)

5. Drawdown (Peak to trough equity decline)
   Target: < 15%
   Critical: Track max drawdown

6. Recovery Factor (Total profit ÷ max drawdown)
   Target: > 2.0
   Shows how quickly you recover from losses

7. Consecutive Losses (Max losing streak)
   Monitor: Should be < 6-7 in a row

OPTIONAL METRICS:

- Consecutive Wins (positive streak)
- Average Duration per Trade
- Monthly Returns
- Sharpe Ratio (risk-adjusted returns)
- Sortino Ratio (downside risk only)
```

**Your Metric Focus:**
```
Must Track:
□ Win Rate (target: ____%)
□ Risk/Reward (target: 1:____)
□ Profit Factor (target: > ____)
□ Drawdown (limit: ____%)
□ Max Consecutive Losses (limit: ____ trades)

Additional Tracking:
□ Average trade duration
□ Monthly returns by month
□ Setup 1 vs Setup 2 separate performance
□ Performance by instrument/TF
```

### 8.3 Optimization Approach
**Decision:** What parameters to optimize?

```
DO NOT OPTIMIZE (Curve-fit trap):
- Lookback period (keep at 150)
- Value Area % (keep at 70%)
- Row Count (keep at 400)
- Volume spike multiplier (keep at 1.3x)
Why: These are mathematically determined, not parameters

SAFE TO OPTIMIZE:
- Lot sizing (risk % range: 0.5-2.0%)
- Max consecutive losses before stop (2-6 trades)
- Daily loss limit (% of account)
- Timeframe selection (test different TF combos)
- Setup 1 vs Setup 2 balance (which to emphasize)
- Entry/exit conditions (add extra confirmations)

OPTIMIZATION METHOD:
1. Run baseline: Setup 1 daily + Setup 2 H1
2. Test variation 1: More conservative (lower risk %)
3. Test variation 2: More aggressive (higher risk %)
4. Test variation 3: Setup 2 on M15 instead of H1
5. Compare metrics, pick best without overfitting
```

**Your Optimization Plan:**
```
Baseline Configuration: ________________
Parameter to test 1: ________________
Parameter to test 2: ________________
Parameter to test 3: ________________

Optimization Rules:
- Keep lookback at: 150 bars
- Keep VA % at: 70%
- Keep row count at: 400
- Keep volume spike at: 1.3x

Curve-Fit Prevention:
□ Use out-of-sample data (last 25% for validation)
□ Don't re-optimize monthly
□ Change only one parameter at a time
```

---

## SECTION 9: PERFORMANCE MONITORING

### 9.1 Monthly Review Process
**Decision:** How to track live performance?

```
TRACKING ELEMENTS:

Daily Log:
- All trades (entry/exit/result)
- Setup type (Setup 1 or 2)
- Win/loss count
- Cumulative P&L
- Drawdown at close

Weekly Summary:
- Total trades
- Win rate
- Largest loss
- Largest win
- Weekly P&L
- Comparison vs. backtest

Monthly Report:
- 30-day performance
- Setup 1 performance separately
- Setup 2 performance separately
- Instrument/TF breakdown
- Drawdown analysis
- Any system failures
- Rule violations

MONTHLY REVIEW MEETING:
1. Does live performance match backtest?
   - If NO: System may be flawed
   - If YES: Continue with confidence
2. Any unusual losses?
   - Market anomalies? News?
   - System errors? Rule violations?
3. Metrics trending up or down?
   - Win rate declining? Investigate
   - Drawdown increasing? Reduce size
4. Any changes needed?
   - Rule adjustments
   - Parameter tweaks
   - Setup emphasis changes
```

**Your Monitoring Plan:**
```
Daily Log: □ Automatic (EA logs)  □ Manual spreadsheet
Weekly Summary: □ Auto email  □ Manual review
Monthly Report: □ Detailed analysis

Review Frequency: Every _____ days
Metrics Dashboard: □ MT5 native  □ Custom Excel

Success Criteria (Monthly):
P&L vs Account: ____% target
Win Rate: ____% minimum
Max Drawdown: ____% limit
Consecutive Losses: Max _____ trades
```

### 9.2 Live Trading Safeguards
**Decision:** What automated safety limits?

```
SOFT LIMITS (Warnings, reduce activity):
- Daily P&L loss > 2% → reduce lot size by 25%
- Drawdown > 10% → alert, manual override
- Win rate dropping < 40% over 20 trades → review
- Spread exceeds 5x normal → skip trading

HARD STOPS (Automatic trading halt):
- Daily loss > 3% → STOP all trading until next day
- Drawdown > 15% → STOP all trading
- Max consecutive losses > 6 → STOP trading
- Critical system error → STOP immediately
- Broker connection lost → STOP immediately

MANUAL OVERRIDES:
You can override soft limits
Cannot override hard stops without code change

LOGGING:
Every stop/limit trigger logged with:
- Timestamp
- Reason
- Action taken
- Equity status
```

**Your Safety Limits:**
```
Soft Limit 1: ________________
  Action: ________________
  
Soft Limit 2: ________________
  Action: ________________

Hard Stop 1: ________________
Soft Limit 2: ________________

Manual Override Allowed: □ Yes  □ No (Recommended: No)
```

---

## SECTION 10: IMPLEMENTATION CHECKLIST

### 10.1 Pre-Coding Decisions (Complete these NOW)

```
MARKET SELECTION
□ Primary instrument(s) identified: ___________
□ Liquidity requirements confirmed: ___________
□ Account type chosen: ___________

TIMEFRAME STRATEGY
□ Setup 1 timeframe selected: _____
□ Setup 2 timeframe selected: _____
□ Lookback period: 150 bars (confirmed)
□ Trade frequency target: _____ per day

SESSION MANAGEMENT
□ Session definition (RTH/24h): _____
□ Session open time: _____
□ Session close time: _____
□ Previous session calculation method: _____

POSITION MANAGEMENT
□ Max simultaneous positions: _____
□ Position queuing rule: _____
□ Max trade duration per setup: _____

RISK MANAGEMENT
□ Risk per trade: _____ %
□ Daily loss limit: _____%
□ Drawdown alert levels set: 10%, 15%, 20%
□ Drawdown critical stop: _____%

TRADING HOURS
□ Setup 1 session hours: _____
□ Setup 2 session hours: _____
□ News event filter: □ Skip all  □ Selective
□ Calendar exclusions listed: _____

EDGE CASE HANDLING
□ Gap handling rules: _____
□ Slippage tolerance: _____ pips
□ System failure recovery: _____
□ Data quality checks: _____

BACKTESTING
□ Phase 1 data range: _____
□ Phase 2 planned: _____ weeks
□ Minimum trades per setup: _____
□ Success criteria defined: _____

MONITORING
□ Review frequency: every _____ days
□ Key metrics identified: _____
□ Alert system: □ Email  □ Dashboard  □ Manual
□ Hard stops configured: _____
```

### 10.2 Code Design Decisions

```
ARCHITECTURE
□ Single EA file or multiple?
□ Use iCustom() for indicators?
□ Store profile data: □ Memory arrays  □ Persistent file
□ Magic number for order tracking: _____

DATA STRUCTURES
□ struct for HVN/LVN nodes: Designed
□ struct for profile levels: Designed
□ struct for session data: Designed
□ Array organization: Designed

INPUT PARAMETERS
□ All 15+ parameters with defaults: Specified
□ Parameter groups: Organized
□ Documentation: Comments added

FUNCTIONS TO CODE
□ CalculateVolumeProfile(): 150+ lines
□ CalculatePreviousSessionProfile(): 100+ lines
□ IdentifyVolumeNodes(): 100+ lines
□ ExecuteSetup1_MeanReversion(): 80+ lines
□ ExecuteSetup2_HVNEdgeTrading(): 100+ lines
□ CalculateLotSize(): 30+ lines
□ ErrorHandling & Logging: 50+ lines
□ Total estimate: 800-1000 lines

ERROR HANDLING
□ Connection loss recovery: Planned
□ Order rejection handling: Planned
□ Data corruption detection: Planned
□ Trade execution verification: Planned

LOGGING
□ Trade entry/exit logged: Yes
□ Setup signals logged: Yes
□ Error messages logged: Yes
□ Performance metrics logged: Yes
```

### 10.3 Testing Plan Outline

```
UNIT TESTING
□ Volume distribution algorithm: 
  - Test with known candle data
  - Verify bin calculations
  - Check multi-level candle prorating
  
□ POC/VAH/VAL calculation:
  - Test with 400, 300, 500 bins
  - Verify 70% calculation
  - Edge cases (no movement, extreme volatility)

□ HVN/LVN detection:
  - Test percentile logic
  - Verify peak/valley detection
  - Multiple nodes handling

□ Position sizing:
  - Risk % calculation verified
  - Fixed lot sizing verified
  - Account balance changes handled

INTEGRATION TESTING
□ Setup 1 full flow: Signal → Entry → SL/TP → Close
□ Setup 2 full flow: Signal → Entry → SL/TP → Close
□ Simultaneous setups: Both triggering at same time
□ Position management: Multiple positions (if allowed)
□ Risk limits: Daily loss limit, drawdown limits

SCENARIO TESTING
□ Overnight gap: System handles correctly
□ Weekend gap: Previous session isolation works
□ News spike: Data validated, slippage managed
□ Low liquidity: Spread widens, trading paused
□ Connection loss: Recovery works
□ Order rejection: Logged, retried

PERFORMANCE TESTING
□ CPU usage: < 5% normally, < 10% at trade time
□ Memory usage: Arrays efficient, no leaks
□ Backtesting speed: 100K candles processed in < 1 min
□ Live execution: Order sent within 500ms of signal
```

---

## SECTION 11: FINAL CHECKLIST BEFORE CODING STARTS

```
PLANNING DOCUMENTS COMPLETED
□ Market selection confirmed
□ Timeframe strategy finalized
□ Session management defined
□ Risk management rules set
□ Trading hours selected
□ Edge cases documented
□ Backtesting plan created
□ Performance metrics identified

KNOWLEDGE VERIFIED
□ 400-bin algorithm understood
□ 70% Value Area logic clear
□ Setup 1 execution flow confirmed
□ Setup 2 execution flow confirmed
□ HVN/LVN identification methods verified
□ Volume prorating algorithm understood

PARAMETERS SPECIFIED
□ All 15+ input parameters defined
□ Default values set
□ Parameter ranges documented
□ Risk calculations tested manually

TESTING PREPARED
□ Backtest data sources available
□ Spreadsheet for tracking ready
□ Acceptance criteria written
□ Success metrics clear

RISK LIMITS CONFIRMED
□ Daily loss limit: _____
□ Weekly loss limit: _____
□ Drawdown trigger levels: 10%, 15%, 20%
□ Max position size: _____

GO/NO-GO DECISION
□ All planning items complete: YES / NO
□ Ready to proceed to coding: YES / NO
□ Outstanding questions: _________________

SIGN-OFF DATE: __________

If any item is unchecked or answer is NO:
→ STOP and resolve before proceeding
→ Planning phase not complete
→ Coding without clear plan = wasted time
```

---

## SECTION 12: COMMON PITFALLS TO AVOID

```
PITFALL 1: Jumping to Code Too Soon
Problem: Start coding before decisions made
Result: Mid-project architectural changes, wasted code
Solution: Complete ALL planning items first
Status: ________________

PITFALL 2: Over-Optimizing Parameters
Problem: Backtest 100 different combinations
Result: Curve-fitting, poor live performance
Solution: Stick to 150 bars, 400 bins, 70% VA, 1.3x volume
Status: ________________

PITFALL 3: Ignoring Edge Cases
Problem: Test only "perfect" market conditions
Result: System fails on gaps, news, liquidity issues
Solution: Design edge case handling upfront
Status: ________________

PITFALL 4: Insufficient Backtesting
Problem: 50 trades considered "enough"
Result: Unlucky string of losses destroys confidence
Solution: Minimum 200-500 trades before live
Status: ________________

PITFALL 5: No Position Management
Problem: Multiple trades pile up unexpectedly
Result: Confusion, contradictory SL/TP, losses
Solution: Clear rules on simultaneous positions
Status: ________________

PITFALL 6: Ignoring Session Context
Problem: Setup 1 doesn't distinguish sessions
Result: False signals, trading against setup logic
Solution: Proper previous session profile calculation
Status: ________________

PITFALL 7: Vague Risk Rules
Problem: "Risk about 1% per trade"
Result: Actually risking 2-3%, drawdown unsustainable
Solution: Explicit calculations, automated position sizing
Status: ________________

PITFALL 8: No Monitoring System
Problem: "I'll check trades when I can"
Result: Miss critical alerts, system drifts
Solution: Daily review process, alert system
Status: ________________
```

---

## APPROVAL & SIGN-OFF

**Planning Phase Status:** ☐ NOT STARTED  ☐ IN PROGRESS  ☐ COMPLETE

**Completed By:** ________________  
**Date:** ________________  
**Time Invested:** _____ hours  

**Ready for Coding?**
- [ ] YES - All decisions made, planning complete
- [ ] NO - Outstanding items (list below)

**Outstanding Items (if NO):**
1. _________________________________
2. _________________________________
3. _________________________________

**Next Steps:**
1. Share this completed document
2. Proceed to MQL5 code development
3. Use Volume_Profile_EA_Code_Framework.mq5 as starter template
4. Reference ACCURACY_CHECK for technical specifications
5. Follow backtesting plan in Phase 1-4

**Estimated Coding Time (now that planning is done):** 10-13 hours

---

**END OF PRE-CODING PLANNING FRAMEWORK**
