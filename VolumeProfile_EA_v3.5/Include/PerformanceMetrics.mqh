//+------------------------------------------------------------------+
//| PerformanceMetrics.mqh - Trade Statistics Calculator
//|
//| Operates on a TradeRecord[] array (from BacktestLogger or CSV).
//| All primary metrics are R-based (lot-size agnostic).
//+------------------------------------------------------------------+

#ifndef __PERFORMANCE_METRICS_MQH__
#define __PERFORMANCE_METRICS_MQH__

#include "BacktestLogger.mqh"

struct SetupStats {
    string name;
    int    count;
    int    wins;
    double winRate;        // %
    double profitFactor;   // grossWinR / abs(grossLossR)
    double expectancy;     // avg pnlR per trade
    double avgWinR;
    double avgLossR;
};

struct RegimeStats {
    string label;          // "BALANCED" | "IMBALANCED"
    int    count;
    int    wins;
    double winRate;
    double expectancy;
};

struct PerformanceReport {
    int    totalTrades;
    int    closedTrades;
    int    openTrades;
    int    wins;
    double winRate;
    double profitFactor;
    double expectancy;
    double totalR;
    double avgWinR;
    double avgLossR;
    double maxWinR;
    double maxLossR;
    double maxDrawdownR;
    double sharpeR;
    double calmarR;
    SetupStats  setup1;
    SetupStats  setup2;
    SetupStats  setup3;   // S3-MR-L, S3-MR-S, S3-BO-L, S3-BO-S
    RegimeStats balanced;
    RegimeStats imbalanced;
    double monthlyR[];
    string monthlyLabel[];
    int    monthlyCount;
};

class PerformanceMetrics {
private:

    void InitSetup(SetupStats& s, string name) {
        s.name = name; s.count = 0; s.wins = 0;
        s.winRate = 0; s.profitFactor = 0; s.expectancy = 0;
        s.avgWinR = 0; s.avgLossR = 0;
    }

    void InitRegime(RegimeStats& r, string label) {
        r.label = label; r.count = 0; r.wins = 0;
        r.winRate = 0; r.expectancy = 0;
    }

    void FinaliseSetup(SetupStats& s) {
        if (s.count == 0) return;
        int losses = s.count - s.wins;
        double grossWin  = s.avgWinR;   // accumulated sum at this point
        double grossLoss = s.avgLossR;  // accumulated sum (negative)
        if (s.wins  > 0) s.avgWinR  = s.avgWinR  / s.wins;
        if (losses  > 0) s.avgLossR = s.avgLossR / losses;
        double absLoss = MathAbs(grossLoss);
        s.profitFactor = (absLoss > 0) ? grossWin / absLoss : (grossWin > 0 ? 999 : 0);
        double wr = (double)s.wins / s.count;
        s.winRate    = 100.0 * wr;
        s.expectancy = (wr * s.avgWinR) + ((1.0 - wr) * s.avgLossR);
    }

    void FinaliseRegime(RegimeStats& r) {
        if (r.count == 0) return;
        r.winRate    = 100.0 * r.wins / r.count;
        r.expectancy = r.expectancy / r.count;
    }

    // Build cumulative R curve sorted by exitTime (insertion sort)
    void BuildEquityCurve(TradeRecord& records[], int count,
                          double& curve[], datetime& times[], int& curveLen) {
        curveLen = 0;
        for (int i = 0; i < count; i++) {
            if (records[i].exitLogged) curveLen++;
        }
        if (curveLen == 0) return;

        ArrayResize(curve, curveLen);
        ArrayResize(times, curveLen);

        int j = 0;
        for (int i = 0; i < count; i++) {
            if (!records[i].exitLogged) continue;
            int pos = j;
            while (pos > 0 && times[pos - 1] > records[i].exitTime) {
                curve[pos] = curve[pos - 1];
                times[pos] = times[pos - 1];
                pos--;
            }
            curve[pos] = records[i].pnlR;
            times[pos] = records[i].exitTime;
            j++;
        }

        double cum = 0;
        for (int i = 0; i < curveLen; i++) { cum += curve[i]; curve[i] = cum; }
    }

    double MaxDrawdown(double& curve[], int len) {
        if (len == 0) return 0;
        double peak = curve[0], maxDD = 0;
        for (int i = 0; i < len; i++) {
            if (curve[i] > peak) peak = curve[i];
            double dd = peak - curve[i];
            if (dd > maxDD) maxDD = dd;
        }
        return maxDD;
    }

    void AggregateDailyR(TradeRecord& records[], int count,
                         double& dailyR[], int& dayCount) {
        datetime days[];
        ArrayResize(days, 0);
        for (int i = 0; i < count; i++) {
            if (!records[i].exitLogged) continue;
            datetime d = records[i].exitTime - records[i].exitTime % 86400;
            bool found = false;
            for (int k = 0; k < ArraySize(days); k++) {
                if (days[k] == d) { found = true; break; }
            }
            if (!found) {
                int sz = ArraySize(days);
                ArrayResize(days, sz + 1);
                days[sz] = d;
            }
        }
        dayCount = ArraySize(days);
        ArrayResize(dailyR, dayCount);
        ArrayInitialize(dailyR, 0);
        for (int i = 0; i < count; i++) {
            if (!records[i].exitLogged) continue;
            datetime d = records[i].exitTime - records[i].exitTime % 86400;
            for (int k = 0; k < dayCount; k++) {
                if (days[k] == d) { dailyR[k] += records[i].pnlR; break; }
            }
        }
    }

    double Sharpe(double& dailyR[], int n, int daysPerYear) {
        if (n < 2) return 0;
        double sum = 0;
        for (int i = 0; i < n; i++) sum += dailyR[i];
        double mean = sum / n;
        double var  = 0;
        for (int i = 0; i < n; i++) { double d = dailyR[i] - mean; var += d * d; }
        var /= (n - 1);
        double sd = MathSqrt(var);
        return (sd > 0) ? (mean / sd) * MathSqrt((double)daysPerYear) : 0;
    }

    void BuildMonthlyR(TradeRecord& records[], int count, PerformanceReport& rep) {
        datetime months[];
        ArrayResize(months, 0);
        for (int i = 0; i < count; i++) {
            if (!records[i].exitLogged) continue;
            MqlDateTime dt;
            TimeToStruct(records[i].exitTime, dt);
            dt.day = 1; dt.hour = 0; dt.min = 0; dt.sec = 0;
            datetime m = StructToTime(dt);
            bool found = false;
            for (int k = 0; k < ArraySize(months); k++) {
                if (months[k] == m) { found = true; break; }
            }
            if (!found) {
                int sz = ArraySize(months);
                ArrayResize(months, sz + 1);
                months[sz] = m;
            }
        }
        int mCount = ArraySize(months);
        ArrayResize(rep.monthlyR,     mCount);
        ArrayResize(rep.monthlyLabel, mCount);
        ArrayInitialize(rep.monthlyR, 0);
        for (int i = 0; i < count; i++) {
            if (!records[i].exitLogged) continue;
            MqlDateTime dt;
            TimeToStruct(records[i].exitTime, dt);
            dt.day = 1; dt.hour = 0; dt.min = 0; dt.sec = 0;
            datetime m = StructToTime(dt);
            for (int k = 0; k < mCount; k++) {
                if (months[k] == m) { rep.monthlyR[k] += records[i].pnlR; break; }
            }
        }
        for (int k = 0; k < mCount; k++) {
            MqlDateTime dt;
            TimeToStruct(months[k], dt);
            rep.monthlyLabel[k] = StringFormat("%04d-%02d", dt.year, dt.mon);
        }
        rep.monthlyCount = mCount;
    }

public:

    PerformanceReport Calculate(TradeRecord& records[], int count,
                                double accountBalance  = 0,
                                int    daysPerYear     = 252) {
        PerformanceReport rep;
        ArrayResize(rep.monthlyR,     0);
        ArrayResize(rep.monthlyLabel, 0);
        rep.monthlyCount  = 0;
        rep.totalTrades   = count;
        rep.closedTrades  = 0;
        rep.openTrades    = 0;
        rep.wins          = 0;
        rep.winRate       = 0;
        rep.profitFactor  = 0;
        rep.expectancy    = 0;
        rep.totalR        = 0;
        rep.avgWinR       = 0;
        rep.avgLossR      = 0;
        rep.maxWinR       = 0;
        rep.maxLossR      = 0;
        rep.maxDrawdownR  = 0;
        rep.sharpeR       = 0;
        rep.calmarR       = 0;
        InitSetup(rep.setup1,    "SETUP1");
        InitSetup(rep.setup2,    "SETUP2");
        InitSetup(rep.setup3,    "SETUP3");
        InitRegime(rep.balanced,   "BALANCED");
        InitRegime(rep.imbalanced, "IMBALANCED");

        if (count == 0) return rep;

        double grossWinR = 0, grossLossR = 0;
        bool   firstWin  = true, firstLoss = true;

        for (int i = 0; i < count; i++) {
            // Value copy — MQL5 forbids array-element references
            TradeRecord r = records[i];

            if (!r.exitLogged) { rep.openTrades++; continue; }
            rep.closedTrades++;

            bool isWin = (r.pnlR > 0);

            if (isWin) {
                rep.wins++;
                rep.avgWinR += r.pnlR;
                grossWinR   += r.pnlR;
                if (firstWin || r.pnlR > rep.maxWinR) { rep.maxWinR = r.pnlR; firstWin = false; }
            } else {
                rep.avgLossR += r.pnlR;
                grossLossR   += r.pnlR;
                if (firstLoss || r.pnlR < rep.maxLossR) { rep.maxLossR = r.pnlR; firstLoss = false; }
            }
            rep.totalR += r.pnlR;

            // Per-setup accumulation — S3- prefix covers all Setup 3 variants
            if (r.setupType == "SETUP1") {
                rep.setup1.count++;
                if (isWin) { rep.setup1.wins++; rep.setup1.avgWinR  += r.pnlR; }
                else         {                    rep.setup1.avgLossR += r.pnlR; }
            } else if (StringFind(r.setupType, "S3-") == 0) {
                rep.setup3.count++;
                if (isWin) { rep.setup3.wins++; rep.setup3.avgWinR  += r.pnlR; }
                else         {                    rep.setup3.avgLossR += r.pnlR; }
            } else {
                rep.setup2.count++;
                if (isWin) { rep.setup2.wins++; rep.setup2.avgWinR  += r.pnlR; }
                else         {                    rep.setup2.avgLossR += r.pnlR; }
            }

            // Per-regime accumulation
            if (r.wasBalanced) {
                rep.balanced.count++;
                if (isWin) rep.balanced.wins++;
                rep.balanced.expectancy += r.pnlR;
            } else {
                rep.imbalanced.count++;
                if (isWin) rep.imbalanced.wins++;
                rep.imbalanced.expectancy += r.pnlR;
            }
        }

        if (rep.closedTrades == 0) return rep;

        rep.winRate    = 100.0 * rep.wins / rep.closedTrades;
        rep.expectancy = rep.totalR / rep.closedTrades;

        int losses = rep.closedTrades - rep.wins;
        if (rep.wins  > 0) rep.avgWinR  /= rep.wins;
        if (losses    > 0) rep.avgLossR /= losses;

        double absLoss = MathAbs(grossLossR);
        rep.profitFactor = (absLoss > 0) ? grossWinR / absLoss : (grossWinR > 0 ? 999 : 0);

        FinaliseSetup(rep.setup1);
        FinaliseSetup(rep.setup2);
        FinaliseSetup(rep.setup3);
        FinaliseRegime(rep.balanced);
        FinaliseRegime(rep.imbalanced);

        // Equity curve + drawdown
        double   curve[];
        datetime curveTimes[];
        int      curveLen = 0;
        BuildEquityCurve(records, count, curve, curveTimes, curveLen);
        rep.maxDrawdownR = MaxDrawdown(curve, curveLen);

        // Sharpe
        double dailyR[];
        int    dayCount = 0;
        AggregateDailyR(records, count, dailyR, dayCount);
        rep.sharpeR = Sharpe(dailyR, dayCount, daysPerYear);

        // Calmar: (totalR / years) / maxDrawdownR
        if (rep.maxDrawdownR > 0 && curveLen >= 2) {
            double secs  = (double)(curveTimes[curveLen - 1] - curveTimes[0]);
            double years = secs / 31536000.0;
            if (years > 0) rep.calmarR = (rep.totalR / years) / rep.maxDrawdownR;
        }

        BuildMonthlyR(records, count, rep);
        return rep;
    }

    void PrintReport(const PerformanceReport& r) {
        Print("========== BACKTEST PERFORMANCE REPORT ==========");
        Print("Trades  total=", r.totalTrades,
              "  closed=", r.closedTrades, "  open=", r.openTrades);
        Print("Win Rate:      ", DoubleToString(r.winRate,      1), "%");
        Print("Profit Factor: ", DoubleToString(r.profitFactor, 2));
        Print("Expectancy:    ", DoubleToString(r.expectancy,   3), "R");
        Print("Total R:       ", DoubleToString(r.totalR,       2), "R");
        Print("Avg Win:  ",      DoubleToString(r.avgWinR,      2),
              "R   Max Win: ",   DoubleToString(r.maxWinR,      2), "R");
        Print("Avg Loss: ",      DoubleToString(r.avgLossR,     2),
              "R   Max Loss: ",  DoubleToString(r.maxLossR,     2), "R");
        Print("Max Drawdown:  ", DoubleToString(r.maxDrawdownR, 2), "R");
        Print("Sharpe (R):    ", DoubleToString(r.sharpeR, 2));
        Print("Calmar (R):    ", DoubleToString(r.calmarR, 2));
        Print("----- Setup Breakdown -----");
        PrintSetup(r.setup1);
        PrintSetup(r.setup2);
        PrintSetup(r.setup3);
        Print("----- Regime Breakdown -----");
        PrintRegime(r.balanced);
        PrintRegime(r.imbalanced);
        Print("----- Monthly R -----");
        for (int i = 0; i < r.monthlyCount; i++) {
            Print("  ", r.monthlyLabel[i], ": ",
                  DoubleToString(r.monthlyR[i], 2), "R");
        }
        Print("=================================================");
    }

private:
    void PrintSetup(const SetupStats& s) {
        if (s.count == 0) return;
        Print("  ", s.name,
              ": n=", s.count,
              "  WR=",   DoubleToString(s.winRate,      1), "%",
              "  PF=",   DoubleToString(s.profitFactor, 2),
              "  E=",    DoubleToString(s.expectancy,   3), "R",
              "  AvgW=", DoubleToString(s.avgWinR,      2), "R",
              "  AvgL=", DoubleToString(s.avgLossR,     2), "R");
    }

    void PrintRegime(const RegimeStats& r) {
        if (r.count == 0) return;
        Print("  ", r.label,
              ": n=", r.count,
              "  WR=", DoubleToString(r.winRate,    1), "%",
              "  E=",  DoubleToString(r.expectancy, 3), "R");
    }
};

#endif // __PERFORMANCE_METRICS_MQH__
