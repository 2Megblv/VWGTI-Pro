# CUSTOMIZED DEVELOPMENT PACKAGE
## Your Personalized Volume Profile MT5 EA Configuration

**Created:** May 2, 2026  
**Status:** ✅ READY FOR CODING  
**Phase:** 2 - MQL5 Development

---

## 📋 YOUR QUESTIONNAIRE SUMMARY

### **TIER 1: MARKET SELECTION** ✅

| Question | Your Answer | Notes |
|----------|-------------|-------|
| **Q1 - Primary Instrument** | Gold, Oil, Indices, EURUSD, GBPJPY | Multi-instrument approach - Start with ONE primary |
| **Q2 - Market Type** | Futures (Real Volume) | ✅ Real volume available - Excellent for accuracy |
| **Q3 - Account Size** | $250,000 | Large account - Allows substantial position sizing |
| **Q4 - Available Leverage** | 1:50 | Moderate leverage - Good risk control |
| **Q5 - Avg Daily Volume** | 10M | Sufficient liquidity for futures trading |
| **Q6 - Typical Spread** | Broker-dependent | Monitor actual spreads daily |

---

### **TIER 1: TIMEFRAME STRATEGY** ✅

| Question | Your Answer | Notes |
|----------|-------------|-------|
| **Q7 - Setup 1 TF** | 15-minute | ⚠️ Non-standard (typical: Daily/4H) - See notes below |
| **Q8 - Setup 2 TF** | 5-minute (M5) | ✅ Aggressive intraday - Good for HVN edge trades |
| **Q9 - Lookback Period** | 400 bars | ⚠️ Larger than 150 (typical) - Captures more history |
| **Q10 - Trades/Day** | 3-5 (Aggressive) | High frequency - More trades, more slippage impact |

**⚠️ SPECIAL CONFIGURATION NEEDED:**
- Setup 1 at M15 (not daily) = Shorter session windows, more frequent setups
- Lookback at 400 bars (not 150) = Each candle affects 400-bin calculation differently
- Aggressive frequency = Need tight risk controls to prevent daily loss limit hits

---

### **TIER 1: RISK MANAGEMENT** ✅

| Question | Your Answer | Notes |
|----------|-------------|-------|
| **Q11 - Risk Method** | Risk % of Account | ✅ Dynamic sizing - Adapts to account changes |
| **Q11a - Risk %** | 1% | ✅ Conservative - Good for longevity |
| **Q12 - Daily Loss Limit** | 2% | ✅ Reasonable - $5,000 max loss/day |
| **Q13 - Drawdown Critical** | 6% | ✅ Moderate - $15,000 max drawdown |
| **Q14 - Max Positions** | Multiple Allowed | More complex - Requires position tracking |

**RISK CALCULATION:**
```
Account Balance: $250,000
Risk Per Trade: 1% = $2,500 per trade
Daily Loss Limit: 2% = $5,000 max loss/day
Drawdown Critical: 6% = $15,000 max total drawdown

Max Trades Before Daily Stop: 
  If avg loss = $2,500 → 2 losing trades = daily limit
  If avg win = $3,750 → 1 win covers 1.5 losses
```

---

### **TIER 1: SESSION MANAGEMENT** ✅

| Question | Your Answer | Notes |
|----------|-------------|-------|
| **Q15 - Previous Session** | Previous RTH Session | ✅ Session-aware - Good for Setup 1 |
| **Q16 - Session Open** | Tokyo + 2 hours | Custom timing - Specific to your strategy |
| **Q17 - Session Close** | 15 min before NY close | Sharp cutoff - Avoid end-of-day volatility |
| **Q18 - Timezone** | GMT | ✅ Standard for international markets |

**SESSION WINDOW DEFINITION:**
```
Trading Window: Tokyo + 2hr to 15 min before NY close
Example (GMT):
  Tokyo Open: 21:00 GMT
  Your Start: 23:00 GMT (Tokyo + 2hr)
  NY Close: 21:00 GMT
  Your Stop: 20:45 GMT (15 min before NY close)

Duration: ~22 hours trading window
Note: Covers most major sessions except early Asian
```

---

### **TIER 2: TRADING HOURS & FILTERS** ✅

| Question | Your Answer | Notes |
|----------|-------------|-------|
| **Q19 - Setup 1 Hours** | Tokyo + 2hr to NY Close | ✅ Unified window |
| **Q20 - Setup 2 Hours** | Tokyo + 2hr to NY Close | ✅ Same window as Setup 1 |
| **Q21 - News Filter** | 30min Before/After Events | ✅ Good protection - Avoids gap risk |

---

### **TIER 2: BACKTESTING PLAN** ✅

| Question | Your Answer | Notes |
|----------|-------------|-------|
| **Q22 - Min Trades Setup 1** | 50 trades | Minimum validation - Conservative |
| **Q23 - Min Trades Setup 2** | 50 trades | Minimum validation - Conservative |
| **Q24 - Win Rate Target** | 65% | ⚠️ Very aggressive (typical: 45-55%) |
| **Q25 - Risk/Reward Target** | 1:1.8 | ✅ Good ratio - 1.8x avg loss per win |

**BACKTESTING CRITERIA:**
```
Must achieve ALL of these to proceed to live trading:
✓ Setup 1: 50+ trades with 65%+ win rate
✓ Setup 2: 50+ trades with 65%+ win rate
✓ Combined: 100+ trades maintaining 65% win rate
✓ Drawdown never exceeds 6%
✓ Profit Factor > 1.5 (total profit ÷ total loss)
✓ Risk/Reward minimum 1:1.8

If any metric fails: Return to optimization phase
```

---

## 🔴 CLARIFICATIONS & SPECIAL NOTES

### **Issue 1: Multiple Primary Instruments** ⚠️
**Your Answer:** Gold, Oil, Indices, EURUSD, GBPJPY

**Recommendation:** Start with ONE primary instrument for initial development:
```
Option A: Gold (GC) - Single commodity, clear structure
Option B: EURUSD - Most liquid, tight spreads
Option C: ES (S&P 500) - Index futures, strong volume

Once Setup 1 & 2 work on primary, then expand to others
Multi-instrument coding = More complexity, testing challenges
```

**Action Required:** Confirm your PRIMARY instrument before coding starts

---

### **Issue 2: Setup 1 at M15 (Unusual Choice)** ⚠️
**Your Answer:** 15-minute timeframe for Setup 1

**Knowledge Base Recommendation:** Daily or 4-Hour (requires clear session structure)

**Your Configuration:** M15 = More trades, but:
- Shorter session windows (2.5 hours of setup 1 data)
- More false signals possible
- Tighter stops needed (larger %)

**Proceed?** YES/NO - Confirm you want M15 for Setup 1

---

### **Issue 3: Lookback at 400 Bars (Non-Standard)** ⚠️
**Your Answer:** 400 bars

**Standard:** 150 bars (proven in knowledge base)

**Your Choice Impact:**
```
150 bars lookback:
  - 5min TF: 12.5 hours history
  - 15min TF: 37.5 hours history
  - Daily TF: 150 days = 5 months

400 bars lookback:
  - 5min TF: 33 hours history
  - 15min TF: 100 hours history
  - Daily TF: 400 days = ~1 year history

Larger lookback = More volume data in profile
Trade-off: Slower calculation, uses more memory
```

**Recommendation:** Keep at 150 for efficiency, test 400 after v1.0 success

**Proceed at 400?** YES/NO - Confirm preference

---

### **Issue 4: Win Rate Target at 65%** ⚠️
**Your Answer:** 65% win rate required to proceed live

**Knowledge Base Target:** 45-55% (more realistic)

**Your Target Implication:**
```
65% win rate = Only 2 losses per ~5.7 trades
Very aggressive expectation
Higher risk of rejecting working system

Typical Profitable Systems:
  Conservative: 40-45% win rate
  Moderate: 50-55% win rate
  Aggressive: 55-65% win rate
  Exceptional: 65%+

Recommendation: Start with 55% target, adjust if consistent
```

**Proceed at 65%?** YES/NO - OR would 55% be more reasonable?

---

## 📝 MQL5 INPUT PARAMETERS (YOUR CONFIGURATION)

```mql5
// ===== CUSTOM INPUT PARAMETERS - YOUR SPECIFIC CONFIGURATION =====

// Market & Instrument Settings
input string Primary_Instrument = "GC";        // Gold (your primary - CONFIRM)
input ENUM_TIMEFRAME Setup1_Timeframe = PERIOD_M15;  // 15-minute
input ENUM_TIMEFRAME Setup2_Timeframe = PERIOD_M5;   // 5-minute

// Volume Profile Settings
input int Lookback_Period = 400;               // 400 bars (non-standard)
input int ROW_COUNT = 400;                     // Fixed: 400 price bins
input double VALUE_AREA_PERCENT = 0.70;        // Fixed: 70% threshold
input ENUM_APPLIED_VOLUME Volume_Source = VOLUME_REAL; // Real Volume (Futures)

// Risk Management - YOUR SETTINGS
input bool Use_Risk_Percentage = true;         // Risk % method (YES)
input double Risk_Percentage = 1.0;            // 1% per trade
input double Daily_Loss_Limit = 2.0;           // 2% daily max loss = $5,000
input int Max_Daily_Trades = 5;                // 3-5 per day target

// Drawdown Management
input double Drawdown_Tier1_Alert = 10.0;      // Alert at 10% ($25,000)
input double Drawdown_Tier2_Reduce = 15.0;     // Reduce size at 15% ($37,500)
input double Drawdown_Tier3_Critical = 6.0;    // STOP at 6% ($15,000) - YOUR SETTING
input double Tier2_Size_Reduction = 0.5;       // Cut to 50% size at Tier 2

// Position Management
input bool Allow_Multiple_Positions = true;    // Multiple positions allowed
input int Max_Simultaneous_Positions = 3;      // Typical for multi-setup

// Session Management - YOUR CUSTOM TIMES
input string SessionOpen_CustomTime = "23:00 GMT";  // Tokyo + 2 hours
input string SessionClose_CustomTime = "20:45 GMT"; // 15 min before NY close
input string SessionTimezone = "GMT";
input bool Use_RTH_Session = true;             // Previous RTH session

// Trading Hours Filters
input string Setup1_Hours = "23:00-20:45 GMT"; // Tokyo + 2hr to NY close
input string Setup2_Hours = "23:00-20:45 GMT"; // Same window as Setup 1

// News Event Protection
input bool Filter_News_Events = true;
input int News_Buffer_Minutes = 30;            // 30 min before/after

// Backtesting Acceptance Criteria
input double Success_WinRate = 65.0;           // YOUR TARGET: 65% (very aggressive)
input double Success_RiskReward = 1.8;         // YOUR TARGET: 1:1.8
input double Success_MinProfitFactor = 1.5;    // Minimum profit factor
input int Success_MinTrades = 50;              // Per setup minimum

// Magic Number for Order Tracking
input int EA_MagicNumber = 25000;              // Futures trading EA marker

// ===== END CUSTOM PARAMETERS =====
```

---

## ✅ DEVELOPMENT CHECKLIST (YOUR SPECIFIC SETUP)

### **Phase 2: MQL5 Development**

```
BEFORE CODING:
[ ] Confirm PRIMARY instrument (not 5 instruments)
[ ] Confirm M15 for Setup 1 (or revert to D/H4)
[ ] Confirm 400 bars lookback (or revert to 150)
[ ] Confirm 65% win rate target (or adjust to 55%)

DURING CODING:
[ ] Implement real volume source (futures-specific)
[ ] Custom session timing: "Tokyo + 2hr" to "20:45 GMT"
[ ] M15 + M5 dual timeframe logic
[ ] Multi-position tracking (up to 3 simultaneous)
[ ] 1% risk per trade with $5,000 daily limit
[ ] 6% drawdown critical stop (strict enforcement)
[ ] 30-minute news event buffer

CODE SECTIONS NEEDED:
[ ] GetSessionOpenTime() - Calculate "Tokyo + 2 hours" dynamically
[ ] GetSessionCloseTime() - "15 minutes before NY close"
[ ] MultiPositionTracker() - Track up to 3 simultaneous positions
[ ] RealVolumeSource() - Pull real volume data (not tick)
[ ] NewsEventFilter() - Check economic calendar
```

---

## 📊 BACKTESTING SEQUENCE (YOUR PLAN)

### **Phase 1: Data Validation (Week 1)**
```
Duration: 3-5 days
Data: 2-4 weeks recent (M5 & M15 data)
Goal: System runs without errors
Expected Trades: 20-40 trades

Your targets:
- 20+ Setup 1 trades (M15)
- 20+ Setup 2 trades (M5)
- Drawdown stays < 6%
```

### **Phase 2: Setup Separation (Weeks 2-3)**
```
Duration: 1-2 weeks
Data: 3-6 months history

Setup 1 Testing (M15):
- Run ONLY Setup 1
- Achieve 50+ trades minimum
- Check: Win rate > 65%? If not, system adjustment needed
- Check: Daily stops working correctly?

Setup 2 Testing (M5):
- Run ONLY Setup 2
- Achieve 50+ trades minimum
- Check: Win rate > 65%? If not, system adjustment needed
```

### **Phase 3: Combined Testing (Weeks 3-4)**
```
Duration: 1-2 weeks
Both setups enabled
Multi-position rules active

Tracking:
- Total trades: 50+ Setup 1 + 50+ Setup 2 = 100+ combined
- Win rate: Maintain 65% average
- Drawdown: Never exceed 6%
- Position conflicts: How multi-position performs
```

### **Phase 4: Extended History (Weeks 4-6)**
```
Duration: 2-3 weeks
Data: Your preference (1-2 years?)
Expected Trades: 300-500+

Validation:
- Win rate consistency across all periods
- Drawdown behavior through different markets
- Monthly P&L variation
- Setup 1 vs Setup 2 individual performance
```

---

## 🚀 NEXT IMMEDIATE STEPS

### **BEFORE CODE STARTS (TODAY):**

**MUST RESOLVE - 3 Critical Clarifications:**

1. **PRIMARY INSTRUMENT** ❓
   - Current: 5 instruments (Gold, Oil, Indices, EURUSD, GBPJPY)
   - Decision: Which ONE to code first?
   - Answer: **__________________**

2. **SETUP 1 TIMEFRAME** ❓
   - Current: M15 (unusual, non-standard)
   - Knowledge Base: D or H4 recommended
   - Decision: Keep M15 or change to 4-Hour?
   - Answer: **__________________**

3. **WIN RATE TARGET** ❓
   - Current: 65% (very aggressive)
   - Typical: 45-55% (realistic)
   - Decision: Keep 65% or adjust to 55%?
   - Answer: **__________________**

**OPTIONAL - Nice to Clarify:**

4. **Lookback Period** (optional)
   - Current: 400 bars (slower processing)
   - Standard: 150 bars (faster, proven)
   - Preference: Keep 400 or revert to 150?
   - Answer: **__________________**

---

### **AFTER CLARIFICATIONS (TOMORROW):**

1. ✅ Create customized MQL5 code file with YOUR parameters
2. ✅ Generate custom position tracking for multi-position logic
3. ✅ Build session timing calculation for "Tokyo + 2 hours"
4. ✅ Implement real volume source (futures-specific)
5. ✅ Provide step-by-step coding checklist
6. ✅ Green-light PHASE 2: Development Start

---

## 📋 YOUR APPROVAL

**All questionnaire data extracted and reviewed.**

**Status:** Awaiting your 3 critical clarifications above.

**Once you provide those 3 answers, you are ready to:**
- ✅ Start MQL5 coding
- ✅ Reference your custom parameters
- ✅ Follow your personalized development checklist
- ✅ Backtest to your specific criteria

---

**TIME TO CODE:** Estimated **10-13 hours** once clarifications are resolved

**TIMELINE:** 
- Days 1-2: Clarifications + customization
- Days 3-5: MQL5 development
- Week 2-6: Backtesting phases 1-4
- Week 7+: Live trading (if backtesting passes)

---

**Please provide your 3 answers above and we'll proceed immediately to PHASE 2!** 🚀

