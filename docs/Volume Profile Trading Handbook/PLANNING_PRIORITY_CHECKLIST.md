# Pre-Coding Planning: Priority Checklist
## Essential Decisions Before Writing Any Code

**Status:** 🔴 **MUST COMPLETE** | **Est. Time:** 4-6 hours | **Criticality:** BLOCKING

---

## 🔴 TIER 1: CRITICAL (MUST DECIDE - Blocks Everything)

These decisions affect the entire EA architecture. **CANNOT CODE WITHOUT THESE.**

### T1.1: What markets/instruments to trade?
```
Decision Point: Choose 1-3 primary instruments
Examples: EURUSD, GBPUSD, ES (S&P 500), QQQ, BTC/USD
Current Status: [ ] NOT DECIDED  [ ] TENTATIVE  [ ] FINAL

Why Critical: 
- Determines volume data source (Tick vs Real)
- Affects liquidity requirements
- Drives minimum account size
- Changes slippage assumptions

Your Answer: _________________
```

### T1.2: What is your account size & leverage available?
```
Decision Point: Starting capital and broker leverage
Examples: $5,000 account with 1:100 leverage (micro)
Current Status: [ ] NOT DECIDED  [ ] TENTATIVE  [ ] FINAL

Why Critical:
- Determines lot sizing calculations
- Affects risk per trade (% of equity)
- Influences daily/weekly loss limits
- Drives position size decisions

Your Answer: Account $_________, Leverage 1:_____
```

### T1.3: Setup 1 timeframe (80% Rule)?
```
Decision Point: Daily, 4H, or H1 for mean reversion setup
Current Status: [ ] NOT DECIDED  [ ] TENTATIVE  [ ] FINAL

Why Critical:
- Determines session management approach
- Affects lookback period (bars to analyze)
- Drives update frequency of EA
- Changes previous session calculation

Recommendation: Daily or 4H (requires clear session structure)
Your Answer: _____
```

### T1.4: Setup 2 timeframe (HVN Edge Trading)?
```
Decision Point: H1, M15, or M5 for HVN edge trades
Current Status: [ ] NOT DECIDED  [ ] TENTATIVE  [ ] FINAL

Why Critical:
- Number of trades per day
- Position hold duration
- Stop loss distance in pips
- Capital requirements

Recommendation: M15 or H1 (balances frequency with accuracy)
Your Answer: _____
```

### T1.5: Risk per trade (% or fixed lot)?
```
Decision Point: How much money at risk per trade?
Examples: 1% of account ($100/trade for $10k account)
Current Status: [ ] NOT DECIDED  [ ] TENTATIVE  [ ] FINAL

Why Critical:
- Determines lot size calculation
- Affects drawdown depth
- Impacts recovery from losses
- Drives daily loss limits

Conservative: 0.5-1.0%
Moderate: 1.0-1.5%
Aggressive: 2.0%+

Your Answer: _____ % or $_______ fixed
```

---

## 🟡 TIER 2: HIGH PRIORITY (SHOULD DECIDE - Impacts Core Logic)

These affect how setups are executed. **NEEDED BEFORE DEVELOPMENT STARTS.**

### T2.1: Max simultaneous positions?
```
Decision Point: Can EA open multiple positions simultaneously?
Options: 
  A) One position max (simplest)
  B) Multiple positions allowed (more complex)
Current Status: [ ] NOT DECIDED  [ ] TENTATIVE  [ ] FINAL

Why Important:
- Affects position management logic
- Changes SL/TP conflict resolution
- Drives code complexity
- Impacts total capital required

Recommendation: START WITH OPTION A (one position max)
Your Answer: ___________________
```

### T2.2: Daily loss limit?
```
Decision Point: What's the maximum daily loss before stopping?
Examples: $200/day, 2% of account, or 3 consecutive losses
Current Status: [ ] NOT DECIDED  [ ] TENTATIVE  [ ] FINAL

Why Important:
- Prevents "revenge trading" after bad days
- Controls equity drawdown
- Provides automatic trading halt
- Protects account from catastrophic loss

Recommended: 2-3% of account per day
Your Answer: _____ % or $_______ per day
```

### T2.3: Session definition (for Setup 1)?
```
Decision Point: How to calculate "previous session" profile?
Options:
  A) Previous calendar day (24 hours back)
  B) Previous RTH session (e.g., 9:30-16:00 for stocks)
Current Status: [ ] NOT DECIDED  [ ] TENTATIVE  [ ] FINAL

Why Important:
- Setup 1 depends on this completely
- Wrong definition = false signals
- Affects session boundary handling
- Drives previous profile storage

For Forex: Previous calendar day (simple)
For Stocks: Previous RTH (more accurate)
Your Answer: _________________
```

### T2.4: Trading hours for Setup 1 & Setup 2?
```
Decision Point: What times of day should each setup trade?
Examples:
  Setup 1: All hours (captures overnight gaps)
  Setup 2: London-NY overlap only (best volume)
Current Status: [ ] NOT DECIDED  [ ] TENTATIVE  [ ] FINAL

Why Important:
- Reduces false signals during low-volume periods
- Captures best market conditions
- Affects trade frequency
- Impacts entry accuracy

Your Answer: Setup 1 hours: _____, Setup 2 hours: _____
```

### T2.5: News event filter?
```
Decision Point: How to handle economic calendar events?
Options:
  A) Skip all trading near news (safest)
  B) Trade with wider stops (balanced)
  C) Skip only high-impact events (selective)
Current Status: [ ] NOT DECIDED  [ ] TENTATIVE  [ ] FINAL

Why Important:
- High-impact news causes huge slippage
- Can hit SLs at unfavorable prices
- Affects win rate consistency
- Changes setup reliability

Recommendation: OPTION A (Skip all news initially)
Your Answer: ___________________
```

---

## 🟢 TIER 3: MEDIUM PRIORITY (SHOULD CLARIFY - Details Matter)

These affect implementation quality. **NICE TO HAVE BEFORE CODING, BUT CAN ADJUST AFTER BACKTESTING.**

### T3.1: Backtest duration & trade count targets?
```
Decision Point: How much historical data to test on?
Examples: 
  Minimum: 100 trades
  Recommended: 200-500 trades
  Thorough: 1000+ trades over 1-2 years
Current Status: [ ] NOT DECIDED  [ ] TENTATIVE  [ ] FINAL

Target Trades:
  Phase 1 (Setup 1): _____ trades
  Phase 2 (Setup 2): _____ trades
  Phase 3 (Combined): _____ trades
```

### T3.2: Success criteria for going live?
```
Decision Point: What performance metrics = "approved for live"?
Examples:
  - Win rate > 50%
  - Risk/Reward > 1:1.5
  - Drawdown < 15%
  - Profit factor > 1.3
Current Status: [ ] NOT DECIDED  [ ] TENTATIVE  [ ] FINAL

Your Criteria:
  Win Rate: ____% minimum
  Risk/Reward: 1:____ minimum
  Max Drawdown: ____% acceptable
  Profit Factor: _____ minimum
```

### T3.3: Slippage & spread assumptions?
```
Decision Point: How much slippage to expect on your broker?
Examples:
  Forex: 1-2 pips average
  Stocks: 1-5 cents
  Futures: 1 tick
Current Status: [ ] NOT DECIDED  [ ] TENTATIVE  [ ] FINAL

Your Assumptions:
  Normal spread: _____ pips/cents
  Max acceptable slippage: _____ pips/cents
  Emergency (halt trading): _____ pips/cents
```

### T3.4: Monitoring & review frequency?
```
Decision Point: How often to review live performance?
Options:
  Daily: Check every morning before trading
  Weekly: Every Sunday evening
  Monthly: End of month full analysis
Current Status: [ ] NOT DECIDED  [ ] TENTATIVE  [ ] FINAL

Your Schedule: Every _____ days
Review items: Trade log, P&L, win rate, drawdown
```

### T3.5: Drawdown alert levels?
```
Decision Point: At what drawdown % to take action?
Examples:
  Tier 1 (Alert): 10% → Review last trades
  Tier 2 (Reduce): 15% → Cut position size 50%
  Tier 3 (Stop): 20% → Pause all trading
Current Status: [ ] NOT DECIDED  [ ] TENTATIVE  [ ] FINAL

Your Levels:
  Alert at: ____% drawdown
  Reduce at: ____% drawdown (cut size: ____%)
  Stop at: ____% drawdown
```

---

## ⚪ TIER 4: OPTIONAL (NICE TO HAVE - Can Use Defaults)

These can be handled with reasonable defaults. **CAN DECIDE DURING CODING IF NEEDED.**

### T4.1: Trading calendar exclusions?
```
Decision Point: Specific days/periods to skip?
Examples: Fridays, last day of month, holidays
Current Status: [ ] NOT NEEDED  [ ] TENTATIVE  [ ] FINAL

Optional Exclusions:
  [ ] Fridays
  [ ] Specific holidays: __________
  [ ] Earnings season (stocks only)
  [ ] Month-end period
```

### T4.2: Edge case handling preferences?
```
Decision Point: How to handle gaps/crashes/errors?
Examples: 
  Gap > 100 pips: Skip entry
  Connection lost: Auto-reconnect
  Data error: Pause and alert
Current Status: [ ] USE DEFAULTS  [ ] CUSTOM

Can use reasonable defaults for now
Review after first 50 trades and adjust
```

### T4.3: Multi-timeframe confirmation?
```
Decision Point: Use higher timeframe confirmation?
Examples: 
  M5 trade confirmed on M15 structure
  H1 trade confirmed on D1 structure
Current Status: [ ] NOT NEEDED (v1.0)  [ ] FUTURE (v2.0)

Recommendation: Skip for version 1.0
Add in version 2.0 after proving base strategy
```

---

## 📋 QUICK DECISION FORM

**Print this out and fill it in (5 minutes):**

```
1. Primary Instrument: _________________
2. Account Size: $_________
3. Setup 1 Timeframe: _____ (D / H4 / H1)
4. Setup 2 Timeframe: _____ (H1 / M15 / M5)
5. Risk Per Trade: _____ %
6. Max Positions: _____ (1 or more)
7. Daily Loss Limit: _____ %
8. Session Definition: _________ (Calendar or RTH)
9. News Filter: _________ (Skip all / Selective)
10. Backtest Target Trades: _____

SIGN-OFF: I have decided on all TIER 1 items above
Initials: _____ Date: ________
```

---

## 🚫 STOP HERE IF:

```
[ ] Any TIER 1 item is NOT DECIDED
[ ] Any TIER 2 item is NOT DECIDED  
[ ] Anything is marked "TENTATIVE" (need final decision)
[ ] You're not confident in your answers

IF YES TO ANY ABOVE:
→ STOP: Do not proceed to coding
→ Complete planning first
→ Ask for help if uncertain
→ Planning now = faster coding + better results

IF NO TO ALL:
→ PROCEED: You're ready to code
→ Use Code Framework as template
→ Reference Planning Framework for decisions
→ Start Phase 1 backtesting as you develop
```

---

## 📊 PLANNING COMPLETION SCORECARD

| Category | Status | Notes |
|----------|--------|-------|
| Market Selection | ☐ Complete | ________________ |
| Account Setup | ☐ Complete | ________________ |
| Timeframe Strategy | ☐ Complete | ________________ |
| Risk Management | ☐ Complete | ________________ |
| Trading Hours | ☐ Complete | ________________ |
| Session Management | ☐ Complete | ________________ |
| Position Rules | ☐ Complete | ________________ |
| Edge Case Handling | ☐ Complete | ________________ |
| Backtest Plan | ☐ Complete | ________________ |
| Monitoring System | ☐ Complete | ________________ |

**Completion Status:** _____ / 10 items complete

**Estimated Coding Start Date:** __________ (when 10/10 complete)

---

## 💡 KEY PRINCIPLE

> **"30 minutes of planning saves 3 hours of coding. 2 hours of planning saves 20 hours of debugging."**

The decisions you make now determine:
- ✅ How fast the code runs
- ✅ How reliable the system is
- ✅ How quickly it makes money
- ✅ How well it survives drawdowns

**Don't skip planning. The code will thank you.**

---

**Document Status: WORKING - Update as you complete items**

**Last Updated:** May 2, 2026  
**Next Review:** When coding starts

---

## 🎯 YOUR NEXT STEP

1. **Right Now (5 min):** Fill out "Quick Decision Form" above
2. **This Hour (30 min):** Complete all TIER 1 items
3. **Next 1-2 Hours:** Work through TIER 2 items  
4. **Next 2-3 Hours:** Review TIER 3 & clarify any questions
5. **Final 30 min:** Sign-off and move to coding

**Total Planning Time: 4-6 hours max**

This is time well spent. Do not skip.

