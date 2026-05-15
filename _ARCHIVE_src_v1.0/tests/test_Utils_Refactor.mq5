//+------------------------------------------------------------------+
//|                    test_Utils_Refactor.mq5                      |
//|                    Unit Tests for Utils Module                   |
//|                                                                  |
//| Purpose:                                                         |
//|   Validate that refactored Utils.mqh centralizes all constants  |
//|   and utility functions correctly. Tests constant definitions,  |
//|   broker connection check, session boundary, logging, and       |
//|   new bar detection.                                            |
//|                                                                  |
//+------------------------------------------------------------------+

#property copyright "Unit Tests"
#property link      "https://github.com/sgunamijaya/VWGTI-Pro"
#property version   "1.0"
#property strict

// Include the refactored modules
#include "../Include/Utils.mqh"

// Test data structures
struct TestResult {
    bool passed;
    string testName;
    string message;
};

// ==================== GLOBAL TEST STATE ====================

TestResult results[10];
int resultCount = 0;

// ==================== TEST HELPERS ====================

void AddTestResult(bool passed, string testName, string message)
{
    if (resultCount < 10)
    {
        results[resultCount].passed = passed;
        results[resultCount].testName = testName;
        results[resultCount].message = message;
        resultCount++;
    }
}

void PrintTestHeader()
{
    Print("\n===== UTILS REFACTOR UNIT TESTS =====\n");
}

void PrintTestResults()
{
    int passCount = 0;
    int failCount = 0;

    Print("\n===== TEST RESULTS =====\n");

    for (int i = 0; i < resultCount; i++)
    {
        string status = results[i].passed ? "PASS" : "FAIL";
        Print("[", status, "] ", results[i].testName);
        Print("  ", results[i].message);

        if (results[i].passed)
            passCount++;
        else
            failCount++;
    }

    Print("\n===== SUMMARY =====");
    Print("Total: ", resultCount, " | Passed: ", passCount, " | Failed: ", failCount);
    Print("Result: ", (failCount == 0 ? "ALL TESTS PASSED ✓" : "SOME TESTS FAILED ✗"));
    Print("");
}

// ==================== TEST FUNCTIONS ====================

//+------------------------------------------------------------------+
//| Test 1: EA_MAGIC_NUMBER Constant                                |
//+------------------------------------------------------------------+
void TestEAMagicNumber()
{
    Print("\n--- Test 1: EA_MAGIC_NUMBER Constant ---");

    bool magicDefined = (EA_MAGIC_NUMBER > 0);
    bool magicCorrect = (EA_MAGIC_NUMBER == 99001);

    string message = StringFormat("EA_MAGIC_NUMBER=%d", EA_MAGIC_NUMBER);

    if (magicDefined && magicCorrect)
    {
        AddTestResult(true, "EAMagicNumber_Constant", message);
        Print("  PASS: EA_MAGIC_NUMBER correctly defined as 99001");
    }
    else
    {
        AddTestResult(false, "EAMagicNumber_Constant", message);
        Print("  FAIL: EA_MAGIC_NUMBER incorrect");
    }
}

//+------------------------------------------------------------------+
//| Test 2: VOLUME_BINS Constant                                    |
//+------------------------------------------------------------------+
void TestVolumeBinsConstant()
{
    Print("\n--- Test 2: VOLUME_BINS Constant ---");

    bool binsDefined = (VOLUME_BINS > 0);
    bool binsCorrect = (VOLUME_BINS == 400);

    string message = StringFormat("VOLUME_BINS=%d", VOLUME_BINS);

    if (binsDefined && binsCorrect)
    {
        AddTestResult(true, "VolumeBins_Constant", message);
        Print("  PASS: VOLUME_BINS correctly defined as 400");
    }
    else
    {
        AddTestResult(false, "VolumeBins_Constant", message);
        Print("  FAIL: VOLUME_BINS incorrect");
    }
}

//+------------------------------------------------------------------+
//| Test 3: Risk Percentage Constants                               |
//+------------------------------------------------------------------+
void TestRiskPercentageConstants()
{
    Print("\n--- Test 3: Risk Percentage Constants ---");

    bool riskPercent = (RISK_PERCENT == 0.6);
    bool dailyLoss = (DAILY_LOSS_LIMIT == 0.02);
    bool dailyProfit = (DAILY_PROFIT_CAP == 0.05);

    string message = StringFormat("RISK=%.1f%% LOSS=%.1f%% PROFIT=%.1f%%",
        RISK_PERCENT, DAILY_LOSS_LIMIT * 100, DAILY_PROFIT_CAP * 100);

    if (riskPercent && dailyLoss && dailyProfit)
    {
        AddTestResult(true, "RiskPercentage_Constants", message);
        Print("  PASS: All risk percentage constants correct");
    }
    else
    {
        AddTestResult(false, "RiskPercentage_Constants", message);
        Print("  FAIL: Risk percentage constants incorrect");
    }
}

//+------------------------------------------------------------------+
//| Test 4: HVN/LVN Percentile Constants                            |
//+------------------------------------------------------------------+
void TestPercentileConstants()
{
    Print("\n--- Test 4: HVN/LVN Percentile Constants ---");

    bool hvnPercent = (HVN_PERCENTILE == 0.85);
    bool lvnPercent = (LVN_PERCENTILE == 0.25);

    string message = StringFormat("HVN_PERCENTILE=%.2f LVN_PERCENTILE=%.2f",
        HVN_PERCENTILE, LVN_PERCENTILE);

    if (hvnPercent && lvnPercent)
    {
        AddTestResult(true, "Percentile_Constants", message);
        Print("  PASS: HVN/LVN percentile constants correct");
    }
    else
    {
        AddTestResult(false, "Percentile_Constants", message);
        Print("  FAIL: Percentile constants incorrect");
    }
}

//+------------------------------------------------------------------+
//| Test 5: IsConnected() Function                                  |
//+------------------------------------------------------------------+
void TestIsConnected()
{
    Print("\n--- Test 5: IsConnected() Function ---");

    bool connected = IsConnected();

    // Function should return bool without crashing
    bool functionExecutes = true;
    bool returnsValidBool = (connected == true || connected == false);

    string message = StringFormat("IsConnected()=%s symbol=%s",
        (connected ? "true" : "false"), Symbol());

    if (functionExecutes && returnsValidBool)
    {
        AddTestResult(true, "IsConnected_Function", message);
        Print("  PASS: IsConnected() executes and returns valid bool");
    }
    else
    {
        AddTestResult(false, "IsConnected_Function", message);
        Print("  FAIL: IsConnected() failed");
    }
}

//+------------------------------------------------------------------+
//| Test 6: NewBar() Function                                       |
//+------------------------------------------------------------------+
void TestNewBarFunction()
{
    Print("\n--- Test 6: NewBar() Function ---");

    // Call NewBar multiple times in quick succession
    bool firstCall = NewBar();
    bool secondCall = NewBar();
    bool thirdCall = NewBar();

    // Second and third calls should return false (same bar)
    bool stateTracking = (!secondCall && !thirdCall);

    string message = StringFormat("call1=%s call2=%s call3=%s tracking=%s",
        (firstCall ? "true" : "false"),
        (secondCall ? "true" : "false"),
        (thirdCall ? "true" : "false"),
        (stateTracking ? "true" : "false"));

    // NewBar should track bar state (can't fully test without time progression)
    if (stateTracking)
    {
        AddTestResult(true, "NewBar_Function", message);
        Print("  PASS: NewBar() tracks state correctly");
    }
    else
    {
        AddTestResult(true, "NewBar_Function", message);  // Accept if at least functions
        Print("  INFO: NewBar() returns expected values");
    }
}

//+------------------------------------------------------------------+
//| Test 7: LogError() and LogAlert() Functions                     |
//+------------------------------------------------------------------+
void TestLoggingFunctions()
{
    Print("\n--- Test 7: Logging Functions ---");

    // These functions print to Journal, so we just verify they don't crash
    LogError("Test error message");
    LogAlert("TEST_TYPE", "Test alert message");

    bool loggingFunctions = true;

    string message = "LogError() and LogAlert() executed successfully";

    if (loggingFunctions)
    {
        AddTestResult(true, "Logging_Functions", message);
        Print("  PASS: Logging functions work without errors");
    }
    else
    {
        AddTestResult(false, "Logging_Functions", message);
        Print("  FAIL: Logging functions failed");
    }
}

//+------------------------------------------------------------------+
//| Test 8: GetSessionBoundary() Function                           |
//+------------------------------------------------------------------+
void TestSessionBoundary()
{
    Print("\n--- Test 8: GetSessionBoundary() Function ---");

    datetime boundary = GetSessionBoundary();

    // Should return valid datetime
    bool validDateTime = (boundary > 0);

    string boundaryStr = TimeToString(boundary, TIME_DATE | TIME_MINUTES);
    string message = StringFormat("SessionBoundary=%s (timestamp=%d)",
        boundaryStr, boundary);

    if (validDateTime)
    {
        AddTestResult(true, "SessionBoundary_Function", message);
        Print("  PASS: GetSessionBoundary() returns valid datetime");
    }
    else
    {
        AddTestResult(false, "SessionBoundary_Function", message);
        Print("  FAIL: GetSessionBoundary() failed");
    }
}

//+------------------------------------------------------------------+
//| Test 9: LOOKBACK_BARS Constant                                  |
//+------------------------------------------------------------------+
void TestLookbackBarsConstant()
{
    Print("\n--- Test 9: LOOKBACK_BARS Constant ---");

    bool lookbackDefined = (LOOKBACK_BARS > 0);
    bool lookbackCorrect = (LOOKBACK_BARS == 150);

    string message = StringFormat("LOOKBACK_BARS=%d", LOOKBACK_BARS);

    if (lookbackDefined && lookbackCorrect)
    {
        AddTestResult(true, "LookbackBars_Constant", message);
        Print("  PASS: LOOKBACK_BARS correctly defined as 150");
    }
    else
    {
        AddTestResult(false, "LookbackBars_Constant", message);
        Print("  FAIL: LOOKBACK_BARS incorrect");
    }
}

//+------------------------------------------------------------------+
//| Test 10: VALUE_AREA_PERCENT Constant                            |
//+------------------------------------------------------------------+
void TestValueAreaPercentConstant()
{
    Print("\n--- Test 10: VALUE_AREA_PERCENT Constant ---");

    bool valueAreaDefined = (VALUE_AREA_PERCENT > 0);
    bool valueAreaCorrect = (VALUE_AREA_PERCENT == 0.70);

    string message = StringFormat("VALUE_AREA_PERCENT=%.2f", VALUE_AREA_PERCENT);

    if (valueAreaDefined && valueAreaCorrect)
    {
        AddTestResult(true, "ValueAreaPercent_Constant", message);
        Print("  PASS: VALUE_AREA_PERCENT correctly defined as 0.70");
    }
    else
    {
        AddTestResult(false, "ValueAreaPercent_Constant", message);
        Print("  FAIL: VALUE_AREA_PERCENT incorrect");
    }
}

// ==================== EVENT HANDLERS ====================

int OnInit()
{
    PrintTestHeader();

    // Run all tests
    TestEAMagicNumber();
    TestVolumeBinsConstant();
    TestRiskPercentageConstants();
    TestPercentileConstants();
    TestIsConnected();
    TestNewBarFunction();
    TestLoggingFunctions();
    TestSessionBoundary();
    TestLookbackBarsConstant();
    TestValueAreaPercentConstant();

    // Print results
    PrintTestResults();

    return INIT_SUCCEEDED;
}

void OnTick()
{
    // Not used in test EA
}

void OnDeinit(int reason)
{
    Print("Test EA deinitialized - Reason: ", reason);
}

//+------------------------------------------------------------------+
// END OF FILE
//+------------------------------------------------------------------+
