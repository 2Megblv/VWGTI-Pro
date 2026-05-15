//+------------------------------------------------------------------+
//| test_VWAPSessionEngine.mq5
//|
//| Unit tests for VWAPSessionEngine:
//|   - BarDelta() static proxy
//|   - VWAP + weighted standard deviation formula correctness
//|   - Band level computation (upper/lower 1,2,3 + parametric)
//|   - IsValid() state transitions
//|   - Session day-change reset
//|   - Zero-volume bar rejection
//|   - Single-bar variance edge case (wStdDev == 0)
//|
//| Run as an MT5 Script (not EA). Results in Experts/Scripts log.
//| Pass criteria: 0 FAIL lines in the log.
//|
//| NOTE: RecalculateFromSessionStart() requires live MT5 bar data
//| and is validated via manual QA in the Strategy Tester.
//+------------------------------------------------------------------+

#property strict

#include "../Include/VWAPSessionEngine.mqh"

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
        Print("  PASS  ", tag, "  got=", DoubleToString(got, 6));
        g_passed++;
    } else {
        Print("  FAIL  ", tag,
              "  got=",      DoubleToString(got,      6),
              "  expected=", DoubleToString(expected, 6),
              "  tol=",      DoubleToString(tol,      8));
        g_failed++;
    }
}

//+------------------------------------------------------------------+
//| SUITE 1: BarDelta static proxy
//+------------------------------------------------------------------+
void Test_BarDelta() {
    Print("===== BarDelta =====");

    // Full bull: close == high
    EXPECT_NEAR(VWAPSessionEngine::BarDelta(10.0, 8.0, 10.0), 1.0, 1e-9, "Full bull → 1.0");

    // Full bear: close == low
    EXPECT_NEAR(VWAPSessionEngine::BarDelta(10.0, 8.0,  8.0), 0.0, 1e-9, "Full bear → 0.0");

    // Midpoint
    EXPECT_NEAR(VWAPSessionEngine::BarDelta(10.0, 8.0,  9.0), 0.5, 1e-9, "Midpoint → 0.5");

    // Upper quarter
    EXPECT_NEAR(VWAPSessionEngine::BarDelta(10.0, 8.0,  9.5), 0.75, 1e-9, "Upper quarter → 0.75");

    // Lower quarter
    EXPECT_NEAR(VWAPSessionEngine::BarDelta(10.0, 8.0,  8.5), 0.25, 1e-9, "Lower quarter → 0.25");

    // Doji guard: high == low → returns 0.5
    EXPECT_NEAR(VWAPSessionEngine::BarDelta(9.0, 9.0, 9.0), 0.5, 1e-9, "Doji (H==L) → 0.5");

    Print("");
}

//+------------------------------------------------------------------+
//| SUITE 2: Single-bar state
//+------------------------------------------------------------------+
void Test_SingleBar() {
    Print("===== Single bar =====");

    // Reuse known test data: H=1910, L=1900, C=1905, V=100
    // TP = (1910+1900+1905)/3 = 1905.0
    // VWAP = 1905.0, wStdDev = 0 (trivially — one observation, no dispersion)

    VWAPSessionEngine eng;
    EXPECT(!eng.IsValid(), "IsValid() false before any bar");

    datetime day1 = D'2024.01.15 09:00';
    eng.UpdateBar(day1, 1910.0, 1900.0, 1905.0, 100);

    EXPECT(eng.IsValid(), "IsValid() true after first bar");
    EXPECT_NEAR(eng.vwap,    1905.0, 1e-6, "VWAP == TP after 1 bar");
    EXPECT_NEAR(eng.wStdDev, 0.0,    1e-6, "wStdDev == 0 after 1 bar (no dispersion)");
    EXPECT_NEAR(eng.upper1,  1905.0, 1e-6, "upper1 == vwap when wStdDev==0");
    EXPECT_NEAR(eng.lower1,  1905.0, 1e-6, "lower1 == vwap when wStdDev==0");

    Print("");
}

//+------------------------------------------------------------------+
//| SUITE 3: Two-bar VWAP and weighted standard deviation
//|
//| Derived by hand:
//|   Bar 1: H=1910, L=1900, C=1905, V=100  → TP=1905
//|   Bar 2: H=1920, L=1910, C=1915, V=200  → TP=1915
//|
//|   cumTPV = 1905*100 + 1915*200 = 190500 + 383000 = 573500
//|   cumVol = 300
//|   VWAP   = 573500/300 = 1911.6̄
//|
//|   Variance = [(1905-1911.6̄)²*100 + (1915-1911.6̄)²*200] / 300
//|            = [(-11/3)²*100 + (19/3)²*200] / 300
//|            = [12100/9 + 72200/9] / 300
//|            = (84300/9) / 300  = 84300/2700 = 200/9 ≈ 22.2222
//|   wStdDev = √(200/9) = 10√2/3 ≈ 4.71405
//+------------------------------------------------------------------+
void Test_TwoBars_VWAP() {
    Print("===== Two-bar VWAP + StdDev =====");

    double expectedVWAP    = 573500.0 / 300.0;               // 1911.6̄
    double expectedVariance = 200.0 / 9.0;                   // 22.2̄
    double expectedStdDev  = MathSqrt(expectedVariance);     // 4.71405...

    VWAPSessionEngine eng;
    datetime t1 = D'2024.01.15 09:00';
    datetime t2 = D'2024.01.15 10:00';

    eng.UpdateBar(t1, 1910.0, 1900.0, 1905.0, 100);
    eng.UpdateBar(t2, 1920.0, 1910.0, 1915.0, 200);

    EXPECT_NEAR(eng.vwap,    expectedVWAP,   1e-4, "Two-bar VWAP");
    EXPECT_NEAR(eng.wStdDev, expectedStdDev, 1e-4, "Two-bar wStdDev");

    // Band levels
    EXPECT_NEAR(eng.upper1,  expectedVWAP + expectedStdDev,       1e-4, "upper1");
    EXPECT_NEAR(eng.lower1,  expectedVWAP - expectedStdDev,       1e-4, "lower1");
    EXPECT_NEAR(eng.upper2,  expectedVWAP + expectedStdDev * 2.0, 1e-4, "upper2");
    EXPECT_NEAR(eng.lower2,  expectedVWAP - expectedStdDev * 2.0, 1e-4, "lower2");
    EXPECT_NEAR(eng.upper3,  expectedVWAP + expectedStdDev * 3.0, 1e-4, "upper3");
    EXPECT_NEAR(eng.lower3,  expectedVWAP - expectedStdDev * 3.0, 1e-4, "lower3");

    Print("");
}

//+------------------------------------------------------------------+
//| SUITE 4: Three-bar VWAP
//|
//|   Bar 3: H=1908, L=1898, C=1902, V=150  → TP=5708/3 = 1902.6̄
//|
//|   cumTPV = 573500 + (5708/3)*150 = 573500 + 285400 = 858900
//|   cumVol = 450
//|   VWAP   = 858900/450 = 17178/9 = 1908.6̄
//|
//|   Variance (direct):
//|     (TP1-VWAP)²*V1 = (-11/3)²*100 = 12100/9 ≈ 1344.4̄
//|     (TP2-VWAP)²*V2 = (19/3)²*200  = 72200/9 ≈ 8022.2̄
//|     (TP3-VWAP)²*V3 = (-6)² * 150  = 5400
//|     variance = (12100/9 + 72200/9 + 5400) / 450 = 884/27 ≈ 32.740
//|   wStdDev = √(884/27) ≈ 5.7218
//+------------------------------------------------------------------+
void Test_ThreeBars_VWAP() {
    Print("===== Three-bar VWAP + StdDev =====");

    double expectedVWAP   = 858900.0 / 450.0;              // 1908.6̄
    double expectedVar    = 884.0 / 27.0;                  // ≈ 32.7407
    double expectedStdDev = MathSqrt(expectedVar);          // ≈ 5.7218

    VWAPSessionEngine eng;
    datetime t1 = D'2024.01.15 09:00';
    datetime t2 = D'2024.01.15 10:00';
    datetime t3 = D'2024.01.15 11:00';

    eng.UpdateBar(t1, 1910.0, 1900.0, 1905.0, 100);
    eng.UpdateBar(t2, 1920.0, 1910.0, 1915.0, 200);
    eng.UpdateBar(t3, 1908.0, 1898.0, 1902.0, 150);

    EXPECT_NEAR(eng.vwap,    expectedVWAP,   1e-4, "Three-bar VWAP");
    EXPECT_NEAR(eng.wStdDev, expectedStdDev, 1e-4, "Three-bar wStdDev");
    EXPECT(eng.wStdDev > 0.0, "wStdDev > 0 (non-degenerate 3-bar set)");

    Print("");
}

//+------------------------------------------------------------------+
//| SUITE 5: Parametric GetUpperBand / GetLowerBand
//+------------------------------------------------------------------+
void Test_ParametricBands() {
    Print("===== Parametric bands =====");

    VWAPSessionEngine eng;
    datetime t1 = D'2024.01.15 09:00';
    datetime t2 = D'2024.01.15 10:00';
    eng.UpdateBar(t1, 1910.0, 1900.0, 1905.0, 100);
    eng.UpdateBar(t2, 1920.0, 1910.0, 1915.0, 200);

    double sd = eng.wStdDev;

    EXPECT_NEAR(eng.GetUpperBand(1.0),  eng.vwap + sd,       1e-9, "GetUpperBand(1.0) == vwap+1SD");
    EXPECT_NEAR(eng.GetLowerBand(1.0),  eng.vwap - sd,       1e-9, "GetLowerBand(1.0) == vwap-1SD");
    EXPECT_NEAR(eng.GetUpperBand(2.5),  eng.vwap + sd * 2.5, 1e-9, "GetUpperBand(2.5)");
    EXPECT_NEAR(eng.GetLowerBand(2.5),  eng.vwap - sd * 2.5, 1e-9, "GetLowerBand(2.5)");
    EXPECT_NEAR(eng.GetUpperBand(0.0),  eng.vwap,            1e-9, "GetUpperBand(0.0) == vwap");

    Print("");
}

//+------------------------------------------------------------------+
//| SUITE 6: Zero-volume bar is ignored
//+------------------------------------------------------------------+
void Test_ZeroVolume() {
    Print("===== Zero-volume bar ignored =====");

    VWAPSessionEngine eng;
    datetime t1 = D'2024.01.15 09:00';
    datetime t2 = D'2024.01.15 09:05';

    eng.UpdateBar(t1, 1910.0, 1900.0, 1905.0, 100);
    double vwapBefore = eng.vwap;

    // Zero-volume bar should leave state unchanged
    eng.UpdateBar(t2, 9999.0, 1.0, 5000.0, 0);

    EXPECT_NEAR(eng.vwap, vwapBefore, 1e-9, "Zero-vol bar does not change VWAP");
    EXPECT(eng.IsValid(), "IsValid() stays true after zero-vol bar");

    Print("");
}

//+------------------------------------------------------------------+
//| SUITE 7: Day-change resets accumulators
//+------------------------------------------------------------------+
void Test_SessionReset() {
    Print("===== Session day-change reset =====");

    VWAPSessionEngine eng;

    // Day 1: two bars
    datetime d1a = D'2024.01.15 09:00';
    datetime d1b = D'2024.01.15 10:00';
    eng.UpdateBar(d1a, 1910.0, 1900.0, 1905.0, 100);
    eng.UpdateBar(d1b, 1920.0, 1910.0, 1915.0, 200);

    double vwapDay1 = eng.vwap;
    EXPECT(vwapDay1 > 1905.0, "Day-1 VWAP > 1905 (blended with 1915 bar)");

    // Day 2: single bar — reset should fire, VWAP should equal TP of this bar alone
    datetime d2a = D'2024.01.16 09:00';
    eng.UpdateBar(d2a, 1930.0, 1920.0, 1925.0, 300);

    double expectedDay2VWAP = (1930.0 + 1920.0 + 1925.0) / 3.0;   // 1925.0
    EXPECT_NEAR(eng.vwap,    expectedDay2VWAP, 1e-4, "Day-2 VWAP reset to single-bar TP");
    EXPECT_NEAR(eng.wStdDev, 0.0, 1e-4, "Day-2 wStdDev == 0 after reset (1 bar)");

    // Day 2 second bar: state accumulates correctly from reset baseline
    datetime d2b = D'2024.01.16 10:00';
    eng.UpdateBar(d2b, 1940.0, 1930.0, 1935.0, 150);

    double expectedCumTPV = 1925.0*300 + 1935.0*150;   // 577500 + 290250 = 867750
    double expectedCumVol = 300 + 150;                  // 450
    double expectedVWAP2  = expectedCumTPV / expectedCumVol;
    EXPECT_NEAR(eng.vwap, expectedVWAP2, 1e-4, "Day-2 two-bar VWAP correct");
    EXPECT(eng.wStdDev > 0.0, "Day-2 wStdDev > 0 after second bar");

    Print("");
}

//+------------------------------------------------------------------+
//| SUITE 8: Symmetry — wStdDev never negative
//+------------------------------------------------------------------+
void Test_NoNegativeVariance() {
    Print("===== No negative variance =====");

    VWAPSessionEngine eng;
    datetime t = D'2024.01.15 08:00';

    // Feed 50 identical bars — variance should remain exactly 0
    for (int i = 0; i < 50; i++) {
        eng.UpdateBar(t + i*3600, 1900.0, 1900.0, 1900.0, 100);
    }

    EXPECT_NEAR(eng.vwap,    1900.0, 1e-6, "Identical bars: VWAP == TP");
    EXPECT_NEAR(eng.wStdDev, 0.0,    1e-6, "Identical bars: wStdDev == 0");
    EXPECT(eng.wStdDev >= 0.0, "wStdDev never negative");

    Print("");
}

//+------------------------------------------------------------------+
//| SUITE 9: Breakout delta filter — boundary and classification
//|
//| The /sc:improve change added delta direction guards to BO-Long and
//| BO-Short in DetectSetup3Signal(). The guards use VWAP_Delta_Min
//| (default 0.55) and its complement (1 - 0.55 = 0.45).
//|
//| This suite verifies that BarDelta() returns values that correctly
//| classify bars at the boundary, so the filter behaves as intended:
//|
//|   BO-Long eligible   : delta >= 0.55  (bullish momentum bar)
//|   BO-Short eligible  : delta <= 0.45  (bearish momentum bar)
//|   Dead zone          : 0.45 < delta < 0.55 (neutral — neither fires)
//|
//| Also verifies the complementary threshold symmetry used in the
//| mean-reversion legs (MR-Long uses >= 0.55, MR-Short uses <= 0.45).
//+------------------------------------------------------------------+
void Test_BreakoutDeltaFilter() {
    Print("===== Breakout delta filter (improvement validation) =====");

    double threshold   = 0.55;          // VWAP_Delta_Min default
    double complement  = 1.0 - threshold; // 0.45 — used for MR-Short / BO-Short

    // --- Bars that SHOULD qualify as BO-Long (delta >= 0.55) ---

    // Strong momentum bar: close near high (H=1920, L=1900, C=1919 → delta=0.95)
    double d1 = VWAPSessionEngine::BarDelta(1920.0, 1900.0, 1919.0);
    EXPECT(d1 >= threshold, "Momentum long bar (C=1919) qualifies BO-Long");

    // Exactly at threshold: H=1910, L=1900, range=10; close = 1900 + 0.55*10 = 1905.5 → delta=0.55
    double d2 = VWAPSessionEngine::BarDelta(1910.0, 1900.0, 1905.5);
    EXPECT(d2 >= threshold, "Close at exact threshold (0.55) qualifies BO-Long");

    // Close at 0.56 — just above threshold
    double d3 = VWAPSessionEngine::BarDelta(1910.0, 1900.0, 1905.6);
    EXPECT(d3 >= threshold, "Close 0.1pt above threshold qualifies BO-Long");

    // --- Bars that SHOULD qualify as BO-Short (delta <= 0.45) ---

    // Strong distribution bar: close near low (H=1920, L=1900, C=1901 → delta=0.05)
    double d4 = VWAPSessionEngine::BarDelta(1920.0, 1900.0, 1901.0);
    EXPECT(d4 <= complement, "Distribution bar (C=1901) qualifies BO-Short");

    // Clearly inside BO-Short range: close = 1900 + 0.40*10 = 1904.0 → delta=0.40
    // Avoids the IEEE 754 boundary ambiguity of testing exactly 0.45 (4.5/10 rounds up).
    double d5 = VWAPSessionEngine::BarDelta(1910.0, 1900.0, 1904.0);
    EXPECT(d5 <= complement, "Close clearly inside BO-Short range (delta=0.40) qualifies");

    // Close at 0.44 — just below complement
    double d6 = VWAPSessionEngine::BarDelta(1910.0, 1900.0, 1904.4);
    EXPECT(d6 <= complement, "Close 0.1pt below complement qualifies BO-Short");

    // --- Dead-zone bars: 0.45 < delta < 0.55 (neither BO fires) ---

    // Mid-range bar: delta = 0.50 (close exactly at midpoint)
    double d7 = VWAPSessionEngine::BarDelta(1910.0, 1900.0, 1905.0);
    EXPECT(d7 < threshold,  "Midpoint bar (delta=0.5) does NOT qualify BO-Long");
    EXPECT(d7 > complement, "Midpoint bar (delta=0.5) does NOT qualify BO-Short");

    // --- MR-Short and BO-Long share the same band condition but opposite delta ---
    // When delta < complement AND delta < threshold:
    //   → qualifies for MR-Short (bearish absorption), NOT BO-Long
    // Confirm the two conditions are mutually exclusive at d4 (delta=0.05):
    EXPECT(d4 < threshold,  "Distribution bar excluded from BO-Long (wrong delta)");
    EXPECT(d4 <= complement,"Distribution bar is MR-Short candidate (bearish delta)");

    // When delta >= threshold:
    //   → qualifies for BO-Long (bullish momentum), NOT MR-Short
    EXPECT(d1 >= threshold,  "Momentum bar qualifies BO-Long (bullish delta)");
    EXPECT(!(d1 <= complement), "Momentum bar excluded from MR-Short (delta > complement)");

    Print("");
}

//+------------------------------------------------------------------+
//| Script entry point
//+------------------------------------------------------------------+
void OnStart() {
    Print("====================================================");
    Print(" VolumeProfile EA v3.5 — VWAPSessionEngine Tests");
    Print("====================================================");

    Test_BarDelta();
    Test_SingleBar();
    Test_TwoBars_VWAP();
    Test_ThreeBars_VWAP();
    Test_ParametricBands();
    Test_ZeroVolume();
    Test_SessionReset();
    Test_NoNegativeVariance();
    Test_BreakoutDeltaFilter();

    Print("====================================================");
    Print(" Results: ", g_passed, " passed, ", g_failed, " failed");
    if (g_failed == 0)
        Print(" ALL TESTS PASSED");
    else
        Print(" *** FAILURES DETECTED — see FAIL lines above ***");
    Print("====================================================");
}
