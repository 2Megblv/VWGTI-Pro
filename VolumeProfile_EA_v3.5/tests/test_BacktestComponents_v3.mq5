//+------------------------------------------------------------------+
//| test_BacktestComponents_v3.mq5
//|
//| Unit tests for:
//|   - BacktestLogger  (LogEntry, LogExit, GetRecord, FlushToCSV)
//|   - PerformanceMetrics.Calculate()
//|   - WalkForwardConfig.BuildWindows()
//|
//| Run as an MT5 Script (not EA). Results in Experts log.
//| Pass criteria: 0 FAIL lines in the log.
//+------------------------------------------------------------------+

#property strict

#include "../Include/BacktestLogger.mqh"
#include "../Include/PerformanceMetrics.mqh"
#include "../Include/WalkForwardConfig.mqh"

//--- test counters
static int g_passed = 0;
static int g_failed = 0;

void EXPECT(bool cond, string tag) {
    if (cond) {
        Print("  PASS  ", tag);
        g_passed++;
    } else {
        Print("  FAIL  ", tag);
        g_failed++;
    }
}

void EXPECT_NEAR(double got, double expected, double tol, string tag) {
    bool ok = MathAbs(got - expected) <= tol;
    if (ok) {
        Print("  PASS  ", tag, "  got=", DoubleToString(got, 4));
        g_passed++;
    } else {
        Print("  FAIL  ", tag,
              "  got=",      DoubleToString(got,      4),
              "  expected=", DoubleToString(expected, 4),
              "  tol=",      DoubleToString(tol,      6));
        g_failed++;
    }
}

//+------------------------------------------------------------------+
//| SUITE 1: BacktestLogger
//+------------------------------------------------------------------+
void Test_BacktestLogger() {
    Print("===== BacktestLogger =====");
    BacktestLogger bl;
    bl.Init("EURUSD");

    // ---- LogEntry ----
    bl.LogEntry(1001, "SETUP1", true,
                1.10000, 1.09000, 1.12000, 0.10,
                1.10500, 1.11000, 1.09500, 1.10800, true);

    EXPECT(bl.GetTradeCount() == 1, "LogEntry: count becomes 1");

    TradeRecord r;
    EXPECT(bl.GetRecord(0, r), "GetRecord(0) returns true");
    EXPECT(r.ticket     == 1001,      "ticket == 1001");
    EXPECT(r.setupType  == "SETUP1",  "setupType == SETUP1");
    EXPECT(r.isLong     == true,      "isLong == true");
    EXPECT_NEAR(r.entryPrice,    1.10000, 1e-6, "entryPrice");
    EXPECT_NEAR(r.stopLoss,      1.09000, 1e-6, "stopLoss");
    EXPECT_NEAR(r.takeProfit,    1.12000, 1e-6, "takeProfit");
    EXPECT_NEAR(r.lots,          0.10,    1e-6, "lots");
    EXPECT_NEAR(r.pocAtEntry,    1.10500, 1e-6, "pocAtEntry");
    EXPECT_NEAR(r.vahAtEntry,    1.11000, 1e-6, "vahAtEntry");
    EXPECT_NEAR(r.valAtEntry,    1.09500, 1e-6, "valAtEntry");
    EXPECT_NEAR(r.htfPocAtEntry, 1.10800, 1e-6, "htfPocAtEntry");
    EXPECT(r.wasBalanced  == true,  "wasBalanced == true");
    EXPECT(r.exitLogged   == false, "exitLogged starts false");
    // rrRatio: |tp - entry| / |entry - sl| = 0.02 / 0.01 = 2.0
    EXPECT_NEAR(r.rrRatio, 2.0, 1e-6, "rrRatio == 2.0");

    // ---- LogExit: LONG TP ----
    // pnlR = (exit - entry) / slDist = (1.11500 - 1.10000) / 0.01 = 1.5
    bl.LogExit(1001, 1.11500, "TP");
    EXPECT(bl.GetRecord(0, r), "GetRecord after exit");
    EXPECT(r.exitLogged == true, "exitLogged == true after LogExit");
    EXPECT(r.exitReason == "TP", "exitReason == TP");
    EXPECT_NEAR(r.exitPrice, 1.11500, 1e-6, "exitPrice == 1.11500");
    EXPECT_NEAR(r.pnlR, 1.5, 1e-6, "pnlR == 1.5R (LONG TP)");

    // ---- LogExit idempotency ----
    bl.LogExit(1001, 1.10000, "SL");  // must be ignored
    bl.GetRecord(0, r);
    EXPECT(r.exitReason == "TP", "Second LogExit ignored (still TP)");
    EXPECT_NEAR(r.pnlR, 1.5, 1e-6, "pnlR unchanged after duplicate exit");

    // ---- SHORT trade pnlR ----
    bl.LogEntry(1002, "SETUP2", false,
                1.20000, 1.21000, 1.18000, 0.05,
                1.20200, 1.20800, 1.19500, 1.20100, false);
    // slDist = |entry - sl| = 0.01
    // exit at 1.18500 → pnlR = (entry - exit) / slDist = (1.20000-1.18500)/0.01 = 1.5
    bl.LogExit(1002, 1.18500, "TP");
    EXPECT(bl.GetRecord(1, r), "GetRecord(1)");
    EXPECT(r.isLong == false, "SHORT: isLong == false");
    EXPECT_NEAR(r.pnlR, 1.5, 1e-6, "SHORT pnlR == 1.5R");

    // ---- GetRecord out of bounds ----
    TradeRecord dummy;
    EXPECT(!bl.GetRecord(-1,  dummy), "GetRecord(-1) returns false");
    EXPECT(!bl.GetRecord(100, dummy), "GetRecord(100) returns false");

    Print("");
}

//+------------------------------------------------------------------+
//| SUITE 2: PerformanceMetrics
//+------------------------------------------------------------------+
void Test_PerformanceMetrics() {
    Print("===== PerformanceMetrics =====");

    // Build 10 synthetic closed trades: 6 wins at +2R, 4 losses at -1R
    // Expected:
    //   winRate       = 60%
    //   expectancy    = 0.6*2 + 0.4*(-1) = 1.2 - 0.4 = 0.8R
    //   profitFactor  = (6*2) / (4*1) = 12/4 = 3.0
    //   totalR        = 6*2 + 4*(-1) = 12 - 4 = 8R

    TradeRecord records[];
    ArrayResize(records, 10);

    datetime t = D'2024.01.02 10:00';
    for (int i = 0; i < 10; i++) {
        records[i].ticket     = 3000 + i;
        records[i].isLong     = true;
        records[i].setupType  = (i < 5) ? "SETUP1" : "SETUP2";
        records[i].wasBalanced = (i % 2 == 0);  // alternating
        records[i].entryTime  = t;
        records[i].exitLogged = true;
        records[i].exitTime   = t + 3600;

        bool win = (i < 6);  // first 6 are wins
        records[i].entryPrice = 1.10000;
        records[i].stopLoss   = 1.09000;  // slDist = 0.01
        if (win) {
            records[i].exitPrice = 1.12000;   // +2R
            records[i].pnlR      = 2.0;
        } else {
            records[i].exitPrice = 1.09000;   // -1R
            records[i].pnlR      = -1.0;
        }
        t += 86400;  // each trade one day apart
    }

    PerformanceMetrics pm;
    PerformanceReport rep = pm.Calculate(records, 10, 10000.0);

    EXPECT(rep.totalTrades  == 10, "totalTrades == 10");
    EXPECT(rep.closedTrades == 10, "closedTrades == 10");
    EXPECT(rep.openTrades   == 0,  "openTrades == 0");
    EXPECT(rep.wins         == 6,  "wins == 6");
    EXPECT_NEAR(rep.winRate,       60.0, 0.01,  "winRate == 60%");
    EXPECT_NEAR(rep.expectancy,     0.8, 0.001, "expectancy == 0.8R");
    EXPECT_NEAR(rep.profitFactor,   3.0, 0.001, "profitFactor == 3.0");
    EXPECT_NEAR(rep.totalR,         8.0, 0.001, "totalR == 8.0R");
    EXPECT_NEAR(rep.avgWinR,        2.0, 0.001, "avgWinR == 2.0R");
    EXPECT_NEAR(rep.avgLossR,      -1.0, 0.001, "avgLossR == -1.0R");
    EXPECT_NEAR(rep.maxWinR,        2.0, 0.001, "maxWinR == 2.0R");
    EXPECT_NEAR(rep.maxLossR,      -1.0, 0.001, "maxLossR == -1.0R");

    // Equity curve: 2,2,2,2,2,2,-1,-1,-1,-1 cumulative: 2,4,6,8,10,12,11,10,9,8
    // Peak = 12, lowest after peak = 8 → max drawdown = 4R
    EXPECT_NEAR(rep.maxDrawdownR, 4.0, 0.001, "maxDrawdownR == 4.0R");

    // Calmar > 0 (positive total R with positive drawdown)
    EXPECT(rep.calmarR > 0.0, "calmarR > 0");

    // Setup breakdown
    EXPECT(rep.setup1.count == 5, "setup1.count == 5");
    EXPECT(rep.setup2.count == 5, "setup2.count == 5");
    // setup1: trades 0-4, wins = trades 0-4 → all 5 wins
    EXPECT(rep.setup1.wins == 5, "setup1.wins == 5");
    // setup2: trades 5-9, wins = trade 5 only
    EXPECT(rep.setup2.wins == 1, "setup2.wins == 1");

    // Empty input guard
    TradeRecord empty[];
    PerformanceReport rep0 = pm.Calculate(empty, 0);
    EXPECT(rep0.totalTrades == 0, "empty input: totalTrades == 0");
    EXPECT_NEAR(rep0.winRate, 0.0, 1e-9, "empty input: winRate == 0");

    Print("");
}

//+------------------------------------------------------------------+
//| SUITE 3: WalkForwardConfig
//+------------------------------------------------------------------+
void Test_WalkForwardConfig() {
    Print("===== WalkForwardConfig =====");

    WalkForwardConfig wfc;
    datetime rangeStart = D'2022.01.01';
    datetime rangeEnd   = D'2025.12.31';
    wfc.BuildWindows(rangeStart, rangeEnd, 12, 3, 3);

    // IS=12mo, OOS=3mo, step=3mo over 4 years → 13 windows
    EXPECT(wfc.GetWindowCount() == 13, "WindowCount == 13");

    // Window 1: IS starts 2022-01-01
    WFWindow w1 = wfc.GetWindow(0);
    EXPECT(w1.id == 1, "Window[0].id == 1");

    MqlDateTime dt1;
    TimeToStruct(w1.inSampleStart, dt1);
    EXPECT(dt1.year == 2022 && dt1.mon == 1 && dt1.day == 1,
           "Window[0].inSampleStart == 2022-01-01");

    // Window 1 OOS end: IS = 12mo from 2022-01-01 → OOS starts 2023-01-01
    // OOS = 3mo → OOS end = day before 2023-04-01 = 2023-03-31 23:59:59
    MqlDateTime dtOosEnd;
    TimeToStruct(w1.outSampleEnd, dtOosEnd);
    EXPECT(dtOosEnd.year == 2023 && dtOosEnd.mon == 3,
           "Window[0].outSampleEnd in month 2023-03");

    // Window 2: IS starts 3 months later = 2022-04-01
    WFWindow w2 = wfc.GetWindow(1);
    MqlDateTime dt2;
    TimeToStruct(w2.inSampleStart, dt2);
    EXPECT(dt2.year == 2022 && dt2.mon == 4 && dt2.day == 1,
           "Window[1].inSampleStart == 2022-04-01");

    // Last window (index 12): IS starts 2022-01-01 + 12*3mo = 2022-01-01 + 36mo = 2025-01-01
    WFWindow wLast = wfc.GetWindow(12);
    MqlDateTime dtLast;
    TimeToStruct(wLast.inSampleStart, dtLast);
    EXPECT(dtLast.year == 2025 && dtLast.mon == 1 && dtLast.day == 1,
           "Window[12].inSampleStart == 2025-01-01");
    EXPECT(wLast.id == 13, "Window[12].id == 13");

    // Label non-empty
    EXPECT(StringLen(w1.label) > 0, "Window[0].label non-empty");

    // Out-of-bounds guard: GetWindow with invalid index returns zero-struct (id==0)
    WFWindow wOob = wfc.GetWindow(99);
    EXPECT(wOob.id == 0, "GetWindow(99) returns zero-struct (id==0)");

    // stepMonths=0 defaults to outSampleMonths
    WalkForwardConfig wfc2;
    wfc2.BuildWindows(rangeStart, rangeEnd, 12, 3, 0);
    EXPECT(wfc2.GetWindowCount() == wfc.GetWindowCount(),
           "stepMonths=0 == stepMonths=outSampleMonths (same count)");

    Print("");
}

//+------------------------------------------------------------------+
//| SUITE 4: PerformanceMetrics — Setup3 attribution (C1 fix)
//|
//| Verifies that S3-* tags route to setup3 and NOT to setup2.
//| Mix: 4 SETUP1, 3 SETUP2, 3 S3 trades (S3-MR-L x2, S3-BO-S x1).
//| setup3 wins: S3-MR-L[0]=+2R(win), S3-MR-L[1]=-1R(loss), S3-BO-S[0]=+2R(win)
//+------------------------------------------------------------------+
void Test_PerformanceMetrics_Setup3() {
    Print("===== PerformanceMetrics — Setup3 attribution =====");

    TradeRecord records[];
    ArrayResize(records, 10);

    datetime t = D'2024.03.01 10:00';
    string tags[] = {"SETUP1","SETUP1","SETUP1","SETUP1",
                     "SETUP2","SETUP2","SETUP2",
                     "S3-MR-L","S3-MR-L","S3-BO-S"};
    // pnlR values: first 4 S1 are wins (+2R), 3 S2 are losses (-1R),
    //             S3-MR-L[0]=+2R, S3-MR-L[1]=-1R, S3-BO-S=+2R
    double pnls[] = {2.0, 2.0, 2.0, 2.0, -1.0, -1.0, -1.0, 2.0, -1.0, 2.0};

    for (int i = 0; i < 10; i++) {
        records[i].ticket      = 5000 + i;
        records[i].setupType   = tags[i];
        records[i].isLong      = true;
        records[i].wasBalanced = false;
        records[i].entryPrice  = 2000.0;
        records[i].stopLoss    = 1990.0;
        records[i].entryTime   = t;
        records[i].exitLogged  = true;
        records[i].exitTime    = t + 3600;
        records[i].pnlR        = pnls[i];
        t += 86400;
    }

    PerformanceMetrics pm;
    PerformanceReport  rep = pm.Calculate(records, 10, 10000.0);

    // --- Setup1 bucket (4 trades, all wins) ---
    EXPECT(rep.setup1.count == 4, "S3 fix: setup1.count == 4");
    EXPECT(rep.setup1.wins  == 4, "S3 fix: setup1.wins  == 4");

    // --- Setup2 bucket (3 trades, all losses) — must NOT include S3 trades ---
    EXPECT(rep.setup2.count == 3, "S3 fix: setup2.count == 3 (no S3 bleed)");
    EXPECT(rep.setup2.wins  == 0, "S3 fix: setup2.wins  == 0");

    // --- Setup3 bucket (3 trades: 2 wins, 1 loss) ---
    EXPECT(rep.setup3.count == 3, "S3 fix: setup3.count == 3");
    EXPECT(rep.setup3.wins  == 2, "S3 fix: setup3.wins  == 2");

    // setup3 expectancy = (2*2 + (-1)) / 3 = 3/3 = 1.0R
    EXPECT_NEAR(rep.setup3.expectancy, 1.0, 0.001, "S3 fix: setup3.expectancy == 1.0R");

    // Totals unaffected
    EXPECT(rep.totalTrades   == 10, "S3 fix: totalTrades == 10");
    EXPECT(rep.closedTrades  == 10, "S3 fix: closedTrades == 10");
    EXPECT(rep.wins          ==  6, "S3 fix: total wins == 6");

    Print("");
}

//+------------------------------------------------------------------+
//| Script entry point
//+------------------------------------------------------------------+
void OnStart() {
    Print("====================================================");
    Print(" VolumeProfile EA v3.5 — Unit Test Suite");
    Print("====================================================");

    Test_BacktestLogger();
    Test_PerformanceMetrics();
    Test_PerformanceMetrics_Setup3();
    Test_WalkForwardConfig();

    Print("====================================================");
    Print(" Results: ", g_passed, " passed, ", g_failed, " failed");
    if (g_failed == 0)
        Print(" ALL TESTS PASSED");
    else
        Print(" *** FAILURES DETECTED — see FAIL lines above ***");
    Print("====================================================");
}
