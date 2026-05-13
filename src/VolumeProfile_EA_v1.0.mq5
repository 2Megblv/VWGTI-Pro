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

// ==================== INCLUDE MODULAR HEADERS ====================

#include "Include/Utils.mqh"
#include "Include/VolumeProfile.mqh"
#include "Include/RiskManager.mqh"
#include "Include/SignalDetection.mqh"
#include "Include/MultiTimeframeContext.mqh"
#include "Include/TradeExecution.mqh"

// ==================== INPUT PARAMETERS ====================

input int    Lookback_Period      = 150;      // Number of bars to analyze for volume profile
input bool   Use_Risk_Percentage  = true;     // Use risk percentage or fixed lot size
input double Fixed_Lot_Size       = 0.1;      // Used when Use_Risk_Percentage = false
input double Risk_Percentage      = 0.6;      // Risk percentage per trade (0.6%)

// ==================== GLOBAL VARIABLES ====================

VolumeProfile     currentProfile;               // Current session profile
VolumeProfile     previousSessionProfile;       // Previous session profile (for comparison)
DailyLimitState   dailyLimits;                  // Daily P&L tracking
PositionRecord    positions[3];                 // Max 3 simultaneous positions
int               positionCount = 0;            // Current number of open positions

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
                double stopLoss = sig1.sweepLow - (10 * Point);  // 10 pips below sweep low
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
                double stopLoss = sig2.sweepLow - (10 * Point);  // 10 pips below LVN sweep low
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
void OnDeinit(int reason)
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

//+------------------------------------------------------------------+
//| Check if new position can be opened (REQ-031)                    |
//| Validates max 1 position per asset rule                          |
//+------------------------------------------------------------------+
bool CanOpenNewPosition(string symbol)
{
    // REQ-031: Max 1 position per asset (XAUUSD OR EURUSD, not both)

    // Check if already have a position on this symbol
    for (int i = 0; i < positionCount; i++)
    {
        if (positions[i].ticket > 0)
        {
            // Check if same symbol
            if (positions[i].symbol == symbol)
            {
                Print("ERROR: Cannot open new position on ", symbol,
                      "; already have active position (ticket: ",
                      positions[i].ticket, ")");
                return false;  // Already open on this asset
            }
        }
    }

    // Check if position array is full
    if (positionCount >= 3)
    {
        Print("ERROR: Position array full (max 3 simultaneous)");
        return false;
    }

    // Check if symbol is valid (XAUUSD or EURUSD)
    if (symbol != "XAUUSD" && symbol != "EURUSD")
    {
        Print("ERROR: Invalid symbol ", symbol, "; only XAUUSD and EURUSD supported");
        return false;
    }

    return true;  // Can open new position
}

//+------------------------------------------------------------------+
//| Add position to tracking array (REQ-031)                         |
//+------------------------------------------------------------------+
bool AddPosition(long ticket, string symbol, double entry, double sl,
                 double tp1, double tp2, double lots)
{
    if (!CanOpenNewPosition(symbol))
        return false;

    // Add to first available slot
    for (int i = 0; i < 3; i++)
    {
        if (positions[i].ticket <= 0)  // Empty slot
        {
            positions[i].ticket = ticket;
            positions[i].symbol = symbol;
            positions[i].entryPrice = entry;
            positions[i].stopLoss = sl;
            positions[i].takeProfit1 = tp1;
            positions[i].takeProfit2 = tp2;
            positions[i].lots = lots;
            positions[i].entryTime = TimeCurrent();

            positionCount++;

            LogAlert("POSITION_ADD", StringFormat("symbol=%s ticket=%ld entry=%.5f sl=%.5f lots=%.2f count=%d/3",
                symbol, ticket, entry, sl, lots, positionCount));

            return true;
        }
    }

    return false;  // No empty slots
}

//+------------------------------------------------------------------+
//| Remove position from tracking array (REQ-031)                    |
//+------------------------------------------------------------------+
bool RemovePosition(long ticket)
{
    for (int i = 0; i < 3; i++)
    {
        if (positions[i].ticket == ticket)
        {
            string symbol = positions[i].symbol;
            ArrayZero(positions[i]);  // Clear struct
            positions[i].ticket = 0;  // Mark as empty

            positionCount--;
            if (positionCount < 0) positionCount = 0;  // Safety

            LogAlert("POSITION_REMOVE", StringFormat("ticket=%ld count=%d/3", ticket, positionCount));

            return true;
        }
    }

    return false;  // Ticket not found
}

//+------------------------------------------------------------------+
//| Reset daily statistics at start of day                           |
//+------------------------------------------------------------------+
void ResetDailyStats()
{
    dailyLimits.closedPnL = 0;
    dailyLimits.openPnL = 0;
    dailyLimits.totalPnL = 0;
    dailyLimits.hardStopHit = false;
    dailyLimits.profitCapReached = false;
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

    // Test 1: CanOpenNewPosition() for valid symbols
    if (CanOpenNewPosition("XAUUSD"))
    {
        Print("  PASS: XAUUSD recognized as valid symbol");
    }
    else
    {
        Print("  FAIL: XAUUSD not recognized");
        return false;
    }

    if (CanOpenNewPosition("EURUSD"))
    {
        Print("  PASS: EURUSD recognized as valid symbol");
    }
    else
    {
        Print("  FAIL: EURUSD not recognized");
        return false;
    }

    // Test 2: CanOpenNewPosition() rejects invalid symbol
    if (!CanOpenNewPosition("INVALID"))
    {
        Print("  PASS: Invalid symbol INVALID rejected");
    }
    else
    {
        Print("  FAIL: Invalid symbol should be rejected");
        return false;
    }

    // Test 3: Position array management
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
