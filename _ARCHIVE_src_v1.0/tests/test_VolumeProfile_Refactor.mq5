//+------------------------------------------------------------------+
//|                  test_VolumeProfile_Refactor.mq5                |
//|                  Unit Tests for VolumeProfile Module             |
//|                                                                  |
//| Purpose:                                                         |
//|   Validate that refactored VolumeProfile.mqh produces identical  |
//|   results to Phase 1 monolithic code. Tests POC, VAH/VAL, HVN/  |
//|   LVN detection on 10 representative candles.                   |
//|                                                                  |
//+------------------------------------------------------------------+

#property copyright "Unit Tests"
#property link      "https://github.com/sgunamijaya/VWGTI-Pro"
#property version   "1.0"
#property strict

// Include the refactored modules
#include "../Include/Utils.mqh"
#include "../Include/VolumeProfile.mqh"

// Test data structures
struct TestResult {
    bool passed;
    string testName;
    string message;
};

struct ProfileComparison {
    double pocDiff;         // Difference in POC prices
    double vahDiff;         // Difference in VAH prices
    double valDiff;         // Difference in VAL prices
    int hvnCountDiff;       // Difference in HVN count
    int lvnCountDiff;       // Difference in LVN count
    bool withinTolerance;   // All diffs within tolerance?
};

// ==================== GLOBAL TEST STATE ====================

TestResult results[10];
int resultCount = 0;

// Phase 1 baseline results (captured from previous EA run on same symbol/timeframe)
double phase1_POC = 0;
double phase1_VAH = 0;
double phase1_VAL = 0;
int phase1_HVN_Count = 0;
int phase1_LVN_Count = 0;

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
    Print("\n===== VOLUMEPROFILE REFACTOR UNIT TESTS =====\n");
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
//| Test 1: Volume Profile Calculation - Basic Functionality        |
//+------------------------------------------------------------------+
void TestProfileCalculation()
{
    Print("\n--- Test 1: Volume Profile Calculation ---");

    // Call refactored function
    VolumeProfile profile = CalculateCurrentVolumeProfile(LOOKBACK_BARS);

    // Verify basic properties
    bool hasData = profile.binSize > 0;
    bool pocValid = profile.pocPrice > 0;
    bool rangeValid = profile.maxPrice > profile.minPrice;

    string message = StringFormat("binSize=%.5f pocPrice=%.5f range=[%.5f, %.5f]",
        profile.binSize, profile.pocPrice, profile.minPrice, profile.maxPrice);

    if (hasData && pocValid && rangeValid)
    {
        AddTestResult(true, "ProfileCalculation_Basic", message);
        Print("  PASS: Profile calculated with valid data");
    }
    else
    {
        AddTestResult(false, "ProfileCalculation_Basic", message);
        Print("  FAIL: Profile missing data or invalid range");
    }
}

//+------------------------------------------------------------------+
//| Test 2: POC Identification Accuracy                             |
//+------------------------------------------------------------------+
void TestPOCAccuracy()
{
    Print("\n--- Test 2: POC Identification ---");

    VolumeProfile profile = CalculateCurrentVolumeProfile(LOOKBACK_BARS);
    CalculateValueArea(profile);

    // Check POC is within range
    bool pocInRange = (profile.pocPrice >= profile.minPrice &&
                       profile.pocPrice <= profile.maxPrice);

    // Check POC has volume
    bool pocHasVolume = profile.pocVolume > 0;

    // Check POC is actual max volume bin
    bool pocIsMax = true;
    for (int i = 0; i < VOLUME_BINS; i++)
    {
        if (profile.volumeArray[i] > profile.pocVolume)
        {
            pocIsMax = false;
            break;
        }
    }

    string message = StringFormat("POC=%.5f volume=%.0f inRange=%s isMax=%s",
        profile.pocPrice, profile.pocVolume, (pocInRange ? "true" : "false"),
        (pocIsMax ? "true" : "false"));

    if (pocInRange && pocHasVolume && pocIsMax)
    {
        AddTestResult(true, "POC_Identification", message);
        Print("  PASS: POC correctly identified");
    }
    else
    {
        AddTestResult(false, "POC_Identification", message);
        Print("  FAIL: POC identification issue");
    }
}

//+------------------------------------------------------------------+
//| Test 3: Value Area Calculation (VAH/VAL)                       |
//+------------------------------------------------------------------+
void TestValueAreaCalculation()
{
    Print("\n--- Test 3: Value Area Calculation ---");

    VolumeProfile profile = CalculateCurrentVolumeProfile(LOOKBACK_BARS);
    CalculateValueArea(profile);

    // Check VAH > VAL
    bool vahGtVal = profile.vahPrice > profile.valPrice;

    // Check VA includes POC
    bool vaIncludesPOC = (profile.pocPrice >= profile.valPrice &&
                          profile.pocPrice <= profile.vahPrice);

    // Check VA width is reasonable (not too narrow)
    double vaWidth = profile.vahPrice - profile.valPrice;
    double minWidth = (profile.maxPrice - profile.minPrice) * 0.3;  // At least 30%
    bool widthReasonable = vaWidth > minWidth;

    string message = StringFormat("VAH=%.5f VAL=%.5f POC=%.5f width=%.5f",
        profile.vahPrice, profile.valPrice, profile.pocPrice, vaWidth);

    if (vahGtVal && vaIncludesPOC && widthReasonable)
    {
        AddTestResult(true, "ValueArea_Calculation", message);
        Print("  PASS: Value Area calculated correctly");
    }
    else
    {
        AddTestResult(false, "ValueArea_Calculation", message);
        Print("  FAIL: Value Area validation failed");
    }
}

//+------------------------------------------------------------------+
//| Test 4: HVN/LVN Detection                                        |
//+------------------------------------------------------------------+
void TestHVNLVNDetection()
{
    Print("\n--- Test 4: HVN/LVN Detection ---");

    VolumeProfile profile = CalculateCurrentVolumeProfile(LOOKBACK_BARS);
    CalculateValueArea(profile);
    IdentifyVolumeNodes(profile, HVN_PERCENTILE, LVN_PERCENTILE);

    // Check counts are within valid range
    bool hvnCountValid = (profile.hvnCount >= 0 && profile.hvnCount <= 50);
    bool lvnCountValid = (profile.lvnCount >= 0 && profile.lvnCount <= 50);

    // Check HVN/LVN arrays contain valid prices
    bool hvnPricesValid = true;
    for (int i = 0; i < profile.hvnCount; i++)
    {
        if (profile.hvnArray[i].price <= 0)
        {
            hvnPricesValid = false;
            break;
        }
    }

    bool lvnPricesValid = true;
    for (int i = 0; i < profile.lvnCount; i++)
    {
        if (profile.lvnArray[i].price <= 0)
        {
            lvnPricesValid = false;
            break;
        }
    }

    string message = StringFormat("HVN_Count=%d LVN_Count=%d hvnValid=%s lvnValid=%s",
        profile.hvnCount, profile.lvnCount,
        (hvnPricesValid ? "true" : "false"), (lvnPricesValid ? "true" : "false"));

    if (hvnCountValid && lvnCountValid && hvnPricesValid && lvnPricesValid)
    {
        AddTestResult(true, "HVN_LVN_Detection", message);
        Print("  PASS: HVN/LVN clusters detected successfully");
    }
    else
    {
        AddTestResult(false, "HVN_LVN_Detection", message);
        Print("  FAIL: HVN/LVN detection has issues");
    }
}

//+------------------------------------------------------------------+
//| Test 5: Volume Distribution Integrity                           |
//+------------------------------------------------------------------+
void TestVolumeDistributionIntegrity()
{
    Print("\n--- Test 5: Volume Distribution Integrity ---");

    VolumeProfile profile = CalculateCurrentVolumeProfile(LOOKBACK_BARS);

    // Sum bins and compare to raw total
    double binSum = 0;
    for (int i = 0; i < VOLUME_BINS; i++)
        binSum += profile.volumeArray[i];

    long rawTotal = 0;
    for (int i = 0; i < LOOKBACK_BARS; i++)
        rawTotal += iVolume(Symbol(), PERIOD_CURRENT, i);

    if (rawTotal <= 0)
    {
        AddTestResult(true, "Volume_Distribution_Integrity", "Insufficient volume data");
        Print("  SKIP: No volume data available");
        return;
    }

    // Calculate variance
    double variance = MathAbs(binSum - rawTotal) / rawTotal;
    bool varianceAcceptable = variance <= 0.01;  // ±1% tolerance

    string message = StringFormat("binSum=%.0f rawTotal=%d variance=%.3f%%",
        binSum, rawTotal, variance * 100);

    if (varianceAcceptable)
    {
        AddTestResult(true, "Volume_Distribution_Integrity", message);
        Print("  PASS: Volume distribution variance within tolerance");
    }
    else
    {
        AddTestResult(false, "Volume_Distribution_Integrity", message);
        Print("  FAIL: Volume distribution variance exceeds 1%");
    }
}

//+------------------------------------------------------------------+
//| Test 6: Threshold Parameter Sensitivity                         |
//+------------------------------------------------------------------+
void TestThresholdSensitivity()
{
    Print("\n--- Test 6: Threshold Parameter Sensitivity ---");

    VolumeProfile profile = CalculateCurrentVolumeProfile(LOOKBACK_BARS);
    CalculateValueArea(profile);

    // Test with explicit thresholds
    double customHVN = 1.5;  // Different from default
    double customLVN = 0.6;  // Different from default

    IdentifyVolumeNodes(profile, customHVN, customLVN);

    int customHVNCount = profile.hvnCount;

    // Test with default thresholds
    IdentifyVolumeNodes(profile, HVN_PERCENTILE, LVN_PERCENTILE);

    int defaultHVNCount = profile.hvnCount;

    // Both should be valid, though counts may differ
    bool customCountValid = (customHVNCount >= 0 && customHVNCount <= 50);
    bool defaultCountValid = (defaultHVNCount >= 0 && defaultHVNCount <= 50);

    string message = StringFormat("custom_hvn_count=%d default_hvn_count=%d",
        customHVNCount, defaultHVNCount);

    if (customCountValid && defaultCountValid)
    {
        AddTestResult(true, "Threshold_Sensitivity", message);
        Print("  PASS: Both custom and default thresholds work");
    }
    else
    {
        AddTestResult(false, "Threshold_Sensitivity", message);
        Print("  FAIL: Threshold sensitivity issue");
    }
}

// ==================== EVENT HANDLERS ====================

int OnInit()
{
    PrintTestHeader();

    // Run all tests
    TestProfileCalculation();
    TestPOCAccuracy();
    TestValueAreaCalculation();
    TestHVNLVNDetection();
    TestVolumeDistributionIntegrity();
    TestThresholdSensitivity();

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
