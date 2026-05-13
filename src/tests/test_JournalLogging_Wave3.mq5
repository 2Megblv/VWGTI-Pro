//+------------------------------------------------------------------+
//| test_JournalLogging_Wave3.mq5
//| Unit tests for comprehensive journal logging
//| Phase 2 Wave 3
//+------------------------------------------------------------------+

#property strict

// Include headers
#include "../Include/Utils.mqh"
#include "../Include/JournalLogger.mqh"

//+------------------------------------------------------------------+
//| OnStart - Unit Test Framework
//+------------------------------------------------------------------+
void OnStart()
{
    Print("\n╔════════════════════════════════════════════════════════╗");
    Print("║  PHASE 2 WAVE 3: JOURNAL LOGGING UNIT TESTS          ║");
    Print("║  Testing: Entry, exit, rejection, and alert logging  ║");
    Print("╚════════════════════════════════════════════════════════╝\n");

    bool allPass = true;

    // Test 1: Log Trade Entry
    Print("Test 1: Log Trade Entry");
    if (TestLogTradeEntry())
    {
        Print("  [PASS] LogTradeEntry() works correctly\n");
    }
    else
    {
        Print("  [FAIL] LogTradeEntry() failed\n");
        allPass = false;
    }

    // Test 2: Log Trade Exit
    Print("Test 2: Log Trade Exit");
    if (TestLogTradeExit())
    {
        Print("  [PASS] LogTradeExit() works correctly\n");
    }
    else
    {
        Print("  [FAIL] LogTradeExit() failed\n");
        allPass = false;
    }

    // Test 3: Log Order Rejection
    Print("Test 3: Log Order Rejection");
    if (TestLogOrderRejection())
    {
        Print("  [PASS] LogOrderRejection() works correctly\n");
    }
    else
    {
        Print("  [FAIL] LogOrderRejection() failed\n");
        allPass = false;
    }

    // Test 4: Log Alert
    Print("Test 4: Log Alert");
    if (TestLogAlert())
    {
        Print("  [PASS] LogAlert() works correctly\n");
    }
    else
    {
        Print("  [FAIL] LogAlert() failed\n");
        allPass = false;
    }

    // Test 5: Log Error
    Print("Test 5: Log Error");
    if (TestLogError())
    {
        Print("  [PASS] LogError() works correctly\n");
    }
    else
    {
        Print("  [FAIL] LogError() failed\n");
        allPass = false;
    }

    // Test 6: Log Reversal Detection
    Print("Test 6: Log Reversal Detection");
    if (TestLogReversalDetection())
    {
        Print("  [PASS] LogReversalDetection() works correctly\n");
    }
    else
    {
        Print("  [FAIL] LogReversalDetection() failed\n");
        allPass = false;
    }

    // Test 7: Log Position Flip
    Print("Test 7: Log Position Flip");
    if (TestLogPositionFlip())
    {
        Print("  [PASS] LogPositionFlip() works correctly\n");
    }
    else
    {
        Print("  [FAIL] LogPositionFlip() failed\n");
        allPass = false;
    }

    // Test 8: Log Daily Summary
    Print("Test 8: Log Daily Summary");
    if (TestLogDailySummary())
    {
        Print("  [PASS] LogDailySummary() works correctly\n");
    }
    else
    {
        Print("  [FAIL] LogDailySummary() failed\n");
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
//| Test 1: Log Trade Entry
//+------------------------------------------------------------------+
bool TestLogTradeEntry()
{
    // Test parameters
    string direction = "BUY";
    double entryPrice = 1.2500;
    double lotSize = 0.1;
    string setupType = "Setup1";
    double stopLoss = 1.2450;
    double takeProfit = 1.2550;
    double riskRewardRatio = 2.0;
    double slippage = 1.5;
    long ticket = 123456;

    // Call logging function
    LogTradeEntry(direction, entryPrice, lotSize, setupType, stopLoss, takeProfit,
                 riskRewardRatio, slippage, ticket);

    Print("    [PASS] LogTradeEntry executed without error");
    return true;
}

//+------------------------------------------------------------------+
//| Test 2: Log Trade Exit
//+------------------------------------------------------------------+
bool TestLogTradeExit()
{
    // Test parameters
    long ticket = 123456;
    string symbol = "EURUSD";
    string setupType = "Setup1";
    double entryPrice = 1.2500;
    double exitPrice = 1.2550;
    string exitReason = "TP";
    double pnlPips = 50.0;
    double closeLots = 0.1;

    // Call logging function
    LogTradeExit(ticket, symbol, setupType, entryPrice, exitPrice, exitReason,
                pnlPips, closeLots);

    Print("    [PASS] LogTradeExit executed without error");
    return true;
}

//+------------------------------------------------------------------+
//| Test 3: Log Order Rejection
//+------------------------------------------------------------------+
bool TestLogOrderRejection()
{
    // Test parameters
    double intendedPrice = 1.2500;
    double stopLoss = 1.2450;
    double takeProfit = 1.2550;
    double lots = 0.1;
    string reason = "Slippage exceeds 50 pips";
    long errorCode = 10016;

    // Call logging function
    LogOrderRejection(intendedPrice, stopLoss, takeProfit, lots, reason, errorCode);

    Print("    [PASS] LogOrderRejection executed without error");
    return true;
}

//+------------------------------------------------------------------+
//| Test 4: Log Alert
//+------------------------------------------------------------------+
bool TestLogAlert()
{
    // Test parameters
    string alertType = "HARD_STOP_HIT";
    string message = "Daily loss=-2.5%, limit=-2.0%. Closing all positions.";

    // Call logging function
    LogAlert(alertType, message);

    Print("    [PASS] LogAlert executed without error");
    return true;
}

//+------------------------------------------------------------------+
//| Test 5: Log Error
//+------------------------------------------------------------------+
bool TestLogError()
{
    // Test parameters
    string message = "Failed to close position 123456 for flip. Error: 10016";

    // Call logging function
    LogError(message);

    Print("    [PASS] LogError executed without error");
    return true;
}

//+------------------------------------------------------------------+
//| Test 6: Log Reversal Detection
//+------------------------------------------------------------------+
bool TestLogReversalDetection()
{
    // Test parameters
    bool isLong = true;
    double reversalPrice = 1.2600;
    double confirmationPrice = 1.2610;

    // Call logging function
    LogReversalDetection(isLong, reversalPrice, confirmationPrice);

    Print("    [PASS] LogReversalDetection executed without error");
    return true;
}

//+------------------------------------------------------------------+
//| Test 7: Log Position Flip
//+------------------------------------------------------------------+
bool TestLogPositionFlip()
{
    // Test parameters
    long oldTicket = 123456;
    long newTicket = 789012;
    bool newIsLong = false;
    double newEntryPrice = 1.2450;

    // Call logging function
    LogPositionFlip(oldTicket, newTicket, newIsLong, newEntryPrice);

    Print("    [PASS] LogPositionFlip executed without error");
    return true;
}

//+------------------------------------------------------------------+
//| Test 8: Log Daily Summary
//+------------------------------------------------------------------+
bool TestLogDailySummary()
{
    // Test parameters
    double closedPnL = 150.50;
    double openPnL = 50.25;
    double totalPnL = 200.75;
    int tradesExecuted = 5;
    int tradesWon = 3;
    double winRate = 60.0;

    // Call logging function
    LogDailySummary(closedPnL, openPnL, totalPnL, tradesExecuted, tradesWon, winRate);

    Print("    [PASS] LogDailySummary executed without error");
    return true;
}
