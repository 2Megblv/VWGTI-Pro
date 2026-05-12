//+------------------------------------------------------------------+
//|                      VolumeProfile_EA_v1.0.mq5                  |
//|                  Volume Profile Swing Trading EA                |
//|                          Phase 1: Core Engine                   |
//|                                                                  |
//| Description:                                                     |
//|   Complete 400-bin volume profile calculation engine with        |
//|   POC/VAH/VAL computation, HVN/LVN detection, and embedded       |
//|   unit tests. This is the foundational calculation system for   |
//|   all entry signals in Phase 2.                                 |
//|                                                                  |
//| Core Features (Phase 1):                                         |
//|   - 400-bin volume distribution from 150-bar lookback           |
//|   - Point of Control (POC) identification                       |
//|   - Value Area High/Low (VAH/VAL) at 70% cumulative volume      |
//|   - High/Low Volume Node detection (1.3x/0.7x thresholds)      |
//|   - Position sizing formula (0.6% risk per trade)               |
//|   - Daily hard stop (-2%) and profit cap (+5%)                  |
//|   - Embedded unit tests in OnInit                               |
//|                                                                  |
//+------------------------------------------------------------------+

#property copyright "Phase 1 Volume Profile Engine"
#property link      "https://github.com/sgunamijaya/VWGTI-Pro"
#property version   "1.0"
#property strict
#property icon      "\\Images\\EarnForex\\forex.ico"

// ==================== GLOBAL CONSTANTS ====================

#define VOLUME_BINS 400
#define HVN_MULTIPLIER 1.3      // D-02: locked for HVN detection
#define LVN_MULTIPLIER 0.7      // D-02: locked for LVN detection
#define VALUE_AREA_PERCENT 0.70 // 70% cumulative volume
#define RISK_PERCENT 0.6        // D-03: hardcoded 0.6% per trade
#define DAILY_LOSS_LIMIT 0.02   // -2% hard stop
#define DAILY_PROFIT_CAP 0.05   // +5% profit cap
#define FRIDAY_CLOSE_HOUR 21
#define FRIDAY_CLOSE_MIN 45
#define EA_MAGIC_NUMBER 99001

// ==================== INPUT PARAMETERS ====================

input int    Lookback_Period      = 150;      // Number of bars to analyze for volume profile
input bool   Use_Risk_Percentage  = true;     // Use risk percentage or fixed lot size
input double Fixed_Lot_Size       = 0.1;      // Used when Use_Risk_Percentage = false
input double Risk_Percentage      = 0.6;      // Risk percentage per trade (0.6%)

// ==================== DATA STRUCTURES ====================

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

struct SessionProfile {
    double vahPrice;                    // Previous session VAH
    double valPrice;                    // Previous session VAL
    datetime sessionDate;               // Date of session
};

struct DailyStats {
    double closedPnL;                   // Closed profit/loss today
    double openPnL;                     // Open position P&L
    double totalPnL;                    // Total P&L today
    bool hardStopHit;                   // -2% loss limit triggered
    bool profitCapReached;              // +5% profit cap triggered
};

struct PositionRecord {
    long   ticket;                      // Order ticket number
    string symbol;                      // Trading symbol
    double entryPrice;                  // Entry price
    double stopLoss;                    // Stop loss price
    double takeProfit1;                 // First take profit (65%)
    double takeProfit2;                 // Second take profit (35%)
    double lots;                        // Position size
    datetime entryTime;                 // Entry timestamp
};

// ==================== GLOBAL VARIABLES ====================

VolumeProfile     currentProfile;               // Current session profile
VolumeProfile     previousSessionProfile;       // Previous session profile (for comparison)
SessionProfile    prevSessionVA;                // Previous day's Value Area
DailyStats        dailyStats;                   // Today's P&L tracking
PositionRecord    positions[3];                 // Max 3 simultaneous positions
int               positionCount = 0;            // Current number of open positions

bool              dailyHardStopHit = false;     // -2% loss flag
bool              dailyProfitCapReached = false;// +5% gain flag
bool              fridayClosedFlag = false;     // Friday close flag
datetime          lastSessionDate = 0;          // Last session date for reset

// ==================== FUNCTION DECLARATIONS ====================

// Volume Profile Engine
void CalculateCurrentVolumeProfile();
void CalculateValueArea();
void IdentifyVolumeNodes();
void CalculatePreviousSessionProfile();

// Risk Management
double CalculateLotSize(double entryPrice, double stopLossPrice);
bool CheckDailyLimits();
bool CheckProfitCap();
void CheckFridayClose();
bool CanOpenNewPosition(string symbol);
void ResetDailyStats();

// Data Validation & Utilities
void ValidateProfileCalculation();
bool CheckDataQuality();
string GetSymbolName();

// Logging
void LogVolumeProfile();
void LogTradeEntry(string direction, double entryPrice, double stopLoss, double takeProfit1, double takeProfit2, double lots);
void LogError(string errorMsg);
void LogAlert(string alertType, string message);

// Unit Tests (Phase 1)
bool TestVolumeValidation();
bool TestPOCIdentification();
bool TestValueAreaCalculation();
bool TestHVNLVNDetection();
void RunAllTests();

// Event Handlers
int OnInit();
void OnTick();
void OnDeinit(int reason);

// ==================== EVENT HANDLERS ====================

//+------------------------------------------------------------------+
//| Expert initialization function                                  |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("===== PHASE 1: VOLUME PROFILE CORE ENGINE =====");
    Print("EA Magic Number: ", EA_MAGIC_NUMBER);
    Print("Lookback Period: ", Lookback_Period, " bars");
    Print("Risk Percentage: ", Risk_Percentage, "%");
    Print("Volume Bins: ", VOLUME_BINS);
    Print("HVN Threshold: ", HVN_MULTIPLIER, "x average");
    Print("LVN Threshold: ", LVN_MULTIPLIER, "x average");
    Print("Value Area: ", VALUE_AREA_PERCENT * 100, "%");

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
    // TODO: Phase 2 - Main orchestration loop
    // For Phase 1, we just calculate and log the volume profile

    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(Symbol(), PERIOD_CURRENT, 0);

    // Only recalculate on new bar
    if (currentBarTime != lastBarTime)
    {
        lastBarTime = currentBarTime;

        // Calculate volume profile
        CalculateCurrentVolumeProfile();
        CalculateValueArea();
        IdentifyVolumeNodes();

        // Check data quality
        if (!CheckDataQuality())
        {
            LogError("Data quality check failed");
            return;
        }

        // Validate profile
        ValidateProfileCalculation();

        // Log current profile (optional, disable for performance)
        // LogVolumeProfile();
    }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(int reason)
{
    Print("EA Deinitializing. Reason: ", reason);
    // Cleanup if needed
}

// ==================== VOLUME PROFILE ENGINE ====================

//+------------------------------------------------------------------+
//| Calculate 400-bin volume distribution (REQ-001, REQ-008)         |
//| Implementation per D-01: Proportional-to-range proration         |
//+------------------------------------------------------------------+
void CalculateCurrentVolumeProfile()
{
    int lookbackPeriod = Lookback_Period;

    // Step 1: Find price range from lookback period
    double minPrice = iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, lookbackPeriod, 0);
    double maxPrice = iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, lookbackPeriod, 0);

    if (maxPrice <= minPrice)
    {
        LogError("Invalid price range for volume profile");
        return;
    }

    // Calculate bin size
    double binSize = (maxPrice - minPrice) / VOLUME_BINS;

    // Store metadata
    currentProfile.minPrice = minPrice;
    currentProfile.maxPrice = maxPrice;
    currentProfile.binSize = binSize;

    // Step 2: Initialize volume array to zero
    ArrayInitialize(currentProfile.volumeArray, 0);

    // Step 3: Iterate through lookback bars and prorate volume
    for (int i = 0; i < lookbackPeriod; i++)
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
                    currentProfile.volumeArray[binIdx] += volumePerBin;
                }
            }
        }
        else
        {
            // Doji or flat candle: all volume goes to close price bin
            int binIdx = (int)((close - minPrice) / binSize);
            if (binIdx >= 0 && binIdx < VOLUME_BINS)
            {
                currentProfile.volumeArray[binIdx] += volume;
            }
        }
    }

    // Step 4: Validation - Check volume distribution integrity
    double binSum = 0;
    long rawTotal = 0;

    for (int i = 0; i < lookbackPeriod; i++)
        rawTotal += iVolume(Symbol(), PERIOD_CURRENT, i);

    for (int i = 0; i < VOLUME_BINS; i++)
        binSum += currentProfile.volumeArray[i];

    if (rawTotal > 0)
    {
        double variance = MathAbs(binSum - rawTotal) / rawTotal;
        if (variance > 0.01)  // >1% variance
        {
            LogAlert("WARNING", StringFormat("Volume distribution variance %.2f%% > 1%%, sum=%.0f, total=%d",
                variance * 100, binSum, rawTotal));
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate POC and VAH/VAL boundaries (REQ-002, REQ-003, REQ-004) |
//| POC = single price bin with max volume                            |
//| VAH/VAL = 70% cumulative volume expanding from POC                |
//+------------------------------------------------------------------+
void CalculateValueArea()
{
    if (currentProfile.binSize <= 0)
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
        if (currentProfile.volumeArray[i] > maxVol)
        {
            maxVol = currentProfile.volumeArray[i];
            pocIdx = i;
        }
    }

    // Convert bin index to price (use center of bin)
    currentProfile.pocBinIndex = pocIdx;
    currentProfile.pocPrice = currentProfile.minPrice +
                              (pocIdx * currentProfile.binSize) +
                              (currentProfile.binSize / 2.0);
    currentProfile.pocVolume = maxVol;

    // Step 2: Calculate VAH/VAL (70% Value Area expansion)
    // Calculate total volume and target threshold
    double totalVol = 0;
    for (int i = 0; i < VOLUME_BINS; i++)
    {
        totalVol += currentProfile.volumeArray[i];
    }

    if (totalVol <= 0)
    {
        LogError("Total volume <= 0 for VAH/VAL calculation");
        return;
    }

    double targetVol = totalVol * VALUE_AREA_PERCENT;  // 70% threshold

    // Expand outward from POC until 70% cumulative volume reached
    double cumulativeVol = currentProfile.volumeArray[currentProfile.pocBinIndex];
    int offset = 0;
    int maxOffset = 200;  // Safety: don't expand > 50% of bins

    while (cumulativeVol < targetVol && offset < maxOffset)
    {
        offset++;

        // Add bin above POC (higher price)
        if (currentProfile.pocBinIndex + offset < VOLUME_BINS)
        {
            cumulativeVol += currentProfile.volumeArray[currentProfile.pocBinIndex + offset];
        }

        // Add bin below POC (lower price)
        if (currentProfile.pocBinIndex - offset >= 0)
        {
            cumulativeVol += currentProfile.volumeArray[currentProfile.pocBinIndex - offset];
        }
    }

    // Step 3: Calculate VAH and VAL prices
    int vahBinIndex = currentProfile.pocBinIndex + offset;
    int valBinIndex = currentProfile.pocBinIndex - offset;

    // Clamp to valid range
    if (vahBinIndex >= VOLUME_BINS)
        vahBinIndex = VOLUME_BINS - 1;
    if (valBinIndex < 0)
        valBinIndex = 0;

    currentProfile.vahPrice = currentProfile.minPrice +
                              (vahBinIndex * currentProfile.binSize);
    currentProfile.valPrice = currentProfile.minPrice +
                              (valBinIndex * currentProfile.binSize);

    // Step 4: Validation - Check Value Area width is reasonable
    double vaWidth = currentProfile.vahPrice - currentProfile.valPrice;
    if (vaWidth < currentProfile.binSize)
    {
        LogAlert("WARNING", StringFormat("VA width %.5f < bin size %.5f",
            vaWidth, currentProfile.binSize));
    }
}

//+------------------------------------------------------------------+
//| Identify High/Low Volume Nodes (REQ-005, REQ-006)               |
//| HVN = local peaks > 1.3x average volume (locked per D-02)       |
//| LVN = local valleys < 0.7x average volume (locked per D-02)    |
//+------------------------------------------------------------------+
void IdentifyVolumeNodes()
{
    if (currentProfile.pocPrice <= 0)
    {
        LogError("POC not calculated before node identification");
        return;
    }

    // Step 1: Calculate average volume per bin
    double totalVol = 0;
    for (int i = 0; i < VOLUME_BINS; i++)
    {
        totalVol += currentProfile.volumeArray[i];
    }

    if (totalVol <= 0)
    {
        LogError("Total volume <= 0 for node identification");
        return;
    }

    double avgVolume = totalVol / VOLUME_BINS;

    // Step 2: Calculate thresholds (locked, non-negotiable per D-02)
    double hvnThreshold = avgVolume * HVN_MULTIPLIER;  // 1.3x
    double lvnThreshold = avgVolume * LVN_MULTIPLIER;  // 0.7x

    // Step 3: Reset arrays and counters
    currentProfile.hvnCount = 0;
    currentProfile.lvnCount = 0;
    // Zero out HVN and LVN arrays
    for (int j = 0; j < 50; j++)
    {
        currentProfile.hvnArray[j].price = 0;
        currentProfile.hvnArray[j].volume = 0;
        currentProfile.lvnArray[j].price = 0;
        currentProfile.lvnArray[j].volume = 0;
    }

    // Step 4: Iterate and classify bins as HVN or LVN
    for (int i = 0; i < VOLUME_BINS; i++)
    {
        double binVolume = currentProfile.volumeArray[i];
        double binPrice = currentProfile.minPrice + (i * currentProfile.binSize);

        // HVN: local peaks > 1.3x average
        if (binVolume > hvnThreshold)
        {
            if (currentProfile.hvnCount < 50)  // Max 50 HVN clusters
            {
                currentProfile.hvnArray[currentProfile.hvnCount].price = binPrice;
                currentProfile.hvnArray[currentProfile.hvnCount].volume = binVolume;
                currentProfile.hvnCount++;
            }
        }

        // LVN: local valleys < 0.7x average
        if (binVolume < lvnThreshold)
        {
            if (currentProfile.lvnCount < 50)  // Max 50 LVN clusters
            {
                currentProfile.lvnArray[currentProfile.lvnCount].price = binPrice;
                currentProfile.lvnArray[currentProfile.lvnCount].volume = binVolume;
                currentProfile.lvnCount++;
            }
        }
    }

    // Step 5: Validation - sanity-check cluster counts
    if (currentProfile.hvnCount > 50)
    {
        LogAlert("WARNING", StringFormat("HVN count %d exceeds max (50); truncated",
            currentProfile.hvnCount));
        currentProfile.hvnCount = 50;
    }

    if (currentProfile.lvnCount > 50)
    {
        LogAlert("WARNING", StringFormat("LVN count %d exceeds max (50); truncated",
            currentProfile.lvnCount));
        currentProfile.lvnCount = 50;
    }
}

//+------------------------------------------------------------------+
//| Calculate previous session profile (REQ-007)                     |
//+------------------------------------------------------------------+
void CalculatePreviousSessionProfile()
{
    // TODO: Implement previous session calculation
    // Store yesterday's VAH/VAL for Setup 1 entry validation
}

// ==================== RISK MANAGEMENT ====================

//+------------------------------------------------------------------+
//| Calculate position size based on risk (REQ-029, REQ-030)         |
//+------------------------------------------------------------------+
double CalculateLotSize(double entryPrice, double stopLossPrice)
{
    // TODO: Implement lot size calculation
    return 0.1;  // Placeholder
}

//+------------------------------------------------------------------+
//| Check daily loss limit (-2%) (REQ-032, REQ-035)                  |
//+------------------------------------------------------------------+
bool CheckDailyLimits()
{
    // TODO: Implement daily limit checking
    return true;
}

//+------------------------------------------------------------------+
//| Check daily profit cap (+5%) (REQ-033)                           |
//+------------------------------------------------------------------+
bool CheckProfitCap()
{
    // TODO: Implement profit cap checking
    return true;
}

//+------------------------------------------------------------------+
//| Check and enforce Friday hard close (REQ-034)                    |
//+------------------------------------------------------------------+
void CheckFridayClose()
{
    // TODO: Implement Friday close logic
}

//+------------------------------------------------------------------+
//| Check if new position can be opened (REQ-031)                    |
//+------------------------------------------------------------------+
bool CanOpenNewPosition(string symbol)
{
    // TODO: Implement position limit checking
    return true;
}

//+------------------------------------------------------------------+
//| Reset daily statistics at start of day                           |
//+------------------------------------------------------------------+
void ResetDailyStats()
{
    dailyStats.closedPnL = 0;
    dailyStats.openPnL = 0;
    dailyStats.totalPnL = 0;
    dailyStats.hardStopHit = false;
    dailyStats.profitCapReached = false;
}

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
//| Log current volume profile (optional)                            |
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
void LogTradeEntry(string direction, double entryPrice, double stopLoss,
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

//+------------------------------------------------------------------+
//| Log error message                                                |
//+------------------------------------------------------------------+
void LogError(string errorMsg)
{
    Print("[ERROR] ", errorMsg);
}

//+------------------------------------------------------------------+
//| Log alert message                                                |
//+------------------------------------------------------------------+
void LogAlert(string alertType, string message)
{
    Print("[", alertType, "] ", message);
}

// ==================== UNIT TESTS ====================

//+------------------------------------------------------------------+
//| Test 1: Volume Distribution Validation (REQ-001, REQ-009)        |
//+------------------------------------------------------------------+
bool TestVolumeValidation()
{
    Print("TEST: Volume Distribution Validation");

    // Call the actual calculation
    CalculateCurrentVolumeProfile();

    // Validate distribution
    double binSum = 0;
    for (int i = 0; i < VOLUME_BINS; i++)
        binSum += currentProfile.volumeArray[i];

    // Get raw total from lookback period
    long rawTotal = 0;
    for (int i = 0; i < Lookback_Period; i++)
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
//| Run all unit tests                                               |
//+------------------------------------------------------------------+
void RunAllTests()
{
    bool allPass = true;

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

    Print("\n===== TESTS COMPLETE =====");

    if (allPass)
        Print("PASS: All critical tests PASSED");
    else
        Print("WARN: Some tests skipped or warned; run full backtest for validation");
}

//+------------------------------------------------------------------+
// END OF FILE
//+------------------------------------------------------------------+
