//+------------------------------------------------------------------+
//| VWAPSessionEngine.mqh - Session VWAP with Weighted Std-Dev Bands|
//|                                                                  |
//| Cumulative (non-repainting) calculation:                         |
//|   VWAP = Σ(TP × Vol) / ΣVol                                     |
//|   WStdDev = √( Σ(TP² × Vol)/ΣVol - VWAP² )   [population N]   |
//|                                                                  |
//| Session resets daily at broker midnight.                         |
//| RecalculateFromSessionStart() bootstraps state on EA restart.   |
//+------------------------------------------------------------------+

#ifndef __VWAP_SESSION_ENGINE_MQH__
#define __VWAP_SESSION_ENGINE_MQH__

class VWAPSessionEngine {
private:
    double m_cumTPV;    // Σ(TypicalPrice × Volume)
    double m_cumVol;    // ΣVolume
    double m_cumTPV2;   // Σ(TypicalPrice² × Volume)
    int    m_prevDay;
    int    m_prevMon;
    int    m_prevYear;
    bool   m_isValid;

    void ResetAccumulators() {
        m_cumTPV  = 0.0;
        m_cumVol  = 0.0;
        m_cumTPV2 = 0.0;
        m_isValid = false;
        vwap = upper1 = lower1 = upper2 = lower2 = upper3 = lower3 = wStdDev = 0.0;
    }

    void UpdateBands() {
        if (m_cumVol <= 0.0) return;

        vwap = m_cumTPV / m_cumVol;

        double variance = (m_cumTPV2 / m_cumVol) - (vwap * vwap);
        wStdDev = MathSqrt(MathMax(0.0, variance));

        upper1 = vwap + wStdDev;         lower1 = vwap - wStdDev;
        upper2 = vwap + wStdDev * 2.0;   lower2 = vwap - wStdDev * 2.0;
        upper3 = vwap + wStdDev * 3.0;   lower3 = vwap - wStdDev * 3.0;

        m_isValid = true;
    }

public:
    // Published band levels — read directly from calling code
    double vwap;
    double upper1, lower1;
    double upper2, lower2;
    double upper3, lower3;
    double wStdDev;

    VWAPSessionEngine() : m_cumTPV(0), m_cumVol(0), m_cumTPV2(0),
                          m_prevDay(-1), m_prevMon(-1), m_prevYear(-1),
                          m_isValid(false),
                          vwap(0), upper1(0), lower1(0), upper2(0), lower2(0),
                          upper3(0), lower3(0), wStdDev(0) {}

    bool IsValid() const { return m_isValid; }

    //+------------------------------------------------------------------+
    //| Convenience: band at any arbitrary SD multiplier
    //+------------------------------------------------------------------+
    double GetUpperBand(double mult) const { return vwap + wStdDev * mult; }
    double GetLowerBand(double mult) const { return vwap - wStdDev * mult; }

    //+------------------------------------------------------------------+
    //| Bootstrap state from today's session bars on EA startup / reload.|
    //| Walks back up to maxLookback bars to find today's session start, |
    //| then accumulates forward so the state matches a live calculation. |
    //+------------------------------------------------------------------+
    void RecalculateFromSessionStart(int maxLookback = 1440) {
        ResetAccumulators();

        MqlDateTime now;
        TimeToStruct(TimeCurrent(), now);
        m_prevDay  = now.day;
        m_prevMon  = now.mon;
        m_prevYear = now.year;

        int available = Bars(Symbol(), PERIOD_CURRENT);
        int limit     = MathMin(maxLookback, available - 1);

        // Find the earliest bar that belongs to today's session
        int sessionStartBar = -1;
        for (int i = limit; i >= 1; i--) {
            MqlDateTime dt;
            TimeToStruct(iTime(Symbol(), PERIOD_CURRENT, i), dt);
            if (dt.day == m_prevDay && dt.mon == m_prevMon && dt.year == m_prevYear) {
                sessionStartBar = i;
                break;
            }
        }

        if (sessionStartBar < 1) {
            Print("[VWAP] No bars found for today's session (bootstrap skipped)");
            return;
        }

        // Accumulate forward: sessionStartBar → bar[1] (last completed bar)
        for (int i = sessionStartBar; i >= 1; i--) {
            double h = iHigh      (Symbol(), PERIOD_CURRENT, i);
            double l = iLow       (Symbol(), PERIOD_CURRENT, i);
            double c = iClose     (Symbol(), PERIOD_CURRENT, i);
            long   v = iTickVolume(Symbol(), PERIOD_CURRENT, i);
            if (v <= 0) continue;

            double tp = (h + l + c) / 3.0;
            double fv = (double)v;
            m_cumTPV  += tp * fv;
            m_cumVol  += fv;
            m_cumTPV2 += (tp * tp) * fv;
        }

        UpdateBands();
        Print("[VWAP] Bootstrap complete. VWAP=", DoubleToString(vwap, _Digits),
              " StdDev=", DoubleToString(wStdDev, _Digits),
              " Bars from session start=", sessionStartBar);
    }

    //+------------------------------------------------------------------+
    //| Feed bar[1] (just-completed bar) on every new-bar event.        |
    //| Handles daily session reset automatically.                       |
    //+------------------------------------------------------------------+
    void UpdateBar(datetime barTime, double high, double low, double close, long volume) {
        if (volume <= 0) return;

        MqlDateTime dt;
        TimeToStruct(barTime, dt);

        if (dt.day != m_prevDay || dt.mon != m_prevMon || dt.year != m_prevYear) {
            ResetAccumulators();
            m_prevDay  = dt.day;
            m_prevMon  = dt.mon;
            m_prevYear = dt.year;
        }

        double tp = (high + low + close) / 3.0;
        double v  = (double)volume;
        m_cumTPV  += tp * v;
        m_cumVol  += v;
        m_cumTPV2 += (tp * tp) * v;

        UpdateBands();
    }

    //+------------------------------------------------------------------+
    //| Bar close-position proxy for order flow bias.                    |
    //| Returns 0.0 (full bear) … 1.0 (full bull).                      |
    //| Values > 0.55 suggest buying absorption; < 0.45 selling.        |
    //+------------------------------------------------------------------+
    static double BarDelta(double high, double low, double close) {
        double range = high - low;
        if (range < 1e-10) return 0.5;
        return (close - low) / range;
    }
};

#endif // __VWAP_SESSION_ENGINE_MQH__
