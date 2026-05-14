//+------------------------------------------------------------------+
//|                      SignalDetection.mqh                         |
//|              Setup 1 & 2 Signal Detection Logic                   |
//|                      Phase 2, Wave 1                              |
//|                                                                  |
//| Description:                                                     |
//|   Implements balanced/imbalanced market detection via Value Area |
//|   width ratio. Detects Setup 1 signals (gap/reclaim/confirmation)|
//|   for balanced markets. Detects Setup 2 signals (LVN sweep/HVN   |
//|   edge/pattern/volume) for imbalanced markets.                   |
//|   Provides candle pattern recognition (Hammer/Shooting Star/Doji)|
//|                                                                  |
//| Exported Functions:                                              |
//|   - bool IsBalancedMarket()                                      |
//|   - Setup1Signal DetectSetup1Signal()                            |
//|   - Setup2Signal DetectSetup2Signal()                            |
//|   - CandlePattern DetectCandlePattern()                          |
//|                                                                  |
//| Exported Structures:                                             |
//|   - struct Setup1Signal                                          |
//|   - struct Setup2Signal                                          |
//|   - struct CandlePattern                                         |
//|                                                                  |
//+------------------------------------------------------------------+

#ifndef __SIGNAL_DETECTION_MQH__
#define __SIGNAL_DETECTION_MQH__

// ==================== STRUCTURES ====================

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

// ==================== BALANCED MARKET DETECTION ====================

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

// ==================== SETUP 1: GAP/RECLAIM/CONFIRMATION ====================

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

// ==================== SETUP 2: LVN/HVN/PATTERN/VOLUME ====================

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
    else if (bodySize <= 1 * Point && lowerWick > 0 && upperWick > 0)
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

#endif // __SIGNAL_DETECTION_MQH__
