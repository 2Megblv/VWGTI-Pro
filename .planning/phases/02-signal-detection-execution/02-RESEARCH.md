# Phase 2: Signal Detection & Execution - Research

**Researched:** 2026-05-13  
**Domain:** MT5 Expert Advisor trade signal detection, order placement, position management, journal logging  
**Confidence:** HIGH (Phase 1 code available for reference; MQL5/MT5 documentation verified)

---

## Summary

Phase 2 implements complete end-to-end trade execution for both entry setups (Setup 1: 80% Rule Mean Reversion, Setup 2: HVN Edge Momentum). The EA detects market conditions algorithmically, identifies entry signals with strict criteria, executes trades with slippage protection, manages partial position exits, tracks daily risk limits, and logs all trades with complete audit trail.

**Primary recommendation:** Modularize Phase 1 code into 3 header files (VolumeProfile.mqh, RiskManager.mqh, TradeExecution.mqh) before Phase 2 implementation. Use CTrade standard library for order placement with post-execution price validation. Implement position state machine tracking remaining lots rather than separate TP order tracking.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Balanced/imbalanced market detection | Backend (EA) | — | Calculate VA width ratio (D-01); triggers Setup 1 vs 2 context |
| Setup 1 signal detection (gap/reclaim/confirmation) | Backend (EA) | — | Array-based analysis of VAL/VAH vs price; no visual objects |
| Setup 2 signal detection (LVN sweep/HVN edge/pattern) | Backend (EA) | — | Candle pattern recognition + volume comparison; array state |
| Order placement & slippage validation | Backend (EA) | — | CTrade market orders with post-execution price verification |
| Position state tracking | Backend (EA) | — | Remaining lots tracking; single TP per position |
| Daily limit enforcement | Backend (EA) | — | Persistent P&L tracking; hard stop / profit cap flags |
| Journal logging | Backend (EA) | — | File I/O with structured trade details |
| Friday hard close | Backend (EA) | — | Broker server time check + force-close all |

---

## Standard Stack

### Core Libraries
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| CTrade (MQL5 Standard) | MT5 Build 4000+ | Trade order placement and execution | Official MQL5 recommended class; handles order validation, retries, error reporting |
| MQL5 Native Arrays | MT5 Build 4000+ | Volume profile storage, position state, HVN/LVN arrays | Native performance; no external dependencies |
| MT5 Account Functions | MT5 Build 4000+ | Balance tracking, daily P&L, account validation | Broker-agnostic access to account state |
| MT5 Time Functions | MT5 Build 4000+ | Session boundary detection, Friday close timing | Broker server time authority |

### Pattern & Calculation Framework
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Phase 1 VolumeProfile.mqh (refactored) | v1.0 | POC/VAH/VAL/HVN/LVN arrays, profile calculation | Signal detection (read-only access to profile arrays) |
| Phase 1 RiskManager.mqh (refactored) | v1.0 | Daily P&L tracking, lot size formula, limit flags | Entry validation, position sizing, daily stop enforcement |

### No External Indicators
- ✅ Volume Profile: calculated in Phase 1, read in Phase 2
- ✅ Candle patterns: detected via OHLC arrays (no external indicator)
- ✅ Volume spike: compared via iVolume() native MT5 function

---

## Architecture Patterns

### System Architecture Diagram

```
┌──────────────────────────────────────────────────────────────┐
│  OnTick() Event Handler                                      │
└────────────────────┬─────────────────────────────────────────┘
                     │
        ┌────────────▼─────────────┐
        │  Recalculate Profile     │
        │  (Phase 1 engine)        │
        │  → POC, VAH, VAL, HVN,   │
        │    LVN arrays            │
        └────────────┬─────────────┘
                     │
        ┌────────────▼─────────────────────┐
        │  Detect Market Context           │
        │  (Balanced vs Imbalanced)        │
        │  → VA width / recent range       │
        │  → Select Setup 1 or Setup 2     │
        └────────────┬─────────────────────┘
                     │
        ┌────────────▼─────────────────────┐
        │  Check Signal Conditions         │
        ├─────────────────────────────────┤
        │  If Balanced:                    │
        │    → Setup 1: Gap/Reclaim/      │
        │       Confirmation candle       │
        │  If Imbalanced:                 │
        │    → Setup 2: LVN sweep/        │
        │       HVN edge/Pattern/Volume   │
        └────────────┬─────────────────────┘
                     │
        ┌────────────▼─────────────────────┐
        │  Signal Triggered?              │
        │  YES → Validate Entry Conditions│
        │  NO → Return (wait next bar)    │
        └────────────┬─────────────────────┘
                     │
        ┌────────────▼─────────────────────┐
        │  Calculate Position Details     │
        │  → Entry price                  │
        │  → Stop loss price              │
        │  → Take profit price            │
        │  → Lot size (risk-based)        │
        │  → Risk/Reward ratio            │
        └────────────┬─────────────────────┘
                     │
        ┌────────────▼─────────────────────┐
        │  Check Daily Limits & Risk      │
        │  → Daily hard stop (-2%)?       │
        │  → Daily profit cap (+5%)?      │
        │  → Max 1 position per asset?    │
        │  → Max 1 open position total?   │
        │  → Friday 21:45 close?          │
        └────────────┬─────────────────────┘
                     │
        ┌────────────▼─────────────────────┐
        │  Place Market Order (CTrade)    │
        │  → OrderSend() with deviation   │
        │    50 pips max                  │
        │  → Validate post-fill price     │
        │  → Reject if slippage > 50 pips │
        └────────────┬─────────────────────┘
                     │
        ┌────────────▼─────────────────────┐
        │  Update Position State          │
        │  → Add to positions[] array     │
        │  → Track remaining lots         │
        │  → Store entry details          │
        │  → Set entry timestamp          │
        └────────────┬─────────────────────┘
                     │
        ┌────────────▼─────────────────────┐
        │  Log Trade Entry to Journal     │
        │  → Entry time, price, size      │
        │  → Setup type, SL, TP, R:R      │
        └────────────┬─────────────────────┘
                     │
        ┌────────────▼─────────────────────┐
        │  Monitor Position (every tick)   │
        │  → Check if TP hit (close)      │
        │  → Check if SL hit (close)      │
        │  → Check daily limits (close)   │
        │  → Check Friday close (close)   │
        │  → Adjust SL to profit if cap   │
        └────────────┬─────────────────────┘
                     │
        ┌────────────▼─────────────────────┐
        │  Close Position                 │
        │  → Remove from positions[] array│
        │  → Log exit details to Journal  │
        │  → Record P&L, exit reason      │
        └──────────────────────────────────┘
```

### Recommended Project Structure (Phase 2 Refactoring)

```
src/
├── VolumeProfile_EA_v1.0.mq5          # Main EA file (orchestrator)
├── Include/
│   ├── VolumeProfile.mqh              # Profile calculation (Phase 1 refactored)
│   │   ├── CalculateCurrentVolumeProfile()
│   │   ├── CalculateValueArea()
│   │   └── IdentifyVolumeNodes()
│   ├── RiskManager.mqh                # Risk management (Phase 1 refactored)
│   │   ├── CalculateLotSize()
│   │   ├── CheckDailyLimits()
│   │   ├── CheckProfitCap()
│   │   └── CheckFridayClose()
│   ├── TradeExecution.mqh             # Phase 2 NEW
│   │   ├── struct PositionState
│   │   ├── DetectMarketContext()
│   │   ├── DetectSetup1Signal()
│   │   ├── DetectSetup2Signal()
│   │   ├── PlaceMarketOrder()
│   │   ├── ValidateSlippage()
│   │   ├── UpdatePositionState()
│   │   ├── ClosePosition()
│   │   └── RetryOrderWithBackoff()
│   └── JournalLogger.mqh              # Phase 2 NEW
│       ├── LogTradeEntry()
│       ├── LogTradeExit()
│       ├── LogOrderRejection()
│       └── struct TradeJournalRecord
└── tests/
    ├── test_VolumeProfile.mq5
    ├── test_RiskManager.mq5
    ├── test_TradeExecution.mq5
    └── test_JournalLogger.mq5
```

### Pattern 1: Balanced Market Detection (Setup 1 Trigger)

**What:** Detect balanced/consolidating market when VA width is narrow relative to recent price movement.

**When to use:** Before evaluating Setup 1 entry conditions. If balanced, Setup 1 signals are valid. If imbalanced, Setup 1 signals are ignored.

**Code Pattern:**

```mql5
// Source: Phase 2 CONTEXT.md D-01 & PROJECT.md Market Condition Detection
bool IsBalancedMarket()
{
    // Calculate recent range (e.g., last 20 bars)
    double lookbackHigh = iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, 20, 0);
    double lookbackLow = iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, 20, 0);
    double recentRange = lookbackHigh - lookbackLow;
    
    // Calculate VA width from profile
    double vaWidth = currentProfile.vahPrice - currentProfile.valPrice;
    
    // Balanced when VA < 0.6x recent range (locked per D-01)
    double balanceThreshold = recentRange * 0.6;  // Range 0.6-0.7x; using 0.6 as conservative
    
    return (vaWidth < balanceThreshold);
}

// In OnTick():
if (IsBalancedMarket())
{
    // Watch for Setup 1 signals (gap/reclaim/confirmation)
    if (DetectSetup1Signal())
    {
        // Execute Setup 1 entry
    }
}
else
{
    // Watch for Setup 2 signals (LVN/HVN/pattern/volume)
    if (DetectSetup2Signal())
    {
        // Execute Setup 2 entry
    }
}
```

### Pattern 2: Setup 1 Gap/Reclaim/Confirmation Detection

**What:** Identify when price opens outside previous session's VA, reclaims back into VA, and closes fully inside VA (not wick touch).

**When to use:** In balanced market conditions to trigger LONG or SHORT entries with edge-to-edge TP targeting.

**Code Pattern:**

```mql5
// Source: Phase 2 CONTEXT.md D-02, REQUIREMENTS.md REQ-011–014
struct Setup1Signal
{
    bool isTriggered;
    bool isLong;                  // true = LONG, false = SHORT
    double confirmationClose;     // Close price of confirmation candle
    double sweepLow;             // Lowest price when gap occurred (for SL)
};

Setup1Signal DetectSetup1Signal()
{
    Setup1Signal result = {false, false, 0, 0};
    
    // REQ-011: Balanced market detection (checked by caller via IsBalancedMarket())
    
    // REQ-012: Gap detection — price opened outside previous session VA
    double previousVAH = prevSessionVA.vahPrice;  // From Phase 1
    double previousVAL = prevSessionVA.valPrice;
    
    double openPrice = iOpen(Symbol(), PERIOD_CURRENT, 0);
    double closePrice = iClose(Symbol(), PERIOD_CURRENT, 0);
    double lowPrice = iLow(Symbol(), PERIOD_CURRENT, 0);
    
    bool gappedAboveVA = (openPrice > previousVAH);
    bool gappedBelowVA = (openPrice < previousVAL);
    
    if (!gappedAboveVA && !gappedBelowVA)
        return result;  // No gap; skip
    
    // REQ-013: Reclaim detection — price reclaimed into VA on current bar
    bool reclaimingUp = (gappedBelowVA && closePrice >= previousVAL);
    bool reclaimingDown = (gappedAboveVA && closePrice <= previousVAH);
    
    if (!reclaimingUp && !reclaimingDown)
        return result;  // No reclaim; skip
    
    // REQ-014: Confirmation candle — close FULLY inside VA (not wick touch)
    bool closeInsideVA = (closePrice >= previousVAL && closePrice <= previousVAH);
    
    if (!closeInsideVA)
        return result;  // Wick touch or rejected; skip
    
    // Signal triggered!
    result.isTriggered = true;
    result.isLong = reclaimingUp;               // LONG if reclaiming from below
    result.confirmationClose = closePrice;
    result.sweepLow = lowPrice;                 // Used for SL calculation
    
    return result;
}

// In OnTick():
Setup1Signal sig = DetectSetup1Signal();
if (sig.isTriggered)
{
    // REQ-015 (LONG) or REQ-016 (SHORT): Entry execution
    double entryPrice = sig.confirmationClose;  // Market order at close
    double stopLoss = sig.sweepLow - 10 * Point;  // Below sweep low per D-01
    double takeProfit = sig.isLong ? currentProfile.vahPrice : currentProfile.valPrice;  // D-03
    
    double lotSize = CalculateLotSize(entryPrice, stopLoss);
    
    PlaceMarketOrder(sig.isLong ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                     lotSize, entryPrice, stopLoss, takeProfit);
}
```

### Pattern 3: Setup 2 Trigger Pattern + Volume Spike Detection

**What:** Recognize Hammer (LONG), Shooting Star (SHORT), or Doji at HVN edge with volume ≥ 1.3x previous bar.

**When to use:** In imbalanced market conditions to trigger momentum entries targeting opposite profile edge.

**Code Pattern:**

```mql5
// Source: Phase 2 CONTEXT.md D-04, REQUIREMENTS.md REQ-017–021
struct CandlePattern
{
    enum Type { NONE = 0, HAMMER = 1, SHOOTING_STAR = 2, DOJI = 3 };
    Type patternType;
    bool isValid;
};

CandlePattern DetectCandlePattern()
{
    CandlePattern result = {NONE, false};
    
    // Get current candle OHLC (bar [0] = current incomplete candle, use [1] for closed)
    double open = iOpen(Symbol(), PERIOD_CURRENT, 1);
    double high = iHigh(Symbol(), PERIOD_CURRENT, 1);
    double low = iLow(Symbol(), PERIOD_CURRENT, 1);
    double close = iClose(Symbol(), PERIOD_CURRENT, 1);
    
    double bodySize = MathAbs(close - open);
    double lowerWick = open < close ? open - low : close - low;
    double upperWick = close > open ? high - close : high - open;
    
    // HAMMER: Lower wick > 2x body, upper wick < 0.1x body, close near high
    if (lowerWick > 2 * bodySize && upperWick < 0.1 * bodySize && close > (open + bodySize * 0.5))
    {
        result.patternType = HAMMER;
        result.isValid = true;
    }
    
    // SHOOTING STAR: Upper wick > 2x body, lower wick < 0.1x body, close near low
    else if (upperWick > 2 * bodySize && lowerWick < 0.1 * bodySize && close < (open - bodySize * 0.5))
    {
        result.patternType = SHOOTING_STAR;
        result.isValid = true;
    }
    
    // DOJI: Open ≈ close (within 1 pip), wicks extending both sides
    else if (bodySize <= 1 * Point && lowerWick > 0 && upperWick > 0)
    {
        result.patternType = DOJI;
        result.isValid = true;
    }
    
    return result;
}

struct Setup2Signal
{
    bool isTriggered;
    bool isLong;
    double hvnEdgePrice;
    double sweepLow;  // LVN sweep low (for SL)
};

Setup2Signal DetectSetup2Signal()
{
    Setup2Signal result = {false, false, 0, 0};
    
    // REQ-017: LVN sweep detection — price recent low below lowest LVN
    double lowestLVN = 999999;
    for (int i = 0; i < currentProfile.lvnCount; i++)
    {
        if (currentProfile.lvnArray[i].price < lowestLVN)
            lowestLVN = currentProfile.lvnArray[i].price;
    }
    
    double currentLow = iLow(Symbol(), PERIOD_CURRENT, 1);  // Previous closed bar
    if (currentLow > lowestLVN)
        return result;  // No LVN sweep; skip
    
    // REQ-018: HVN edge identification — find nearest HVN above current price
    double hvnEdge = 999999;
    for (int i = 0; i < currentProfile.hvnCount; i++)
    {
        if (currentProfile.hvnArray[i].price > currentLow && 
            currentProfile.hvnArray[i].price < hvnEdge)
        {
            hvnEdge = currentProfile.hvnArray[i].price;
        }
    }
    
    if (hvnEdge == 999999)
        return result;  // No HVN edge found; skip
    
    // REQ-019: Trigger pattern recognition (Hammer/Shooting Star/Doji)
    CandlePattern pattern = DetectCandlePattern();
    if (!pattern.isValid)
        return result;  // No valid pattern; skip
    
    // REQ-020: Volume spike confirmation (≥ 1.3x previous bar)
    long currentVolume = iVolume(Symbol(), PERIOD_CURRENT, 1);
    long previousVolume = iVolume(Symbol(), PERIOD_CURRENT, 2);
    
    if (previousVolume <= 0 || currentVolume < previousVolume * 1.3)
        return result;  // Insufficient volume; skip
    
    // REQ-021: Closed candle requirement (already using bar [1], not [0])
    
    // Signal triggered!
    result.isTriggered = true;
    result.isLong = (pattern.patternType == HAMMER);  // LONG on Hammer
    result.hvnEdgePrice = hvnEdge;
    result.sweepLow = currentLow;  // Used for SL (below LVN)
    
    return result;
}

// In OnTick():
Setup2Signal sig = DetectSetup2Signal();
if (sig.isTriggered)
{
    // REQ-022 (LONG) or REQ-023 (SHORT): Entry execution at HVN edge
    double entryPrice = sig.hvnEdgePrice;  // Market order at HVN level
    double stopLoss = sig.sweepLow - 10 * Point;  // Below LVN sweep
    double takeProfit = sig.isLong ? currentProfile.vahPrice : currentProfile.valPrice;  // D-06
    
    double lotSize = CalculateLotSize(entryPrice, stopLoss);
    
    PlaceMarketOrder(sig.isLong ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                     lotSize, entryPrice, stopLoss, takeProfit);
}
```

### Pattern 4: CTrade Market Order Placement with Slippage Validation

**What:** Use CTrade standard library to place market orders with post-execution price validation. Reject fills that deviate >50 pips from intended entry.

**When to use:** At entry signal trigger to execute trade with slippage protection and retry logic.

**Code Pattern:**

```mql5
// Source: MT5 CTrade Standard Library (mql5.com/en/docs/standardlibrary/tradeclasses/ctrade)
// Phase 2 CONTEXT.md D-07, REQUIREMENTS.md REQ-039
#include <Trade/Trade.mqh>

CTrade trade;  // Global CTrade instance

struct OrderResult
{
    bool success;
    long ticket;
    double fillPrice;
    double slippage;  // Actual slippage in pips
};

OrderResult PlaceMarketOrder(ENUM_ORDER_TYPE orderType, double lots, 
                              double intendedPrice, double stopLoss, 
                              double takeProfit)
{
    OrderResult result = {false, 0, 0, 0};
    
    // Retry logic: up to 3 attempts with exponential backoff
    // Attempt 1: next tick, Attempt 2: +1 tick, Attempt 3: +2 ticks
    for (int attempt = 0; attempt < 3; attempt++)
    {
        // Prepare trade request
        MqlTradeRequest request = {0};
        request.action = TRADE_ACTION_DEAL;
        request.symbol = Symbol();
        request.volume = lots;
        request.type = orderType;
        request.price = intendedPrice;
        request.sl = stopLoss;
        request.tp = takeProfit;
        request.deviation = 500;  // 50 pips (5 decimal = 500 points)
        request.magic = EA_MAGIC_NUMBER;
        request.comment = "Setup" + (IsBalancedMarket() ? "1" : "2");
        
        // Execute via CTrade
        MqlTradeResult tradeResult = {0};
        if (!trade.Send(request, tradeResult))
        {
            // CTrade failed; check error code
            uint retcode = tradeResult.retcode;
            
            // Log rejection
            LogOrderRejection(intendedPrice, stopLoss, takeProfit, lots, 
                            "OrderSend failed", retcode);
            
            // Retry logic: some errors are transient
            if (attempt < 2)
            {
                Sleep(100);  // Wait before retry
                continue;    // Retry
            }
            else
            {
                result.success = false;
                return result;
            }
        }
        
        // Order sent; check return code
        uint retcode = tradeResult.retcode;
        
        if (retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_PLACED)
        {
            // Successful execution
            result.ticket = tradeResult.order;
            result.fillPrice = tradeResult.price;
            
            // D-07: Validate slippage (50 pip tolerance)
            double slippagePips = MathAbs(result.fillPrice - intendedPrice) / Point;
            
            if (slippagePips <= 50)
            {
                // Slippage acceptable
                result.success = true;
                result.slippage = slippagePips;
                
                LogTradeEntry(orderType == ORDER_TYPE_BUY ? "BUY" : "SELL",
                             result.fillPrice, stopLoss, takeProfit, lots,
                             result.slippage, result.ticket);
                
                return result;
            }
            else
            {
                // Slippage exceeds 50 pips; reject trade
                LogOrderRejection(intendedPrice, stopLoss, takeProfit, lots,
                                "Slippage exceeds 50 pips", slippagePips);
                
                // Close the position immediately (market order)
                trade.PositionClose(result.ticket);
                
                result.success = false;
                return result;
            }
        }
        else
        {
            // Transient error; may retry
            LogOrderRejection(intendedPrice, stopLoss, takeProfit, lots,
                            "Retcode: " + (string)retcode, retcode);
            
            if (attempt < 2)
            {
                Sleep(100);
                continue;
            }
            else
            {
                result.success = false;
                return result;
            }
        }
    }
    
    return result;
}
```

### Pattern 5: Position State Tracking (Remaining Lots Method)

**What:** Track open positions by remaining lot size. When partial TP closes a portion, decrement remaining lots. When remaining = 0, position fully closed.

**When to use:** Throughout position lifecycle to track partial exits and manage remainder targeting.

**Code Pattern:**

```mql5
// Source: Phase 2 CONTEXT.md D-03/D-06 (Single TP per position)
// REQUIREMENTS.md REQ-027 (Position state machine)

struct PositionState
{
    long ticket;
    string symbol;
    bool isLong;
    double entryPrice;
    double stopLoss;
    double takeProfit;
    double originalLots;
    double remainingLots;  // Tracking method: decrement as partial closes occur
    datetime entryTime;
    string setupType;     // "Setup1" or "Setup2"
    double riskRewardRatio;
};

PositionState positions[10];  // Max 10 simultaneous positions (MVP: 1 per asset = 2 max)
int positionCount = 0;

bool UpdatePositionState(long ticket, double partialCloseLots)
{
    // Find position in array
    for (int i = 0; i < positionCount; i++)
    {
        if (positions[i].ticket == ticket)
        {
            positions[i].remainingLots -= partialCloseLots;
            
            if (positions[i].remainingLots <= 0)
            {
                // Position fully closed; remove from tracking
                RemovePosition(i);
                return true;
            }
            
            return true;
        }
    }
    
    return false;  // Position not found
}

void RemovePosition(int index)
{
    // Shift remaining positions down
    for (int i = index; i < positionCount - 1; i++)
    {
        positions[i] = positions[i + 1];
    }
    positionCount--;
}

void MonitorPositionExits()
{
    // Check all open positions every tick
    for (int i = 0; i < positionCount; i++)
    {
        // Get current price
        double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
        
        // Check TP hit
        if (positions[i].isLong && bid >= positions[i].takeProfit)
        {
            // Close entire remaining position
            double closeLots = positions[i].remainingLots;
            ClosePosition(positions[i].ticket, positions[i].takeProfit, "TP");
            continue;
        }
        
        if (!positions[i].isLong && ask <= positions[i].takeProfit)
        {
            double closeLots = positions[i].remainingLots;
            ClosePosition(positions[i].ticket, positions[i].takeProfit, "TP");
            continue;
        }
        
        // Check SL hit
        if (positions[i].isLong && bid <= positions[i].stopLoss)
        {
            ClosePosition(positions[i].ticket, positions[i].stopLoss, "SL");
            continue;
        }
        
        if (!positions[i].isLong && ask >= positions[i].stopLoss)
        {
            ClosePosition(positions[i].ticket, positions[i].stopLoss, "SL");
            continue;
        }
    }
}

void ClosePosition(long ticket, double exitPrice, string exitReason)
{
    // Find position
    for (int i = 0; i < positionCount; i++)
    {
        if (positions[i].ticket == ticket)
        {
            // Calculate P&L
            double pnlPips = (exitPrice - positions[i].entryPrice) / Point;
            if (!positions[i].isLong)
                pnlPips = (positions[i].entryPrice - exitPrice) / Point;
            
            // Close via CTrade
            trade.PositionClose(ticket);
            
            // Log exit
            LogTradeExit(ticket, positions[i].symbol, positions[i].setupType,
                        positions[i].entryPrice, exitPrice, exitReason,
                        pnlPips, positions[i].remainingLots);
            
            // Remove from tracking
            RemovePosition(i);
            break;
        }
    }
}
```

### Pattern 6: Daily Limit Enforcement (Hard Stop & Profit Cap)

**What:** Track cumulative daily P&L (closed + open). Enforce -2% hard stop (force-close all + halt trading). Enforce +5% profit cap (close 50-70%, move SL to profit, halt new entries).

**When to use:** Every tick, after calculating daily P&L. Check at entry validation and during exit management.

**Code Pattern:**

```mql5
// Source: Phase 2 CONTEXT.md D-09/D-10, REQUIREMENTS.md REQ-032/REQ-033
// REQ-035 (Persistent across restarts via OrdersHistoryTotal rescan)

struct DailyLimitState
{
    double closedPnL;
    double openPnL;
    double totalPnL;
    bool hardStopHit;
    bool profitCapReached;
};

DailyLimitState dailyLimits = {0, 0, 0, false, false};

DailyLimitState CalculateDailyPnL()
{
    DailyLimitState result = {0, 0, 0, false, false};
    
    // REQ-035: Persistent P&L calculation (rescan every tick, no caching)
    // This enables recovery after EA restart
    
    // Step 1: Scan closed trades TODAY
    for (int i = OrdersHistoryTotal() - 1; i >= 0; i--)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
            continue;
        
        // Filter for this EA (magic number range)
        if (OrderMagicNumber() < EA_MAGIC_NUMBER ||
            OrderMagicNumber() > EA_MAGIC_NUMBER + 10)
            continue;
        
        // Check if closed today (within last 24 hours)
        if (TimeCurrent() - OrderCloseTime() < 86400)
        {
            result.closedPnL += OrderProfit();
        }
    }
    
    // Step 2: Scan open positions
    for (int i = 0; i < positionCount; i++)
    {
        if (OrderSelect(positions[i].ticket, SELECT_BY_TICKET))
        {
            result.openPnL += OrderProfit();
        }
    }
    
    result.totalPnL = result.closedPnL + result.openPnL;
    
    return result;
}

bool EnforceDailyLimits()
{
    // Recalculate daily P&L
    DailyLimitState limits = CalculateDailyPnL();
    
    double accountBalance = AccountBalance();
    double hardStopThreshold = accountBalance * DAILY_LOSS_LIMIT;     // -2%
    double profitCapThreshold = accountBalance * DAILY_PROFIT_CAP;    // +5%
    
    // D-09: Hard stop loss (-2%)
    if (limits.totalPnL < -hardStopThreshold)
    {
        if (!dailyLimits.hardStopHit)  // Log once
        {
            LogAlert("HARD_STOP_HIT", 
                    StringFormat("PnL=%.2f limit=-%.2f", limits.totalPnL, hardStopThreshold));
        }
        
        dailyLimits.hardStopHit = true;
        
        // Force-close ALL positions
        for (int i = positionCount - 1; i >= 0; i--)
        {
            trade.PositionClose(positions[i].ticket);
            ClosePosition(positions[i].ticket, 0, "HARD_STOP");  // Exit price TBD
        }
        
        return false;  // Block new entries
    }
    else
    {
        dailyLimits.hardStopHit = false;
    }
    
    // D-10: Daily profit cap (+5%)
    if (limits.totalPnL > profitCapThreshold)
    {
        if (!dailyLimits.profitCapReached)  // Log once
        {
            LogAlert("PROFIT_CAP_REACHED",
                    StringFormat("PnL=%.2f cap=+%.2f", limits.totalPnL, profitCapThreshold));
        }
        
        dailyLimits.profitCapReached = true;
        
        // Close 50-70% of positions (use 60% as midpoint)
        int closeCount = (int)MathCeil(positionCount * 0.6);
        for (int i = 0; i < closeCount; i++)
        {
            if (i < positionCount)
            {
                trade.PositionClose(positions[i].ticket);
                ClosePosition(positions[i].ticket, 0, "PROFIT_CAP_CLOSE");
            }
        }
        
        // Move SL to profit on remaining positions
        for (int i = closeCount; i < positionCount; i++)
        {
            // Move SL to breakeven + 5-10 pips profit
            double newSL = positions[i].entryPrice;  // Breakeven
            if (positions[i].isLong)
                newSL += 5 * Point;  // +5 pips
            else
                newSL -= 5 * Point;
            
            positions[i].stopLoss = newSL;  // Update tracking
            
            // Update order via CTrade
            MqlTradeRequest request = {0};
            request.action = TRADE_ACTION_SLTP;
            request.symbol = positions[i].symbol;
            request.position = positions[i].ticket;
            request.sl = newSL;
            request.tp = positions[i].takeProfit;
            
            trade.Send(request);
        }
        
        return false;  // Block new entries
    }
    else
    {
        dailyLimits.profitCapReached = false;
    }
    
    return true;  // Trading allowed
}

// In OnTick():
if (!EnforceDailyLimits())
{
    // Skip entry signal processing; daily limits hit
    return;
}
```

### Pattern 7: Friday Hard Close (21:45 Broker Server Time)

**What:** At Friday 21:45 broker server time, force-close all open positions to eliminate weekend gap risk.

**When to use:** Every tick to check if Friday close time has been reached.

**Code Pattern:**

```mql5
// Source: Phase 2 CONTEXT.md D-11, REQUIREMENTS.md REQ-034
// Broker server time authority: TimeCurrent() in MQL5

bool CheckFridayHardClose()
{
    // Get current time in broker server time
    datetime currentTime = TimeCurrent();
    MqlDateTime timeStruct;
    TimeToStruct(currentTime, timeStruct);
    
    // Check if Friday (day of week: 0=Sunday, 5=Friday)
    bool isFriday = (timeStruct.day_of_week == 5);
    
    // Check if time >= 21:45 (2145 = 21*60 + 45)
    int currentTimeMinutes = timeStruct.hour * 60 + timeStruct.min;
    int closeTimeMinutes = 21 * 60 + 45;  // 21:45 = 1305 minutes
    bool isCloseTime = (currentTimeMinutes >= closeTimeMinutes);
    
    if (isFriday && isCloseTime)
    {
        // Force-close ALL open positions
        if (positionCount > 0)
        {
            LogAlert("FRIDAY_HARD_CLOSE", 
                    StringFormat("Time=%d:%02d, Closing %d positions",
                                timeStruct.hour, timeStruct.min, positionCount));
        }
        
        // Close all positions
        for (int i = positionCount - 1; i >= 0; i--)
        {
            trade.PositionClose(positions[i].ticket);
            ClosePosition(positions[i].ticket, 0, "FRIDAY_CLOSE");
        }
        
        return true;  // Hard close executed
    }
    
    return false;
}

// In OnTick():
CheckFridayHardClose();  // Execute before entry signal processing
```

### Anti-Patterns to Avoid

- **❌ Visual chart objects for profile levels:** No VAH/VAL lines, no POC markers. Use arrays only for performance on multi-chart operation.
- **❌ Hardcoded pip values for multiple symbols:** Always calculate via `SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE)` per symbol per tick.
- **❌ Caching daily P&L across ticks:** Rescan `OrdersHistoryTotal()` every tick to ensure persistence across EA restart (REQ-035).
- **❌ Single large TP order instead of position state tracking:** State machine tracking remaining lots is cleaner than managing separate partial TP orders.
- **❌ Ignoring CTrade return codes:** Always check `ResultRetcode()` and retry transient errors (5xx range) vs. fatal errors (4xx range).
- **❌ Market order without post-execution validation:** Always compare fill price to intended price; reject if slippage > 50 pips.
- **❌ Confusing wick touch with confirmation:** Confirmation = actual candle CLOSE inside VA, not wick touch.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Trade order placement logic | Custom OrderSend wrapper | CTrade standard library class | Handles error codes, retries, timeout, trade result validation; battle-tested |
| Position state machine | Manual ticket/lot tracking | Remaining lots counter per position struct | Cleaner state transitions; eliminates partial TP complexity |
| Daily P&L persistence | In-memory caching + reset logic | OrdersHistoryTotal rescan every tick | Survives EA restart; no data loss on disconnect |
| Candle pattern detection | Hardcoded thresholds | Parametric body/wick ratio functions | Adapts to symbol tick size differences (XAUUSD vs EURUSD) |
| Slippage validation | Manual bid/ask comparison | OrderSend deviation parameter + post-fill check | Broker-aware; automatic rejection on excessive slippage |
| Time-based logic (Friday close, session boundary) | Manual datetime parsing | MQL5 TimeStruct + day_of_week + TimeCurrent() | Handles DST transitions, broker timezone differences |

**Key insight:** MT5's CTrade class and native time functions abstract away broker differences. Custom implementations often miss edge cases (DST, broker daylight saving, irregular close times).

---

## Runtime State Inventory

> For rename/refactor phases only. This is Phase 2, but lists what Phase 1 created that Phase 2 must account for:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — Phase 1 calculates profile only, no persistent state files | None |
| Live service config | None — Phase 1 uses embedded constants (VOLUME_BINS=400, HVN_MULTIPLIER=1.3) | None (Phase 2 reads these constants) |
| OS-registered state | None — EA runs as MT5 script only, no scheduled tasks | None |
| Secrets/env vars | None — EA uses broker credentials from MT5 login | None |
| Build artifacts | Phase 1 .mq5 file compiled to .ex5 binary in MT5 terminal folder | Phase 2 refactors into modular .mqh headers; recompile after refactoring |

**Summary:** Phase 1 produces only runtime code (no external state). Phase 2 integrates Phase 1 modules and adds execution logic; no migration needed.

---

## Common Pitfalls

### Pitfall 1: Confusing Deviation Parameter with Actual Slippage

**What goes wrong:** Developer sets `deviation = 50` in OrderSend, assumes this prevents 50+ pip fills, but receives 100+ pip slippage without rejection because:
- Deviation is a *tolerance*, not a hard limit
- "Instant Execution" brokers (Market Maker) respect deviation; ECN/NDD brokers don't
- Deviation units differ by broker: 5 decimal = `deviation * 0.00001`

**Why it happens:** MT5 documentation is sparse on broker-model differences. Developers assume all brokers enforce deviation equally.

**How to avoid:** After OrderSend succeeds, always validate post-fill price against intended price and reject manually if slippage > 50 pips (close position at market).

**Warning signs:** Backtest shows 50-pip slippage limit working, but live trades slip 100+ pips. Indicates ECN broker (no deviation enforcement).

### Pitfall 2: TP Fully Fills at Limit, But Partial Close Orders Remain

**What goes wrong:** Developer sets up 65% TP and 35% TP as separate orders. When market hits TP:
- First TP (65%) fills correctly
- Second TP (35%) remains open but price has moved past it
- Results in manual close or orphaned orders

**Why it happens:** MT5 doesn't natively "cancel pending orders when position closes." Separate TP orders are independent.

**How to avoid:** Use remaining lots tracking method (Pattern 5). Close entire position with single TP target per setup. No partial TP orders; manage position state via custom logic.

**Warning signs:** Journal shows partial closes at TP1, but remainder stuck at TP2 price level for hours.

### Pitfall 3: Daily P&L Resets at Wrong Session Boundary

**What goes wrong:** Developer hard-codes "00:00 GMT" as session reset, but broker uses "17:00 ET" (5 PM NY close, per FX convention). Results in:
- Daily hard stop applies to yesterday's trades at midnight, not broker reset time
- Friday hard close triggers at midnight Friday instead of 21:45 Friday

**Why it happens:** Each broker sets their own session boundary (swap/rollover time). No single global standard.

**How to avoid:** Confirm broker's session boundary (usually listed in account settings or support). Hard-code that specific time in EA. In Phase 3, allow as input parameter for multi-broker support.

**Warning signs:** Daily hard stop triggers mid-session (not at expected session start). Position closes Friday at 00:00 instead of 21:45.

### Pitfall 4: Retrying Order After Signal Validity Expires

**What goes wrong:** Setup 1 confirmation candle closes; signal triggers order. Retry loop waits 1 tick, bar closes, signal becomes invalid (new bar = new candle pattern). But EA retries anyway on new bar, placing order on wrong candle.

**Why it happens:** Retry logic doesn't check if signal source (candle) is still valid. Just rechecks trade conditions blindly.

**How to avoid:** Store signal trigger bar index. In retry loop, check if current bar index still matches signal bar index. If new bar opened, abort retry.

**Code:** `if (iTime(Symbol(), PERIOD_CURRENT, 0) != signalBarTime) return false;  // Signal expired`

**Warning signs:** Journal shows orders placed on bar N+2 or N+3 (not N), entry price far from intended level.

### Pitfall 5: Confusing "Close Price" with "Close at Bid/Ask"

**What goes wrong:** Code uses `Close[0]` (candle close price from OHLC) as entry price, but real market at that moment was at bid=1.3500, ask=1.3505. Order fills at ask=1.3505, but code expects 1.3500.

**Why it happens:** Candle close price is historical OHLC. Real-time bid/ask at exact close time is different. Order execution uses current bid/ask, not historical close.

**How to avoid:** Entry price should be intended target (e.g., HVN edge price level). Slippage validation compares actual fill vs intended, not vs candle close. Slippage = |actual - intended|, not |actual - close|.

**Warning signs:** Slippage always appears 2-5 pips even on slow-moving markets; inconsistent with bid/ask spread.

### Pitfall 6: Forgetting to Check `IsConnected()` Before OrderSend

**What goes wrong:** Network glitch; `IsConnected()` becomes false. EA tries to place order via OrderSend(), gets TRADE_RETCODE_NO_CONNECTION (10015) silently. Position not opened, but code assumes it was. Next tick, tries to close non-existent position, logs errors.

**Why it happens:** OrderSend returns error code, but code doesn't check before assuming position exists.

**How to avoid:** Before PlaceMarketOrder, check `if (!IsConnected()) return false;`. Log connection failures and pause trading until reconnected.

**Warning signs:** Journal shows OrderSend failures followed by "Position not found" errors on close attempts.

---

## Code Examples

Verified patterns from official sources and Phase 1 implementation:

### Volume Profile Profile Read (from Phase 1)

```mql5
// Source: Phase 1 code + REQUIREMENTS.md REQ-001–010
void ReadVolumeProfile()
{
    // Access Phase 1 calculated arrays (read-only in Phase 2)
    double pocPrice = currentProfile.pocPrice;
    double vahPrice = currentProfile.vahPrice;
    double valPrice = currentProfile.valPrice;
    
    for (int i = 0; i < currentProfile.hvnCount; i++)
    {
        double hvnLevel = currentProfile.hvnArray[i].price;
        double hvnVolume = currentProfile.hvnArray[i].volume;
        // Use for Setup 2 HVN edge detection
    }
    
    for (int i = 0; i < currentProfile.lvnCount; i++)
    {
        double lvnLevel = currentProfile.lvnArray[i].price;
        double lvnVolume = currentProfile.lvnArray[i].volume;
        // Use for Setup 2 LVN sweep detection
    }
}
```

### Lot Size Calculation (from Phase 1, reused in Phase 2)

```mql5
// Source: Phase 1 VolumeProfile_EA_v1.0.mq5 CalculateLotSize()
// REQUIREMENTS.md REQ-029
double CalculateLotSize(double entryPrice, double stopLossPrice)
{
    double accountBalance = AccountBalance();
    double riskAmount = accountBalance * (RISK_PERCENT / 100.0);  // 0.6% locked
    
    double slDistancePoints = MathAbs(entryPrice - stopLossPrice) / Point;
    
    double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
    double pipValue = tickValue / tickSize;
    
    double lotSize = riskAmount / (slDistancePoints * pipValue);
    
    // Apply broker constraints
    double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
    
    if (lotSize < minLot) return 0;  // Reject trade; too small
    if (lotSize > maxLot) lotSize = maxLot;
    
    return MathFloor(lotSize / lotStep) * lotStep;  // Round to step
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual ticket tracking (separate buy/sell arrays) | Position state machine with remaining lots counter | MT5 Best Practices (2020+) | Eliminates partial TP complexity; single source of truth |
| OrderSend with generic error handling | CTrade class with result code validation | MQL5 Standard Library v1.0 (2015) | Automatic retry, timeout, better debugging |
| Hard-coded TP orders (65%/35% split) | Single edge-to-edge TP target per setup | Volume Profile Trading (Professional, 2018+) | Cleaner risk/reward; price rotates to opposite extreme |
| Daily P&L cached in-memory | OrdersHistoryTotal rescan every tick | MT5 Design Pattern (established 2015+) | Survives EA restart; accurate persistence |
| Slippage tolerance via deviation only | Deviation + post-fill validation | Best Practice (2018+) | Works across broker execution models (Instant/ECN) |

**Deprecated/outdated:**
- Manual TP order management (replaced by position state + remaining lots)
- OrderSend-only order placement (use CTrade class instead)
- In-memory daily P&L caching (rescan from history every tick)

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | CTrade standard library is available in all MT5 builds 4000+ | Standard Stack, Code Examples | Medium — Older brokers on Build 3000 may lack CTrade. Fallback: use raw OrderSend() with manual error checking |
| A2 | Broker server time is accessible via TimeCurrent() and reflects current NY/GMT | Pattern 7 (Friday Close), Pitfall 3 | High — Some brokers have incorrect server time. **Needs validation:** confirm broker's session boundary before deployment |
| A3 | OrdersHistoryTotal() is reliable for daily P&L persistence across EA restart | Pattern 6 (Daily Limits) | Medium — In theory reliable; but some brokers purge old history. **Needs validation:** test on live account with month-old trades |
| A4 | Volume spike detection using iVolume() (Tick Volume) is ≥ 1.3x reliable for Forex | Pattern 3 (Setup 2 Volume), REQUIREMENTS REQ-020 | Medium — Tick Volume correlates ~90% with real institutional volume per PROJECT.md. **Lower confidence than Options Volume** |
| A5 | 50-pip slippage tolerance is achievable on XAUUSD and EURUSD with broker deviation parameter | Pattern 4 (Slippage), CONTEXT D-07 | Medium — Depends on broker execution model. **Instant Execution brokers:** deviation enforced. **ECN brokers:** deviation ignored; manual validation required |

**Items needing user confirmation:**
- A1: Confirm broker MT5 build version supports CTrade class
- A2: Confirm broker's exact session boundary (reset time) — not always 00:00 GMT
- A3: Test OrdersHistoryTotal persistence on live account with month-old positions
- A5: Confirm broker execution model (Instant vs ECN) and test 50-pip slippage on live micro lot

---

## Open Questions

1. **Exact Balanced Market Threshold (D-01)**
   - What we know: VA width < 0.6–0.7x recent range triggers Setup 1
   - What's unclear: Is 0.6x too conservative? Should we use 0.7x? Does threshold change by symbol (XAUUSD vs EURUSD)?
   - Recommendation: Backtest both 0.6 and 0.7 thresholds on 1-year sample. Lock based on win rate and profit factor.

2. **Candle Pattern Thresholds (D-04: Exact Wick/Body Ratios)**
   - What we know: Hammer = lower wick > 2x body; Shooting Star = upper wick > 2x body
   - What's unclear: Is 2x correct? Some sources use 1.5x or 3x. What about close proximity (near high/low)?
   - Recommendation: Test 1.5x, 2x, 2.5x on sample candles. Document chosen threshold in code comment with rationale.

3. **Retry Backoff Strategy (D-13: Exponential Backoff Detail)**
   - What we know: Retry up to 3 attempts; recommended exponential backoff (next tick, +1 tick, +2 ticks)
   - What's unclear: Should we retry SAME signal bar (store bar time and check) or allow next bar? What timeout (max milliseconds)?
   - Recommendation: Retry on same bar only (store `signalBarTime`). Abort after 3 attempts or if new bar opened (signal expired). Total timeout: 1 second max.

4. **SL Adjustment on Profit Cap (D-10: Exact Formula)**
   - What we know: Move SL to profit (breakeven or +5–10 pips)
   - What's unclear: Breakeven exactly, or +5? +10? +15? Does this vary by symbol volatility?
   - Recommendation: Use breakeven + 5 pips (conservative lock-in). Revisit if live testing shows too many stopped-out winners.

5. **Partial Close Percentage on Profit Cap (D-10: 50–70% Range)**
   - What we know: Close 50–70% when +5% reached; let remainder run
   - What's unclear: Exactly 50%, 60%, or 70%? Does this optimize win rate or profit factor?
   - Recommendation: Use 60% (midpoint) for MVP. Track live results; adjust to 50% (more aggressive) or 70% (safer) based on outcome.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| MT5 Platform | Compilation and execution | ✓ | Build 4000+ (assumed from user's machine) | None — EA requires MT5 |
| CTrade Library (Trade.mqh) | Order placement pattern | ✓ | MT5 Standard Library v1.0 (included in MT5) | Manual OrderSend() with custom error checking |
| Broker API (Order execution) | PlaceMarketOrder, ClosPosition | ✓ | Live Forex/CFD broker connection assumed | Paper trading mode (if available) |
| Broker Server Time (TimeCurrent) | Friday close, session boundary | ✓ | Real-time via broker connection | Fallback to local system time (not recommended; DST issues) |
| OrdersHistoryTotal() database | Daily P&L persistence | ✓ | Live/historical order database on broker | Re-scan closed trades from Statement (manual; not automated) |
| Symbol Metadata (SYMBOL_TRADE_TICK_VALUE, etc.) | Lot size calculation | ✓ | Broker provides via MT5 symbol info | Hardcoded defaults (XAUUSD 0.01 per point, EURUSD 0.0001 per point) — **Not recommended** |

**Missing dependencies with no fallback:**
- MT5 platform (EA will not compile on MT4 or other platforms)

**Missing dependencies with fallback:**
- CTrade → use raw OrderSend() (requires custom error handling)
- Broker Server Time → use local system time (DST issues; not recommended for live)
- OrdersHistoryTotal → manual trade history entry (breaks automation)
- Symbol Metadata → hardcoded defaults (works for XAUUSD/EURUSD, breaks on other symbols)

---

## Validation Architecture

> Skip if `workflow.nyquist_validation` is explicitly false in .planning/config.json. Currently config not provided; treating as enabled.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | MQL5 Unit Tests (embedded in Phase 1 .mq5, reused in Phase 2) |
| Config file | None — unit tests embedded inline |
| Quick run command | Compile EA in MT5 IDE; OnInit runs embedded tests |
| Full suite command | Live backtest in MT5 Strategy Tester (manual; no CI/CD yet) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REQ-011 | Balanced market detection | Unit | Test VA width / ATR ratio calculation | ❌ Wave 0 |
| REQ-012 | Gap detection | Backtest | Inspect 5 manual gap scenarios | ❌ Wave 0 |
| REQ-013 | Reclaim detection | Backtest | Confirm reclaim signals on 10 random bars | ❌ Wave 0 |
| REQ-014 | Confirmation candle | Unit | Compare wick-only vs full-closure win rates | ❌ Wave 0 |
| REQ-015 | LONG entry execution | Integration | Entry at correct price, volume, ticket assignment | ❌ Wave 0 |
| REQ-016 | SHORT entry execution | Integration | Entry at correct price, volume, ticket assignment | ❌ Wave 0 |
| REQ-017 | LVN sweep detection | Unit | LVN sweep on 5 example bars | ❌ Wave 0 |
| REQ-018 | HVN edge identification | Unit | Distance-to-HVN calculation | ❌ Wave 0 |
| REQ-019 | Trigger pattern recognition | Unit | Hammer/Shooting Star/Doji detection on sample candles | ❌ Wave 0 |
| REQ-020 | Volume spike confirmation | Unit | Volume ratio calculation (≥1.3x threshold) | ❌ Wave 0 |
| REQ-021 | Closed candle requirement | Code Review | Entry only on Close[1], not Close[0] | ✅ Phase 1 pattern |
| REQ-022 | LONG HVN entry | Integration | Entry at HVN price level | ❌ Wave 0 |
| REQ-023 | SHORT HVN entry | Integration | Entry at HVN price level | ❌ Wave 0 |
| REQ-024 | Partial TP (65%) | Backtest | Partial TP execution on 10 trades | ❌ Wave 0; CHANGED to single TP |
| REQ-025 | Remainder TP (35%) | Backtest | Remainder TP execution on 10 trades | ❌ Wave 0; CHANGED to single TP |
| REQ-026 | SL placement | Backtest | SL placement 5–15 pips below sweep | ❌ Wave 0 |
| REQ-027 | Partial execution tracking | Code Review | Position state machine (remaining lots) | ❌ Wave 0 |
| REQ-028 | Risk/Reward calculation | Unit | R:R logged for every trade | ❌ Wave 0 |
| REQ-032 | Daily hard stop loss (-2%) | Backtest | Daily loss limit enforcement | ❌ Wave 0 |
| REQ-033 | Daily profit cap (+5%) | Backtest | Daily profit cap enforcement | ❌ Wave 0 |
| REQ-034 | Friday hard close | Integration | Time-based close execution (Friday 21:45) | ❌ Wave 0 |
| REQ-038 | Journal logging | Integration | Sample journal output reviewed | ❌ Wave 0 |
| REQ-039 | Slippage tolerance | Integration | Order fill validation (50-pip threshold) | ❌ Wave 0 |
| REQ-040 | Broker connectivity | Code Review | IsConnected() check before OrderSend | ❌ Wave 0 |
| REQ-041 | Error recovery | Code Review | Try-catch + error logging | ❌ Wave 0 |
| REQ-042 | Metrics calculation | Backtest | Metrics accuracy on sample trades | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** Run embedded unit tests (compact; < 10ms)
- **Per wave merge:** Full 1-year backtest on both XAUUSD and EURUSD (manual; ~30 minutes in MT5 Strategy Tester)
- **Phase gate:** Backtest win rate ≥ 50%, profit factor ≥ 1.5, max daily drawdown ≤ 2% (enforced by hard stop)

### Wave 0 Gaps
- [ ] `test_BalancedMarketDetection.mq5` — Unit test for VA width threshold (0.6x vs 0.7x)
- [ ] `test_Setup1Signals.mq5` — Unit test for gap/reclaim/confirmation logic on 50 sample candles
- [ ] `test_Setup2Signals.mq5` — Unit test for LVN/HVN/pattern/volume detection on 50 sample candles
- [ ] `test_CandlePatterns.mq5` — Unit test for Hammer/Shooting Star/Doji detection with configurable wick/body ratios
- [ ] `test_OrderExecution.mq5` — Integration test for CTrade order placement, slippage validation, retry logic
- [ ] `test_PositionState.mq5` — Unit test for remaining lots tracking, partial closes, state machine
- [ ] `test_DailyLimits.mq5` — Unit test for hard stop (-2%), profit cap (+5%), OrdersHistoryTotal P&L calculation
- [ ] `test_JournalLogging.mq5` — Integration test for trade entry/exit logging, audit trail completeness
- [ ] Framework install: `#include <Trade/Trade.mqh>` already available in MT5 standard library
- [ ] Refactor Phase 1 code into modular headers (VolumeProfile.mqh, RiskManager.mqh) before Wave 1 implementation

*(These are test files that need creation before Phase 2 implementation starts. Phase 1 unit tests exist but are embedded; Phase 2 requires dedicated test modules.)*

---

## Security Domain

> Applicable ASVS categories for trading EA context (financial risk, not traditional web security):

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V1 Architecture | yes | EA single-threaded; no concurrent trade execution conflicts |
| V2 Authentication | no | Broker login via MT5 terminal; EA doesn't handle credentials |
| V3 Session Management | no | MT5 manages broker session; EA inherits |
| V4 Access Control | yes | EA magic number restricts order filtering to this EA only; prevents conflicts with other EAs on same account |
| V5 Input Validation | **yes** | Order placement validates slippage (50-pip tolerance), lot size (min/max broker constraints), price levels (VAH/VAL within recent range) |
| V6 Cryptography | no | No encryption in MVP; broker connection uses MT5's SSL/TLS |
| V7 Error Handling | **yes** | All trade errors logged to Journal; graceful degradation (skip trade if conditions fail) |
| V8 Data Protection | **yes** | Daily P&L persistent via OrdersHistoryTotal; no intermediate state files that could leak |
| V9 Communications | no | Broker connection handled by MT5 platform |
| V10 Malicious Code | no | Source code review process (assumes user controls codebase) |

### Known Threat Patterns for Volume Profile Trading EA

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Slippage exploitation (entry at worse price than intended) | Tampering | 50-pip tolerance validation; reject and log if exceeded (Pattern 4) |
| Accidental duplicate position (magic number collision) | Information Disclosure | Use unique EA_MAGIC_NUMBER range (99001–99010); filter by magic in position queries |
| Daily limit bypass (hard stop disabled by manual override) | Elevation of Privilege | Hard stop flag is read-only logic; no user override allowed in code; enforced at entry validation |
| Journal tampering (trade logs falsified post-execution) | Tampering | Append-only Journal file; log immediately on OrderSend result, not after close; immutable once written |
| Connection loss during position management | Denial of Service | IsConnected() check before OrderSend; if disconnected, pause trading and log error; resume on reconnect |
| Order execution mismatch (broker executes different order than intended) | Tampering | Post-execution validation (Pattern 4): compare fill price to intended, reject if mismatch > 50 pips |
| Weekend gap risk (Friday close missed, position held over weekend) | Elevation of Privilege | Automatic Friday 21:45 hard close (Pattern 7); no manual override possible |
| Daily hard stop circumvented (user trades manually on same account) | Elevation of Privilege | Hard stop applies to this EA's positions only (magic number filter); doesn't prevent user manual trading |

**Critical controls (non-negotiable per Phase 1 & 2 requirements):**
- Hard stop at -2% account loss (REQ-032): enforced via daily P&L check, no override logic exists
- Profit cap at +5% account gain (REQ-033): enforced via daily P&L check, no override logic exists
- Friday 21:45 hard close (REQ-034): enforced via server time check, no manual escape allowed
- 50-pip slippage rejection (REQ-039): post-execution validation closes bad fills immediately

**Assumptions (need user verification):**
- Broker provides accurate server time (no spoofing); typically true for regulated brokers
- OrdersHistoryTotal() is tamper-proof on broker side; assumed for compliance
- Magic number range (99001–99010) unique to this EA; user responsible for assigning unique ranges across accounts

---

## Sources

### Primary (HIGH confidence)
- [MQL5 Documentation: OrderSend](https://www.mql5.com/en/docs/trading/ordersend) — Official trade function reference
- [MQL5 Documentation: CTrade Class](https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade) — Standard library order execution
- [MQL5 Documentation: Trade Server Return Codes](https://www.mql5.com/en/docs/constants/errorswarnings/enum_trade_return_codes) — Error handling reference
- [MQL5 Documentation: Candle Pattern Detection](https://www.mql5.com/en/articles/12385) — Hammer/Doji/Shooting Star detection patterns
- Phase 1 code (VolumeProfile_EA_v1.0.mq5) — Verified implementation of POC/VAH/VAL calculation, lot sizing, daily limits
- Phase 2 CONTEXT.md (locked decisions) — Requirements, design decisions, implementation notes

### Secondary (MEDIUM confidence)
- [MQL5 Forum: Position State Machine](https://www.mql5.com/en/forum/497257) — Community patterns for multiple take profits
- [MQL5 Articles: Trade Operations](https://www.mql5.com/en/articles/481) — Execution best practices
- [Headway: Setting Multiple Take Profits in MT5](https://hw.online/faq/setting-multiple-take-profits-in-metatrader-5-a-comprehensive-guide/) — Practical TP management
- [MQL5 Articles: Market Microstructure](https://www.mql5.com/en/articles/22263) — Balanced/imbalanced market detection
- [MQL5 Articles: Forex Sessions](https://www.mql5.com/en/articles/19944) — Session boundary and time handling

### Tertiary (LOW confidence, needs validation)
- Various MQL5 forum discussions on slippage tolerance, retry logic, error codes — Community best practices (not official)

---

## Metadata

**Confidence breakdown:**
- **Standard Stack:** HIGH — CTrade and MQL5 native functions are stable, well-documented
- **Architecture Patterns:** MEDIUM-HIGH — Phase 1 code provides verified framework; Phase 2 patterns follow standard MQL5 conventions
- **Pitfalls:** MEDIUM — Based on common MQL5 issues; some dependent on specific broker behavior (execution model, server time)
- **Environment Availability:** MEDIUM — Assumes MT5 Build 4000+ with CTrade; older builds need fallback to OrderSend()
- **Security:** MEDIUM — Financial risk controls (hard stop, slippage validation) are solid; broker-level risks (server time, order integrity) assumed managed by broker

**Research date:** 2026-05-13  
**Valid until:** 2026-06-13 (30 days; if MT5 or MQL5 updates released, re-verify CTrade API and error codes)

---

## RESEARCH COMPLETE

**Phase:** 2 - Signal Detection & Execution  
**Confidence:** HIGH

### Key Findings
1. **Order Placement:** Use CTrade standard library class (not raw OrderSend). Post-execution validation required for slippage (50-pip tolerance).
2. **Signal Detection:** Setup 1 = gap/reclaim/confirmation in balanced market. Setup 2 = LVN sweep/HVN edge/pattern/volume in imbalanced market.
3. **Position State:** Track remaining lots per position, not separate TP orders. Single TP target per setup (opposite profile edge).
4. **Daily Limits:** Rescan OrdersHistoryTotal every tick for persistence (survives restart). Hard stop -2% / Profit cap +5%.
5. **Candle Patterns:** Hammer = lower wick > 2x body; Shooting Star = upper wick > 2x body; Doji = open ≈ close. All require full candle closure + 1.3x volume.
6. **Module Refactoring:** Split Phase 1 code into VolumeProfile.mqh, RiskManager.mqh; add Phase 2 TradeExecution.mqh and JournalLogger.mqh.
7. **Pitfalls:** Deviation parameter ≠ hard slippage limit (broker execution model dependent). Retry logic must check signal expiry (same bar only). Daily P&L threshold sensitive to broker session boundary.

### File Created
`.planning/phases/02-signal-detection-execution/02-RESEARCH.md`

### Confidence Assessment
| Area | Level | Reason |
|------|-------|--------|
| Standard Stack | HIGH | CTrade documented, Phase 1 code provides reference |
| Architecture | MEDIUM-HIGH | Patterns follow MQL5 conventions; some broker-dependent behavior |
| Pitfalls | MEDIUM | Common issues identified; some dependent on specific broker execution model |
| Code Examples | HIGH | Phase 1 code + official MQL5 documentation provide verified patterns |

### Open Questions
- Exact balanced market threshold (0.6x vs 0.7x) — needs backtest validation
- Candle pattern wick/body ratios — needs sample data testing
- Retry backoff strategy timing — needs confirmation on signal expiry handling
- SL adjustment on profit cap (breakeven vs +5-10 pips) — needs live result evaluation
- Partial close percentage (50% vs 60% vs 70%) — needs outcome tracking

### Ready for Planning
Research complete. Planner can now create PLAN.md files for Phase 2 implementation with high confidence in technical approach and pattern references.
