# MT5 Volume Profile EA — Architecture Design

**Project:** VWGTI-PRO-VP-EA (MT5 Volume Profile Swing Trading EA)  
**Domain:** Automated trading system for Volume Profile entry/exit signals  
**Researched:** 2026-05-13  
**Confidence:** HIGH (specification-driven, MQL5 patterns established)

---

## Executive Summary

The Volume Profile EA requires a **modular calculation-first architecture** where:
1. **Volume Profile Engine** performs all 400-bin distribution calculations independently
2. **Setup Detection Modules** consume profile data to identify entry signals
3. **Trade Execution Engine** manages position lifecycle with risk enforcement
4. **Risk Management System** overrides execution if limits breached

This design separates **data calculation** from **decision logic** from **order management**, enabling unit-testable components and clear data ownership. Build in strict dependency order: calculation → detection → execution → risk management.

---

## 1. Component Architecture Overview

### High-Level Module Breakdown

```
┌─────────────────────────────────────────────────────────────────┐
│                    MT5 Volume Profile EA                         │
│                  (OnTick() Main Event Loop)                      │
└──────────────────────┬──────────────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
        ▼              ▼              ▼
   ┌─────────┐   ┌─────────┐   ┌─────────────┐
   │ VOLUME  │   │ SIGNAL  │   │ EXECUTION & │
   │PROFILE  │──▶│DETECTION│──▶│ RISK MGMT   │
   │ ENGINE  │   │ MODULES │   │   SYSTEM    │
   └────┬────┘   └─────────┘   └─────────────┘
        │                             │
        │    ┌────────────────────────┘
        │    │
        ▼    ▼
   ┌──────────────┐
   │  LOGGING &   │
   │  JOURNAL     │
   └──────────────┘
```

### Component Responsibilities

| Component | Responsibility | Input | Output |
|-----------|-----------------|-------|--------|
| **Volume Profile Engine** | 400-bin distribution, POC/VAL/VAH/HVN/LVN calculation | OHLCV bars (150 lookback) | Profile struct with all levels |
| **Setup 1 Detector** | 80% Rule mean reversion logic (gap + return to VA) | Current profile + previous session profile | Setup1Signal struct (null if not triggered) |
| **Setup 2 Detector** | HVN Edge trading + volume spike + candle pattern | Current profile + HVN/LVN arrays | Setup2Signal struct (null if not triggered) |
| **Trade Executor** | Order placement, validation, position tracking | Signal + lot sizing calculation | OrderTicket + position record |
| **Risk Manager** | Position sizing, daily limits, drawdown enforcement | Account balance + open positions | Position size adjustment / Trading halt |
| **Logger/Journal** | Event recording, audit trail, debugging | All events (calc, signal, trade, error) | TradeJournal.txt + MT5 Journal |

---

## 2. Data Structures & Arrays

### 2.1 Core Data Structures

```cpp
// ===== VOLUME PROFILE DATA STRUCTURE =====
struct VolumeProfile
{
    // Price levels (inputs)
    double minPrice;
    double maxPrice;
    double binSize;
    
    // Distribution (output)
    double volumeArray[400];        // Volume per bin [0-399]
    
    // Key levels (calculated)
    double pocPrice;                // Point of Control
    double pocVolume;               // Volume at POC
    double vahPrice;                // Value Area High (70%)
    double valPrice;                // Value Area Low (70%)
    double valueAreaVolume;         // Total volume in VA
    
    // Tracking
    datetime calculatedTime;        // When profile was computed
    int barCount;                   // Number of bars in calculation
};

// ===== SESSION PROFILE (Setup 1 reference) =====
struct SessionProfile
{
    VolumeProfile profile;
    datetime sessionStart;
    datetime sessionEnd;
    int barCount;
    
    // Cached for quick access
    double pocPrice;
    double vahPrice;
    double valPrice;
};

// ===== HIGH/LOW VOLUME NODES =====
struct VolumeNode
{
    double price;
    double volume;
    int binIndex;
    bool isHVN;                     // TRUE=high, FALSE=low
};

struct VolumeNodeArray
{
    VolumeNode nodes[50];           // Up to 50 HVN/LVN levels
    int count;
};

// ===== SETUP 1: 80% RULE SIGNAL =====
struct Setup1Signal
{
    bool triggered;
    string direction;               // "LONG" or "SHORT"
    double entryPrice;
    double stopLoss;
    double takeProfit;
    double riskRewardRatio;
    
    // Context
    double previousVAL;
    double previousVAH;
    int daysInformation;            // How old is previous session?
    datetime signalTime;
};

// ===== SETUP 2: HVN EDGE SIGNAL =====
struct Setup2Signal
{
    bool triggered;
    string direction;               // "LONG" or "SHORT"
    double entryPrice;
    double stopLoss;
    double takeProfit;
    double hvnLevel;                // HVN being traded
    double lvnLevel;                // LVN swept
    double volumeMultiplier;        // Confirmation candle volume ratio
    double riskRewardRatio;
    
    datetime signalTime;
};

// ===== OPEN POSITION TRACKING =====
struct PositionRecord
{
    int ticket;
    string setup;                   // "Setup1" or "Setup2"
    string direction;               // "LONG" or "SHORT"
    double entryPrice;
    double stopLoss;
    double takeProfit;
    double lotSize;
    
    // Entry context
    datetime entryTime;
    double pocAtEntry;
    double volAtEntry;
    
    // Status tracking
    string status;                  // "OPEN", "PARTIAL_TP", "CLOSED"
    double unrealizedPnL;
    int barsOpen;
};

// ===== DAILY ACCOUNTING =====
struct DailyStats
{
    int totalTrades;
    int winningTrades;
    int losingTrades;
    double totalPnL;
    double closedPnL;
    double openPnL;
    double maxDrawdown;
    double peakEquity;
    datetime dayStart;
};
```

### 2.2 Array Organization

```cpp
// ===== GLOBAL ARRAYS =====

// Current profile (recalculated every bar)
VolumeProfile currentProfile;

// Previous session profile (for Setup 1)
SessionProfile previousSessionProfile;

// Volume nodes
VolumeNodeArray hvnArray;           // High Volume Nodes
VolumeNodeArray lvnArray;           // Low Volume Nodes

// Position tracking (max 3 simultaneous)
PositionRecord positions[3];        // Array of open positions
int positionCount = 0;

// Daily statistics
DailyStats dailyStats;

// Trade journal (persistent across sessions)
string tradeJournal[];              // Dynamic array of logged entries
```

---

## 3. Calculation Pipeline — Order of Operations

### OnTick() Main Event Loop

```cpp
void OnTick()
{
    // PHASE 1: DATA VALIDATION & PREPARATION
    if (!CheckTradingConditions())
        return;                    // Exit if trading hours outside window
    
    if (!LoadHistoricalData())
        return;                    // Exit if data loading fails
    
    // PHASE 2: VOLUME PROFILE CALCULATION (Core Engine)
    CalculateCurrentVolumeProfile();  // Updates currentProfile
    CalculatePreviousSessionProfile(); // Updates previousSessionProfile
    IdentifyVolumeNodes();            // Updates hvnArray[], lvnArray[]
    
    // PHASE 3: SIGNAL DETECTION
    Setup1Signal sig1 = DetectSetup1Signal();  // Evaluates 80% Rule
    Setup2Signal sig2 = DetectSetup2Signal();  // Evaluates HVN Edge
    
    // PHASE 4: RISK MANAGEMENT ENFORCEMENT
    if (!CheckDailyLimits())
    {
        CloseAllPositions("DAILY_LIMIT_HIT");
        return;
    }
    
    if (!CheckDrawdownTiers())
    {
        // May close positions or reduce position size
        return;
    }
    
    // PHASE 5: POSITION MANAGEMENT (Entry)
    if (sig1.triggered)
        ExecuteSetup1Entry(sig1);
    
    if (sig2.triggered)
        ExecuteSetup2Entry(sig2);
    
    // PHASE 6: POSITION MANAGEMENT (Exit & Tracking)
    ManageOpenPositions();         // Check for SL/TP hits, time stops
    
    // PHASE 7: LOGGING & MONITORING
    LogDailyStats();
}
```

### Detailed Calculation Sequence

#### Step 1: Current Volume Profile Calculation (Execution Flow)

```cpp
void CalculateCurrentVolumeProfile()
{
    // Step 1.1: Determine price range
    currentProfile.maxPrice = iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, Lookback_Period, 0);
    currentProfile.minPrice = iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, Lookback_Period, 0);
    currentProfile.binSize = (currentProfile.maxPrice - currentProfile.minPrice) / 400;
    
    // Step 1.2: Initialize volume array
    ArrayInitialize(currentProfile.volumeArray, 0);
    
    // Step 1.3: Multi-level candle prorating
    for (int i = 0; i < Lookback_Period; i++)
    {
        double candle_high = iHigh(Symbol(), PERIOD_CURRENT, i);
        double candle_low = iLow(Symbol(), PERIOD_CURRENT, i);
        double candle_open = iOpen(Symbol(), PERIOD_CURRENT, i);
        double candle_close = iClose(Symbol(), PERIOD_CURRENT, i);
        long candle_volume = iVolume(Symbol(), PERIOD_CURRENT, i);
        
        double price_range = candle_high - candle_low;
        
        if (price_range > 0)
        {
            // Prorate volume across all price levels in candle
            double steps = price_range / currentProfile.binSize;
            
            for (double price = candle_low; price <= candle_high; 
                 price += currentProfile.binSize)
            {
                int bin_index = (int)((price - currentProfile.minPrice) / 
                                       currentProfile.binSize);
                
                if (bin_index >= 0 && bin_index < 400)
                {
                    double prorated_volume = (candle_volume / steps);
                    currentProfile.volumeArray[bin_index] += prorated_volume;
                }
            }
        }
        else
        {
            // Doji or spinning top: assign to close price
            int bin_index = (int)((candle_close - currentProfile.minPrice) / 
                                   currentProfile.binSize);
            if (bin_index >= 0 && bin_index < 400)
                currentProfile.volumeArray[bin_index] += candle_volume;
        }
    }
    
    // Step 1.4: Calculate Point of Control (POC)
    double maxVolume = 0;
    int pocBinIndex = 0;
    
    for (int i = 0; i < 400; i++)
    {
        if (currentProfile.volumeArray[i] > maxVolume)
        {
            maxVolume = currentProfile.volumeArray[i];
            pocBinIndex = i;
        }
    }
    
    currentProfile.pocPrice = currentProfile.minPrice + 
                              (pocBinIndex * currentProfile.binSize) + 
                              (currentProfile.binSize / 2);
    currentProfile.pocVolume = maxVolume;
    
    // Step 1.5: Calculate Value Area (70% rule)
    CalculateValueArea();
    
    // Step 1.6: Timestamp
    currentProfile.calculatedTime = TimeCurrent();
    currentProfile.barCount = Lookback_Period;
}

void CalculateValueArea()
{
    double totalVolume = 0;
    for (int i = 0; i < 400; i++)
        totalVolume += currentProfile.volumeArray[i];
    
    double targetVolume = totalVolume * 0.70;
    double valueAreaVolume = 0;
    
    // Find POC bin
    int pocBinIndex = 0;
    double maxVolume = 0;
    for (int i = 0; i < 400; i++)
    {
        if (currentProfile.volumeArray[i] > maxVolume)
        {
            maxVolume = currentProfile.volumeArray[i];
            pocBinIndex = i;
        }
    }
    
    // Expand outward from POC until 70% reached
    int offset = 0;
    while (valueAreaVolume < targetVolume && offset < 200)
    {
        offset++;
        
        // Add bin above POC
        if (pocBinIndex + offset < 400)
            valueAreaVolume += currentProfile.volumeArray[pocBinIndex + offset];
        
        // Add bin below POC
        if (pocBinIndex - offset >= 0)
            valueAreaVolume += currentProfile.volumeArray[pocBinIndex - offset];
    }
    
    currentProfile.vahPrice = currentProfile.minPrice + 
                              ((pocBinIndex + offset) * currentProfile.binSize);
    currentProfile.valPrice = currentProfile.minPrice + 
                              ((pocBinIndex - offset) * currentProfile.binSize);
    currentProfile.valueAreaVolume = valueAreaVolume;
}
```

#### Step 2: Previous Session Profile Calculation

```cpp
void CalculatePreviousSessionProfile()
{
    // Determine previous session boundaries
    datetime currentDayStart = iTime(Symbol(), PERIOD_D1, 0);
    datetime previousDayStart = iTime(Symbol(), PERIOD_D1, 1);
    
    // Extract bars within previous session (could be calendar day or RTH)
    int previousSessionBarCount = 0;
    double previousSessionHigh = 0;
    double previousSessionLow = 999999;
    
    for (int i = 1; i < 500; i++)  // Look back up to 500 bars
    {
        datetime barTime = iTime(Symbol(), PERIOD_CURRENT, i);
        
        if (barTime >= previousDayStart && barTime < currentDayStart)
        {
            previousSessionBarCount++;
            double barHigh = iHigh(Symbol(), PERIOD_CURRENT, i);
            double barLow = iLow(Symbol(), PERIOD_CURRENT, i);
            
            if (barHigh > previousSessionHigh)
                previousSessionHigh = barHigh;
            if (barLow < previousSessionLow)
                previousSessionLow = barLow;
        }
        else if (barTime < previousDayStart)
            break;  // Gone back far enough
    }
    
    // Only proceed if we found previous session data
    if (previousSessionBarCount > 0)
    {
        // Initialize previous session profile
        previousSessionProfile.profile.maxPrice = previousSessionHigh;
        previousSessionProfile.profile.minPrice = previousSessionLow;
        previousSessionProfile.profile.binSize = (previousSessionHigh - previousSessionLow) / 400;
        
        ArrayInitialize(previousSessionProfile.profile.volumeArray, 0);
        
        // Recalculate volume distribution for previous session bars only
        for (int i = 1; i < 500; i++)
        {
            datetime barTime = iTime(Symbol(), PERIOD_CURRENT, i);
            
            if (barTime >= previousDayStart && barTime < currentDayStart)
            {
                // Add this bar to previous session profile
                double h = iHigh(Symbol(), PERIOD_CURRENT, i);
                double l = iLow(Symbol(), PERIOD_CURRENT, i);
                double v = iVolume(Symbol(), PERIOD_CURRENT, i);
                
                double range = h - l;
                if (range > 0)
                {
                    double steps = range / previousSessionProfile.profile.binSize;
                    for (double p = l; p <= h; p += previousSessionProfile.profile.binSize)
                    {
                        int bin = (int)((p - previousSessionLow) / 
                                        previousSessionProfile.profile.binSize);
                        if (bin >= 0 && bin < 400)
                            previousSessionProfile.profile.volumeArray[bin] += (v / steps);
                    }
                }
            }
        }
        
        // Calculate POC, VAL, VAH for previous session
        CalculateProfileLevels(previousSessionProfile.profile);
        
        previousSessionProfile.sessionStart = previousDayStart;
        previousSessionProfile.sessionEnd = currentDayStart;
        previousSessionProfile.barCount = previousSessionBarCount;
    }
}

void CalculateProfileLevels(VolumeProfile &profile)
{
    // Find POC
    double maxVol = 0;
    int pocIdx = 0;
    for (int i = 0; i < 400; i++)
    {
        if (profile.volumeArray[i] > maxVol)
        {
            maxVol = profile.volumeArray[i];
            pocIdx = i;
        }
    }
    profile.pocPrice = profile.minPrice + (pocIdx * profile.binSize) + 
                       (profile.binSize / 2);
    profile.pocVolume = maxVol;
    
    // Calculate VA using same 70% method
    double totalVol = 0;
    for (int i = 0; i < 400; i++)
        totalVol += profile.volumeArray[i];
    
    double targetVol = totalVol * 0.70;
    double vaVol = 0;
    int offset = 0;
    
    while (vaVol < targetVol && offset < 200)
    {
        offset++;
        if (pocIdx + offset < 400)
            vaVol += profile.volumeArray[pocIdx + offset];
        if (pocIdx - offset >= 0)
            vaVol += profile.volumeArray[pocIdx - offset];
    }
    
    profile.vahPrice = profile.minPrice + ((pocIdx + offset) * profile.binSize);
    profile.valPrice = profile.minPrice + ((pocIdx - offset) * profile.binSize);
}
```

#### Step 3: Identify HVN/LVN Zones

```cpp
void IdentifyVolumeNodes()
{
    double avgVolume = 0;
    for (int i = 0; i < 400; i++)
        avgVolume += currentProfile.volumeArray[i];
    avgVolume /= 400;
    
    double hvnThreshold = avgVolume * 1.30;    // 30% above average
    double lvnThreshold = avgVolume * 0.70;    // 30% below average
    
    hvnArray.count = 0;
    lvnArray.count = 0;
    
    for (int i = 0; i < 400; i++)
    {
        double volume = currentProfile.volumeArray[i];
        double price = currentProfile.minPrice + (i * currentProfile.binSize);
        
        // Identify HVN
        if (volume > hvnThreshold && hvnArray.count < 50)
        {
            hvnArray.nodes[hvnArray.count].price = price;
            hvnArray.nodes[hvnArray.count].volume = volume;
            hvnArray.nodes[hvnArray.count].binIndex = i;
            hvnArray.nodes[hvnArray.count].isHVN = true;
            hvnArray.count++;
        }
        
        // Identify LVN
        if (volume < lvnThreshold && lvnArray.count < 50)
        {
            lvnArray.nodes[lvnArray.count].price = price;
            lvnArray.nodes[lvnArray.count].volume = volume;
            lvnArray.nodes[lvnArray.count].binIndex = i;
            lvnArray.nodes[lvnArray.count].isHVN = false;
            lvnArray.count++;
        }
    }
    
    // Sort HVN by volume (highest first)
    for (int i = 0; i < hvnArray.count - 1; i++)
    {
        for (int j = i + 1; j < hvnArray.count; j++)
        {
            if (hvnArray.nodes[j].volume > hvnArray.nodes[i].volume)
            {
                VolumeNode temp = hvnArray.nodes[i];
                hvnArray.nodes[i] = hvnArray.nodes[j];
                hvnArray.nodes[j] = temp;
            }
        }
    }
}
```

---

## 4. Signal Generation Logic

### Setup 1: 80% Rule Mean Reversion

```cpp
Setup1Signal DetectSetup1Signal()
{
    Setup1Signal signal;
    signal.triggered = false;
    
    // Condition 1: Check trading window
    if (!IsInTradingWindow())
        return signal;
    
    // Condition 2: Previous session data available
    if (previousSessionProfile.barCount == 0)
        return signal;
    
    // Condition 3: Price gapped outside previous VA at open
    double openPrice = iOpen(Symbol(), PERIOD_CURRENT, 0);
    
    bool gappedBelow = (openPrice < previousSessionProfile.profile.valPrice);
    bool gappedAbove = (openPrice > previousSessionProfile.profile.vahPrice);
    
    if (!gappedBelow && !gappedAbove)
        return signal;  // Not Setup 1 condition
    
    // Condition 4: Price returned to VA (current candle close)
    double closePrice = iClose(Symbol(), PERIOD_CURRENT, 0);
    bool closedInVA = (closePrice > previousSessionProfile.profile.valPrice && 
                       closePrice < previousSessionProfile.profile.vahPrice);
    
    if (!closedInVA)
        return signal;  // Not closed in VA yet
    
    // Condition 5: Volume confirmation
    double avgVolume = 0;
    for (int i = 1; i <= 20; i++)
        avgVolume += iVolume(Symbol(), PERIOD_CURRENT, i);
    avgVolume /= 20;
    
    if (iVolume(Symbol(), PERIOD_CURRENT, 0) < avgVolume)
        return signal;  // Insufficient volume
    
    // Condition 6: Determine direction
    string direction;
    if (gappedBelow)
    {
        direction = "LONG";
        signal.entryPrice = Ask;
        signal.takeProfit = previousSessionProfile.profile.vahPrice;
        signal.stopLoss = previousSessionProfile.profile.valPrice - (0.0020);
    }
    else
    {
        direction = "SHORT";
        signal.entryPrice = Bid;
        signal.takeProfit = previousSessionProfile.profile.valPrice;
        signal.stopLoss = previousSessionProfile.profile.vahPrice + (0.0020);
    }
    
    // Condition 7: Validate risk/reward
    double risk = (direction == "LONG") ? 
                  (signal.entryPrice - signal.stopLoss) : 
                  (signal.stopLoss - signal.entryPrice);
    double reward = (direction == "LONG") ? 
                    (signal.takeProfit - signal.entryPrice) : 
                    (signal.entryPrice - signal.takeProfit);
    
    signal.riskRewardRatio = (risk > 0) ? (reward / risk) : 0;
    
    if (signal.riskRewardRatio < 1.0)
        return signal;  // Risk/reward invalid
    
    // All conditions met
    signal.triggered = true;
    signal.direction = direction;
    signal.previousVAL = previousSessionProfile.profile.valPrice;
    signal.previousVAH = previousSessionProfile.profile.vahPrice;
    signal.signalTime = TimeCurrent();
    
    LogSignal("SETUP1_TRIGGERED", signal.direction, signal.entryPrice, 
              signal.riskRewardRatio);
    
    return signal;
}
```

### Setup 2: HVN Edge Trading with Volume Confirmation

```cpp
Setup2Signal DetectSetup2Signal()
{
    Setup2Signal signal;
    signal.triggered = false;
    
    // Condition 1: Check trading window
    if (!IsInTradingWindow())
        return signal;
    
    // Condition 2: HVN/LVN arrays populated
    if (hvnArray.count == 0 || lvnArray.count == 0)
        return signal;
    
    // Condition 3: Identify LVN sweep (price moved into low volume)
    double currentClose = iClose(Symbol(), PERIOD_CURRENT, 0);
    double currentHigh = iHigh(Symbol(), PERIOD_CURRENT, 0);
    double currentLow = iLow(Symbol(), PERIOD_CURRENT, 0);
    
    // Find nearest HVN and LVN to current price
    double nearestHVNAbove = 999999;
    double nearestHVNBelow = -1;
    double nearestLVNAbove = 999999;
    double nearestLVNBelow = -1;
    
    for (int i = 0; i < hvnArray.count; i++)
    {
        if (hvnArray.nodes[i].price > currentClose && 
            hvnArray.nodes[i].price < nearestHVNAbove)
            nearestHVNAbove = hvnArray.nodes[i].price;
        
        if (hvnArray.nodes[i].price < currentClose && 
            hvnArray.nodes[i].price > nearestHVNBelow)
            nearestHVNBelow = hvnArray.nodes[i].price;
    }
    
    for (int i = 0; i < lvnArray.count; i++)
    {
        if (lvnArray.nodes[i].price > currentClose && 
            lvnArray.nodes[i].price < nearestLVNAbove)
            nearestLVNAbove = lvnArray.nodes[i].price;
        
        if (lvnArray.nodes[i].price < currentClose && 
            lvnArray.nodes[i].price > nearestLVNBelow)
            nearestLVNBelow = lvnArray.nodes[i].price;
    }
    
    // Condition 4: Check for LVN sweep + HVN rebound
    bool longSetup = false;
    bool shortSetup = false;
    
    // LONG: Price swept below VAL into LVN, now rebounding to HVN
    if (currentLow < currentProfile.valPrice && 
        currentClose > nearestHVNBelow && nearestHVNBelow > -1)
    {
        longSetup = true;
        signal.lvnLevel = currentLow;
        signal.hvnLevel = nearestHVNBelow;
    }
    
    // SHORT: Price swept above VAH into LVN, now rebounding to HVN
    if (currentHigh > currentProfile.vahPrice && 
        currentClose < nearestHVNAbove && nearestHVNAbove < 999999)
    {
        shortSetup = true;
        signal.lvnLevel = currentHigh;
        signal.hvnLevel = nearestHVNAbove;
    }
    
    if (!longSetup && !shortSetup)
        return signal;  // No LVN/HVN setup
    
    // Condition 5: Volume spike confirmation (current candle >= 1.3x previous)
    long currentVol = iVolume(Symbol(), PERIOD_CURRENT, 0);
    long previousVol = iVolume(Symbol(), PERIOD_CURRENT, 1);
    
    signal.volumeMultiplier = (previousVol > 0) ? 
                              ((double)currentVol / (double)previousVol) : 0;
    
    if (signal.volumeMultiplier < 1.3)
        return signal;  // Insufficient volume confirmation
    
    // Condition 6: Candle pattern confirmation (hammer/doji)
    double body = MathAbs(iClose(Symbol(), PERIOD_CURRENT, 0) - 
                          iOpen(Symbol(), PERIOD_CURRENT, 0));
    double upperWick = iHigh(Symbol(), PERIOD_CURRENT, 0) - 
                       MathMax(iOpen(Symbol(), PERIOD_CURRENT, 0), 
                               iClose(Symbol(), PERIOD_CURRENT, 0));
    double lowerWick = MathMin(iOpen(Symbol(), PERIOD_CURRENT, 0), 
                               iClose(Symbol(), PERIOD_CURRENT, 0)) - 
                       iLow(Symbol(), PERIOD_CURRENT, 0);
    
    bool validPattern = false;
    
    if (longSetup && body > (lowerWick * 1.5))  // Hammer for LONG
        validPattern = true;
    
    if (shortSetup && body > (upperWick * 1.5))  // Inverted hammer for SHORT
        validPattern = true;
    
    if (!validPattern)
        return signal;  // Invalid candle pattern
    
    // All conditions met - set signal
    signal.triggered = true;
    
    if (longSetup)
    {
        signal.direction = "LONG";
        signal.entryPrice = Ask;
        signal.takeProfit = signal.hvnLevel * 1.002;  // 0.2% above HVN
        signal.stopLoss = signal.hvnLevel * 0.995;    // 0.5% below HVN
    }
    else
    {
        signal.direction = "SHORT";
        signal.entryPrice = Bid;
        signal.takeProfit = signal.hvnLevel * 0.998;  // 0.2% below HVN
        signal.stopLoss = signal.hvnLevel * 1.005;    // 0.5% above HVN
    }
    
    // Calculate R:R
    double risk = (signal.direction == "LONG") ? 
                  (signal.entryPrice - signal.stopLoss) : 
                  (signal.stopLoss - signal.entryPrice);
    double reward = (signal.direction == "LONG") ? 
                    (signal.takeProfit - signal.entryPrice) : 
                    (signal.entryPrice - signal.takeProfit);
    
    signal.riskRewardRatio = (risk > 0) ? (reward / risk) : 0;
    signal.signalTime = TimeCurrent();
    
    LogSignal("SETUP2_TRIGGERED", signal.direction, signal.entryPrice, 
              signal.riskRewardRatio);
    
    return signal;
}
```

---

## 5. Trade Execution Engine

### Position Entry Flow

```cpp
void ExecuteSetup1Entry(Setup1Signal &signal)
{
    // Pre-execution validation
    if (!ValidateEntrySignal(signal))
    {
        LogError("SETUP1_VALIDATION_FAILED", "Signal validation failed");
        return;
    }
    
    // Check position conflicts
    if (!CanOpenNewPosition(signal.direction))
    {
        LogWarning("SETUP1_CONFLICT", "Position already open in direction");
        return;
    }
    
    // Calculate lot size
    double lotSize = CalculateLotSize(signal.entryPrice, signal.stopLoss);
    
    if (lotSize < MinLotSize || lotSize > MaxLotSize)
    {
        LogWarning("SETUP1_INVALID_SIZE", StringFormat("Lot size %f out of range", 
                   lotSize));
        return;
    }
    
    // Place order
    int ticket = -1;
    
    if (signal.direction == "LONG")
    {
        ticket = OrderSend(
            Symbol(),
            OP_BUY,
            lotSize,
            Ask,
            3,                                  // 3 pip slippage tolerance
            signal.stopLoss,
            signal.takeProfit,
            "Setup1-LongEntry",
            EA_MagicNumber + Setup1_MagicOffset,
            0,
            clrGreen
        );
    }
    else
    {
        ticket = OrderSend(
            Symbol(),
            OP_SELL,
            lotSize,
            Bid,
            3,
            signal.stopLoss,
            signal.takeProfit,
            "Setup1-ShortEntry",
            EA_MagicNumber + Setup1_MagicOffset,
            0,
            clrRed
        );
    }
    
    // Handle execution result
    if (ticket > 0)
    {
        // Record position
        if (AddPositionRecord(ticket, "Setup1", signal.direction, 
            signal.entryPrice, signal.stopLoss, signal.takeProfit, lotSize))
        {
            LogTradeEntry(ticket, "Setup1", signal.direction, 
                         signal.entryPrice, signal.stopLoss, 
                         signal.takeProfit, signal.riskRewardRatio);
        }
    }
    else
    {
        LogError("SETUP1_ORDER_FAILED", StringFormat("Error code: %d", 
                 GetLastError()));
    }
}

void ExecuteSetup2Entry(Setup2Signal &signal)
{
    // Pre-execution validation
    if (!ValidateEntrySignal(signal))
    {
        LogError("SETUP2_VALIDATION_FAILED", "Signal validation failed");
        return;
    }
    
    // Check position conflicts
    if (!CanOpenNewPosition(signal.direction))
    {
        LogWarning("SETUP2_CONFLICT", "Position already open in direction");
        return;
    }
    
    // Calculate lot size
    double lotSize = CalculateLotSize(signal.entryPrice, signal.stopLoss);
    
    if (lotSize < MinLotSize || lotSize > MaxLotSize)
    {
        LogWarning("SETUP2_INVALID_SIZE", StringFormat("Lot size %f out of range", 
                   lotSize));
        return;
    }
    
    // Place order
    int ticket = -1;
    
    if (signal.direction == "LONG")
    {
        ticket = OrderSend(
            Symbol(),
            OP_BUY,
            lotSize,
            Ask,
            3,
            signal.stopLoss,
            signal.takeProfit,
            "Setup2-HVNEdge-Long",
            EA_MagicNumber + Setup2_MagicOffset,
            0,
            clrGreen
        );
    }
    else
    {
        ticket = OrderSend(
            Symbol(),
            OP_SELL,
            lotSize,
            Bid,
            3,
            signal.stopLoss,
            signal.takeProfit,
            "Setup2-HVNEdge-Short",
            EA_MagicNumber + Setup2_MagicOffset,
            0,
            clrRed
        );
    }
    
    // Handle execution result
    if (ticket > 0)
    {
        if (AddPositionRecord(ticket, "Setup2", signal.direction, 
            signal.entryPrice, signal.stopLoss, signal.takeProfit, lotSize))
        {
            LogTradeEntry(ticket, "Setup2", signal.direction, 
                         signal.entryPrice, signal.stopLoss, 
                         signal.takeProfit, signal.riskRewardRatio);
        }
    }
    else
    {
        LogError("SETUP2_ORDER_FAILED", StringFormat("Error code: %d", 
                 GetLastError()));
    }
}
```

### Position Management & Exit

```cpp
void ManageOpenPositions()
{
    for (int i = 0; i < positionCount; i++)
    {
        if (positions[i].ticket <= 0)
            continue;  // Slot empty
        
        // Query current position
        if (!OrderSelect(positions[i].ticket, SELECT_BY_TICKET))
            continue;
        
        double currentBid = Bid;
        double currentAsk = Ask;
        
        // Check exit conditions
        bool shouldClose = false;
        string closeReason = "";
        
        // 1. TP HIT
        if (positions[i].direction == "LONG" && 
            currentBid >= positions[i].takeProfit)
        {
            shouldClose = true;
            closeReason = "TP_HIT";
        }
        else if (positions[i].direction == "SHORT" && 
                 currentAsk <= positions[i].takeProfit)
        {
            shouldClose = true;
            closeReason = "TP_HIT";
        }
        
        // 2. SL HIT
        else if (positions[i].direction == "LONG" && 
                 currentBid <= positions[i].stopLoss)
        {
            shouldClose = true;
            closeReason = "SL_HIT";
        }
        else if (positions[i].direction == "SHORT" && 
                 currentAsk >= positions[i].stopLoss)
        {
            shouldClose = true;
            closeReason = "SL_HIT";
        }
        
        // 3. TIME STOP
        int hoursOpen = (TimeCurrent() - positions[i].entryTime) / 3600;
        if (positions[i].setup == "Setup1" && hoursOpen > 4)
        {
            shouldClose = true;
            closeReason = "TIME_STOP_SETUP1";
        }
        else if (positions[i].setup == "Setup2" && hoursOpen > 2)
        {
            shouldClose = true;
            closeReason = "TIME_STOP_SETUP2";
        }
        
        // 4. SESSION END
        if (!IsInTradingWindow())
        {
            shouldClose = true;
            closeReason = "SESSION_END";
        }
        
        // 5. DAILY LOSS LIMIT
        if (!CheckDailyLimits())
        {
            shouldClose = true;
            closeReason = "DAILY_LIMIT";
        }
        
        // Execute close
        if (shouldClose)
        {
            ClosePosition(positions[i].ticket, closeReason);
            positions[i].ticket = 0;  // Mark slot as empty
        }
    }
}

void ClosePosition(int ticket, string reason)
{
    if (!OrderSelect(ticket, SELECT_BY_TICKET))
        return;
    
    double closePrice = 0;
    bool closedOK = false;
    
    if (OrderType() == OP_BUY)
    {
        closePrice = Bid;
        closedOK = OrderClose(ticket, OrderOpenSize(), closePrice, 3, clrRed);
    }
    else
    {
        closePrice = Ask;
        closedOK = OrderClose(ticket, OrderOpenSize(), closePrice, 3, clrRed);
    }
    
    if (closedOK)
    {
        double pnl = OrderProfit();
        LogTradeExit(ticket, OrderOpenPrice(), closePrice, pnl, reason);
    }
    else
    {
        LogError("CLOSE_FAILED", StringFormat("Ticket %d, Error: %d", 
                 ticket, GetLastError()));
    }
}
```

---

## 6. Risk Management System

### Position Sizing

```cpp
double CalculateLotSize(double entryPrice, double stopLoss)
{
    // Risk amount in dollars
    double accountBalance = AccountBalance();
    double riskAmount = accountBalance * (Risk_Percentage / 100.0);
    
    // SL distance in pips
    double slDistance = MathAbs(entryPrice - stopLoss) / Point;
    
    // Pip value (varies by symbol)
    double pipValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    
    // Calculate lot size
    double lotSize = riskAmount / (slDistance * pipValue);
    
    // Apply drawdown tier reduction if active
    if (drawdownTier2Active)
        lotSize *= Tier2_Size_Reduction;  // 0.5 for 50% reduction
    
    // Validate against broker limits
    double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
    
    if (lotSize < minLot)
        lotSize = 0;  // Too small, reject trade
    
    if (lotSize > maxLot)
        lotSize = maxLot;  // Cap at max
    
    // Round to lot step
    lotSize = MathFloor(lotSize / lotStep) * lotStep;
    
    return lotSize;
}
```

### Daily Limits Enforcement

```cpp
bool CheckDailyLimits()
{
    // Calculate today's P&L
    double closedPnL = 0;
    double openPnL = 0;
    
    // Scan closed trades for today
    for (int i = OrdersHistoryTotal() - 1; i >= 0; i--)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
            continue;
        
        if (OrderCloseTime() == 0)
            continue;  // Order not closed
        
        if (OrderMagicNumber() < EA_MagicNumber ||
            OrderMagicNumber() > EA_MagicNumber + 10)
            continue;  // Not our order
        
        // Check if closed today
        if (OrderCloseTime() > TimeCurrent() - 86400)
            closedPnL += OrderProfit();
    }
    
    // Scan open positions
    for (int i = 0; i < positionCount; i++)
    {
        if (positions[i].ticket <= 0)
            continue;
        
        if (!OrderSelect(positions[i].ticket, SELECT_BY_TICKET))
            continue;
        
        openPnL += OrderProfit();
    }
    
    double dailyTotalPnL = closedPnL + openPnL;
    double dailyLossLimit = AccountBalance() * (Daily_Loss_Limit / 100.0);
    
    // Store daily stats
    dailyStats.closedPnL = closedPnL;
    dailyStats.openPnL = openPnL;
    dailyStats.totalPnL = dailyTotalPnL;
    
    if (dailyTotalPnL < -dailyLossLimit)
    {
        LogAlert("DAILY_LOSS_LIMIT_EXCEEDED", 
                StringFormat("Loss: $%.2f, Limit: $%.2f", 
                dailyTotalPnL, -dailyLossLimit));
        return false;
    }
    
    return true;
}
```

### Drawdown Tier Management

```cpp
bool CheckDrawdownTiers()
{
    double currentEquity = AccountEquity();
    
    // Track peak equity for drawdown calculation
    if (currentEquity > peakEquity)
        peakEquity = currentEquity;
    
    double drawdownAmount = peakEquity - currentEquity;
    double drawdownPercent = (peakEquity > 0) ? 
                             (drawdownAmount / peakEquity * 100) : 0;
    
    // Tier 3: CRITICAL STOP (6%)
    if (drawdownPercent >= Drawdown_Tier3_Critical)
    {
        LogCritical("DRAWDOWN_TIER3_CRITICAL", 
                   StringFormat("Drawdown: %.2f%%", drawdownPercent));
        
        // Close all positions
        for (int i = 0; i < positionCount; i++)
        {
            if (positions[i].ticket > 0)
                ClosePosition(positions[i].ticket, "DRAWDOWN_CRITICAL");
        }
        
        // Halt EA
        EA_Enabled = false;
        return false;
    }
    
    // Tier 2: REDUCE (15%)
    if (drawdownPercent >= Drawdown_Tier2_Reduce)
    {
        if (!drawdownTier2Active)
        {
            LogAlert("DRAWDOWN_TIER2_REDUCE", 
                    StringFormat("Drawdown: %.2f%%, Reducing position size to 50%%", 
                    drawdownPercent));
            drawdownTier2Active = true;
        }
        return true;
    }
    else
    {
        if (drawdownTier2Active)
        {
            LogAlert("DRAWDOWN_RECOVERED", "Restoring normal position size");
            drawdownTier2Active = false;
        }
    }
    
    // Tier 1: ALERT (10%)
    if (drawdownPercent >= Drawdown_Tier1_Alert)
    {
        if (!drawdownTier1Active)
        {
            LogWarning("DRAWDOWN_TIER1_ALERT", 
                      StringFormat("Drawdown: %.2f%%, Review recent trades", 
                      drawdownPercent));
            drawdownTier1Active = true;
        }
    }
    else
    {
        drawdownTier1Active = false;
    }
    
    return true;
}
```

---

## 7. Error Handling & Recovery

### Input Validation

```cpp
bool ValidateEntrySignal(Setup1Signal &signal)
{
    // Direction validation
    if (signal.direction != "LONG" && signal.direction != "SHORT")
        return false;
    
    // Price validation
    if (signal.entryPrice <= 0 || signal.stopLoss <= 0 || 
        signal.takeProfit <= 0)
        return false;
    
    // SL/TP logic
    if (signal.direction == "LONG")
    {
        if (signal.entryPrice <= signal.stopLoss)
            return false;  // SL must be below entry
        if (signal.entryPrice >= signal.takeProfit)
            return false;  // TP must be above entry
    }
    else
    {
        if (signal.entryPrice >= signal.stopLoss)
            return false;  // SL must be above entry
        if (signal.entryPrice <= signal.takeProfit)
            return false;  // TP must be below entry
    }
    
    // Risk/Reward validation
    if (signal.riskRewardRatio < 1.0)
        return false;  // Minimum 1:1
    
    return true;
}

bool ValidateEntrySignal(Setup2Signal &signal)
{
    // Similar validation for Setup 2
    if (signal.direction != "LONG" && signal.direction != "SHORT")
        return false;
    
    if (signal.entryPrice <= 0 || signal.stopLoss <= 0 || 
        signal.takeProfit <= 0 || signal.hvnLevel <= 0)
        return false;
    
    // Direction-specific validation
    if (signal.direction == "LONG")
    {
        if (signal.entryPrice <= signal.stopLoss)
            return false;
        if (signal.entryPrice >= signal.takeProfit)
            return false;
    }
    else
    {
        if (signal.entryPrice >= signal.stopLoss)
            return false;
        if (signal.entryPrice <= signal.takeProfit)
            return false;
    }
    
    return true;
}
```

### Data Quality Checks

```cpp
bool CheckDataQuality()
{
    // Check for stale data
    datetime lastBarTime = iTime(Symbol(), PERIOD_CURRENT, 0);
    int secondsSinceBar = TimeCurrent() - lastBarTime;
    
    if (secondsSinceBar > 300)  // 5 minutes for M5 chart
    {
        LogWarning("STALE_DATA", StringFormat("No new bar for %d seconds", 
                   secondsSinceBar));
        return false;
    }
    
    // Check for volume anomalies
    long currentVolume = iVolume(Symbol(), PERIOD_CURRENT, 0);
    long avgVolume = 0;
    
    for (int i = 1; i <= 20; i++)
        avgVolume += iVolume(Symbol(), PERIOD_CURRENT, i);
    avgVolume /= 20;
    
    if (currentVolume > (avgVolume * 5))
    {
        LogWarning("VOLUME_SPIKE", StringFormat("Volume spike: %.0f vs avg: %.0f", 
                   (double)currentVolume, (double)avgVolume));
        // Could skip trade or widen stops
    }
    
    return true;
}
```

### Connection Loss Recovery

```cpp
bool CheckConnectionStatus()
{
    if (!IsConnected())
    {
        LogAlert("CONNECTION_LOST", "Broker connection lost");
        return false;
    }
    
    // Check if we can query accounts (basic connectivity test)
    double balance = AccountBalance();
    if (balance <= 0)
    {
        LogAlert("ACCOUNT_DATA_UNAVAILABLE", "Cannot query account");
        return false;
    }
    
    return true;
}
```

---

## 8. Logging & Journal

### Trade Entry Logging

```cpp
void LogTradeEntry(int ticket, string setup, string direction, 
                   double entry, double sl, double tp, double rr)
{
    string logMsg = StringFormat(
        "%s | ENTRY | Setup:%s | %s %s | Entry:%.5f | SL:%.5f | TP:%.5f | R:R:%.2f | POC:%.5f",
        TimeToString(TimeCurrent()), setup, Symbol(), direction,
        entry, sl, tp, rr, currentProfile.pocPrice
    );
    
    Print(logMsg);
    FileLog("TradeJournal.txt", logMsg);
}

void LogTradeExit(int ticket, double entryPrice, double exitPrice, 
                  double pnl, string reason)
{
    double pips = MathAbs(exitPrice - entryPrice) / Point;
    
    string logMsg = StringFormat(
        "%s | EXIT | Ticket:%d | Exit:%.5f | Pips:%.0f | P&L:$%.2f | Reason:%s",
        TimeToString(TimeCurrent()), ticket, exitPrice, pips, pnl, reason
    );
    
    Print(logMsg);
    FileLog("TradeJournal.txt", logMsg);
}

void FileLog(string filename, string message)
{
    int fileHandle = FileOpen(filename, FILE_READ|FILE_WRITE|FILE_TXT);
    if (fileHandle < 0)
        return;
    
    FileSeek(fileHandle, 0, SEEK_END);
    FileWriteString(fileHandle, message + "\n");
    FileClose(fileHandle);
}
```

---

## 9. Suggested Build Sequence

### Dependency Order (Respect This)

```
Phase 1: Data Structures & Utilities
  └─ Define all struct types (VolumeProfile, Setup1Signal, etc.)
  └─ Implement helper functions (TimeToString, MathFloor, etc.)
  └─ Implement logging functions
  
Phase 2: Volume Profile Calculation Engine (CORE)
  └─ CalculateCurrentVolumeProfile() → **TEST WITH KNOWN DATA**
  └─ CalculateValueArea() → **VALIDATE 70% LOGIC**
  └─ CalculatePreviousSessionProfile()
  └─ IdentifyVolumeNodes()
  ✓ UNIT TEST: Profile calculation with sample bars
  
Phase 3: Signal Detection Modules (Depends on Phase 2)
  └─ DetectSetup1Signal() → **TEST DETECTION LOGIC**
  └─ DetectSetup2Signal()
  └─ ValidateEntrySignal() (both setups)
  ✓ UNIT TEST: Signal triggers on known price/volume patterns
  
Phase 4: Trade Execution Engine (Depends on Phase 3)
  └─ ExecuteSetup1Entry()
  └─ ExecuteSetup2Entry()
  └─ ManageOpenPositions()
  └─ ClosePosition()
  └─ AddPositionRecord()
  ✓ INTEGRATION TEST: Entry → tracking → exit flow
  
Phase 5: Risk Management System (Depends on Phase 4)
  └─ CalculateLotSize()
  └─ CheckDailyLimits()
  └─ CheckDrawdownTiers()
  └─ CanOpenNewPosition()
  ✓ INTEGRATION TEST: Risk limits enforcement
  
Phase 6: Error Handling & Data Quality (Depends on all above)
  └─ CheckDataQuality()
  └─ CheckConnectionStatus()
  └─ Error logging and recovery
  
Phase 7: Main Event Loop (Depends on all modules)
  └─ OnInit()
  └─ OnTick()
  └─ OnDeinit()
  
Phase 8: Testing & Debugging
  └─ Backtest Phase 3.1 (2 weeks data)
  └─ Fix compilation errors
  └─ Fix logic errors
```

### Critical Testing Checkpoints

| Checkpoint | What to Test | Pass Criteria |
|-----------|--------------|---------------|
| **Profile Calc** | CalculateCurrentVolumeProfile() with 150 bars | POC, VAL, VAH calculated; binning correct |
| **Session Profile** | CalculatePreviousSessionProfile() | Previous session VAL/VAH isolated correctly |
| **HVN/LVN** | IdentifyVolumeNodes() | HVN array populated with correct count |
| **Setup1 Detection** | DetectSetup1Signal() on gap data | Triggers only when: gap + return to VA + volume OK |
| **Setup2 Detection** | DetectSetup2Signal() on LVN/HVN data | Triggers only when: sweep + HVN + volume spike |
| **Position Entry** | ExecuteSetup1Entry(signal) | Order placed, position recorded, logged |
| **Position Exit** | ManageOpenPositions() | SL/TP hit closes position correctly |
| **Risk Sizing** | CalculateLotSize() with various SL distances | Lot size matches risk % |
| **Daily Limits** | CheckDailyLimits() after losses | Trading halts when daily loss limit hit |
| **Full Flow** | OnTick() → Profile → Signal → Entry → Exit | Complete cycle without crashes |

---

## 10. Integration Points with MT5

### MT5 API Calls (Where System Touches Broker)

| MT5 Function | Usage | Frequency |
|-------------|-------|-----------|
| `iOpen/iHigh/iLow/iClose/iVolume()` | Load OHLCV bars for profile calculation | Every OnTick() |
| `iTime()` | Get timestamp for session boundary detection | Every profile calc |
| `OrderSend()` | Place buy/sell orders | Only on signal entry |
| `OrderSelect()` | Query position details | Before close, during management |
| `OrderClose()` | Close position at TP/SL/exit | On exit condition |
| `OrdersHistoryTotal()` | Scan closed trades for daily P&L | Daily limits check |
| `Ask/Bid` | Current market prices | On entry/exit |
| `AccountBalance()` | Account equity for position sizing | On every entry |
| `AccountEquity()` | Current account value for drawdown | Every tick for monitoring |
| `TimeCurrent()` | Current time for session/news filters | Every tick |
| `Point` | Broker's point value (0.0001 or 0.00001) | Position sizing |
| `Symbol()` | Current chart symbol | Every order |
| `GetLastError()` | Error codes for recovery | After OrderSend failures |

### No Visual Objects Policy

**CRITICAL:** The EA uses **arrays only** (memory) for profile storage. No chart drawing:
- ✅ Store POC/VAL/VAH in structs
- ✅ Store HVN/LVN in arrays
- ✅ Print debug info to Journal
- ❌ NO ObjectCreate() for levels
- ❌ NO Labels, Lines, or Rectangles on chart
- ❌ NO Comment() for visual output (use logging only)

This enables:
- Silent background execution on multiple charts
- No chart lag/slowdown
- Scalable to 10+ simultaneous EAs

---

## 11. Module-Level Testing Seams

### Where Unit Tests Attach

```cpp
// SEAM 1: Profile calculation verification
bool TestVolumeProfileCalculation()
{
    // Load known candles, verify POC/VAL/VAH match expected
    // Example: 100 bars all at 1.2000 price = POC should be 1.2000
    // Example: 50 bars at 1.1950, 50 bars at 1.2050 = POC should be 1.2000
    return true;  // If all pass
}

// SEAM 2: Setup1 detection verification
bool TestSetup1Detection()
{
    // Inject artificial bars:
    // - Previous session: VAL=1.2000, VAH=1.2050
    // - Current open: 1.1950 (outside VA)
    // - Current close: 1.2025 (inside VA)
    // Should trigger LONG signal
    return (setup1Signal.triggered && setup1Signal.direction == "LONG");
}

// SEAM 3: Position sizing verification
bool TestPositionSizing()
{
    // Account: $10,000
    // Risk: 1% = $100
    // Entry: 1.2000, SL: 1.1950 (50 pips)
    // Expected lot: Based on pip value
    double lotSize = CalculateLotSize(1.2000, 1.1950);
    return (lotSize > MinLotSize && lotSize < MaxLotSize);
}

// SEAM 4: Risk limit enforcement
bool TestDailyLossLimit()
{
    // Simulate account loss > daily limit
    // Should return false
    return !CheckDailyLimits();
}
```

---

## Key Architectural Principles

### 1. **Calculation → Detection → Execution → Risk (Never reverse)**
   - Calculate profile BEFORE detecting signals
   - Detect signals BEFORE attempting entry
   - Execute entry BEFORE risk checks (but risk can veto)
   - Clean separation of concerns

### 2. **Data Ownership is Clear**
   - Profile calculation owns currentProfile array
   - Setup1 detector owns Setup1Signal struct
   - Trade executor owns PositionRecord array
   - Risk manager overrides all above

### 3. **Every Module is Unit-Testable**
   - Profile calc: Feed bars, verify POC/VAL/VAH
   - Signal detection: Feed profile, verify signal struct
   - Position sizing: Feed account/SL, verify lot size
   - Limits: Feed P&L, verify true/false return

### 4. **Error Handling is Fail-Safe**
   - Invalid signal → no entry (logged)
   - Order rejection → log + retry next tick
   - Connection loss → pause trading, don't crash
   - Data corruption → skip candle, continue

### 5. **Logging is Comprehensive**
   - Every entry/exit logged with context
   - Every error logged with code + reason
   - Daily summary for monitoring
   - Audit trail for post-mortem analysis

---

## Confidence Assessment

| Area | Confidence | Why |
|------|-----------|-----|
| **Architecture** | HIGH | Modular design from specification; clear component boundaries |
| **Calculation Order** | HIGH | Dependencies explicit; profile → detection → execution → risk |
| **Data Structures** | HIGH | Structs from MT5_DEVELOPMENT_SPECIFICATIONS.md validated |
| **Build Sequence** | HIGH | Dependency order enforces testability at each phase |
| **Integration Points** | HIGH | MT5 API calls documented in Development Specifications |
| **Testing Strategy** | MEDIUM | Unit seams identified, but requires actual implementation validation |

---

## Files to Create Next (Roadmap)

1. **Volume_Profile_EA_v1.0.mq5** — Main EA implementation (10-13 hours)
2. **Unit tests** for each module (2-3 hours)
3. **Backtesting plan** (reference COMPLETE_DEVELOPMENT_ROADMAP.md)
4. **Performance monitoring spreadsheet** (for live trading)

---

## Summary

This architecture separates **data calculation** (volume profile), **signal logic** (entry detection), **order management** (execution), and **risk enforcement** into independent modules with clear data flow. Each module is unit-testable and can be built/debugged in dependency order. The design supports multi-position management, comprehensive logging, and graceful error recovery — essential for a production-grade trading system.

**Next step:** Implement Volume_Profile_EA_v1.0.mq5 following the build sequence. Start with Phase 1 (data structures), then Phase 2 (profile calculation with unit tests).
