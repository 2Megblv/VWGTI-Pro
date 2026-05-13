# MT5 Volume Profile EA - Development Specifications
## Complete Technical Specification for MQL5 Implementation

**Created:** May 2, 2026  
**Version:** 1.0  
**Status:** SPECIFICATIONS DRAFT (Awaiting 3 Clarifications)  
**Based On:** CUSTOMIZED_DEVELOPMENT_PACKAGE.md  

---

## TABLE OF CONTENTS

1. [System Overview](#system-overview)
2. [Core Configuration](#core-configuration)
3. [Volume Profile Engine](#volume-profile-engine)
4. [Setup 1: 80% Rule Mean Reversion](#setup-1-80-rule-mean-reversion)
5. [Setup 2: HVN Edge Trading](#setup-2-hvn-edge-trading)
6. [Entry Logic](#entry-logic)
7. [Exit Logic](#exit-logic)
8. [Stop Loss Specifications](#stop-loss-specifications)
9. [Take Profit Specifications](#take-profit-specifications)
10. [Position Sizing & Risk](#position-sizing--risk)
11. [Session Management](#session-management)
12. [News Event Filtering](#news-event-filtering)
13. [Position Management Rules](#position-management-rules)
14. [Drawdown Management Tiers](#drawdown-management-tiers)
15. [Validation & Error Handling](#validation--error-handling)
16. [Backtesting Acceptance Criteria](#backtesting-acceptance-criteria)
17. [Trade Logging & Journal](#trade-logging--journal)
18. [Edge Cases](#edge-cases)

---

## SYSTEM OVERVIEW

### Dual-Setup Architecture

```
Volume Profile EA
├── Setup 1 (M15): 80% Rule Mean Reversion
│   ├── Previous Session Profile Analysis
│   ├── VAL/VAH/POC Calculation
│   ├── Gap & Return to VA Entry
│   └── Target: Previous Session VAH
│
├── Setup 2 (M5): HVN Edge Trading
│   ├── Real-Time Volume Profile
│   ├── LVN Sweep Detection
│   ├── HVN Rebound Entry
│   ├── Candle Pattern Confirmation
│   └── Target: HVN Resistance Level
│
├── Risk Management Module
│   ├── Position Sizing (1% Risk)
│   ├── Daily Loss Limit ($5,000)
│   ├── Drawdown Tiers (10%/15%/6%)
│   └── Multiple Position Tracking
│
└── Session Control
    ├── Tokyo + 2 hours to 20:45 GMT
    ├── News Event Buffer (30 min)
    └── Trading Hours Filters
```

### Key Performance Targets

- **Setup 1 Win Rate:** 65% (YOUR TARGET - AGGRESSIVE)
- **Setup 2 Win Rate:** 65% (YOUR TARGET - AGGRESSIVE)
- **Combined Win Rate:** 65%+
- **Risk/Reward Ratio:** Minimum 1:1.8
- **Profit Factor:** Minimum 1.5 (Total Profit ÷ Total Loss)
- **Max Drawdown:** 6% ($15,000 on $250k account)
- **Daily Loss Limit:** 2% ($5,000)

---

## CORE CONFIGURATION

### Input Parameters

```
// ===== MARKET & INSTRUMENT =====
input string Primary_Instrument = "GC";  // [PENDING: Gold/Oil/Indices/EURUSD/GBPJPY?]
input ENUM_TIMEFRAME Setup1_Timeframe = PERIOD_M15;  // [PENDING: Keep M15 or H4?]
input ENUM_TIMEFRAME Setup2_Timeframe = PERIOD_M5;

// ===== VOLUME PROFILE SETTINGS =====
input int Lookback_Period = 400;        // Bars to analyze
input int ROW_COUNT = 400;              // Price bins (fixed)
input double VALUE_AREA_PERCENT = 0.70; // 70% threshold (fixed)
input ENUM_APPLIED_VOLUME Volume_Source = VOLUME_REAL; // Real volume (futures)

// ===== RISK MANAGEMENT =====
input bool Use_Risk_Percentage = true;
input double Risk_Percentage = 1.0;     // 1% of account per trade
input double Daily_Loss_Limit = 2.0;    // 2% daily max = $5,000
input double Account_Balance = 250000;  // Starting account
input int Max_Daily_Trades = 5;         // 3-5 per day

// ===== DRAWDOWN TIERS =====
input double Drawdown_Tier1_Alert = 10.0;      // Alert at 10%
input double Drawdown_Tier2_Reduce = 15.0;     // Reduce size at 15%
input double Drawdown_Tier3_Critical = 6.0;    // STOP at 6% (YOUR SETTING)
input double Tier2_Size_Reduction = 0.5;       // 50% size reduction

// ===== POSITION MANAGEMENT =====
input bool Allow_Multiple_Positions = true;
input int Max_Simultaneous_Positions = 3;

// ===== SESSION MANAGEMENT =====
input string SessionOpen_Time = "23:00";       // Tokyo + 2 hours (GMT)
input string SessionClose_Time = "20:45";      // 15 min before NY close
input string SessionTimezone = "GMT";
input bool Use_Previous_RTH_Session = true;

// ===== TRADING HOURS FILTERS =====
input string Setup1_Hours_Open = "23:00";
input string Setup1_Hours_Close = "20:45";
input string Setup2_Hours_Open = "23:00";
input string Setup2_Hours_Close = "20:45";

// ===== NEWS EVENT FILTER =====
input bool Filter_News_Events = true;
input int News_Buffer_Minutes = 30;    // 30 min before/after

// ===== BACKTESTING CRITERIA =====
input double Success_WinRate = 65.0;   // [PENDING: Keep 65% or 55%?]
input double Success_RiskReward = 1.8;
input double Success_MinProfitFactor = 1.5;
input int Success_MinTrades = 50;      // Per setup

// ===== MAGIC NUMBERS =====
input int EA_MagicNumber = 25000;
input int Setup1_MagicOffset = 1;      // 25001
input int Setup2_MagicOffset = 2;      // 25002
```

---

## VOLUME PROFILE ENGINE

### 400-Bin Distribution Algorithm

#### Step 1: Initialize Volume Array
```
double volumeProfile[400];     // Volume per price bin
int binCount = 400;
double minPrice, maxPrice;     // Session high/low
double binSize = (maxPrice - minPrice) / binCount;
```

#### Step 2: Multi-Level Candle Prorating

For each candle in lookback period:
```
FOR each candle C in last 400 bars:
  
  candle_open = Open[C]
  candle_close = Close[C]
  candle_high = High[C]
  candle_low = Low[C]
  candle_volume = Volume[C]
  
  // Determine candle direction
  IF candle_close >= candle_open:
    direction = "UP"
    price_range = candle_high - candle_low
  ELSE:
    direction = "DOWN"
    price_range = candle_high - candle_low
  
  // Prorate volume across price levels
  IF price_range > 0:
    FOR each price_level from candle_low to candle_high (step = bin_size):
      bin_index = (price_level - minPrice) / bin_size
      price_percentage = (price_level - candle_low) / price_range
      prorated_volume = candle_volume * (1.0 / (price_range / bin_size))
      volumeProfile[bin_index] += prorated_volume
  ELSE:
    // Doji/Spinning top: distribute volume evenly
    bin_index = (candle_close - minPrice) / bin_size
    volumeProfile[bin_index] += candle_volume

END FOR
```

#### Step 3: Calculate Point of Control (POC)

```
double maxVolume = MAX(volumeProfile[])
int pocBin = INDEX_OF(maxVolume)
double pocPrice = minPrice + (pocBin * binSize) + (binSize / 2)
```

#### Step 4: Calculate Value Area (VAL/VAH)

```
double totalVolume = SUM(volumeProfile[])
double targetVolume = totalVolume * 0.70  // 70% Value Area
double valueAreaVolume = 0
int pocBinIndex = INDEX_OF(MAX(volumeProfile))

// Build Value Area from POC outward
WHILE valueAreaVolume < targetVolume:
  // Add bin above POC
  IF pocBinIndex + offset < ROW_COUNT:
    valueAreaVolume += volumeProfile[pocBinIndex + offset]
  
  // Add bin below POC
  IF pocBinIndex - offset >= 0:
    valueAreaVolume += volumeProfile[pocBinIndex - offset]
  
  offset++

// Find VAH and VAL
double VAH = pocPrice + (offset * binSize)  // High end of VA
double VAL = pocPrice - (offset * binSize)  // Low end of VA
```

#### Step 5: Identify HVN and LVN

```
double averageVolume = totalVolume / ROW_COUNT
double HVN_Threshold = averageVolume * 1.3   // 30% above average

// HVN: High Volume Nodes
ARRAY hvnLevels[]
FOR i = 0 to ROW_COUNT:
  IF volumeProfile[i] > HVN_Threshold:
    price = minPrice + (i * binSize)
    hvnLevels.ADD({price, volumeProfile[i]})

// LVN: Low Volume Nodes (vacuum areas)
ARRAY lvnLevels[]
FOR i = 0 to ROW_COUNT:
  IF volumeProfile[i] < averageVolume * 0.7:
    price = minPrice + (i * binSize)
    lvnLevels.ADD({price, volumeProfile[i]})
```

#### Step 6: Previous Session Profile Calculation (For Setup 1)

```
// Run the above 6 steps separately for "previous session" data
FUNCTION CalculatePreviousSessionProfile():
  
  // Determine session boundaries
  IF Use_Previous_RTH_Session:
    // Previous calendar day (24 hours back)
    startTime = iTime(Symbol(), PERIOD_D1, 1)  // Yesterday's open
    endTime = iTime(Symbol(), PERIOD_D1, 0)    // Today's open
  
  // Extract bars within previous session
  previousSessionBars = GetBarsWithinTimeRange(startTime, endTime)
  
  // Run Steps 1-5 on previous session data only
  CALL VolumeProfileEngine(previousSessionBars)
  
  // Store previous session values
  previousSession.VAL = VAL
  previousSession.VAH = VAH
  previousSession.POC = POC
  previousSession.HVNLevels = hvnLevels[]
  
  RETURN previousSession

END FUNCTION
```

---

## SETUP 1: 80% RULE MEAN REVERSION

### Market Context Detection

```
FUNCTION IsMarketBalanced():
  // Balanced = Value Area width is less than 0.5x average daily range
  
  VAwidth = VAH - VAL
  avgDailyRange = Average(High[0] - Low[0] for last 20 days)
  
  IF VAwidth < (avgDailyRange * 0.5):
    RETURN TRUE   // Balanced market
  ELSE:
    RETURN FALSE  // Imbalanced market
  
END FUNCTION
```

### Entry Conditions (ALL must be TRUE)

```
SETUP_1_ENTRY_CONDITIONS:

1. TIMEFRAME CHECK:
   ✓ Current timeframe must be M15
   ✓ Previous timeframe bar must be complete

2. SESSION WINDOW CHECK:
   ✓ Current time >= 23:00 GMT (Tokyo + 2 hours)
   ✓ Current time <= 20:45 GMT (15 min before NY close)
   ✓ NOT during news event window (30 min buffer)

3. PREVIOUS SESSION PROFILE LOADED:
   ✓ previousSession.VAL != NULL
   ✓ previousSession.VAH != NULL
   ✓ previousSession.POC != NULL

4. GAP FROM PREVIOUS VA:
   ✓ Price opened OUTSIDE previous session Value Area
   
   LONG Entry: Open < previousSession.VAL
   SHORT Entry: Open > previousSession.VAH

5. RETURN TO VA SETUP:
   ✓ Price closed back INSIDE previous session Value Area
   
   FOR LONG:
     Close[0] > previousSession.VAL
     Close[0] < previousSession.VAH
   
   FOR SHORT:
     Close[0] > previousSession.VAL
     Close[0] < previousSession.VAH

6. CONFIRMATION CANDLE (Current/Trigger Candle):
   ✓ Price opens above (LONG) or below (SHORT) entry level
   ✓ Price closes near the open (small wick opposite direction)
   
   FOR LONG CONFIRMATION:
     Open[0] > Entry_Level
     (Close[0] - Open[0]) / PointValue >= Min_Confirmation_Range (4 pips)
     Lower_Wick <= Upper_Wick
   
   FOR SHORT CONFIRMATION:
     Open[0] < Entry_Level
     (Open[0] - Close[0]) / PointValue >= Min_Confirmation_Range (4 pips)
     Upper_Wick <= Lower_Wick

7. DAILY TRADE LIMIT NOT EXCEEDED:
   ✓ Daily_Trades_Today < Max_Daily_Trades (5)

8. NO CONFLICTING POSITIONS:
   ✓ For multiple positions: Max_Simultaneous_Positions not reached
   ✓ If position exists in same direction: Skip (wait for exit first)

9. VOLUME CONFIRMATION:
   ✓ Volume[0] > Average_Volume (last 20 bars)
   
10. DRAWDOWN CHECK:
    ✓ Current_Drawdown <= Drawdown_Tier3_Critical (6%)
    ✓ IF Current_Drawdown > Tier3: STOP all trading (no entries)
```

### Entry Execution

```
FUNCTION ExecuteSetup1Entry():
  
  // Determine direction
  IF Close[0] > previousSession.VAL AND Close[0] < previousSession.VAH:
    // Price returned to VA from below (was below VAL)
    direction = LONG
    entry_price = Ask
    target_price = previousSession.VAH
    sl_distance = entry_price - (previousSession.VAL - 20*Point)  // 20 pips below VAL
  
  ELSE:
    // Price returned to VA from above (was above VAH)
    direction = SHORT
    entry_price = Bid
    target_price = previousSession.VAL
    sl_distance = (previousSession.VAH + 20*Point) - entry_price  // 20 pips above VAH
  
  // Calculate lot size
  risk_amount = Account_Balance * (Risk_Percentage / 100)
  lot_size = CalculateLotSize(risk_amount, sl_distance)
  
  // Validate lot size
  IF lot_size < MinLotSize:
    lot_size = MinLotSize
  IF lot_size > MaxLotSize:
    RETURN FALSE  // Position too small, skip
  
  // Place order
  magic = EA_MagicNumber + Setup1_MagicOffset
  
  IF direction == LONG:
    ticket = OrderSend(Symbol(), OP_BUY, lot_size, Ask, 3, 
                       entry_price - (sl_distance*Point), 
                       target_price, "Setup1-LongEntry", magic)
  ELSE:
    ticket = OrderSend(Symbol(), OP_SELL, lot_size, Bid, 3,
                       entry_price + (sl_distance*Point),
                       target_price, "Setup1-ShortEntry", magic)
  
  IF ticket > 0:
    LOG_TRADE("Setup1_Entry", direction, lot_size, entry_price, target_price, ticket)
    RETURN TRUE
  ELSE:
    LOG_ERROR("Setup1_Entry_Failed", GetLastError())
    RETURN FALSE
  
END FUNCTION
```

---

## SETUP 2: HVN EDGE TRADING

### Entry Conditions (ALL must be TRUE)

```
SETUP_2_ENTRY_CONDITIONS:

1. TIMEFRAME CHECK:
   ✓ Current timeframe must be M5
   ✓ Previous timeframe bar must be complete

2. SESSION WINDOW CHECK:
   ✓ Current time >= 23:00 GMT
   ✓ Current time <= 20:45 GMT
   ✓ NOT during news event window (30 min buffer)

3. REAL-TIME VOLUME PROFILE LOADED:
   ✓ Current_VAL != NULL
   ✓ Current_VAH != NULL
   ✓ HVN_Levels[] array populated

4. LVN SWEEP DETECTION (Vacuum Formation):
   ✓ Price moved into LVN area (vacuum)
   ✓ Volume lower than average during sweep
   ✓ No support/resistance nearby
   
   LONG Setup: Price swept below current VAL into LVN
   SHORT Setup: Price swept above current VAH into LVN

5. HVN REBOUND RECOGNITION:
   ✓ Price reversed from LVN back toward HVN
   ✓ Close occurred above (LONG) or below (SHORT) HVN edge
   
   FOR LONG:
     Close[0] > Nearest_HVN_Below_Current_Price
     
   FOR SHORT:
     Close[0] < Nearest_HVN_Above_Current_Price

6. CANDLE PATTERN CONFIRMATION:
   ✓ Confirmation candle shows reversal structure
   
   VALID PATTERNS:
   - Hammer (LONG): Low < LVN, Close > Open, Body > Wick
   - Hammer (SHORT): High > LVN, Close < Open, Body > Wick
   - Star (LONG): Gap down, small body, close > midpoint
   - Star (SHORT): Gap up, small body, close < midpoint
   - Doji (either): Open ≈ Close, Long wicks both sides
   
   PATTERN LOGIC:
   FOR LONG HAMMER:
     body_size = Close[0] - Open[0]
     lower_wick = Open[0] - Low[0]
     upper_wick = High[0] - Close[0]
     
     IF body_size > 0:  // Close above open
       IF body_size >= (lower_wick * 1.5):  // Body > wick
         PATTERN_CONFIRMED = TRUE
   
   FOR SHORT HAMMER:
     body_size = Open[0] - Close[0]
     upper_wick = High[0] - Open[0]
     lower_wick = Close[0] - Low[0]
     
     IF body_size > 0:  // Open above close
       IF body_size >= (upper_wick * 1.5):  // Body > wick
         PATTERN_CONFIRMED = TRUE

7. VOLUME SPIKE CONFIRMATION:
   ✓ Volume on confirmation candle >= Previous bar volume * 1.3
   
   volume_ratio = Volume[0] / Volume[1]
   IF volume_ratio >= 1.3:
     VOLUME_CONFIRMED = TRUE

8. DAILY TRADE LIMIT NOT EXCEEDED:
   ✓ Daily_Trades_Today < Max_Daily_Trades (5)

9. NO CONFLICTING POSITIONS:
   ✓ Max_Simultaneous_Positions not exceeded
   ✓ No existing position in same direction

10. DRAWDOWN CHECK:
    ✓ Current_Drawdown <= 6%
    ✓ IF Current_Drawdown > Tier3: STOP all trading
```

### Entry Execution

```
FUNCTION ExecuteSetup2Entry():
  
  // Determine direction and entry level
  IF Close[0] > Nearest_HVN:
    direction = LONG
    entry_price = Ask
    hvn_level = Nearest_HVN
    target_price = hvn_level + (hvn_level * 0.002)  // 0.2% above HVN
    sl_price = hvn_level - (hvn_level * 0.005)      // 0.5% below HVN
  ELSE:
    direction = SHORT
    entry_price = Bid
    hvn_level = Nearest_HVN
    target_price = hvn_level - (hvn_level * 0.002)  // 0.2% below HVN
    sl_price = hvn_level + (hvn_level * 0.005)      // 0.5% above HVN
  
  sl_distance = ABS(entry_price - sl_price)
  
  // Calculate lot size
  risk_amount = Account_Balance * (Risk_Percentage / 100)
  lot_size = CalculateLotSize(risk_amount, sl_distance)
  
  // Validate lot size
  IF lot_size < MinLotSize:
    lot_size = MinLotSize
  
  // Place order
  magic = EA_MagicNumber + Setup2_MagicOffset
  
  IF direction == LONG:
    ticket = OrderSend(Symbol(), OP_BUY, lot_size, Ask, 3,
                       sl_price, target_price, "Setup2-HVNEdge-Long", magic)
  ELSE:
    ticket = OrderSend(Symbol(), OP_SELL, lot_size, Bid, 3,
                       sl_price, target_price, "Setup2-HVNEdge-Short", magic)
  
  IF ticket > 0:
    LOG_TRADE("Setup2_Entry", direction, lot_size, entry_price, target_price, ticket)
    RETURN TRUE
  ELSE:
    LOG_ERROR("Setup2_Entry_Failed", GetLastError())
    RETURN FALSE
  
END FUNCTION
```

---

## ENTRY LOGIC

### Priority & Order

```
ENTRY_EXECUTION_SEQUENCE (Every M5 candle close):

1. Check system status
   - Is EA enabled?
   - Trading hours valid?
   - News event buffer?
   
2. Update Volume Profile
   - Recalculate all 400 bins
   - Update POC, VAL, VAH, HVN, LVN
   - Refresh previous session data
   
3. Check Daily Limits
   - Daily_Trades_Today < 5?
   - Daily_Loss < $5,000?
   - Drawdown < 6%?
   
4. Evaluate Setup 1 (M15 data)
   - All 10 entry conditions met?
   - Calculate entry price/SL/TP
   - Execute if all pass
   
5. Evaluate Setup 2 (M5 data)
   - All 10 entry conditions met?
   - Calculate entry price/SL/TP
   - Execute if all pass
   
6. Position Tracking
   - Update open position status
   - Check for exit conditions
   - Apply drawdown tier logic

END SEQUENCE
```

---

## EXIT LOGIC

### Setup 1 Exit Conditions (ANY triggers exit)

```
SETUP_1_EXIT_TRIGGERS:

1. TARGET REACHED:
   ✓ FOR LONG: Bid >= Target_Price (Previous VAH)
   ✓ FOR SHORT: Ask <= Target_Price (Previous VAL)
   
   Action: Close position at market, log as TP_HIT

2. STOP LOSS HIT:
   ✓ FOR LONG: Bid <= SL_Price
   ✓ FOR SHORT: Ask >= SL_Price
   
   Action: Close position at market, log as SL_HIT

3. DAILY LOSS LIMIT:
   ✓ Today's closed P&L + open P&L < -$5,000
   
   Action: Close ALL positions immediately, log as DAILY_LIMIT_TRIGGERED

4. DRAWDOWN CRITICAL:
   ✓ Current Account Drawdown > 6% ($15,000)
   
   Action: Close ALL positions, halt EA trading, log as DRAWDOWN_CRITICAL

5. SESSION END:
   ✓ Current time > 20:45 GMT (15 min before NY close)
   
   Action: Close position at market, log as SESSION_CLOSED

6. TIME STOP (Optional):
   ✓ Position open > 4 hours for Setup 1
   
   Action: Close at market, log as TIME_STOP_TRIGGERED

SETUP_1_EXIT_EXECUTION:
  FOR each Setup1 position:
    IF any exit condition TRUE:
      CloseOrder(ticket, "Setup1_Exit_Reason")
      LogTradeExit(ticket, close_price, P&L, reason)
```

### Setup 2 Exit Conditions (ANY triggers exit)

```
SETUP_2_EXIT_TRIGGERS:

1. TARGET REACHED:
   ✓ FOR LONG: Bid >= Target_Price
   ✓ FOR SHORT: Ask <= Target_Price
   
   Action: Close position at market, log as TP_HIT

2. STOP LOSS HIT:
   ✓ FOR LONG: Bid <= SL_Price
   ✓ FOR SHORT: Ask >= SL_Price
   
   Action: Close position at market, log as SL_HIT

3. DAILY LOSS LIMIT:
   ✓ Today's closed P&L + open P&L < -$5,000
   
   Action: Close ALL positions immediately

4. DRAWDOWN CRITICAL:
   ✓ Current Account Drawdown > 6%
   
   Action: Close ALL positions, halt EA

5. SESSION END:
   ✓ Current time > 20:45 GMT
   
   Action: Close position at market

6. TIME STOP (Shorter for M5):
   ✓ Position open > 2 hours for Setup 2
   
   Action: Close at market, log as TIME_STOP_TRIGGERED

7. HVN BREAK (Advanced):
   ✓ Price breaks HVN in opposite direction
   ✓ Close crosses HVN level
   
   FOR LONG: Close < HVN_Level
   FOR SHORT: Close > HVN_Level
   
   Action: Close position, log as HVN_BREAK

SETUP_2_EXIT_EXECUTION:
  FOR each Setup2 position:
    IF any exit condition TRUE:
      CloseOrder(ticket, "Setup2_Exit_Reason")
      LogTradeExit(ticket, close_price, P&L, reason)
```

---

## STOP LOSS SPECIFICATIONS

### Setup 1 Stop Loss Placement

```
SETUP_1_SL_LOGIC:

FOR LONG ENTRY:
  Entry occurs at price opening outside (below) VAL
  Target set to previous VAH
  
  SL_Price = Previous_VAL - Buffer
  Buffer = 20 pips (below Value Area edge)
  
  CALCULATION:
    SL_Distance = Entry - (Previous_VAL - 20 pips)
    SL_Distance in Points = SL_Distance / Point
    
  EXAMPLE:
    Previous_VAL = 1.2000
    Entry = 1.1950
    SL = 1.2000 - 0.0020 = 1.1980
    SL_Distance = 1.1950 - 1.1980 = 0.0030 = 30 pips

FOR SHORT ENTRY:
  Entry occurs at price opening outside (above) VAH
  Target set to previous VAL
  
  SL_Price = Previous_VAH + Buffer
  Buffer = 20 pips (above Value Area edge)
  
  CALCULATION:
    SL_Distance = (Previous_VAH + 20 pips) - Entry
    
  EXAMPLE:
    Previous_VAH = 1.2050
    Entry = 1.2100
    SL = 1.2050 + 0.0020 = 1.2070
    SL_Distance = 1.2070 - 1.2100 = 0.0030 = 30 pips

STOP LOSS MANAGEMENT:
  1. Place SL at order creation (hard stop)
  2. Never modify SL to take larger loss
  3. Can tighten SL if trade moves in profit
  4. SL must be adjusted for slippage tolerance (3 pips max)
```

### Setup 2 Stop Loss Placement

```
SETUP_2_SL_LOGIC:

FOR LONG ENTRY (HVN Edge):
  Entry Price = Entry level
  HVN Level = High volume node
  
  SL_Price = HVN_Level * (1 - 0.005)  // 0.5% below HVN
  SL_Distance = Entry - SL_Price
  
  EXAMPLE:
    HVN = 1.2050
    Entry = 1.2100
    SL = 1.2050 * 0.995 = 1.2000
    SL_Distance = 1.2100 - 1.2000 = 0.0100 = 100 pips

FOR SHORT ENTRY (HVN Edge):
  Entry Price = Entry level
  HVN Level = High volume node
  
  SL_Price = HVN_Level * (1 + 0.005)  // 0.5% above HVN
  SL_Distance = SL_Price - Entry
  
  EXAMPLE:
    HVN = 1.2050
    Entry = 1.2000
    SL = 1.2050 * 1.005 = 1.2110
    SL_Distance = 1.2110 - 1.2000 = 0.0110 = 110 pips

STOP LOSS MANAGEMENT:
  1. Place SL at order creation (hard stop)
  2. Tight SL acceptable (trading HVN edge)
  3. If SL too large, reduce position size instead
  4. Never leave Setup 2 trades without SL
```

### Volatility-Adjusted Stop Loss (Advanced)

```
// Optional: Adjust SL based on ATR volatility
FUNCTION CalculateVolatilityAdjustedSL(int atr_period = 14):
  
  current_atr = iATR(Symbol(), 0, atr_period, 0)
  atr_in_pips = current_atr / Point
  
  // Low volatility: tighter SL
  // High volatility: wider SL
  
  volatility_ratio = current_atr / Average_ATR
  
  adjusted_sl = base_sl * volatility_ratio
  
  RETURN adjusted_sl

END FUNCTION
```

---

## TAKE PROFIT SPECIFICATIONS

### Setup 1 Take Profit

```
SETUP_1_TP_LOGIC:

FOR LONG ENTRY:
  Entry: Price returns to VA from below VAL
  Target: Previous session VAH
  
  TP_Price = Previous_VAH
  TP_Distance = TP_Price - Entry
  
  LOGIC:
    Mean reversion: price returns to area of control (VAH)
    Once it reaches VAH, sellers emerge
    Exit at resistance level
  
  EXAMPLE:
    Previous_VAL = 1.2000
    Previous_VAH = 1.2050
    Entry = 1.1950
    TP = 1.2050
    TP_Distance = 1.2050 - 1.1950 = 0.0100 = 100 pips

FOR SHORT ENTRY:
  Entry: Price returns to VA from above VAH
  Target: Previous session VAL
  
  TP_Price = Previous_VAL
  TP_Distance = Entry - TP_Price
  
  EXAMPLE:
    Previous_VAL = 1.2000
    Previous_VAH = 1.2050
    Entry = 1.2100
    TP = 1.2000
    TP_Distance = 1.2100 - 1.2000 = 0.0100 = 100 pips

TAKE PROFIT MANAGEMENT:
  1. Place TP at order creation (hard stop)
  2. No modification once entered
  3. Automatically closes at TP price
  4. TP = Primary exit target
```

### Setup 2 Take Profit

```
SETUP_2_TP_LOGIC:

FOR LONG ENTRY (HVN Rebound):
  Entry: Price rebounds from LVN to HVN
  Target: Above nearest HVN level
  
  TP_Price = HVN_Level * (1 + 0.002)  // 0.2% above HVN
  TP_Distance = TP_Price - Entry
  
  RATIONALE:
    Price rebounds to HVN (high volume)
    Expects seller interest at HVN
    Exit slightly above for confirmation
    Tighter TP = faster confirmation candle
  
  EXAMPLE:
    HVN = 1.2050
    Entry = 1.2100
    TP = 1.2050 * 1.002 = 1.2074
    TP_Distance = 1.2074 - 1.2100 = -0.0026 (NEGATIVE - entry above TP)
    
    CORRECTION: For HVN edge trade:
    If entry is above HVN (short), TP is below HVN
    TP_Price = HVN - (HVN * 0.002)

FOR SHORT ENTRY (HVN Rebound):
  Entry: Price rebounds from LVN to HVN (from above)
  Target: Below nearest HVN level
  
  TP_Price = HVN_Level * (1 - 0.002)  // 0.2% below HVN
  TP_Distance = Entry - TP_Price
  
  EXAMPLE:
    HVN = 1.2050
    Entry = 1.2000
    TP = 1.2050 * 0.998 = 1.2026
    TP_Distance = 1.2000 - 1.2026 = -0.0026 (NEGATIVE)
    
    CORRECTION: Entry is BELOW HVN for short setup
    TP should be BELOW HVN:
    TP_Price = 1.2026

TAKE PROFIT MANAGEMENT:
  1. Place TP at order creation (hard stop)
  2. Tighter TP acceptable for HVN edge (higher hit rate)
  3. Expect 1-2 TP hits per day on M5
  4. Risk/Reward = 1:1.8 minimum (validate in backtesting)
```

### Risk/Reward Validation

```
FUNCTION ValidateRiskRewardRatio():
  
  FOR each potential entry:
    entry_price = current Ask/Bid
    sl_price = calculated SL
    tp_price = calculated TP
    
    IF direction == LONG:
      risk = entry_price - sl_price
      reward = tp_price - entry_price
    ELSE:
      risk = sl_price - entry_price
      reward = entry_price - tp_price
    
    ratio = reward / risk
    
    IF ratio < 1.8:  // YOUR TARGET
      LOG_WARNING("Risk/Reward below 1.8", ratio)
      // CAN STILL ENTER (your choice)
    ELSE:
      LOG_INFO("Risk/Reward confirmed", ratio)
    
    RETURN ratio

END FUNCTION
```

---

## POSITION SIZING & RISK

### Lot Size Calculation (1% Risk Method)

```
FUNCTION CalculateLotSize(risk_amount, sl_distance_points):
  
  // Risk amount = 1% of account = $2,500
  // SL distance = distance in points between entry and SL
  
  // Step 1: Calculate pip value
  pip_value = (contract_size * tick_size) / (ask_price)
  
  // For standard account:
  // 1 lot = 100,000 units
  // 1 pip = $10 (for most currency pairs)
  // 1 point = $10
  
  // Step 2: Calculate point value
  point_value = pip_value / 10  // If 10 points = 1 pip
  
  // Step 3: Calculate maximum lot size
  lot_size = risk_amount / (sl_distance_points * point_value)
  
  // Step 4: Validate against broker limits
  IF lot_size < MinLotSize:
    lot_size = MinLotSize
  
  IF lot_size > MaxLotSize:
    lot_size = MaxLotSize
  
  // Step 5: Round to standard increment
  lot_size = ROUND(lot_size, broker_lot_step)
  
  RETURN lot_size

END FUNCTION
```

### Example Calculation

```
SCENARIO: Setup 1 Long Entry
  Account Balance: $250,000
  Risk % per trade: 1%
  Risk Amount: $2,500
  Instrument: Gold (GC)
  Entry Price: 1,950.00
  SL Price: 1,945.00
  SL Distance: 5.00 points
  
CALCULATION:
  1. pip_value (Gold): $100 per pip
  2. point_value: $10 per point
  3. lot_size = $2,500 / (5 × $10) = 50 lots
  4. Validate: 50 lots within broker limits? YES
  5. Lot Size = 50 lots
  
RESULT:
  - Entry: 50 lots at 1,950.00
  - SL: 50 lots at 1,945.00
  - Risk: 5 points × 50 lots × $10 = $2,500 ✓
```

### Daily Loss Limit Enforcement

```
FUNCTION CheckDailyLossLimit():
  
  // Calculate today's losses
  daily_closed_pnl = SUM(P&L of all closed trades today)
  daily_open_pnl = SUM(unrealized P&L of open positions)
  daily_total_pnl = daily_closed_pnl + daily_open_pnl
  
  daily_loss_limit = Account_Balance * (Daily_Loss_Limit / 100)  // $5,000
  
  IF daily_total_pnl < -daily_loss_limit:
    // Exceeded daily loss
    LOG_ALERT("DAILY_LOSS_LIMIT_EXCEEDED", daily_total_pnl)
    
    // Close all open positions
    CloseAllPositions("DAILY_LOSS_LIMIT")
    
    // Prevent new entries
    RETURN FALSE
  
  ELSE:
    RETURN TRUE

END FUNCTION
```

### Drawdown Tracking

```
FUNCTION TrackDrawdown():
  
  // Calculate drawdown from peak
  current_balance = AccountBalance()
  
  IF current_balance > peak_balance:
    peak_balance = current_balance
  
  drawdown_amount = peak_balance - current_balance
  drawdown_percent = (drawdown_amount / peak_balance) * 100
  
  // Tier 1: Alert (10%)
  IF drawdown_percent >= 10.0 AND drawdown_percent < 15.0:
    LOG_ALERT("DRAWDOWN_TIER1_ALERT", drawdown_percent, "Review trades")
  
  // Tier 2: Reduce Position Size (15%)
  ELSE IF drawdown_percent >= 15.0 AND drawdown_percent < 6.0:
    // Note: This seems wrong (15% < 6% is impossible)
    // Assuming this should be checked separately:
    current_size_multiplier = 0.5  // Cut to 50%
    LOG_ALERT("DRAWDOWN_TIER2_REDUCE", drawdown_percent, "Size reduced to 50%")
  
  // Tier 3: Critical Stop (6%)
  ELSE IF drawdown_percent >= 6.0:
    LOG_CRITICAL("DRAWDOWN_TIER3_CRITICAL", drawdown_percent, "ALL TRADING HALTED")
    EA_Enabled = FALSE
    CloseAllPositions("DRAWDOWN_CRITICAL")
  
  RETURN drawdown_percent

END FUNCTION
```

---

## SESSION MANAGEMENT

### Trading Window Definition

```
SESSION_WINDOW:
  
Open Time:  Tokyo + 2 hours = 23:00 GMT (approximately)
Close Time: 15 minutes before NY close = 20:45 GMT

ACTUAL CLOCK TIMES (GMT):
  Session Start: 23:00 GMT
  Session End: 20:45 GMT
  Duration: ~22 hours
  
BREAKDOWN:
  Tokyo Open: 21:00 GMT (21:00 - 06:00 GMT = Asian session)
  Tokyo + 2h: 23:00 GMT
  London Open: 08:00 GMT
  London-NY: 13:00-21:00 GMT (best liquidity)
  NY Close: 21:00 GMT
  15 min before: 20:45 GMT

COVERAGE:
  ✓ Includes Tokyo session (partial)
  ✓ Includes London session (full)
  ✓ Includes NY session (nearly full)
  ✗ Excludes early Asian (21:00-23:00)
  ✗ Excludes last 15 min NY close
```

### Session Time Calculations

```
FUNCTION IsInTradingWindow():
  
  current_time = TimeLocal()  // Current server time
  
  // Convert to GMT
  current_hour = HOUR(current_time)
  current_minute = MINUTE(current_time)
  current_time_gmt = current_time + (ServerTimezone_Offset)
  
  session_open = 23:00 GMT
  session_close = 20:45 GMT
  
  // Handle day boundary (window crosses midnight)
  IF current_time_gmt >= session_open OR current_time_gmt <= session_close:
    RETURN TRUE  // In trading window
  ELSE:
    RETURN FALSE  // Outside trading window

END FUNCTION
```

### Previous Session Profile Timing

```
FUNCTION CalculatePreviousSessionTime():
  
  // For daily timeframe setup
  current_bar_time = iTime(Symbol(), PERIOD_D1, 0)
  previous_bar_time = iTime(Symbol(), PERIOD_D1, 1)
  
  // Previous session = yesterday's daily bar
  previous_session_start = START_OF_DAY(previous_bar_time)
  previous_session_end = END_OF_DAY(previous_bar_time)
  
  // Extract all M5/M15 bars within this period
  FOR i = 0 to 400:
    bar_time = iTime(Symbol(), PERIOD_M5, i)
    
    IF bar_time >= previous_session_start AND bar_time <= previous_session_end:
      // Include this bar in previous session profile
      AddToProfileArray(Volume[i], Close[i], High[i], Low[i])
  
  // Calculate profile on extracted bars
  CALL VolumeProfileEngine()

END FUNCTION
```

---

## NEWS EVENT FILTERING

### News Event Buffer Implementation

```
NEWS_EVENT_FILTER:
  
Buffer: 30 minutes before AND 30 minutes after event

LOGIC:
  IF high_impact_news_event exists:
    event_time = news_time
    safe_start = event_time - 30 minutes
    safe_end = event_time + 30 minutes
    
    IF current_time >= safe_start AND current_time <= safe_end:
      // SKIP TRADING (no new entries)
      RETURN FALSE
    
    ELSE:
      // Safe to trade
      RETURN TRUE

IMPLEMENTATION:
  // Check economic calendar source
  // Typical high-impact events: NFP, CPI, GDP, Interest Rate decisions
  
  FUNCTION IsNewsEventActive():
    
    // Query economic calendar API (AlphaVantage, FRED, etc.)
    economic_events = GetEconomicCalendar(current_date)
    
    FOR each event in economic_events:
      IF event.impact == "HIGH":
        
        event_time_gmt = CONVERT_TO_GMT(event.time)
        buffer_start = event_time_gmt - 30 minutes
        buffer_end = event_time_gmt + 30 minutes
        
        current_time_gmt = TimeLocal()
        
        IF current_time_gmt >= buffer_start AND 
           current_time_gmt <= buffer_end:
          
          LOG_INFO("News event buffer active", event.name, current_time_gmt)
          RETURN TRUE  // Active news buffer
    
    RETURN FALSE  // No active news buffer

  END FUNCTION
```

### News Event Source Integration

```
// MQL5 provides access to:
// 1. Local broker calendar (if available)
// 2. External API integration (custom)
// 3. Manual calendar maintenance (backup)

FUNCTION CheckNewsCalendar():
  
  // Method 1: Broker calendar (if supported)
  IF Broker_Has_Calendar:
    calendar_events = QueryBrokerCalendar(Symbol(), current_date)
  
  // Method 2: External API (AlphaVantage example)
  ELSE:
    api_key = "your_api_key"
    country_code = GetCountryFromSymbol(Symbol())  // e.g., "USD"
    
    api_url = "https://www.alphavantage.co/query?function=NEWS_SENTIMENT"
               "&apikey=" + api_key
    
    response = WebRequest("GET", api_url)
    calendar_events = ParseJSON(response)
  
  // Method 3: Manual calendar (hardcoded important dates)
  ELSE:
    calendar_events = LoadManualCalendar()
  
  RETURN calendar_events

END FUNCTION
```

---

## POSITION MANAGEMENT RULES

### Multiple Position Tracking (Up to 3 simultaneous)

```
POSITION_TRACKING_STRUCTURE:

Position[] positions[3];  // Max 3 positions

STRUCTURE Position:
  int ticket
  string setup  // "Setup1" or "Setup2"
  string direction  // "LONG" or "SHORT"
  double entry_price
  double stop_loss
  double take_profit
  double lot_size
  double open_time
  double entry_volume  // Volume context at entry
  string hvn_level  // For Setup 2 only
  string notes  // Entry rationale
END STRUCTURE

FUNCTION OpenNewPosition(setup, direction, entry_price, sl, tp, lot_size):
  
  // Find empty position slot
  FOR i = 0 to 2:
    IF positions[i].ticket == 0:
      
      // Populate new position
      positions[i].ticket = ticket
      positions[i].setup = setup
      positions[i].direction = direction
      positions[i].entry_price = entry_price
      positions[i].stop_loss = sl
      positions[i].take_profit = tp
      positions[i].lot_size = lot_size
      positions[i].open_time = TimeCurrent()
      
      LOG_INFO("Position opened", i, setup, direction, entry_price)
      RETURN TRUE
  
  // No empty slots
  LOG_WARNING("Max positions reached", 3)
  RETURN FALSE

END FUNCTION

FUNCTION ClosePosition(ticket, reason):
  
  // Find and close position
  FOR i = 0 to 2:
    IF positions[i].ticket == ticket:
      
      // Calculate P&L
      close_price = (direction == LONG) ? Bid : Ask
      pnl = (direction == LONG) ? 
            (close_price - entry_price) * lot_size :
            (entry_price - close_price) * lot_size
      
      // Update accounting
      LOG_TRADE_EXIT(ticket, close_price, pnl, reason)
      
      // Clear position
      positions[i].ticket = 0
      
      RETURN TRUE
  
  RETURN FALSE

END FUNCTION

FUNCTION TrackOpenPositions():
  
  FOR i = 0 to 2:
    IF positions[i].ticket != 0:
      
      // Check exit conditions
      current_price = (positions[i].direction == LONG) ? Bid : Ask
      
      // TP hit
      IF positions[i].direction == LONG AND current_price >= positions[i].take_profit:
        ClosePosition(positions[i].ticket, "TP_HIT")
      
      // SL hit
      ELSE IF positions[i].direction == LONG AND current_price <= positions[i].stop_loss:
        ClosePosition(positions[i].ticket, "SL_HIT")
      
      // Similar for SHORT...
      
      // Time stop
      time_open = TimeCurrent() - positions[i].open_time
      IF positions[i].setup == "Setup1" AND time_open > 4 * 3600:  // 4 hours
        ClosePosition(positions[i].ticket, "TIME_STOP")
      
      ELSE IF positions[i].setup == "Setup2" AND time_open > 2 * 3600:  // 2 hours
        ClosePosition(positions[i].ticket, "TIME_STOP")

END FUNCTION
```

### Position Conflict Resolution

```
FUNCTION CanOpenNewPosition(setup, direction):
  
  // Count existing positions in same direction
  same_direction_count = 0
  FOR i = 0 to 2:
    IF positions[i].ticket != 0 AND positions[i].direction == direction:
      same_direction_count++
  
  // Rule: No more than 1 position per direction (conservative)
  IF same_direction_count > 0:
    LOG_WARNING("Position exists in same direction, skipping entry")
    RETURN FALSE
  
  // Rule: No more than 3 simultaneous positions total
  total_positions = COUNT_OPEN_POSITIONS()
  IF total_positions >= 3:
    LOG_WARNING("Max positions reached, skipping entry")
    RETURN FALSE
  
  RETURN TRUE

END FUNCTION
```

---

## DRAWDOWN MANAGEMENT TIERS

### Tier System

```
DRAWDOWN_TIER_1 (ALERT):
  Threshold: 10% drawdown = $25,000
  Action: LOG_ALERT
  Position Effect: No change
  Next Check: Every candle
  Purpose: Awareness trigger

DRAWDOWN_TIER_2 (REDUCE):
  Threshold: 15% drawdown = $37,500
  Action: Reduce position size to 50%
  Position Effect: All NEW positions = 50% of normal size
  Next Check: Every candle
  Purpose: Risk reduction
  Implementation:
    position_size_multiplier = 0.5
    new_lot_size = CalculateLotSize(...) * 0.5

DRAWDOWN_TIER_3 (CRITICAL STOP):
  Threshold: 6% drawdown = $15,000
  Action: HALT ALL TRADING
  Position Effect: Close ALL open positions immediately
  Next Check: After restart
  Purpose: Capital preservation
  Implementation:
    CloseAllPositions("DRAWDOWN_CRITICAL")
    EA_Enabled = FALSE
    SendAlert("CRITICAL: EA STOPPED - Drawdown 6%")
```

### Drawdown Tier Monitoring

```
FUNCTION ManageDrawdownTiers():
  
  current_dd = CalculateCurrentDrawdown()
  
  // Tier 3: Critical (highest priority)
  IF current_dd >= Drawdown_Tier3_Critical:
    LOG_CRITICAL("TIER3_CRITICAL", current_dd)
    CloseAllPositions("TIER3_CRITICAL")
    EA_Enabled = FALSE
    RETURN "HALTED"
  
  // Tier 2: Reduce
  ELSE IF current_dd >= Drawdown_Tier2_Reduce:
    IF NOT tier2_active:
      LOG_ALERT("TIER2_REDUCE", current_dd)
      tier2_active = TRUE
      position_size_multiplier = Tier2_Size_Reduction  // 0.5
  
  // Tier 1: Alert
  ELSE IF current_dd >= Drawdown_Tier1_Alert:
    IF NOT tier1_active:
      LOG_ALERT("TIER1_ALERT", current_dd)
      tier1_active = TRUE
  
  // Below all tiers: restore normal sizing
  ELSE:
    IF tier2_active OR tier1_active:
      LOG_INFO("Drawdown recovered, restoring normal position size")
      position_size_multiplier = 1.0
      tier2_active = FALSE
      tier1_active = FALSE

END FUNCTION
```

---

## VALIDATION & ERROR HANDLING

### Input Validation

```
FUNCTION ValidateInputParameters():
  
  errors = []
  
  // Risk validation
  IF Risk_Percentage <= 0 OR Risk_Percentage > 5:
    errors.ADD("Risk % must be 0.1-5.0")
  
  IF Daily_Loss_Limit <= 0 OR Daily_Loss_Limit > 10:
    errors.ADD("Daily loss limit must be 1-10%")
  
  IF Drawdown_Tier3_Critical <= 0 OR Drawdown_Tier3_Critical > 20:
    errors.ADD("Critical drawdown must be 1-20%")
  
  // Timeframe validation
  IF Setup1_Timeframe NOT IN [PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1]:
    errors.ADD("Setup1 timeframe must be M15, H1, H4, or D1")
  
  IF Setup2_Timeframe NOT IN [PERIOD_M5, PERIOD_M15, PERIOD_H1]:
    errors.ADD("Setup2 timeframe must be M5, M15, or H1")
  
  // Session validation
  IF SessionOpen_Time >= SessionClose_Time:
    errors.ADD("Session open must be before close")
  
  // Position validation
  IF Max_Simultaneous_Positions < 1 OR Max_Simultaneous_Positions > 5:
    errors.ADD("Max positions must be 1-5")
  
  IF errors.SIZE() > 0:
    FOR each error in errors:
      LOG_ERROR("VALIDATION_ERROR", error)
    RETURN FALSE
  
  RETURN TRUE

END FUNCTION
```

### Trade Execution Validation

```
FUNCTION ValidateBeforeEntry(setup, direction, entry_price, sl, tp, lot_size):
  
  // SL validation
  IF direction == LONG:
    IF entry_price <= sl:
      LOG_ERROR("INVALID_SL", "SL must be below entry for LONG")
      RETURN FALSE
  ELSE:
    IF entry_price >= sl:
      LOG_ERROR("INVALID_SL", "SL must be above entry for SHORT")
      RETURN FALSE
  
  // TP validation
  IF direction == LONG:
    IF entry_price >= tp:
      LOG_ERROR("INVALID_TP", "TP must be above entry for LONG")
      RETURN FALSE
  ELSE:
    IF entry_price <= tp:
      LOG_ERROR("INVALID_TP", "TP must be below entry for SHORT")
      RETURN FALSE
  
  // Risk/Reward validation
  IF direction == LONG:
    risk = entry_price - sl
    reward = tp - entry_price
  ELSE:
    risk = sl - entry_price
    reward = entry_price - tp
  
  ratio = reward / risk
  IF ratio < 1.0:
    LOG_ERROR("INVALID_RR", "Risk/Reward must be > 1:1")
    RETURN FALSE
  
  // Lot size validation
  IF lot_size < MinLotSize OR lot_size > MaxLotSize:
    LOG_ERROR("INVALID_LOT", "Lot size outside broker limits")
    RETURN FALSE
  
  // Risk validation
  IF direction == LONG:
    risk_amount = (entry_price - sl) * lot_size * contract_size
  ELSE:
    risk_amount = (sl - entry_price) * lot_size * contract_size
  
  IF risk_amount > (Account_Balance * 0.05):  // More than 5%
    LOG_ERROR("RISK_TOO_HIGH", "Risk exceeds 5% of account")
    RETURN FALSE
  
  RETURN TRUE

END FUNCTION
```

### Error Logging

```
FUNCTION LogError(error_code, error_message, error_details = ""):
  
  timestamp = TimeLocal()
  ticket = "N/A"
  
  log_entry = StringFormat(
    "%s | ERROR | %s | %s | %s",
    timestamp,
    error_code,
    error_message,
    error_details
  )
  
  // Log to journal
  Print(log_entry)
  
  // Log to file
  FileHandle = FileOpen("EA_ErrorLog.txt", FILE_READ|FILE_WRITE)
  FileSeek(FileHandle, 0, SEEK_END)
  FileWriteString(FileHandle, log_entry + "\n")
  FileClose(FileHandle)
  
  // Send alert if critical
  IF error_code IN ["CRITICAL", "HALTED", "DAILY_LIMIT", "DRAWDOWN_CRITICAL"]:
    SendNotification(error_message)

END FUNCTION
```

---

## BACKTESTING ACCEPTANCE CRITERIA

### Phase 1: Data Validation (Week 1)

```
DURATION: 3-5 days
DATA: 2-4 weeks recent data (M5 & M15)
GOAL: System runs without errors

ACCEPTANCE CRITERIA:
  ✓ No runtime errors
  ✓ No array index out of bounds
  ✓ Volume profile calculates on all candles
  ✓ POC/VAL/VAH update correctly
  ✓ HVN/LVN detection functional
  
EXPECTED TRADES:
  ✓ 20+ Setup 1 trades (M15)
  ✓ 20+ Setup 2 trades (M5)
  ✓ Drawdown stays < 6%

PASS CRITERIA:
  System runs cleanly without stopping or errors
  
FAIL CRITERIA:
  - Runtime errors prevent completion
  - Missing trade entries
  - Incorrect SL/TP placement
  
NEXT STEP: If PASS → Proceed to Phase 2
```

### Phase 2: Setup Separation (Weeks 2-3)

```
DURATION: 1-2 weeks
DATA: 3-6 months history

SETUP 1 TESTING (M15 ONLY):
  ✓ Run ONLY Setup 1 enabled
  ✓ Setup 2 disabled
  ✓ Achieve 50+ trades minimum
  ✓ Win Rate > 65%? (YOUR TARGET)
  ✓ Risk/Reward > 1:1.8?
  ✓ Daily stops working correctly?
  ✓ Drawdown never > 6%?
  
SETUP 2 TESTING (M5 ONLY):
  ✓ Run ONLY Setup 2 enabled
  ✓ Setup 1 disabled
  ✓ Achieve 50+ trades minimum
  ✓ Win Rate > 65%?
  ✓ Risk/Reward > 1:1.8?
  ✓ HVN detection accurate?
  ✓ Drawdown never > 6%?

ACCEPTANCE CRITERIA (BOTH SETUPS):
  ✓ Setup 1: 50+ trades, 65%+ win rate, 1:1.8 RR, <6% DD
  ✓ Setup 2: 50+ trades, 65%+ win rate, 1:1.8 RR, <6% DD
  ✓ Profit Factor > 1.5

PASS CRITERIA:
  BOTH setups meet all criteria
  
FAIL CRITERIA:
  - Either setup < 65% win rate
  - Either setup < 1:1.8 RR
  - Drawdown > 6% at any point
  - Profit Factor < 1.5
  
IF FAIL:
  Return to Phase 1: Identify root cause
  Adjust parameters (TP, SL, entry conditions)
  Re-test same historical data
  
IF PASS:
  Proceed to Phase 3
```

### Phase 3: Combined Testing (Weeks 3-4)

```
DURATION: 1-2 weeks
DATA: 3-6 months history
CONFIGURATION: BOTH setups enabled, multi-position rules active

TRACKING:
  ✓ Total trades: 50+ Setup1 + 50+ Setup2 = 100+ combined minimum
  ✓ Win rate: Maintain 65% average
  ✓ Drawdown: Never exceed 6%
  ✓ Position conflicts: Analyze multi-position behavior
  ✓ Daily loss limit: Triggered correctly?

ACCEPTANCE CRITERIA:
  ✓ 100+ combined trades
  ✓ 65%+ win rate combined
  ✓ 1:1.8+ RR maintained
  ✓ Profit Factor > 1.5
  ✓ Max drawdown < 6%
  ✓ No position conflicts
  ✓ Daily loss limit working

PASS CRITERIA:
  All acceptance criteria met
  
FAIL CRITERIA:
  - Combined win rate < 65%
  - Position conflicts causing issue
  - Drawdown > 6%
  - Daily limit failures
  
IF FAIL:
  Reduce Max_Simultaneous_Positions to 2
  Adjust overlap rules
  Re-test Phase 3
  
IF PASS:
  Proceed to Phase 4
```

### Phase 4: Extended History (Weeks 4-6)

```
DURATION: 2-3 weeks
DATA: 1-2 years history
EXPECTED TRADES: 300-500+ total

VALIDATION:
  ✓ Win rate consistency across all periods
  ✓ Drawdown behavior through different market conditions
  ✓ Monthly P&L variation (identify seasonal patterns)
  ✓ Setup 1 vs Setup 2 individual performance
  ✓ Performance in trending vs ranging markets
  ✓ Performance in volatile vs calm markets

ACCEPTANCE CRITERIA:
  ✓ 300+ trades minimum
  ✓ Win rate > 65% across entire period
  ✓ RR > 1:1.8 maintained
  ✓ Profit Factor > 1.5
  ✓ Max drawdown < 6% at any point
  ✓ Monthly profit >= 2% of account (target)
  ✓ Sharpe Ratio > 1.0 (preferred)

ANALYSIS:
  - Best performing market condition: _____
  - Worst performing market condition: _____
  - Setup 1 win rate: ____% (Setup 2 win rate: ____%)
  - Average trade duration: _____
  - Largest winning trade: _____ pips
  - Largest losing trade: _____ pips

PASS CRITERIA:
  System performs consistently across 1-2 years
  
FINAL DECISION:
  APPROVED FOR LIVE TRADING → Proceed with small account
  NEEDS OPTIMIZATION → Identify weak periods, adjust parameters
  NOT APPROVED → Return to design phase, reconsider setup logic
```

---

## TRADE LOGGING & JOURNAL

### Trade Entry Logging

```
FUNCTION LogTradeEntry(ticket, setup, direction, entry_price, sl, tp, lot_size):
  
  timestamp = TimeLocal()
  symbol = Symbol()
  timeframe = Period()
  
  // Volume profile context
  poc = CalculatePOC()
  val = CalculateVAL()
  vah = CalculateVAH()
  
  log_string = StringFormat(
    "%s | ENTRY | Ticket:%d | %s | %s %s | Entry:%.5f | SL:%.5f | TP:%.5f | Size:%.2f | POC:%.5f | VAL:%.5f | VAH:%.5f",
    timestamp,
    ticket,
    setup,
    symbol,
    direction,
    entry_price,
    sl,
    tp,
    lot_size,
    poc,
    val,
    vah
  )
  
  // Write to journal file
  LogToFile("TradeJournal.txt", log_string)
  
  // Optional: Send to external database
  SendToDatabase(log_string)

END FUNCTION
```

### Trade Exit Logging

```
FUNCTION LogTradeExit(ticket, setup, exit_price, entry_price, pnl, reason):
  
  timestamp = TimeLocal()
  symbol = Symbol()
  
  // Calculate statistics
  pip_profit = (exit_price - entry_price) / Point
  IF reason == "TP_HIT":
    result = "WIN"
  ELSE IF reason == "SL_HIT":
    result = "LOSS"
  ELSE:
    result = reason
  
  log_string = StringFormat(
    "%s | EXIT | Ticket:%d | %s | %s | Exit:%.5f | Entry:%.5f | PnL:$%.2f | Pips:%.0f | Reason:%s",
    timestamp,
    ticket,
    setup,
    symbol,
    exit_price,
    entry_price,
    pnl,
    pip_profit,
    reason
  )
  
  // Write to journal file
  LogToFile("TradeJournal.txt", log_string)

END FUNCTION
```

### Daily Summary

```
FUNCTION GenerateDailySummary():
  
  date = Date()
  
  daily_trades = CountTradesForDate(date)
  daily_wins = CountWinsForDate(date)
  daily_losses = CountLossesForDate(date)
  daily_pnl = SumPnLForDate(date)
  
  win_rate = (daily_wins / daily_trades) * 100
  
  summary = StringFormat(
    "=== DAILY SUMMARY %s ===\n"
    "Trades: %d | Wins: %d | Losses: %d | Win Rate: %.1f%%\n"
    "Daily P&L: $%.2f | Avg Trade: $%.2f\n"
    "Max Drawdown: %.2f%% | Account: $%.2f",
    date,
    daily_trades,
    daily_wins,
    daily_losses,
    win_rate,
    daily_pnl,
    daily_pnl / daily_trades,
    GetDailyDrawdown(),
    AccountBalance()
  )
  
  LogToFile("DailySummary.txt", summary)
  SendNotification(summary)

END FUNCTION
```

---

## EDGE CASES

### Gap Handling

```
EDGE CASE 1: OVERNIGHT GAP

Scenario:
  Market closes at 1.2000
  Market opens at 1.2050 (50 pip gap up)
  Previous session VAH = 1.2040
  Previous session VAL = 1.1980

Setup 1 Response:
  Gap direction = UP (above VAH)
  
  Setup 1 Entry logic:
    IF Open > Previous_VAH:
      Setup 1 triggers SHORT when price returns to VA
    
  Entry will be on candle that closes below previous VAH

Setup 2 Response:
  New LVN areas created by gap
  Profile recalculates with new range
  May miss Setup 2 entries if gap is very large

HANDLING:
  1. Detect gap at market open
  2. Adjust volume profile to include gap area
  3. Set profile range to include gap (not compress it)
```

### Low Liquidity Periods

```
EDGE CASE 2: LOW LIQUIDITY (Weekend, holiday, thin spreads)

Risk:
  - Slippage increases
  - Bid/Ask spread widens
  - Volume profile unreliable
  - Entries may not fill

Detection:
  IF Spread > Normal_Spread * 2:
    Low_Liquidity = TRUE
  
  IF Average_Volume < Typical_Volume * 0.5:
    Low_Liquidity = TRUE

Response:
  IF Low_Liquidity:
    SKIP all new entries
    Allow only position exits
    Return TRUE when liquidity returns

Implementation:
  FUNCTION CheckLiquidity():
    current_spread = Ask - Bid
    avg_spread = AVERAGE(Bid-Ask for last 20 bars)
    
    IF current_spread > (avg_spread * 1.5):
      RETURN FALSE  // Skip entries
    
    current_volume = Volume[0]
    avg_volume = AVERAGE(Volume for last 20 bars)
    
    IF current_volume < (avg_volume * 0.5):
      RETURN FALSE  // Skip entries
    
    RETURN TRUE  // Liquidity OK

  END FUNCTION
```

### Data Connection Loss

```
EDGE CASE 3: DATA CONNECTION LOSS / DISCONNECTION

Risk:
  - Missing candles in backtest/live
  - Stale volume profile
  - Entries on false signals

Detection:
  IF no new bar for > 60 seconds (M5 timeframe):
    Connection_Lost = TRUE

Response:
  1. STOP all new entries
  2. Keep existing positions open (let SL/TP work)
  3. Wait for reconnection
  4. Resume when data is current

Implementation:
  last_bar_time = Time[0]
  
  IF TimeCurrent() - last_bar_time > 120:  // 2 minutes for M5
    Connection_Lost = TRUE
    LOG_ALERT("DATA_DISCONNECTED")
    Skip_New_Entries = TRUE
  
  ELSE IF TimeCurrent() - last_bar_time < 10:
    Connection_Lost = FALSE
    Skip_New_Entries = FALSE
```

### Extreme Volatility

```
EDGE CASE 4: EXTREME VOLATILITY (Spikes, crashes, fast moves)

Risk:
  - SL gets hit on noise
  - Entry signals false
  - Slippage on orders

Detection:
  current_atr = iATR(Symbol(), PERIOD_M5, 14, 0)
  avg_atr = AVERAGE_ATR(14 days)
  
  volatility_ratio = current_atr / avg_atr
  
  IF volatility_ratio > 2.0:
    Extreme_Volatility = TRUE

Response:
  IF Extreme_Volatility:
    Option A: Skip trading entirely
    Option B: Widen SL/TP accordingly
    Option C: Reduce position size to 50%

Implementation:
  FUNCTION GetVolatilityAdjustment():
    volatility_ratio = current_atr / avg_atr
    
    IF volatility_ratio > 3.0:
      RETURN 0.0  // Skip trading
    
    ELSE IF volatility_ratio > 2.0:
      RETURN 0.5  // 50% position size
    
    ELSE:
      RETURN 1.0  // Normal size

  END FUNCTION
```

### Multiple HVN Scenarios

```
EDGE CASE 5: MULTIPLE HVN LEVELS

Scenario:
  Price history shows multiple significant HVN levels:
  - HVN_A: 1.2050 (strongest, topmost)
  - HVN_B: 1.2000 (moderate)
  - HVN_C: 1.1950 (moderate)

Setup 2 Entry Rules:
  FOR HVN Edge trade, use NEAREST HVN
  
  IF price at 1.2025 (between HVN_A and HVN_B):
    Nearest_HVN_Above = HVN_A (1.2050)
    Nearest_HVN_Below = HVN_B (1.2000)
  
  SHORT entry: Use HVN_A (1.2050) - nearest above
  LONG entry: Use HVN_B (1.2000) - nearest below

Priority:
  1. Identify all HVNs in array
  2. Sort by volume (highest first)
  3. For entry, use nearest to current price
  4. Use next level as target if first is bypassed
```

---

## PENDING CLARIFICATIONS

Before finalizing this specification, confirm:

### ❓ CRITICAL DECISION 1: PRIMARY INSTRUMENT
**Current:** Gold, Oil, Indices, EURUSD, GBPJPY  
**Decision:** Which ONE to code first?  
**Answer:** ________________

**Impact:** Determines volume source, contract size calculations, spread assumptions, leverage capability

---

### ❓ CRITICAL DECISION 2: SETUP 1 TIMEFRAME
**Current:** M15 (non-standard choice)  
**Alternative:** H4 or Daily (knowledge base recommended)  
**Decision:** Keep M15 or change?  
**Answer:** ________________

**Impact:** If M15: More trades/day but shorter session windows. If H4/Daily: Fewer trades but more stable profiles.

---

### ❓ CRITICAL DECISION 3: WIN RATE TARGET
**Current:** 65% (very aggressive)  
**Alternative:** 55% (typical profitable systems)  
**Decision:** Keep 65% or adjust to 55%?  
**Answer:** ________________

**Impact:** 65% = Only 2 losses per ~5.7 trades. Higher risk of rejecting working system. 55% = More realistic, easier to validate.

---

## SUMMARY

This Development Specifications document provides a complete roadmap for MQL5 implementation of your Volume Profile Trading EA. It covers:

✅ Core volume profile math (400-bin distribution, POC/VAL/VAH)  
✅ Setup 1 (80% Rule) entry/exit/SL/TP logic  
✅ Setup 2 (HVN Edge) entry/exit/SL/TP logic  
✅ Position sizing (1% risk per trade)  
✅ Risk management (daily limits, drawdown tiers)  
✅ Session management (Tokyo +2hr to NY -15min)  
✅ News event filtering (30 min buffer)  
✅ Multi-position tracking (up to 3 simultaneous)  
✅ Trade logging & journal  
✅ Edge case handling  
✅ Backtesting acceptance criteria (4 phases)  
✅ Error handling & validation  

**Status:** Ready for coding once 3 clarifications are provided.

**Estimated Development Time:** 10-13 hours

---

**Document Version:** 1.0  
**Date:** May 2, 2026  
**Next Step:** Provide answers to 3 critical decisions above
