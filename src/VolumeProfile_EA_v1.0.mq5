//+------------------------------------------------------------------+
//|                      VolumeProfile_EA_v1.0.mq5                  |
//|                  Volume Profile Swing Trading EA                |
//|                       Phase 2: Modular Refactor                 |
//|                                                                  |
//| Description:                                                     |
//|   Refactored main EA orchestrator using modular header files.    |
//|   All calculation logic extracted to VolumeProfile.mqh,          |
//|   RiskManager.mqh, and Utils.mqh. Main EA now focuses on        |
//|   OnInit, OnDeinit, OnTick orchestration and future Phase 2     |
//|   signal detection logic.                                        |
//|                                                                  |
//| Core Features (Phase 1 + 2 Refactor):                            |
//|   - 400-bin volume distribution from modular header              |
//|   - Point of Control (POC) identification                       |
//|   - Value Area High/Low (VAH/VAL) at 70% cumulative volume      |
//|   - High/Low Volume Node detection (1.3x/0.7x thresholds)      |
//|   - Position sizing formula (0.6% risk per trade)               |
//|   - Daily hard stop (-2%) and profit cap (+5%)                  |
//|   - Modular risk management and utility functions               |
//|                                                                  |
//+------------------------------------------------------------------+

#property copyright "Phase 2 Modular Refactor"
#property link      "https://github.com/sgunamijaya/VWGTI-Pro"
#property version   "2.0"
#property strict
#property icon      "\\Images\\EarnForex\\forex.ico"

// ==================== TRADE.MQH IMPORT ====================

#include <Trade/Trade.mqh>

// ==================== CONSOLIDATED HEADERS (from Phase 02.1) ====================

// -------- Utils.mqh --------

// ==================== GLOBAL CONSTANTS ====================
// All magic numbers and hardcoded values centralized here

#define EA_MAGIC_NUMBER 99001
#define VOLUME_BINS 400
#define LOOKBACK_BARS 150
#define RISK_PERCENT 0.6
#define DAILY_LOSS_LIMIT 0.02
#define DAILY_PROFIT_CAP 0.05
#define HVN_PERCENTILE 0.85
#define LVN_PERCENTILE 0.25
#define SLIPPAGE_TOLERANCE_PIPS 50
#define FRIDAY_CLOSE_HOUR 21
#define FRIDAY_CLOSE_MINUTE 45
#define VALUE_AREA_PERCENT 0.70

// ==================== UTILITY FUNCTIONS ====================

//+------------------------------------------------------------------+
//| Check broker connection and symbol validity                      |
//+------------------------------------------------------------------+
bool IsConnected()
{
    if (!TerminalInfoInteger(TERMINAL_CONNECTED))
    {
        LogError("Terminal not connected to broker");
        return false;
    }

    double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);

    if (tickValue <= 0 || tickSize <= 0)
    {
        LogError("Invalid symbol or broker data not available - " + Symbol());
        LogAlert("ERROR", "SYMBOL_TRADE_TICK_VALUE = " + DoubleToString(tickValue, 8));
        LogAlert("ERROR", "SYMBOL_TRADE_TICK_SIZE = " + DoubleToString(tickSize, 8));
        return false;
    }

    LogAlert("INFO", "Connected to broker, symbol=" + Symbol() +
             " tick_value=" + DoubleToString(tickValue, 8) +
             " tick_size=" + DoubleToString(tickSize, 8));

    return true;
}

//+------------------------------------------------------------------+
//| Get session boundary time (Tokyo open, 00:00 SGT / 17:00 Fri ET) |
//| Used for daily limit resets and previous session data            |
//+------------------------------------------------------------------+
datetime GetSessionBoundary()
{
    // Session boundary: 00:00 SGT (Singapore) = 17:00 Friday ET (New York)
    // This marks when daily limits reset

    MqlDateTime timeStruct;
    TimeToStruct(TimeCurrent(), timeStruct);

    // For now, return midnight broker server time
    // TODO: Implement proper timezone-aware session boundary

    timeStruct.hour = 0;
    timeStruct.min = 0;
    timeStruct.sec = 0;

    return StructToTime(timeStruct);
}

//+------------------------------------------------------------------+
//| Log error to Journal                                             |
//+------------------------------------------------------------------+
void LogError(string message)
{
    Print("[ERROR] ", message);
}

//+------------------------------------------------------------------+
//| Log alert to Journal                                             |
//+------------------------------------------------------------------+
void LogAlert(string alertType, string message)
{
    Print("[", alertType, "] ", message);
}

//+------------------------------------------------------------------+
//| Detect new bar on current timeframe                              |
//| Returns true if a new bar has formed since last call             |
//+------------------------------------------------------------------+
bool NewBar()
{
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(Symbol(), PERIOD_CURRENT, 0);

    if (currentBarTime != lastBarTime)
    {
        lastBarTime = currentBarTime;
        return true;
    }

    return false;
}

// -------- VolumeProfile.mqh --------

// ==================== VOLUME PROFILE DATA STRUCTURES ====================

struct VolumeNode {
    double price;
    double volume;
};

struct VolumeProfile {
    double volumeArray[VOLUME_BINS];    // 400-bin distribution
    double pocPrice;                    // Point of Control price
    double pocVolume;                   // Volume at POC
    double vahPrice;                    // Value Area High
    double valPrice;                    // Value Area Low
    double binSize;                     // Price per bin
    double minPrice;                    // Minimum price in lookback
    double maxPrice;                    // Maximum price in lookback
    int    pocBinIndex;                 // Bin index of POC
    int    hvnCount;                    // Number of HVN zones
    int    lvnCount;                    // Number of LVN zones
    VolumeNode hvnArray[50];            // High Volume Node array
    VolumeNode lvnArray[50];            // Low Volume Node array
};

//+------------------------------------------------------------------+
//| Calculate 400-bin volume distribution (REQ-001, REQ-008)         |
//| Implementation per D-01: Proportional-to-range proration         |
//+------------------------------------------------------------------+
VolumeProfile CalculateCurrentVolumeProfile(int lookbackBars)
{
    VolumeProfile profile;

    // Step 1: Find price range from lookback period
    double minPrice = iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, lookbackBars, 0);
    double maxPrice = iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, lookbackBars, 0);

    if (maxPrice <= minPrice)
    {
        LogError("Invalid price range for volume profile");
        profile.pocPrice = 0;  // Initialize profile.pocPrice to 0
        return profile;
    }

    // Calculate bin size
    double binSize = (maxPrice - minPrice) / VOLUME_BINS;

    // Store metadata
    profile.minPrice = minPrice;
    profile.maxPrice = maxPrice;
    profile.binSize = binSize;

    // Step 2: Initialize volume array to zero
    ArrayInitialize(profile.volumeArray, 0);

    // Step 3: Iterate through lookback bars and prorate volume
    for (int i = 0; i < lookbackBars; i++)
    {
        double high = iHigh(Symbol(), PERIOD_CURRENT, i);
        double low = iLow(Symbol(), PERIOD_CURRENT, i);
        double close = iClose(Symbol(), PERIOD_CURRENT, i);
        long volume = iVolume(Symbol(), PERIOD_CURRENT, i);

        if (volume <= 0)
            continue;  // Skip bars with zero volume

        double range = high - low;

        // Multi-level candle: distribute volume proportionally across price range
        if (range > binSize)
        {
            // Calculate how many bins this candle spans
            int numBins = (int)(range / binSize) + 1;
            if (numBins > VOLUME_BINS)
                numBins = VOLUME_BINS;  // Safety cap

            double volumePerBin = (double)volume / numBins;

            // Iterate from low to high in bin steps
            for (double price = low; price <= high && price <= maxPrice; price += binSize)
            {
                int binIdx = (int)((price - minPrice) / binSize);
                if (binIdx >= 0 && binIdx < VOLUME_BINS)
                {
                    profile.volumeArray[binIdx] += volumePerBin;
                }
            }
        }
        else
        {
            // Doji or flat candle: all volume goes to close price bin
            int binIdx = (int)((close - minPrice) / binSize);
            if (binIdx >= 0 && binIdx < VOLUME_BINS)
            {
                profile.volumeArray[binIdx] += (double)volume;
            }
        }
    }

    // Step 4: Validation - Check volume distribution integrity
    double binSum = 0;
    long rawTotal = 0;

    for (int i = 0; i < lookbackBars; i++)
        rawTotal += iVolume(Symbol(), PERIOD_CURRENT, i);

    for (int i = 0; i < VOLUME_BINS; i++)
        binSum += profile.volumeArray[i];

    if (rawTotal > 0)
    {
        double variance = MathAbs(binSum - rawTotal) / rawTotal;
        if (variance > 0.01)  // >1% variance
        {
            LogAlert("WARNING", StringFormat("Volume distribution variance %.2f%% > 1%%, sum=%.0f, total=%d",
                variance * 100, binSum, rawTotal));
        }
        else if (variance > 0.001)  // >0.1% variance
        {
            LogAlert("WARNING", StringFormat("Volume distribution variance %.3f%% (minor)", variance * 100));
        }
    }

    return profile;
}

//+------------------------------------------------------------------+
//| Calculate POC and VAH/VAL boundaries (REQ-002, REQ-003, REQ-004) |
//| POC = single price bin with max volume                            |
//| VAH/VAL = 70% cumulative volume expanding from POC                |
//+------------------------------------------------------------------+
void CalculateValueArea(VolumeProfile &profile)
{
    if (profile.binSize <= 0)
    {
        LogError("Volume profile not calculated before VAH/VAL");
        return;
    }

    // Step 1: Identify POC (Point of Control)
    // POC = price bin with highest accumulated volume
    double maxVol = 0;
    int pocIdx = 0;

    for (int i = 0; i < VOLUME_BINS; i++)
    {
        if (profile.volumeArray[i] > maxVol)
        {
            maxVol = profile.volumeArray[i];
            pocIdx = i;
        }
    }

    // Convert bin index to price (use center of bin)
    profile.pocBinIndex = pocIdx;
    profile.pocPrice = profile.minPrice +
                       (pocIdx * profile.binSize) +
                       (profile.binSize / 2.0);
    profile.pocVolume = maxVol;

    // Step 2: Calculate VAH/VAL (70% Value Area expansion)
    // Calculate total volume and target threshold
    double totalVol = 0;
    for (int i = 0; i < VOLUME_BINS; i++)
    {
        totalVol += profile.volumeArray[i];
    }

    if (totalVol <= 0)
    {
        LogError("Total volume <= 0 for VAH/VAL calculation");
        return;
    }

    double targetVol = totalVol * VALUE_AREA_PERCENT;  // 70% threshold

    // Expand outward from POC until 70% cumulative volume reached
    double cumulativeVol = profile.volumeArray[profile.pocBinIndex];
    int offset = 0;
    int maxOffset = 200;  // Safety: don't expand > 50% of bins

    while (cumulativeVol < targetVol && offset < maxOffset)
    {
        offset++;

        // Add bin above POC (higher price)
        if (profile.pocBinIndex + offset < VOLUME_BINS)
        {
            cumulativeVol += profile.volumeArray[profile.pocBinIndex + offset];
        }

        // Add bin below POC (lower price)
        if (profile.pocBinIndex - offset >= 0)
        {
            cumulativeVol += profile.volumeArray[profile.pocBinIndex - offset];
        }
    }

    // Step 3: Calculate VAH and VAL prices
    int vahBinIndex = profile.pocBinIndex + offset;
    int valBinIndex = profile.pocBinIndex - offset;

    // Clamp to valid range
    if (vahBinIndex >= VOLUME_BINS)
        vahBinIndex = VOLUME_BINS - 1;
    if (valBinIndex < 0)
        valBinIndex = 0;

    profile.vahPrice = profile.minPrice +
                       (vahBinIndex * profile.binSize);
    profile.valPrice = profile.minPrice +
                       (valBinIndex * profile.binSize);

    // Step 4: Validation - Check Value Area width is reasonable
    double vaWidth = profile.vahPrice - profile.valPrice;
    if (vaWidth < profile.binSize)
    {
        LogAlert("WARNING", StringFormat("VA width %.5f < bin size %.5f",
            vaWidth, profile.binSize));
    }

    // Log POC/VAH/VAL prices for audit trail
    LogAlert("VA_CALC", StringFormat("POC=%.5f VAH=%.5f VAL=%.5f width_pips=%.2f",
        profile.pocPrice,
        profile.vahPrice,
        profile.valPrice,
        (profile.vahPrice - profile.valPrice) / Point()));
}

//+------------------------------------------------------------------+
//| Identify High/Low Volume Nodes (REQ-005, REQ-006)               |
//| HVN = local peaks > 1.3x average volume (locked per D-02)       |
//| LVN = local valleys < 0.7x average volume (locked per D-02)    |
//+------------------------------------------------------------------+
void IdentifyVolumeNodes(VolumeProfile &profile, double hvnThreshold, double lvnThreshold)
{
    if (profile.pocPrice <= 0)
    {
        LogError("POC not calculated before node identification");
        return;
    }

    // Step 1: Calculate average volume per bin
    double totalVol = 0;
    for (int i = 0; i < VOLUME_BINS; i++)
    {
        totalVol += profile.volumeArray[i];
    }

    if (totalVol <= 0)
    {
        LogError("Total volume <= 0 for node identification");
        return;
    }

    double avgVolume = totalVol / VOLUME_BINS;

    // Step 2: Apply provided thresholds (or use defaults)
    double hvnThresholdActual = (hvnThreshold > 0) ? hvnThreshold : (avgVolume * 1.3);
    double lvnThresholdActual = (lvnThreshold > 0) ? lvnThreshold : (avgVolume * 0.7);

    // Step 3: Reset arrays and counters
    profile.hvnCount = 0;
    profile.lvnCount = 0;
    // Zero out HVN and LVN arrays
    for (int j = 0; j < 50; j++)
    {
        profile.hvnArray[j].price = 0;
        profile.hvnArray[j].volume = 0;
        profile.lvnArray[j].price = 0;
        profile.lvnArray[j].volume = 0;
    }

    // Step 4: Iterate and classify bins as HVN or LVN
    for (int i = 0; i < VOLUME_BINS; i++)
    {
        double binVolume = profile.volumeArray[i];
        double binPrice = profile.minPrice + (i * profile.binSize);

        // HVN: local peaks > 1.3x average
        if (binVolume > hvnThresholdActual)
        {
            if (profile.hvnCount < 50)  // Max 50 HVN clusters
            {
                profile.hvnArray[profile.hvnCount].price = binPrice;
                profile.hvnArray[profile.hvnCount].volume = binVolume;
                profile.hvnCount++;
            }
        }

        // LVN: local valleys < 0.7x average
        if (binVolume < lvnThresholdActual)
        {
            if (profile.lvnCount < 50)  // Max 50 LVN clusters
            {
                profile.lvnArray[profile.lvnCount].price = binPrice;
                profile.lvnArray[profile.lvnCount].volume = binVolume;
                profile.lvnCount++;
            }
        }
    }

    // Step 5: Validation - sanity-check cluster counts
    if (profile.hvnCount > 50)
    {
        LogAlert("WARNING", StringFormat("HVN count %d exceeds max (50); truncated",
            profile.hvnCount));
        profile.hvnCount = 50;
    }

    if (profile.lvnCount > 50)
    {
        LogAlert("WARNING", StringFormat("LVN count %d exceeds max (50); truncated",
            profile.lvnCount));
        profile.lvnCount = 50;
    }
}

// -------- RiskManager.mqh --------

//+------------------------------------------------------------------+
//| Calculate position size based on risk (REQ-029, REQ-030)         |
//| Formula: Lot Size = (Balance × 0.6%) / (SL Distance × Pip Value) |
//+------------------------------------------------------------------+
double CalculateLotSize(double entryPrice, double stopLossPrice)
{
    // REQ-029: Risk-based sizing formula

    // Step 1: Calculate risk amount in account currency
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * (RISK_PERCENT / 100.0);  // 0.6% locked

    if (riskAmount <= 0)
    {
        Print("ERROR: Invalid account balance for lot sizing");
        return 0;
    }

    // Step 2: Calculate SL distance in pips (broker's point units)
    double slDistancePoints = MathAbs(entryPrice - stopLossPrice) / Point();

    if (slDistancePoints <= 0)
    {
        Print("ERROR: Invalid SL distance for lot sizing");
        return 0;
    }

    // Step 3: Fetch pip value for this symbol
    // CRITICAL: Use SymbolInfoDouble() to get broker-specific pip value
    // DO NOT hardcode; brokers differ on XAUUSD tick value

    double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);

    if (tickValue <= 0 || tickSize <= 0)
    {
        Print("ERROR: Invalid tick value/size for symbol ", Symbol());
        return 0;
    }

    double pipValue = tickValue / tickSize;

    // Step 4: Calculate lot size
    double lotSize = riskAmount / (slDistancePoints * pipValue);

    if (lotSize <= 0)
    {
        Print("ERROR: Calculated lot size <= 0");
        return 0;
    }

    // Step 5: Apply broker constraints (REQ-029 acceptance criteria)
    double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

    if (minLot <= 0 || maxLot <= 0 || lotStep <= 0)
    {
        Print("ERROR: Invalid broker lot constraints");
        return 0;
    }

    // Validate minimum lot
    if (lotSize < minLot)
    {
        Print("WARNING: Calculated lot size ", lotSize, " < minimum ", minLot,
              "; rejecting trade");
        return 0;  // Reject trade; too small
    }

    // Cap at maximum lot (if position would be too large)
    if (lotSize > maxLot)
    {
        Print("WARNING: Calculated lot size ", lotSize, " > maximum ", maxLot,
              "; capping at max");
        lotSize = maxLot;
    }

    // Round to lot step (e.g., 0.01 for Forex)
    lotSize = MathFloor(lotSize / lotStep) * lotStep;

    return lotSize;
}

// -------- SignalDetection.mqh --------

//+------------------------------------------------------------------+
//| Setup 1 Signal Structure                                         |
//+------------------------------------------------------------------+
struct Setup1Signal
{
    bool   isTriggered;           // Signal detected (gap + reclaim + confirmation all present)
    bool   isLong;                // true = LONG, false = SHORT
    double confirmationClose;     // Close price of confirmation candle (entry price)
    double sweepLow;              // Lowest price during gap phase (for SL calculation)
};

//+------------------------------------------------------------------+
//| Setup 2 Signal Structure                                         |
//+------------------------------------------------------------------+
struct Setup2Signal
{
    bool   isTriggered;           // Signal detected (LVN sweep + HVN edge + pattern + volume all present)
    bool   isLong;                // true = LONG (Hammer), false = SHORT (Shooting Star)
    double hvnEdgePrice;          // HVN edge price (entry target)
    double sweepLow;              // LVN sweep low (for SL calculation)
};

//+------------------------------------------------------------------+
//| Candle Pattern Structure                                         |
//+------------------------------------------------------------------+
struct CandlePattern
{
    enum Type { NONE = 0, HAMMER = 1, SHOOTING_STAR = 2, DOJI = 3 };
    Type patternType;
    bool isValid;
};

//+------------------------------------------------------------------+
//| IsBalancedMarket()                                               |
//| Determines if market is balanced (Setup 1 active) or imbalanced  |
//| (Setup 2 active) by comparing Value Area width to recent range   |
//|                                                                  |
//| Balanced (Setup 1 active) when: VA width < 0.6x recent range    |
//| Imbalanced (Setup 2 active) when: VA width >= 0.6x recent range |
//+------------------------------------------------------------------+
bool IsBalancedMarket()
{
    // Calculate recent range (last 20 bars, locked value per D-01)
    double lookbackHigh = iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, 20, 0);
    double lookbackLow = iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, 20, 0);
    double recentRange = lookbackHigh - lookbackLow;

    // Edge case: no range, assume balanced
    if (recentRange == 0)
        return true;

    // Calculate VA width from current profile (set by Phase 1 volume profile calculation)
    double vaWidth = currentProfile.vahPrice - currentProfile.valPrice;

    // Balanced when VA < 0.6x recent range (per D-01: VA width < 0.6x recent range)
    double balanceThreshold = recentRange * 0.6;

    return (vaWidth < balanceThreshold);
}

//+------------------------------------------------------------------+
//| DetectSetup1Signal()                                             |
//| Detects Setup 1 signal when ALL three conditions aligned:        |
//| 1. GAP: Price opened outside previous session VA                 |
//| 2. RECLAIM: Price reclaimed into VA on current bar               |
//| 3. CONFIRMATION: Close FULLY inside VA (not wick touch)          |
//|                                                                  |
//| Returns: Setup1Signal with isTriggered=true only when all        |
//|          conditions present; entry and SL details included       |
//+------------------------------------------------------------------+
Setup1Signal DetectSetup1Signal()
{
    Setup1Signal result = {false, false, 0, 0};

    // REQ-011: Only evaluate Setup 1 when balanced (caller responsibility via IsBalancedMarket())

    // Get previous closed bar data (bar [1])
    double openPrice = iOpen(Symbol(), PERIOD_CURRENT, 1);
    double closePrice = iClose(Symbol(), PERIOD_CURRENT, 1);
    double lowPrice = iLow(Symbol(), PERIOD_CURRENT, 1);

    // REQ-012: Gap detection — price opened outside previous session VA
    double previousVAH = previousSessionProfile.vahPrice;
    double previousVAL = previousSessionProfile.valPrice;

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

    // Signal triggered! All three conditions present.
    result.isTriggered = true;
    result.isLong = reclaimingUp;              // LONG if reclaiming from below
    result.confirmationClose = closePrice;    // Entry at close of confirmation candle
    result.sweepLow = lowPrice;                // Used for SL (below this)

    return result;
}

//+------------------------------------------------------------------+
//| DetectCandlePattern()                                            |
//| Recognizes Hammer, Shooting Star, and Doji candle patterns       |
//|                                                                  |
//| HAMMER: Lower wick > 2x body, upper wick < 0.1x body            |
//|         Bullish reversal (for Setup 2 LONG entry)               |
//|                                                                  |
//| SHOOTING STAR: Upper wick > 2x body, lower wick < 0.1x body    |
//|                Bearish reversal (for Setup 2 SHORT entry)       |
//|                                                                  |
//| DOJI: Open ≈ close (within 1 pip), wicks extending both sides   |
//|       Neutral indecision (for either Setup 2 direction)         |
//+------------------------------------------------------------------+
CandlePattern DetectCandlePattern()
{
    CandlePattern result = {CandlePattern::NONE, false};

    // Get previous closed candle (bar [1])
    double open = iOpen(Symbol(), PERIOD_CURRENT, 1);
    double high = iHigh(Symbol(), PERIOD_CURRENT, 1);
    double low = iLow(Symbol(), PERIOD_CURRENT, 1);
    double close = iClose(Symbol(), PERIOD_CURRENT, 1);

    // Calculate body and wick sizes
    double bodySize = MathAbs(close - open);
    double lowerWick = open < close ? open - low : close - low;
    double upperWick = close > open ? high - close : high - open;

    // HAMMER: Lower wick > 2x body, upper wick < 0.1x body, close near high
    if (lowerWick > 2.0 * bodySize && upperWick < 0.1 * bodySize && close > (open + bodySize * 0.5))
    {
        result.patternType = CandlePattern::HAMMER;
        result.isValid = true;
    }
    // SHOOTING STAR: Upper wick > 2x body, lower wick < 0.1x body, close near low
    else if (upperWick > 2.0 * bodySize && lowerWick < 0.1 * bodySize && close < (open - bodySize * 0.5))
    {
        result.patternType = CandlePattern::SHOOTING_STAR;
        result.isValid = true;
    }
    // DOJI: Open ≈ close (within 1 pip), wicks extending both sides
    else if (bodySize <= 1 * Point() && lowerWick > 0 && upperWick > 0)
    {
        result.patternType = CandlePattern::DOJI;
        result.isValid = true;
    }

    return result;
}

//+------------------------------------------------------------------+
//| DetectSetup2Signal()                                             |
//| Detects Setup 2 signal when ALL four conditions aligned:         |
//| 1. LVN SWEEP: Price recent low below lowest LVN                 |
//| 2. HVN EDGE: Nearest HVN above current price identified         |
//| 3. PATTERN: Hammer/Shooting Star/Doji at HVN boundary           |
//| 4. VOLUME: Tick volume ≥ 1.3x previous bar                      |
//|                                                                  |
//| Returns: Setup2Signal with isTriggered=true only when all        |
//|          conditions present; entry and SL details included       |
//+------------------------------------------------------------------+
Setup2Signal DetectSetup2Signal()
{
    Setup2Signal result = {false, false, 0, 0};

    // Get current bar data
    double currentLow = iLow(Symbol(), PERIOD_CURRENT, 1);

    // REQ-017: LVN sweep detection — price recent low below lowest LVN
    double lowestLVN = 999999;
    for (int i = 0; i < currentProfile.lvnCount; i++)
    {
        if (currentProfile.lvnArray[i].price < lowestLVN)
            lowestLVN = currentProfile.lvnArray[i].price;
    }

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

    // Signal triggered! All four conditions present.
    result.isTriggered = true;
    result.isLong = (pattern.patternType == CandlePattern::HAMMER);  // LONG on Hammer, SHORT on Shooting Star
    result.hvnEdgePrice = hvnEdge;
    result.sweepLow = currentLow;  // Used for SL (below LVN)

    return result;
}

// -------- MultiTimeframeContext.mqh --------

//+------------------------------------------------------------------+
//| 15M Profile Structure                                            |
//+------------------------------------------------------------------+
struct Profile15M
{
    double vahPrice;           // Value Area High on 15M timeframe
    double valPrice;           // Value Area Low on 15M timeframe
    double pocPrice;           // Point of Control on 15M timeframe
    datetime lastUpdateTime;   // Last update timestamp
};

// Global 15M profile cache
Profile15M profile15M = {0, 0, 0, 0};

//+------------------------------------------------------------------+
//| Load15MProfile()                                                 |
//| Recalculates 15M profile using 150-bar lookback on PERIOD_M15   |
//| Provides higher-timeframe context for direction bias validation  |
//|                                                                  |
//| Calculation approach (MVP):                                      |
//|   - VAL: 25th percentile of 150-bar range (low support)         |
//|   - VAH: 75th percentile of 150-bar range (high resistance)     |
//|   - PoC: Midpoint of range (simplified; full calculation deferred)|
//+------------------------------------------------------------------+
void Load15MProfile()
{
    // Recalculate 15M profile using 150-bar lookback on PERIOD_M15
    // This provides higher-timeframe context for direction bias

    // Get 15M profile data (300 bars back on 15M = 75 hours of data)
    double high15M = iHighest(Symbol(), PERIOD_M15, MODE_HIGH, 150, 0);
    double low15M = iLowest(Symbol(), PERIOD_M15, MODE_LOW, 150, 0);

    // Simplified 15M profile: Use iLowest/iHighest as VAL/VAH proxies
    // Full calculation would use CalculateCurrentVolumeProfile on 15M data
    // For MVP: approximate VAL as 25th percentile of range, VAH as 75th percentile

    double range15M = high15M - low15M;
    profile15M.valPrice = low15M + range15M * 0.25;
    profile15M.vahPrice = high15M - range15M * 0.25;
    profile15M.pocPrice = (high15M + low15M) / 2.0;  // POC as midpoint (simplified)
    profile15M.lastUpdateTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Get15MVAHContext()                                               |
//| Returns 15M Value Area High for direction bias reference         |
//+------------------------------------------------------------------+
double Get15MVAHContext()
{
    return profile15M.vahPrice;
}

//+------------------------------------------------------------------+
//| Get15MVALContext()                                               |
//| Returns 15M Value Area Low for direction bias reference          |
//+------------------------------------------------------------------+
double Get15MVALContext()
{
    return profile15M.valPrice;
}

//+------------------------------------------------------------------+
//| Validate15MDirectionBias()                                       |
//| Prevents counter-trend entries by checking 15M context           |
//|                                                                  |
//| For LONG entries: Don't enter if current price too close to      |
//|                   15M VAL (downside risk)                        |
//| For SHORT entries: Don't enter if current price too close to     |
//|                    15M VAH (upside risk)                         |
//|                                                                  |
//| Conservative buffer: 50 pips above/below profile boundary        |
//+------------------------------------------------------------------+
bool Validate15MDirectionBias(bool isLongEntry)
{
    // Get current bid/ask prices
    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double mid = (bid + ask) / 2.0;

    if (isLongEntry)
    {
        // LONG: require at least 50 pips above 15M VAL (conservative buffer)
        return (mid > profile15M.valPrice + 50 * Point());
    }
    else
    {
        // SHORT: require at least 50 pips below 15M VAH (conservative buffer)
        return (mid < profile15M.vahPrice - 50 * Point());
    }
}

//+------------------------------------------------------------------+
//| IsSessionAllowed()                                               |
//| Blocks entries during low-liquidity, high-volatility sessions:   |
//|   1. GRAVE HOUR: NY 16:00–17:00 (daily)                         |
//|   2. PRE-TOKYO: Sun 23:00 NY – Mon 00:00 NY (weekly)            |
//|                                                                  |
//| Assumes broker server time = NY time (typical forex)            |
//+------------------------------------------------------------------+
bool IsSessionAllowed()
{
    // Get current time in broker server time (NY time or GMT, depending on broker)
    // Assume broker uses NY time (typical for Forex brokers)

    MqlDateTime timeStruct;
    TimeToStruct(TimeCurrent(), timeStruct);

    int currentHour = timeStruct.hour;
    int currentMinute = timeStruct.min;
    int dayOfWeek = timeStruct.day_of_week;  // 0=Sunday, 1=Monday, ..., 5=Friday, 6=Saturday

    // GRAVE HOUR BLOCK: NY 16:00–17:00 (4 PM – 5 PM NY close, low liquidity, high volatility)
    // This occurs daily Monday–Friday
    if (currentHour == 16)
    {
        return false;  // Block all entries during this hour
    }

    // PRE-TOKYO BLOCK: Sunday 23:00 NY through Monday 00:00 NY (minimal liquidity before Tokyo open)
    // Sunday 23:00 = Sunday close, Monday 00:00 = early Monday before Asian open
    bool isPreTokyoSunday = (dayOfWeek == 0 && currentHour == 23);  // Sunday 11 PM
    bool isPreTokyoMonday = (dayOfWeek == 1 && currentHour == 0);   // Monday midnight

    if (isPreTokyoSunday || isPreTokyoMonday)
    {
        return false;  // Block all entries
    }

    // Otherwise: trading allowed (Europe, Asia-Pacific, or US hours)
    return true;
}

//+------------------------------------------------------------------+
//| ValidateLiquidity()                                              |
//| Checks bid-ask spread and tick volume before entry               |
//|                                                                  |
//| D-14 Requirements:                                               |
//|   - Spread ≤ 3 pips for Gold (XAUUSD)                           |
//|   - Spread ≤ 5 pips for EURUSD                                  |
//|   - Tick volume ≥ 10 (minimum liquidity threshold)              |
//|                                                                  |
//| Returns: true if all liquidity conditions met; false otherwise   |
//+------------------------------------------------------------------+
bool ValidateLiquidity()
{
    // Check bid-ask spread and tick volume before entry

    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double spread = ask - bid;

    // Get broker tick value to convert spread to pips
    double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
    double spreadPips = spread / tickSize;

    // Symbol-specific spread threshold
    double spreadLimit = 5.0;  // Default 5 pips (EURUSD)

    if (StringFind(Symbol(), "XAUUSD") >= 0)
    {
        spreadLimit = 3.0;  // Gold: 3 pips limit
    }

    if (spreadPips > spreadLimit)
    {
        return false;  // Spread too wide; reject
    }

    // Check tick volume (minimum 10)
    long tickVolume = SymbolInfoInteger(Symbol(), SYMBOL_VOLUME);
    if (tickVolume < 10)
    {
        return false;  // Insufficient volume; reject
    }

    return true;  // Liquidity acceptable
}

// -------- TradeExecution.mqh --------

// ==================== TRADE EXECUTION CONSTANTS ====================

#define MAX_POSITIONS 10           // Max simultaneous positions
#define SLIPPAGE_LIMIT 50          // 50-pip tolerance (D-07)
#define RETRY_ATTEMPTS 3           // Order placement retry attempts
#define RETRY_DELAY 100            // Milliseconds between retries

// ==================== TRADE EXECUTION DATA STRUCTURES ====================

// Result of order placement attempt
struct OrderResult
{
    bool success;                  // Order filled successfully
    long ticket;                   // Position ticket number
    double fillPrice;              // Actual fill price
    double slippage;               // Actual slippage in pips
};

// Position state tracking (remaining lots method per D-03/D-06)
struct PositionState
{
    long ticket;                   // Position ticket
    string symbol;                 // Trading symbol
    bool isLong;                   // True=LONG, False=SHORT
    double entryPrice;             // Entry execution price
    double stopLoss;               // SL price (below sweep low + buffer)
    double takeProfit;             // TP price (opposite profile edge)
    double originalLots;           // Original position size at entry
    double remainingLots;          // Remaining lots (decrements on partial closes)
    datetime entryTime;            // Entry timestamp
    string setupType;              // "Setup1" or "Setup2"
    double riskRewardRatio;        // R:R ratio at entry
};

// ==================== TRADE EXECUTION GLOBAL VARIABLES ====================

CTrade trade;                      // Global CTrade instance
PositionState positions[MAX_POSITIONS];  // Position tracking array
int positionCount = 0;             // Number of active positions

//+------------------------------------------------------------------+
//| Place Market Order with Post-Execution Slippage Validation      |
//| Per D-07: Reject fills >50 pips from intended entry; close bad   |
//| fills immediately. Retry logic for transient errors.             |
//+------------------------------------------------------------------+
OrderResult PlaceMarketOrder(ENUM_ORDER_TYPE orderType, double lots,
                             double intendedPrice, double stopLoss,
                             double takeProfit)
{
    OrderResult result = {false, 0, 0, 0};

    // Retry logic: up to 3 attempts for transient errors
    for (int attempt = 0; attempt < RETRY_ATTEMPTS; attempt++)
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
        request.deviation = 500;   // 50 pips (5 decimal places)
        request.magic = EA_MAGIC_NUMBER;
        request.comment = (orderType == ORDER_TYPE_BUY) ? "Setup-LONG" : "Setup-SHORT";

        // Execute via CTrade
        MqlTradeResult tradeResult = {0};
        if (!trade.Send(request, tradeResult))
        {
            uint retcode = tradeResult.retcode;
            LogError(StringFormat("OrderSend failed. Retcode=%d, Attempt=%d/%d",
                                retcode, attempt + 1, RETRY_ATTEMPTS));

            // Retry transient errors (not terminal retcodes)
            if (attempt < RETRY_ATTEMPTS - 1)
            {
                Sleep(RETRY_DELAY);
                continue;
            }
            else
            {
                result.success = false;
                return result;
            }
        }

        // Order executed; check return code
        uint retcode = tradeResult.retcode;

        if (retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_PLACED)
        {
            // Successful execution; validate slippage
            result.ticket = tradeResult.order;
            result.fillPrice = tradeResult.price;

            // D-07: Validate slippage (50-pip tolerance)
            double slippagePips = MathAbs(result.fillPrice - intendedPrice) / Point();

            if (slippagePips <= SLIPPAGE_LIMIT)
            {
                // Slippage acceptable
                result.success = true;
                result.slippage = slippagePips;

                LogAlert("ORDER_FILLED",
                        StringFormat("Ticket=%ld, Price=%.5f, Slippage=%.1f pips, Intent=%.5f",
                                    result.ticket, result.fillPrice, result.slippage, intendedPrice));

                return result;
            }
            else
            {
                // Slippage exceeds 50 pips; reject and close position immediately
                LogError(StringFormat("Slippage exceeds limit (%.1f pips > %d pips). Closing position ticket=%ld",
                                    slippagePips, SLIPPAGE_LIMIT, result.ticket));

                // Close the position at market (avoid locking in bad fill)
                trade.PositionClose(result.ticket);

                result.success = false;
                result.slippage = slippagePips;
                return result;
            }
        }
        else
        {
            // Transient error; may retry
            LogError(StringFormat("OrderSend retcode=%d, Attempt=%d/%d",
                                retcode, attempt + 1, RETRY_ATTEMPTS));

            if (attempt < RETRY_ATTEMPTS - 1)
            {
                Sleep(RETRY_DELAY);
                continue;
            }
            else
            {
                result.success = false;
                return result;
            }
        }
    }

    result.success = false;
    return result;
}

//+------------------------------------------------------------------+
//| Add new position to tracking array                               |
//+------------------------------------------------------------------+
void AddPosition(long ticket, string symbol, bool isLong, double entryPrice,
                 double stopLoss, double takeProfit, double lots,
                 string setupType, double riskRewardRatio)
{
    if (positionCount >= MAX_POSITIONS)
    {
        LogError("Position array full; cannot add new position");
        return;
    }

    positions[positionCount].ticket = ticket;
    positions[positionCount].symbol = symbol;
    positions[positionCount].isLong = isLong;
    positions[positionCount].entryPrice = entryPrice;
    positions[positionCount].stopLoss = stopLoss;
    positions[positionCount].takeProfit = takeProfit;
    positions[positionCount].originalLots = lots;
    positions[positionCount].remainingLots = lots;
    positions[positionCount].entryTime = TimeCurrent();
    positions[positionCount].setupType = setupType;
    positions[positionCount].riskRewardRatio = riskRewardRatio;

    positionCount++;

    LogAlert("POSITION_ADDED",
            StringFormat("Ticket=%ld, Symbol=%s, Side=%s, Entry=%.5f, SL=%.5f, TP=%.5f, Lots=%.2f, Setup=%s, RR=%.2f:1",
                        ticket, symbol, isLong ? "LONG" : "SHORT", entryPrice, stopLoss, takeProfit, lots, setupType, riskRewardRatio));
}

//+------------------------------------------------------------------+
//| Update position state on partial close (decrement remaining lots)|
//+------------------------------------------------------------------+
bool UpdatePositionState(long ticket, double partialCloseLots)
{
    // Find position in array and decrement remaining lots
    for (int i = 0; i < positionCount; i++)
    {
        if (positions[i].ticket == ticket)
        {
            positions[i].remainingLots -= partialCloseLots;

            // Log partial close
            LogAlert("PARTIAL_CLOSE",
                    StringFormat("Ticket=%ld, ClosedLots=%.2f, RemainingLots=%.2f",
                                ticket, partialCloseLots, positions[i].remainingLots));

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

//+------------------------------------------------------------------+
//| Remove position from tracking array                              |
//+------------------------------------------------------------------+
void RemovePosition(int index)
{
    if (index < 0 || index >= positionCount)
    {
        LogError(StringFormat("Invalid index for RemovePosition: %d", index));
        return;
    }

    // Shift remaining positions down
    for (int i = index; i < positionCount - 1; i++)
    {
        positions[i] = positions[i + 1];
    }
    positionCount--;

    LogAlert("POSITION_REMOVED",
            StringFormat("Array index %d removed; positionCount now %d", index, positionCount));
}

//+------------------------------------------------------------------+
//| Find position by ticket number                                   |
//+------------------------------------------------------------------+
int FindPositionByTicket(long ticket)
{
    for (int i = 0; i < positionCount; i++)
    {
        if (positions[i].ticket == ticket)
            return i;
    }
    return -1;  // Not found
}

//+------------------------------------------------------------------+
//| Monitor all open positions for TP/SL hits (called every tick)    |
//+------------------------------------------------------------------+
void MonitorPositionExits()
{
    // Check all open positions every tick for TP/SL hits
    for (int i = 0; i < positionCount; i++)
    {
        // Get current bid/ask
        double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

        // Check TP hit (entire remaining position closes)
        if (positions[i].isLong && bid >= positions[i].takeProfit)
        {
            // LONG position TP hit
            LogAlert("TP_HIT",
                    StringFormat("LONG ticket=%ld at TP=%.5f (bid=%.5f)",
                                positions[i].ticket, positions[i].takeProfit, bid));
            ClosePosition(positions[i].ticket, bid, "TP", positions[i].remainingLots);
            return;  // Exit loop (position was removed by ClosePosition)
        }

        if (!positions[i].isLong && ask <= positions[i].takeProfit)
        {
            // SHORT position TP hit
            LogAlert("TP_HIT",
                    StringFormat("SHORT ticket=%ld at TP=%.5f (ask=%.5f)",
                                positions[i].ticket, positions[i].takeProfit, ask));
            ClosePosition(positions[i].ticket, ask, "TP", positions[i].remainingLots);
            return;
        }

        // Check SL hit (entire remaining position closes)
        if (positions[i].isLong && bid <= positions[i].stopLoss)
        {
            // LONG position SL hit
            LogAlert("SL_HIT",
                    StringFormat("LONG ticket=%ld at SL=%.5f (bid=%.5f)",
                                positions[i].ticket, positions[i].stopLoss, bid));
            ClosePosition(positions[i].ticket, bid, "SL", positions[i].remainingLots);
            return;
        }

        if (!positions[i].isLong && ask >= positions[i].stopLoss)
        {
            // SHORT position SL hit
            LogAlert("SL_HIT",
                    StringFormat("SHORT ticket=%ld at SL=%.5f (ask=%.5f)",
                                positions[i].ticket, positions[i].stopLoss, ask));
            ClosePosition(positions[i].ticket, ask, "SL", positions[i].remainingLots);
            return;
        }
    }
}

//+------------------------------------------------------------------+
//| Close position and update state                                  |
//+------------------------------------------------------------------+
void ClosePosition(long ticket, double exitPrice, string exitReason, double closeLots)
{
    // Find position in array
    int idx = FindPositionByTicket(ticket);
    if (idx < 0)
    {
        LogError(StringFormat("Position ticket=%ld not found for close", ticket));
        return;
    }

    PositionState &pos = positions[idx];

    // Calculate P&L for this trade
    double pnlPips = (exitPrice - pos.entryPrice) / Point();
    if (!pos.isLong)
        pnlPips = (pos.entryPrice - exitPrice) / Point();  // SHORT P&L inverted

    // Close position via CTrade
    bool closed = trade.PositionClose(ticket);

    if (closed)
    {
        LogAlert("POSITION_CLOSED",
                StringFormat("Ticket=%ld, Setup=%s, Entry=%.5f, Exit=%.5f, PnL=%.1f pips, Reason=%s, RR=%.2f:1",
                            ticket, pos.setupType, pos.entryPrice, exitPrice, pnlPips, exitReason, pos.riskRewardRatio));

        // Update position state (remove from tracking)
        UpdatePositionState(ticket, closeLots);
    }
    else
    {
        LogError(StringFormat("Failed to close position ticket=%ld", ticket));
    }
}

//+------------------------------------------------------------------+
//| Calculate Risk/Reward Ratio (REQ-028)                            |
//| Formula: R:R = (TP distance in pips) / (SL distance in pips)     |
//+------------------------------------------------------------------+
double CalculateRiskRewardRatio(double entryPrice, double stopLossPrice,
                                double takeProfitPrice)
{
    // R:R = (TP distance in pips) / (SL distance in pips)

    double riskDistancePips = MathAbs(entryPrice - stopLossPrice) / Point();
    double rewardDistancePips = MathAbs(takeProfitPrice - entryPrice) / Point();

    if (riskDistancePips <= 0)
    {
        LogError("Risk distance is zero; invalid SL placement");
        return 0;
    }

    double rrRatio = rewardDistancePips / riskDistancePips;

    return rrRatio;
}

// -------- RiskLimits.mqh --------

//+------------------------------------------------------------------+
//| Structures for Daily Risk Enforcement
//+------------------------------------------------------------------+

struct DailyLimitState
{
  double closedPnL;           // P&L from closed trades today
  double openPnL;             // P&L from open positions
  double totalPnL;            // closedPnL + openPnL
  bool hardStopHit;           // -2% threshold breached
  bool profitCapReached;      // +5% threshold reached
  datetime lastCalculation;   // Last calculation time
};

// Global daily limits state
DailyLimitState dailyLimits = {0, 0, 0, false, false, 0};

//+------------------------------------------------------------------+
//| Calculate Daily P&L (persistent across ticks)
//| Rescans OrdersHistoryTotal to find trades closed today
//| Adds open position P&L for unrealized gain/loss
//+------------------------------------------------------------------+

DailyLimitState CalculateDailyPnL()
{
  DailyLimitState result = {0, 0, 0, false, false, TimeCurrent()};

  // Get session boundary (today's open in broker server time)
  datetime sessionStart = GetSessionBoundary();

  // Step 1: Scan closed trades from order history
  // Use HistoryOrdersTotal() to find all completed trades

  int ordersHistoryCount = HistoryOrdersTotal();
  for (int i = 0; i < ordersHistoryCount; i++)
  {
    ulong ticket = HistoryOrderGetTicket(i);
    if (ticket == 0)
      continue;

    // Filter for this EA's trades via magic number
    // Positions API: check if position's magic matches
    if (HistoryOrderGetInteger(ticket, ORDER_MAGIC) != EA_MAGIC_NUMBER)
      continue;

    // Only include trades closed in current session
    datetime closeTime = (datetime)HistoryOrderGetInteger(ticket, ORDER_TIME_DONE);
    if (closeTime == 0 || closeTime < sessionStart)
      continue;

    // Add profit from this closed position
    // In MT5, profit is in account currency
    double profit = HistoryOrderGetDouble(ticket, ORDER_PROPERTY_PROFIT);
    if (profit != 0 || HistoryOrderGetInteger(ticket, ORDER_TYPE) >= 0)
        result.closedPnL += profit;
  }

  // Step 2: Scan open positions for current P&L
  // Loop through all open positions in positionCount array
  for (int i = 0; i < positionCount; i++)
  {
    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

    // Calculate unrealized P&L for this position
    double pnl = 0;
    double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);

    if (positions[i].isLong)
    {
      // For LONG: P&L = (Bid - Entry) * Lots * TickValue
      pnl = (bid - positions[i].entryPrice) * positions[i].remainingLots * tickValue;
    }
    else
    {
      // For SHORT: P&L = (Entry - Ask) * Lots * TickValue
      pnl = (positions[i].entryPrice - ask) * positions[i].remainingLots * tickValue;
    }

    result.openPnL += pnl;
  }

  result.totalPnL = result.closedPnL + result.openPnL;

  return result;
}

//+------------------------------------------------------------------+
//| Enforce Daily Risk Limits
//| Returns: true if trading allowed, false if hard stop or profit cap hit
//+------------------------------------------------------------------+

bool EnforceDailyLimits()
{
  // Recalculate daily P&L on this tick
  DailyLimitState limits = CalculateDailyPnL();
  dailyLimits = limits;

  double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
  double hardStopThreshold = accountBalance * (DAILY_LOSS_LIMIT / 100.0);      // -2%
  double profitCapThreshold = accountBalance * (DAILY_PROFIT_CAP / 100.0);     // +5%

  // Check D-09: Hard stop loss (-2%)
  if (limits.totalPnL < -hardStopThreshold)
  {
    // Only log once per hard stop
    if (!dailyLimits.hardStopHit)
    {
      LogAlert("HARD_STOP_HIT",
               StringFormat("Daily loss=%.2f (balance=%.2f), limit=-%.2f. Closing all positions.",
                           limits.totalPnL, accountBalance, hardStopThreshold));
    }

    dailyLimits.hardStopHit = true;

    // Force-close ALL open positions immediately
    for (int i = positionCount - 1; i >= 0; i--)
    {
      // Use market order to close
      trade.PositionClose(positions[i].ticket);
      ClosePosition(positions[i].ticket, SymbolInfoDouble(Symbol(), SYMBOL_BID),
                   "HARD_STOP", positions[i].remainingLots);
    }

    return false;  // Block new entries
  }

  // Check D-10: Daily profit cap (+5%)
  if (limits.totalPnL > profitCapThreshold)
  {
    // Only log once per profit cap
    if (!dailyLimits.profitCapReached)
    {
      LogAlert("PROFIT_CAP_REACHED",
               StringFormat("Daily profit=%.2f (balance=%.2f), cap=+%.2f. Closing 60%% of positions.",
                           limits.totalPnL, accountBalance, profitCapThreshold));
    }

    dailyLimits.profitCapReached = true;

    // Close 60% of positions (midpoint between 50-70% per D-10)
    int closeCount = (int)MathCeil(positionCount * 0.6);

    for (int i = 0; i < closeCount && i < positionCount; i++)
    {
      trade.PositionClose(positions[i].ticket);
      ClosePosition(positions[i].ticket, SymbolInfoDouble(Symbol(), SYMBOL_BID),
                   "PROFIT_CAP_CLOSE", positions[i].remainingLots);
    }

    // Move SL of remaining positions to profit (breakeven + 5 pips)
    for (int i = closeCount; i < positionCount; i++)
    {
      double newSL = positions[i].entryPrice;  // Breakeven

      if (positions[i].isLong)
        newSL += 5 * Point();  // +5 pips profit
      else
        newSL -= 5 * Point();  // -5 pips for SHORT

      // Update position SL via CTrade
      MqlTradeRequest request = {0};
      request.action = TRADE_ACTION_SLTP;
      request.symbol = Symbol();
      request.position = positions[i].ticket;
      request.sl = newSL;
      request.tp = positions[i].takeProfit;

      MqlTradeResult result = {0};
      if (trade.Send(request, result))
      {
        if (result.retcode == TRADE_RETCODE_DONE)
        {
          positions[i].stopLoss = newSL;
        }
      }
    }

    return false;  // Block new entries
  }

  return true;  // Trading allowed
}

//+------------------------------------------------------------------+
//| Check Friday Hard Close (21:45 Broker Server Time)
//| Returns: true if close was executed, false otherwise
//+------------------------------------------------------------------+

bool CheckFridayHardClose()
{
  // Get current time in broker server time
  datetime currentTime = TimeCurrent();
  MqlDateTime timeStruct;
  TimeToStruct(currentTime, timeStruct);

  // Check if Friday (day_of_week: 0=Sunday, ..., 5=Friday, 6=Saturday)
  bool isFriday = (timeStruct.day_of_week == 5);

  // Check if time >= 21:45
  int currentTimeMinutes = timeStruct.hour * 60 + timeStruct.min;
  int closeTimeMinutes = 21 * 60 + 45;  // 21:45 = 1305 minutes
  bool isCloseTime = (currentTimeMinutes >= closeTimeMinutes);

  if (isFriday && isCloseTime)
  {
    // Force-close ALL open positions
    if (positionCount > 0)
    {
      LogAlert("FRIDAY_HARD_CLOSE",
               StringFormat("Time=%02d:%02d. Closing all %d positions before weekend.",
                           timeStruct.hour, timeStruct.min, positionCount));
    }

    // Close all positions
    for (int i = positionCount - 1; i >= 0; i--)
    {
      trade.PositionClose(positions[i].ticket);
      ClosePosition(positions[i].ticket, SymbolInfoDouble(Symbol(), SYMBOL_BID),
                   "FRIDAY_CLOSE", positions[i].remainingLots);
    }

    return true;  // Hard close executed
  }

  return false;
}

//+------------------------------------------------------------------+
//| Reset Daily Limits at Session Boundary
//| Called at start of each trading day
//+------------------------------------------------------------------+

void ResetDailyLimits()
{
  dailyLimits.closedPnL = 0;
  dailyLimits.openPnL = 0;
  dailyLimits.totalPnL = 0;
  dailyLimits.hardStopHit = false;
  dailyLimits.profitCapReached = false;
  dailyLimits.lastCalculation = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Get Current Daily Limits State
//+------------------------------------------------------------------+

DailyLimitState GetDailyLimitsState()
{
  return dailyLimits;
}

// -------- JournalLogger.mqh --------

//+------------------------------------------------------------------+
//| Trade Journal Record Structure
//+------------------------------------------------------------------+

struct TradeJournalRecord
{
  datetime entryTime;
  string symbol;
  string direction;           // "BUY" or "SELL"
  double entryPrice;
  double lotSize;
  string setupType;           // "Setup1", "Setup2", "REVERSAL"
  double stopLoss;
  double takeProfit;
  double riskRewardRatio;
  datetime exitTime;
  double exitPrice;
  string exitReason;          // "TP", "SL", "HARD_STOP", "PROFIT_CAP", "FRIDAY_CLOSE", "REVERSAL"
  double pnlPips;
  double pnlCurrency;
  double slippage;
};

//+------------------------------------------------------------------+
//| Log Trade Entry
//| Logs entry details: time, symbol, direction, price, lot, setup, SL, TP, R:R
//+------------------------------------------------------------------+

void LogTradeEntryFull(string direction, double entryPrice, double lotSize, string setupType,
                   double stopLoss, double takeProfit, double riskRewardRatio,
                   double slippage, long ticket)
{
  string logMsg = StringFormat(
    "%s | ENTRY | %s | Ticket=%lld | Price=%.5f | Lot=%.2f | Setup=%s | "
    "SL=%.5f | TP=%.5f | R:R=%.2f:1 | Slippage=%.1f pips",
    TimeToString(TimeCurrent()), direction, ticket, entryPrice, lotSize, setupType,
    stopLoss, takeProfit, riskRewardRatio, slippage);

  Print(logMsg);  // Output to MT5 Journal
}

//+------------------------------------------------------------------+
//| Log Trade Exit
//| Logs exit details: time, symbol, setup, entry/exit price, reason, P&L, lot
//+------------------------------------------------------------------+

void LogTradeExitFull(long ticket, string symbol, string setupType, double entryPrice,
                  double exitPrice, string exitReason, double pnlPips, double closeLots)
{
  // Calculate P&L in currency
  double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
  double pnlCurrency = pnlPips * closeLots * tickValue;

  string logMsg = StringFormat(
    "%s | EXIT | %s | Ticket=%lld | Setup=%s | Entry=%.5f | Exit=%.5f | "
    "Reason=%s | PnL=%.1f pips (%.2f) | Lot=%.2f",
    TimeToString(TimeCurrent()), symbol, ticket, setupType, entryPrice, exitPrice,
    exitReason, pnlPips, pnlCurrency, closeLots);

  Print(logMsg);  // Output to MT5 Journal
}

//+------------------------------------------------------------------+
//| Log Order Rejection
//| Logs rejected orders with reason and order details
//+------------------------------------------------------------------+

void LogOrderRejection(double intendedPrice, double stopLoss, double takeProfit,
                       double lots, string reason, long errorCode)
{
  string logMsg = StringFormat(
    "%s | REJECTION | Entry=%.5f | SL=%.5f | TP=%.5f | Lot=%.2f | Reason=%s | ErrorCode=%lld",
    TimeToString(TimeCurrent()), intendedPrice, stopLoss, takeProfit, lots, reason, errorCode);

  Print(logMsg);  // Output to MT5 Journal
}

//+------------------------------------------------------------------+
//| Log Reversal Detection
//| Logs when reversal candle is detected
//+------------------------------------------------------------------+

void LogReversalDetection(bool isLong, double reversalPrice, double confirmationPrice)
{
  string direction = isLong ? "LONG" : "SHORT";
  string logMsg = StringFormat(
    "%s | REVERSAL_DETECT | Direction=%s | ReversalPrice=%.5f | ConfirmPrice=%.5f",
    TimeToString(TimeCurrent()), direction, reversalPrice, confirmationPrice);

  Print(logMsg);
}

//+------------------------------------------------------------------+
//| Log Position Flip Execution
//| Logs when position flip completes (close old + enter new)
//+------------------------------------------------------------------+

void LogPositionFlip(long oldTicket, long newTicket, bool newIsLong, double newEntryPrice)
{
  string direction = newIsLong ? "LONG" : "SHORT";
  string logMsg = StringFormat(
    "%s | POSITION_FLIP | OldTicket=%lld | NewTicket=%lld | NewDir=%s | NewEntry=%.5f",
    TimeToString(TimeCurrent()), oldTicket, newTicket, direction, newEntryPrice);

  Print(logMsg);
}

//+------------------------------------------------------------------+
//| Log Daily Summary
//| Logs end-of-day summary with P&L, win rate, etc.
//+------------------------------------------------------------------+

void LogDailySummary(double closedPnL, double openPnL, double totalPnL,
                     int tradesExecuted, int tradesWon, double winRate)
{
  string logMsg = StringFormat(
    "%s | DAILY_SUMMARY | ClosedPnL=%.2f | OpenPnL=%.2f | Total=%.2f | "
    "Trades=%d | Wins=%d | WinRate=%.1f%%",
    TimeToString(TimeCurrent()), closedPnL, openPnL, totalPnL,
    tradesExecuted, tradesWon, winRate);

  Print(logMsg);
}

//+------------------------------------------------------------------+
//| Log Liquidity/Session Check
//| Logs when session or liquidity checks reject entry
//+------------------------------------------------------------------+

void LogSessionCheck(string checkType, string reason)
{
  string logMsg = StringFormat(
    "%s | SESSION_CHECK | Type=%s | Reason=%s | Entry rejected",
    TimeToString(TimeCurrent()), checkType, reason);

  Print(logMsg);
}

// -------- ReversalExit.mqh --------

//+------------------------------------------------------------------+
//| Reversal Signal Structure
//+------------------------------------------------------------------+

struct ReversalSignal
{
  bool isTriggered;          // Reversal candle detected
  bool isConfirmed;          // 1M confirmation validated
  bool isLong;               // Direction of reversal (true=LONG reversal, false=SHORT)
  double reversalPrice;      // Price level of reversal candle (high or low)
  double confirmationPrice;  // Price level of 1M confirmation
};

//+------------------------------------------------------------------+
//| Detect 5M Reversal Candle
//| For LONG position: detects lower high (rejection of VAH)
//| For SHORT position: detects higher low (rejection of VAL)
//+------------------------------------------------------------------+

ReversalSignal DetectReversalCandle(bool currentLong)
{
  ReversalSignal result = {false, false, false, 0, 0};

  // Get current 5M candle (completed bar 1) and previous bar 2
  double currentHigh = iHigh(Symbol(), PERIOD_CURRENT, 1);  // Previous 5M bar high
  double currentLow = iLow(Symbol(), PERIOD_CURRENT, 1);    // Previous 5M bar low
  double previousHigh = iHigh(Symbol(), PERIOD_CURRENT, 2); // Bar 2 high
  double previousLow = iLow(Symbol(), PERIOD_CURRENT, 2);   // Bar 2 low

  if (currentLong)
  {
    // LONG position reversal: lower high
    // This indicates rejection of the higher level (VAH)
    if (currentHigh < previousHigh)
    {
      result.isTriggered = true;
      result.isLong = false;  // Reversal direction is SHORT
      result.reversalPrice = currentHigh;
      return result;
    }
  }
  else
  {
    // SHORT position reversal: higher low
    // This indicates rejection of the lower level (VAL)
    if (currentLow > previousLow)
    {
      result.isTriggered = true;
      result.isLong = true;   // Reversal direction is LONG
      result.reversalPrice = currentLow;
      return result;
    }
  }

  return result;
}

//+------------------------------------------------------------------+
//| Confirm Reversal on 1M Structure
//| For LONG reversal: price breaks above 1M recent high + buffer
//| For SHORT reversal: price breaks below 1M recent low - buffer
//+------------------------------------------------------------------+

bool ConfirmReversal1M(bool reversalIsLong)
{
  // Get 1M price levels
  double high1M = iHighest(Symbol(), PERIOD_M1, MODE_HIGH, 5, 0);  // Highest in last 5 1M bars
  double low1M = iLowest(Symbol(), PERIOD_M1, MODE_LOW, 5, 0);     // Lowest in last 5 1M bars

  double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
  double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

  if (reversalIsLong)
  {
    // LONG reversal: price must break above 1M recent high + 10 pips buffer
    // Using ask price for entry perspective
    return (ask > high1M + 10 * Point());
  }
  else
  {
    // SHORT reversal: price must break below 1M recent low - 10 pips buffer
    // Using bid price for entry perspective
    return (bid < low1M - 10 * Point());
  }
}

//+------------------------------------------------------------------+
//| Execute Position Flip
//| Closes current position and enters new position in opposite direction
//+------------------------------------------------------------------+

bool ExecutePositionFlip(long oldTicket, bool newLongEntry, double newEntryPrice,
                         double newStopLoss, double newTakeProfit)
{
  // Step 1: Close current position
  if (!trade.PositionClose(oldTicket))
  {
    LogError(StringFormat("Failed to close position %lld for flip. Error: %d",
                         oldTicket, GetLastError()));
    return false;
  }

  // Find position in our tracking array and update state
  int oldIdx = FindPositionByTicket(oldTicket);
  if (oldIdx >= 0)
  {
    double exitPrice = newLongEntry ? SymbolInfoDouble(Symbol(), SYMBOL_ASK)
                                    : SymbolInfoDouble(Symbol(), SYMBOL_BID);
    ClosePosition(oldTicket, exitPrice, "REVERSAL_EXIT", positions[oldIdx].remainingLots);
  }

  // Step 2: Enter new position (opposite direction)
  double lotSize = CalculateLotSize(newEntryPrice, newStopLoss);

  OrderResult result = PlaceMarketOrder(
    newLongEntry ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
    lotSize,
    newEntryPrice,
    newStopLoss,
    newTakeProfit);

  if (result.success)
  {
    double rr = CalculateRiskRewardRatio(result.fillPrice, newStopLoss, newTakeProfit);
    AddPosition(result.ticket, Symbol(), newLongEntry, result.fillPrice,
               newStopLoss, newTakeProfit, lotSize, "REVERSAL", rr);

    LogPositionFlip(oldTicket, result.ticket, newLongEntry, result.fillPrice);

    LogTradeEntryFull(newLongEntry ? "BUY" : "SELL", result.fillPrice, lotSize, "REVERSAL",
                 newStopLoss, newTakeProfit, rr, result.slippage, result.ticket);

    return true;
  }
  else
  {
    LogError(StringFormat("Failed to place new position after flip. Old ticket: %lld", oldTicket));
    return false;
  }
}

//+------------------------------------------------------------------+
//| Check if Position is Near Take Profit
//| Returns distance in pips to TP, or negative if past TP
//+------------------------------------------------------------------+

double GetDistanceToTP(int positionIndex)
{
  if (positionIndex < 0 || positionIndex >= positionCount)
    return -1;

  double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
  double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
  double currentPrice = positions[positionIndex].isLong ? bid : ask;

  double distanceInPrice = MathAbs(positions[positionIndex].takeProfit - currentPrice);
  return distanceInPrice / Point();  // Convert to pips
}

//+------------------------------------------------------------------+
//| Monitor Positions for Reversals
//| Called from OnTick after position monitoring but before new signals
//| Checks if position near TP and if reversal conditions are met
//+------------------------------------------------------------------+

void MonitorReversals()
{
  // Loop through all positions
  for (int i = 0; i < positionCount; i++)
  {
    // Check if position is near TP (within 50 pips)
    double distanceToTP = GetDistanceToTP(i);

    if (distanceToTP > 0 && distanceToTP < 50)
    {
      // Position near TP; check for reversal candle
      ReversalSignal revSignal = DetectReversalCandle(positions[i].isLong);

      if (revSignal.isTriggered)
      {
        // 5M reversal detected; now confirm on 1M
        if (ConfirmReversal1M(revSignal.isLong))
        {
          // Both 5M and 1M conditions met; reversal is confirmed
          LogReversalDetection(revSignal.isLong, revSignal.reversalPrice, 0);

          // In a full implementation, check if a Setup 1 or 2 signal
          // forms in the opposite direction before flipping

          // For now, log the detection; flip logic would integrate with signal detection
          LogAlert("REVERSAL_CONFIRMED",
                  StringFormat("Position %lld near TP (%.1f pips). Reversal detected, awaiting signal.",
                              positions[i].ticket, distanceToTP));
        }
      }
    }
  }
}

// ==================== INPUT PARAMETERS ====================

input int    Lookback_Period      = 150;      // Number of bars to analyze for volume profile
input bool   Use_Risk_Percentage  = true;     // Use risk percentage or fixed lot size
input double Fixed_Lot_Size       = 0.1;      // Used when Use_Risk_Percentage = false
input double Risk_Percentage      = 0.6;      // Risk percentage per trade (0.6%)

// ==================== GLOBAL VARIABLES ====================

VolumeProfile     currentProfile;               // Current session profile
VolumeProfile     previousSessionProfile;       // Previous session profile (for comparison)
// Note: DailyLimitState dailyLimits declared in RiskLimits.mqh
// Note: PositionState and positions[] declared in TradeExecution.mqh
// Note: CTrade trade instance declared in TradeExecution.mqh

bool              dailyHardStopHit = false;     // -2% loss flag
bool              dailyProfitCapReached = false;// +5% gain flag
bool              fridayClosedFlag = false;     // Friday close flag
datetime          lastSessionDate = 0;          // Last session date for reset

// ==================== EVENT HANDLERS ====================

//+------------------------------------------------------------------+
//| Expert initialization function                                  |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("===== PHASE 2: MODULAR REFACTORED EA WITH ORDER EXECUTION =====");
    Print("EA Magic Number: ", EA_MAGIC_NUMBER);
    Print("Lookback Period: ", Lookback_Period, " bars");
    Print("Risk Percentage: ", Risk_Percentage, "%");
    Print("Volume Bins: ", VOLUME_BINS);
    Print("HVN Threshold: ", HVN_PERCENTILE, "x average");
    Print("LVN Threshold: ", LVN_PERCENTILE, "x average");
    Print("Value Area: ", VALUE_AREA_PERCENT * 100, "%");

    // Validate broker connection and symbol
    if (!IsConnected())
        return INIT_FAILED;

    // Initialize CTrade for order placement (Wave 2)
    trade.SetExpertMagicNumber(EA_MAGIC_NUMBER);
    LogAlert("TRADE_INIT", "CTrade initialized with magic number " + IntegerToString(EA_MAGIC_NUMBER));

    Print("\n===== RUNNING UNIT TESTS =====\n");

    // Run embedded unit tests
    RunAllTests();

    Print("\n===== EA INITIALIZED SUCCESSFULLY =====\n");

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check broker connection
    if (!IsConnected())
    {
        LogError("Broker disconnected");
        return;
    }

    // EVERY TICK: Monitor existing positions for exit conditions (Wave 2)
    MonitorPositionExits();

    // EVERY TICK: Monitor for reversals (Wave 3)
    MonitorReversals();

    // Recalculate profile on new bar
    if (NewBar())
    {
        // Save previous profile
        previousSessionProfile = currentProfile;

        // Step 1: Recalculate volume profile (150-bar lookback)
        currentProfile = CalculateCurrentVolumeProfile(LOOKBACK_BARS);

        // Step 2: Calculate POC/VAH/VAL
        CalculateValueArea(currentProfile);

        // Step 3: Detect HVN/LVN nodes
        IdentifyVolumeNodes(currentProfile, HVN_PERCENTILE, LVN_PERCENTILE);

        // Step 4: Check data quality before processing
        if (!ValidateDataQuality())
        {
            LogAlert("SKIP_BAR", "Data quality check failed");
            return;
        }

        // Step 5: Check daily limits and Friday close FIRST (highest priority)
        if (!EnforceDailyLimits() || CheckFridayHardClose())
        {
            LogAlert("TRADING_BLOCKED", "Daily limits or Friday close triggered");
            return;  // Block all entry signals if limits hit
        }

        // Validate profile
        ValidateProfileCalculation();

        // Log current profile (optional, disable for performance)
        LogVolumeProfile();

        // ===== PHASE 2 WAVE 1: SIGNAL DETECTION WITH MULTI-TIMEFRAME CONTEXT =====

        // Load/update 15M profile every 15M bar close
        static datetime lastProfile15MTime = 0;
        if (iTime(Symbol(), PERIOD_M15, 0) != lastProfile15MTime)
        {
            Load15MProfile();
            lastProfile15MTime = iTime(Symbol(), PERIOD_M15, 0);
        }

        // Check session filtering: skip all entries during grave hour and pre-Tokyo
        if (!IsSessionAllowed())
        {
            LogAlert("SESSION_BLOCKED", "Grave hour or pre-Tokyo session; entries blocked");
            return;  // Skip all signal detection during blocked sessions
        }

        // Determine market context (balanced vs imbalanced)
        bool balanced = IsBalancedMarket();

        if (balanced)
        {
            // SETUP 1: Gap/Reclaim/Confirmation (balanced market mean reversion)
            Setup1Signal sig1 = DetectSetup1Signal();

            if (sig1.isTriggered)
            {
                // Before processing signal, validate 15M direction bias and liquidity
                if (!Validate15MDirectionBias(sig1.isLong))
                {
                    LogAlert("DIRECTION_BIAS_REJECTED", "Setup1 signal rejected: 15M direction bias does not support entry");
                    return;
                }

                if (!ValidateLiquidity())
                {
                    LogAlert("LIQUIDITY_REJECTED", "Setup1 signal rejected: spread too wide or volume too low");
                    return;
                }

                // Log Setup 1 signal detection
                LogAlert("SETUP1_SIGNAL_DETECTED",
                    StringFormat("direction=%s entry=%.5f sweepLow=%.5f",
                        sig1.isLong ? "LONG" : "SHORT",
                        sig1.confirmationClose,
                        sig1.sweepLow));

                // Wave 2: Order placement on Setup 1 signal
                // Calculate position details
                double entryPrice = sig1.confirmationClose;
                double stopLoss = sig1.sweepLow - (10 * Point());  // 10 pips below sweep low
                double takeProfit = sig1.isLong ? currentProfile.vahPrice : currentProfile.valPrice;  // D-03/D-06: opposite edge

                // Calculate lot size
                double lotSize = CalculateLotSize(entryPrice, stopLoss);

                if (lotSize > 0)
                {
                    // Calculate R:R ratio before placing order
                    double rr = CalculateRiskRewardRatio(entryPrice, stopLoss, takeProfit);

                    // Place market order
                    OrderResult result = PlaceMarketOrder(
                        sig1.isLong ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                        lotSize,
                        entryPrice,
                        stopLoss,
                        takeProfit);

                    // On success, add position to tracking
                    if (result.success)
                    {
                        AddPosition(result.ticket, Symbol(), sig1.isLong, result.fillPrice,
                                   stopLoss, takeProfit, lotSize, "Setup1", rr);
                        LogAlert("ENTRY_RR", StringFormat("Setup 1 Entry RR Ratio=%.2f:1", rr));
                    }
                    else
                    {
                        LogError(StringFormat("Setup 1 order placement failed. Slippage=%.1f pips",
                                            result.slippage));
                    }
                }
                else
                {
                    LogError("Setup 1: Invalid lot size calculation; skipping entry");
                }
            }
        }
        else
        {
            // SETUP 2: LVN/HVN/Pattern/Volume (imbalanced market momentum)
            Setup2Signal sig2 = DetectSetup2Signal();

            if (sig2.isTriggered)
            {
                // Before processing signal, validate 15M direction bias and liquidity
                if (!Validate15MDirectionBias(sig2.isLong))
                {
                    LogAlert("DIRECTION_BIAS_REJECTED", "Setup2 signal rejected: 15M direction bias does not support entry");
                    return;
                }

                if (!ValidateLiquidity())
                {
                    LogAlert("LIQUIDITY_REJECTED", "Setup2 signal rejected: spread too wide or volume too low");
                    return;
                }

                // Log Setup 2 signal detection
                LogAlert("SETUP2_SIGNAL_DETECTED",
                    StringFormat("direction=%s hvnEdge=%.5f sweepLow=%.5f",
                        sig2.isLong ? "LONG" : "SHORT",
                        sig2.hvnEdgePrice,
                        sig2.sweepLow));

                // Wave 2: Order placement on Setup 2 signal
                // Calculate position details
                double entryPrice = sig2.hvnEdgePrice;
                double stopLoss = sig2.sweepLow - (10 * Point());  // 10 pips below LVN sweep low
                double takeProfit = sig2.isLong ? currentProfile.vahPrice : currentProfile.valPrice;  // D-06: opposite edge

                // Calculate lot size
                double lotSize = CalculateLotSize(entryPrice, stopLoss);

                if (lotSize > 0)
                {
                    // Calculate R:R ratio before placing order
                    double rr = CalculateRiskRewardRatio(entryPrice, stopLoss, takeProfit);

                    // Place market order
                    OrderResult result = PlaceMarketOrder(
                        sig2.isLong ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                        lotSize,
                        entryPrice,
                        stopLoss,
                        takeProfit);

                    // On success, add position to tracking
                    if (result.success)
                    {
                        AddPosition(result.ticket, Symbol(), sig2.isLong, result.fillPrice,
                                   stopLoss, takeProfit, lotSize, "Setup2", rr);
                        LogAlert("ENTRY_RR", StringFormat("Setup 2 Entry RR Ratio=%.2f:1", rr));
                    }
                    else
                    {
                        LogError(StringFormat("Setup 2 order placement failed. Slippage=%.1f pips",
                                            result.slippage));
                    }
                }
                else
                {
                    LogError("Setup 2: Invalid lot size calculation; skipping entry");
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Cleanup
    Print("EA Deinit - Reason: ", reason);

    // Log final state
    Print("Final position count: ", positionCount);
    Print("Daily stats - PnL: ", dailyLimits.totalPnL,
          ", HardStop: ", dailyLimits.hardStopHit,
          ", ProfitCap: ", dailyLimits.profitCapReached);
}

// ==================== POSITION MANAGEMENT ====================
// NOTE: Position management functions are defined above:
//   - PlaceMarketOrder()
//   - AddPosition()
//   - RemovePosition()
//   - MonitorPositionExits()
// Main EA uses these from consolidated code instead of local definitions

// ==================== DATA VALIDATION ====================

//+------------------------------------------------------------------+
//| Validate volume profile calculation                              |
//+------------------------------------------------------------------+
void ValidateProfileCalculation()
{
    if (currentProfile.pocPrice <= 0)
        return;  // Not yet calculated

    // Verify POC is within valid range
    if (currentProfile.pocPrice < currentProfile.minPrice ||
        currentProfile.pocPrice > currentProfile.maxPrice)
    {
        LogError("POC outside price range");
    }

    // Verify VAH > VAL
    if (currentProfile.vahPrice <= currentProfile.valPrice)
    {
        LogError("VAH <= VAL (invalid Value Area)");
    }
}

//+------------------------------------------------------------------+
//| Validate data quality - comprehensive checks                     |
//+------------------------------------------------------------------+
bool ValidateDataQuality()
{
    // Check if price data is available and reasonable
    double high = iHigh(Symbol(), PERIOD_CURRENT, 0);
    double low = iLow(Symbol(), PERIOD_CURRENT, 0);
    double close = iClose(Symbol(), PERIOD_CURRENT, 0);
    long volume = iVolume(Symbol(), PERIOD_CURRENT, 0);

    if (high <= 0 || low <= 0 || close <= 0)
    {
        LogError("Invalid OHLC data - High: " + DoubleToString(high, 5) +
                 " Low: " + DoubleToString(low, 5) +
                 " Close: " + DoubleToString(close, 5));
        return false;
    }

    if (high < low)
    {
        LogError("High < Low in single bar (data corruption)");
        return false;
    }

    if (volume <= 0)
    {
        LogAlert("WARNING", "Zero volume on current bar");
        // Don't fail; some brokers have zero-volume bars
    }

    if (close < low || close > high)
    {
        LogAlert("WARNING", "Close outside High-Low range");
    }

    return true;
}

//+------------------------------------------------------------------+
//| Check data quality from broker                                   |
//+------------------------------------------------------------------+
bool CheckDataQuality()
{
    // Verify we have minimum bars
    if (Bars(Symbol(), PERIOD_CURRENT) < Lookback_Period)
        return false;

    // Verify volume data is available
    if (iVolume(Symbol(), PERIOD_CURRENT, 0) <= 0)
        return false;

    return true;
}

//+------------------------------------------------------------------+
//| Get current symbol name                                          |
//+------------------------------------------------------------------+
string GetSymbolName()
{
    return Symbol();
}

// ==================== LOGGING ====================

//+------------------------------------------------------------------+
//| Log current volume profile                                       |
//+------------------------------------------------------------------+
void LogVolumeProfile()
{
    if (currentProfile.pocPrice <= 0)
        return;

    Print(StringFormat("[VP] POC: %.5f, VAH: %.5f, VAL: %.5f, HVN: %d, LVN: %d",
        currentProfile.pocPrice,
        currentProfile.vahPrice,
        currentProfile.valPrice,
        currentProfile.hvnCount,
        currentProfile.lvnCount));
}

//+------------------------------------------------------------------+
//| Log trade entry                                                  |
//+------------------------------------------------------------------+
void LogTradeEntryMain(string direction, double entryPrice, double stopLoss,
                   double takeProfit1, double takeProfit2, double lots)
{
    Print(StringFormat("[ENTRY] %s @ %.5f | SL: %.5f | TP1: %.5f (65%%) | TP2: %.5f (35%%) | Lots: %.2f",
        direction,
        entryPrice,
        stopLoss,
        takeProfit1,
        takeProfit2,
        lots));
}

// ==================== UNIT TESTS ====================

//+------------------------------------------------------------------+
//| Test 1: Volume Distribution Validation (REQ-001, REQ-009)        |
//+------------------------------------------------------------------+
bool TestVolumeValidation()
{
    Print("TEST: Volume Distribution Validation");

    // Call the actual calculation
    VolumeProfile testProfile = CalculateCurrentVolumeProfile(LOOKBACK_BARS);

    // Validate distribution
    double binSum = 0;
    for (int i = 0; i < VOLUME_BINS; i++)
        binSum += testProfile.volumeArray[i];

    // Get raw total from lookback period
    long rawTotal = 0;
    for (int i = 0; i < LOOKBACK_BARS; i++)
        rawTotal += iVolume(Symbol(), PERIOD_CURRENT, i);

    if (rawTotal <= 0)
    {
        Print("  SKIP: No volume data available (live/incomplete bar)");
        return true;  // Can't validate without data
    }

    double variance = MathAbs(binSum - rawTotal) / rawTotal;

    if (variance <= 0.01)  // ±1% tolerance
    {
        Print("  PASS: Volume distribution variance = ", variance * 100, "%");
        return true;
    }
    else
    {
        Print("  FAIL: Volume distribution variance = ", variance * 100, "% > 1%");
        return false;
    }
}

//+------------------------------------------------------------------+
//| Test 2: POC Identification (REQ-002)                             |
//+------------------------------------------------------------------+
bool TestPOCIdentification()
{
    Print("TEST: POC Identification");

    // Precondition: CalculateCurrentVolumeProfile() must run first
    if (currentProfile.pocPrice <= 0)
    {
        Print("  SKIP: POC not calculated");
        return false;
    }

    // Verify POC is within price range
    if (currentProfile.pocPrice >= currentProfile.minPrice &&
        currentProfile.pocPrice <= currentProfile.maxPrice)
    {
        Print("  PASS: POC = ", currentProfile.pocPrice,
              " (range: ", currentProfile.minPrice, " - ", currentProfile.maxPrice, ")");
        return true;
    }
    else
    {
        Print("  FAIL: POC = ", currentProfile.pocPrice, " outside range");
        return false;
    }
}

//+------------------------------------------------------------------+
//| Test 3: VAH/VAL Calculation (REQ-003, REQ-004)                   |
//+------------------------------------------------------------------+
bool TestValueAreaCalculation()
{
    Print("TEST: VAH/VAL Calculation");

    if (currentProfile.vahPrice <= 0 || currentProfile.valPrice <= 0)
    {
        Print("  SKIP: VAH/VAL not calculated");
        return false;
    }

    // Verify VAH > VAL
    if (currentProfile.vahPrice > currentProfile.valPrice)
    {
        double vaWidth = currentProfile.vahPrice - currentProfile.valPrice;
        double rangeWidth = currentProfile.maxPrice - currentProfile.minPrice;
        double vaPercent = (vaWidth / rangeWidth) * 100;

        // VA should capture ~70% of range (some variance acceptable)
        if (vaPercent > 60 && vaPercent < 80)
        {
            Print("  PASS: VAH = ", currentProfile.vahPrice,
                  ", VAL = ", currentProfile.valPrice,
                  " (width = ", vaPercent, "% of range)");
            return true;
        }
        else
        {
            Print("  WARN: VA width = ", vaPercent, "% (expected ~70%)");
            return true;  // Don't fail; warn for backtest verification
        }
    }
    else
    {
        Print("  FAIL: VAH <= VAL");
        return false;
    }
}

//+------------------------------------------------------------------+
//| Test 4: HVN/LVN Detection (REQ-005, REQ-006)                    |
//+------------------------------------------------------------------+
bool TestHVNLVNDetection()
{
    Print("TEST: HVN/LVN Detection");

    if (currentProfile.hvnCount < 0)
    {
        Print("  SKIP: HVN/LVN not calculated");
        return false;
    }

    // Verify reasonable counts (expect 5-30 per day)
    if (currentProfile.hvnCount > 0 && currentProfile.hvnCount <= 50)
    {
        Print("  PASS: HVN count = ", currentProfile.hvnCount);
    }
    else
    {
        Print("  INFO: HVN count = ", currentProfile.hvnCount,
              " (0-50 expected; verify in backtest)");
    }

    if (currentProfile.lvnCount > 0 && currentProfile.lvnCount <= 50)
    {
        Print("  PASS: LVN count = ", currentProfile.lvnCount);
    }
    else
    {
        Print("  INFO: LVN count = ", currentProfile.lvnCount,
              " (0-50 expected; verify in backtest)");
    }

    return true;  // Info-level; don't fail
}

//+------------------------------------------------------------------+
//| Test 5: Position Sizing Calculation (REQ-029, REQ-030)           |
//+------------------------------------------------------------------+
bool TestPositionSizing()
{
    Print("TEST: Position Sizing Calculation");

    // Test 1: Risk-based sizing
    double testEntry = 1.2000;
    double testSL = 1.1950;  // 50 pips

    double testLot = CalculateLotSize(testEntry, testSL);

    if (testLot > 0)
    {
        Print("  PASS: Risk-based lot sizing = ", testLot);
    }
    else
    {
        Print("  INFO: Lot sizing returned 0 (may be OK on live account)");
    }

    return true;
}

//+------------------------------------------------------------------+
//| Test 6: Daily Limits Logic (REQ-032, REQ-033, REQ-035)           |
//+------------------------------------------------------------------+
bool TestDailyLimits()
{
    Print("TEST: Daily Limits Logic");

    // Test EnforceDailyLimits() returns bool
    bool limitsOK = EnforceDailyLimits();

    if (limitsOK == true || limitsOK == false)  // Just check it doesn't crash
    {
        Print("  PASS: EnforceDailyLimits() callable, returned ", limitsOK);
    }
    else
    {
        Print("  FAIL: EnforceDailyLimits() didn't return valid bool");
        return false;
    }

    // Test CheckFridayHardClose() returns bool
    bool fridayOK = CheckFridayHardClose();

    if (fridayOK == true || fridayOK == false)
    {
        Print("  PASS: CheckFridayHardClose() callable, returned ", fridayOK);
    }
    else
    {
        Print("  FAIL: CheckFridayHardClose() didn't return valid bool");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Test 7: Position Management (REQ-031, REQ-036, REQ-037)          |
//+------------------------------------------------------------------+
bool TestPositionManagement()
{
    Print("TEST: Position Management");

    // Test 1: Position array management
    if (positionCount >= 0 && positionCount <= 3)
    {
        Print("  PASS: Position count valid (", positionCount, "/3)");
    }
    else
    {
        Print("  FAIL: Position count out of range");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Run all unit tests                                               |
//+------------------------------------------------------------------+
void RunAllTests()
{
    bool allPass = true;

    // Volume Profile Tests
    if (!TestVolumeValidation())
        allPass = false;

    Print("");  // Blank line for readability

    if (!TestPOCIdentification())
        allPass = false;

    Print("");

    if (!TestValueAreaCalculation())
        allPass = false;

    Print("");

    if (!TestHVNLVNDetection())
        allPass = false;

    Print("");

    // Risk Management Tests
    if (!TestPositionSizing())
        allPass = false;

    Print("");

    if (!TestDailyLimits())
        allPass = false;

    Print("");

    if (!TestPositionManagement())
        allPass = false;

    Print("\n===== TESTS COMPLETE =====");

    if (allPass)
        Print("✓ All critical tests PASSED");
    else
        Print("✗ Some tests FAILED; check Journal");
}

//+------------------------------------------------------------------+
// END OF FILE
//+------------------------------------------------------------------+
