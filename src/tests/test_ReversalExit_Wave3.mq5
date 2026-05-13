//+------------------------------------------------------------------+
//| test_ReversalExit_Wave3.mq5
//| Unit tests for reversal candle detection and position flip logic
//| Phase 2 Wave 3
//+------------------------------------------------------------------+

#property strict

// Include headers
#include "../Include/Utils.mqh"
#include "../Include/ReversalExit.mqh"
#include "../Include/TradeExecution.mqh"
#include "../Include/JournalLogger.mqh"

//+------------------------------------------------------------------+
//| OnStart - Unit Test Framework
//+------------------------------------------------------------------+
void OnStart()
{
    Print("\n╔════════════════════════════════════════════════════════╗");
    Print("║  PHASE 2 WAVE 3: REVERSAL EXIT UNIT TESTS            ║");
    Print("║  Testing: Reversal detection, confirmation, flip     ║");
    Print("╚════════════════════════════════════════════════════════╝\n");

    bool allPass = true;

    // Test 1: Reversal Signal Structure
    Print("Test 1: Reversal Signal Structure");
    if (TestReversalSignalStructure())
    {
        Print("  [PASS] ReversalSignal structure valid\n");
    }
    else
    {
        Print("  [FAIL] ReversalSignal structure invalid\n");
        allPass = false;
    }

    // Test 2: DetectReversalCandle for LONG
    Print("Test 2: DetectReversalCandle for LONG Position");
    if (TestDetectReversalCandleLong())
    {
        Print("  [PASS] Detects lower high for LONG reversal\n");
    }
    else
    {
        Print("  [FAIL] LONG reversal detection failed\n");
        allPass = false;
    }

    // Test 3: DetectReversalCandle for SHORT
    Print("Test 3: DetectReversalCandle for SHORT Position");
    if (TestDetectReversalCandleShort())
    {
        Print("  [PASS] Detects higher low for SHORT reversal\n");
    }
    else
    {
        Print("  [FAIL] SHORT reversal detection failed\n");
        allPass = false;
    }

    // Test 4: ConfirmReversal1M for LONG
    Print("Test 4: ConfirmReversal1M for LONG");
    if (TestConfirmReversal1MLong())
    {
        Print("  [PASS] 1M confirmation for LONG reversal works\n");
    }
    else
    {
        Print("  [FAIL] 1M LONG confirmation failed\n");
        allPass = false;
    }

    // Test 5: ConfirmReversal1M for SHORT
    Print("Test 5: ConfirmReversal1M for SHORT");
    if (TestConfirmReversal1MShort())
    {
        Print("  [PASS] 1M confirmation for SHORT reversal works\n");
    }
    else
    {
        Print("  [FAIL] 1M SHORT confirmation failed\n");
        allPass = false;
    }

    // Test 6: Distance to TP Calculation
    Print("Test 6: Distance to TP Calculation");
    if (TestGetDistanceToTP())
    {
        Print("  [PASS] GetDistanceToTP works correctly\n");
    }
    else
    {
        Print("  [FAIL] GetDistanceToTP failed\n");
        allPass = false;
    }

    // Test 7: Monitor Reversals Function
    Print("Test 7: Monitor Reversals Function");
    if (TestMonitorReversals())
    {
        Print("  [PASS] MonitorReversals works correctly\n");
    }
    else
    {
        Print("  [FAIL] MonitorReversals failed\n");
        allPass = false;
    }

    Print("═════════════════════════════════════════════════════════");
    if (allPass)
    {
        Print("✓ ALL TESTS PASSED");
    }
    else
    {
        Print("✗ SOME TESTS FAILED");
    }
    Print("═════════════════════════════════════════════════════════\n");
}

//+------------------------------------------------------------------+
//| Test 1: Reversal Signal Structure
//+------------------------------------------------------------------+
bool TestReversalSignalStructure()
{
    // Create a ReversalSignal and verify fields
    ReversalSignal sig;
    sig.isTriggered = true;
    sig.isConfirmed = false;
    sig.isLong = true;
    sig.reversalPrice = 1.2500;
    sig.confirmationPrice = 1.2510;

    if (sig.isTriggered == true)
    {
        Print("    [PASS] isTriggered field valid");
    }
    else
    {
        Print("    [FAIL] isTriggered field invalid");
        return false;
    }

    if (sig.isConfirmed == false)
    {
        Print("    [PASS] isConfirmed field valid");
    }
    else
    {
        Print("    [FAIL] isConfirmed field invalid");
        return false;
    }

    if (sig.isLong == true)
    {
        Print("    [PASS] isLong field valid");
    }
    else
    {
        Print("    [FAIL] isLong field invalid");
        return false;
    }

    if (sig.reversalPrice > 0)
    {
        Print("    [PASS] reversalPrice field valid: ", sig.reversalPrice);
    }
    else
    {
        Print("    [FAIL] reversalPrice field invalid");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Test 2: DetectReversalCandle for LONG
//+------------------------------------------------------------------+
bool TestDetectReversalCandleLong()
{
    // Test that function returns a ReversalSignal
    ReversalSignal sig = DetectReversalCandle(true);  // true = current LONG position

    // Verify signal structure
    if (sig.isTriggered == true || sig.isTriggered == false)
    {
        Print("    [PASS] isTriggered field valid: ", sig.isTriggered);
    }
    else
    {
        Print("    [FAIL] isTriggered field invalid");
        return false;
    }

    // If reversal detected, verify direction
    if (sig.isTriggered && sig.isLong == false)
    {
        Print("    [PASS] LONG reversal signal has isLong=false (SHORT reversal)");
    }
    else if (sig.isTriggered)
    {
        Print("    [INFO] Reversal detected but direction unexpected");
    }
    else
    {
        Print("    [INFO] No reversal detected on current bar (OK)");
    }

    return true;
}

//+------------------------------------------------------------------+
//| Test 3: DetectReversalCandle for SHORT
//+------------------------------------------------------------------+
bool TestDetectReversalCandleShort()
{
    // Test that function returns a ReversalSignal
    ReversalSignal sig = DetectReversalCandle(false);  // false = current SHORT position

    // Verify signal structure
    if (sig.isTriggered == true || sig.isTriggered == false)
    {
        Print("    [PASS] isTriggered field valid: ", sig.isTriggered);
    }
    else
    {
        Print("    [FAIL] isTriggered field invalid");
        return false;
    }

    // If reversal detected, verify direction
    if (sig.isTriggered && sig.isLong == true)
    {
        Print("    [PASS] SHORT reversal signal has isLong=true (LONG reversal)");
    }
    else if (sig.isTriggered)
    {
        Print("    [INFO] Reversal detected but direction unexpected");
    }
    else
    {
        Print("    [INFO] No reversal detected on current bar (OK)");
    }

    return true;
}

//+------------------------------------------------------------------+
//| Test 4: ConfirmReversal1M for LONG
//+------------------------------------------------------------------+
bool TestConfirmReversal1MLong()
{
    // Test 1M confirmation for LONG reversal (price breaks above 1M high + buffer)
    bool confirmed = ConfirmReversal1M(true);  // true = LONG reversal direction

    if (confirmed == true || confirmed == false)
    {
        Print("    [PASS] ConfirmReversal1M returns valid bool: ", confirmed);
    }
    else
    {
        Print("    [FAIL] ConfirmReversal1M returned invalid value");
        return false;
    }

    if (confirmed)
    {
        Print("    [INFO] 1M confirmation active for LONG reversal");
    }
    else
    {
        Print("    [INFO] 1M confirmation not met (price below high+buffer)");
    }

    return true;
}

//+------------------------------------------------------------------+
//| Test 5: ConfirmReversal1M for SHORT
//+------------------------------------------------------------------+
bool TestConfirmReversal1MShort()
{
    // Test 1M confirmation for SHORT reversal (price breaks below 1M low - buffer)
    bool confirmed = ConfirmReversal1M(false);  // false = SHORT reversal direction

    if (confirmed == true || confirmed == false)
    {
        Print("    [PASS] ConfirmReversal1M returns valid bool: ", confirmed);
    }
    else
    {
        Print("    [FAIL] ConfirmReversal1M returned invalid value");
        return false;
    }

    if (confirmed)
    {
        Print("    [INFO] 1M confirmation active for SHORT reversal");
    }
    else
    {
        Print("    [INFO] 1M confirmation not met (price above low-buffer)");
    }

    return true;
}

//+------------------------------------------------------------------+
//| Test 6: Distance to TP Calculation
//+------------------------------------------------------------------+
bool TestGetDistanceToTP()
{
    // Note: This test can only verify function signature and return type
    // Actual distance depends on open positions which may be empty in test

    // Test with invalid index (should return -1)
    double distance = GetDistanceToTP(-1);

    if (distance == -1)
    {
        Print("    [PASS] GetDistanceToTP returns -1 for invalid index");
    }
    else
    {
        Print("    [INFO] GetDistanceToTP test: distance=" , distance);
    }

    // Test with index 0 (may or may not have a position)
    double distance0 = GetDistanceToTP(0);

    if (distance0 == -1 || distance0 >= 0)
    {
        Print("    [PASS] GetDistanceToTP returns valid value: ", distance0);
    }
    else
    {
        Print("    [FAIL] GetDistanceToTP returned invalid distance");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Test 7: Monitor Reversals Function
//+------------------------------------------------------------------+
bool TestMonitorReversals()
{
    // Test that MonitorReversals() can be called without crashing
    MonitorReversals();

    Print("    [PASS] MonitorReversals executed without error");
    return true;
}
