//+------------------------------------------------------------------+
//| WalkForwardConfig.mqh - Walk-Forward Test Window Generator
//|
//| Builds rolling IS/OOS date-window pairs for walk-forward
//| validation.  Call PrintWindowSchedule() to log the date pairs,
//| then run the MT5 Strategy Tester once per window with those dates.
//|
//| Recommended configuration for VP swing-trade EA:
//|   IS  = 12 months   OOS = 3 months   Step = 3 months
//|   Range 2022-01-01 → 2025-12-31  →  13 windows
//+------------------------------------------------------------------+

#ifndef __WALK_FORWARD_CONFIG_MQH__
#define __WALK_FORWARD_CONFIG_MQH__

struct WFWindow {
    int      id;
    datetime inSampleStart;
    datetime inSampleEnd;
    datetime outSampleStart;
    datetime outSampleEnd;
    string   label;
};

class WalkForwardConfig {
private:
    WFWindow m_windows[];
    int      m_count;

    // Advance a datetime by N calendar months
    datetime AddMonths(datetime base, int months) {
        MqlDateTime dt;
        TimeToStruct(base, dt);

        int totalMonths = dt.mon - 1 + months;
        dt.year += totalMonths / 12;
        dt.mon   = totalMonths % 12 + 1;

        // Clamp day to valid range for the new month
        int maxDay = DaysInMonth(dt.year, dt.mon);
        if (dt.day > maxDay) dt.day = maxDay;

        return StructToTime(dt);
    }

    int DaysInMonth(int year, int month) {
        int days[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
        if (month == 2 && IsLeapYear(year)) return 29;
        return days[month - 1];
    }

    bool IsLeapYear(int year) {
        return ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0);
    }

    // Return last second of the day before the given datetime
    datetime DayBefore(datetime dt) {
        MqlDateTime s;
        TimeToStruct(dt, s);
        s.hour = 0; s.min = 0; s.sec = 0;
        return StructToTime(s) - 1;
    }

public:
    WalkForwardConfig() : m_count(0) {
        ArrayResize(m_windows, 0);
    }

    //+------------------------------------------------------------------+
    //| Build rolling walk-forward windows.
    //|
    //| rangeStart      : first day of the full test range
    //| rangeEnd        : last day of the full test range
    //| inSampleMonths  : length of in-sample (training) period
    //| outSampleMonths : length of out-of-sample (validation) period
    //| stepMonths      : how many months to advance the window each pass
    //|                   (0 = non-anchored rolling; equal to outSampleMonths)
    //+------------------------------------------------------------------+
    void BuildWindows(datetime rangeStart,   datetime rangeEnd,
                      int inSampleMonths  = 12,
                      int outSampleMonths = 3,
                      int stepMonths      = 3) {
        ArrayResize(m_windows, 0);
        m_count = 0;

        if (stepMonths <= 0) stepMonths = outSampleMonths;

        datetime isStart = rangeStart;

        for (int pass = 1; ; pass++) {
            datetime isEnd   = DayBefore(AddMonths(isStart, inSampleMonths));
            datetime oosStart = AddMonths(isStart, inSampleMonths);
            datetime oosEnd   = DayBefore(AddMonths(oosStart, outSampleMonths));

            if (oosEnd > rangeEnd) break;

            ArrayResize(m_windows, m_count + 1);
            m_windows[m_count].id             = pass;
            m_windows[m_count].inSampleStart  = isStart;
            m_windows[m_count].inSampleEnd    = isEnd;
            m_windows[m_count].outSampleStart = oosStart;
            m_windows[m_count].outSampleEnd   = oosEnd;
            m_windows[m_count].label = StringFormat("WF-%02d  IS:%s->%s  OOS:%s->%s",
                pass,
                TimeToString(isStart,  TIME_DATE),
                TimeToString(isEnd,    TIME_DATE),
                TimeToString(oosStart, TIME_DATE),
                TimeToString(oosEnd,   TIME_DATE));
            m_count++;

            isStart = AddMonths(isStart, stepMonths);
        }
    }

    int      GetWindowCount() const { return m_count; }

    WFWindow GetWindow(int index) const {
        if (index < 0 || index >= m_count) {
            WFWindow empty;
            empty.id             = 0;
            empty.inSampleStart  = 0;
            empty.inSampleEnd    = 0;
            empty.outSampleStart = 0;
            empty.outSampleEnd   = 0;
            empty.label          = "";
            return empty;
        }
        return m_windows[index];
    }

    //+------------------------------------------------------------------+
    //| Print the full window schedule to the MT5 Experts log
    //+------------------------------------------------------------------+
    void PrintWindowSchedule() const {
        Print("===== Walk-Forward Window Schedule (", m_count, " passes) =====");
        for (int i = 0; i < m_count; i++) {
            WFWindow w = m_windows[i];   // value copy — MQL5 forbids array-element references
            Print(w.label);
        }
        Print("  Run Strategy Tester once per window with the dates above.");
        Print("  Each run produces: backtest_journal_[symbol]_[date].csv");
        Print("  Then run GenerateBacktestReport.mq5 Script to aggregate.");
        Print("=============================================================");
    }

    //+------------------------------------------------------------------+
    //| Convenience: print a single window summary (for OnInit logging)
    //+------------------------------------------------------------------+
    void PrintWindow(int index) const {
        if (index < 0 || index >= m_count) return;
        Print(m_windows[index].label);
    }
};

#endif // __WALK_FORWARD_CONFIG_MQH__
