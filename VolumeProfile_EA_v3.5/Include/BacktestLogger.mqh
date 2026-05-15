//+------------------------------------------------------------------+
//| BacktestLogger.mqh - Trade Journal with VP Context Capture
//|
//| Records every filled trade with the volume profile state that
//| existed at entry time (POC/VAH/VAL/HTF-POC, market regime).
//| Computes P&L in R-multiples at exit.
//| Flushes to CSV on OnDeinit for offline analysis.
//+------------------------------------------------------------------+

#ifndef __BACKTEST_LOGGER_MQH__
#define __BACKTEST_LOGGER_MQH__

struct TradeRecord {
    long      ticket;
    string    setupType;        // "SETUP1" | "SETUP2"
    bool      isLong;
    double    entryPrice;
    double    stopLoss;
    double    takeProfit;
    double    lots;
    double    rrRatio;          // planned R:R at entry
    // VP context frozen at entry
    double    pocAtEntry;
    double    vahAtEntry;
    double    valAtEntry;
    double    htfPocAtEntry;
    bool      wasBalanced;      // balanced market context flag
    // Filled at close
    double    exitPrice;
    double    pnlR;             // P&L in R-multiples (+ = win, - = loss)
    string    exitReason;       // "TP"|"SL"|"FRIDAY"|"HARD_STOP"|"PROFIT_CAP"|"DEINIT"
    datetime  entryTime;
    datetime  exitTime;
    bool      exitLogged;
};

class BacktestLogger {
private:
    TradeRecord m_records[];
    int         m_count;
    string      m_symbol;

    int FindByTicket(long ticket) const {
        for (int i = 0; i < m_count; i++) {
            if (m_records[i].ticket == ticket) return i;
        }
        return -1;
    }

public:
    BacktestLogger() : m_count(0), m_symbol("") {
        ArrayResize(m_records, 0);
    }

    ~BacktestLogger() {
        ArrayFree(m_records);
    }

    void Init(string symbol) {
        m_symbol = symbol;
    }

    //+------------------------------------------------------------------+
    //| Called immediately after OrderExecutor reports STATUS_FILLED
    //+------------------------------------------------------------------+
    void LogEntry(long ticket, string setupType, bool isLong,
                  double entry, double sl, double tp, double lots,
                  double poc, double vah, double val, double htfPoc,
                  bool balanced) {
        ArrayResize(m_records, m_count + 1);

        // MQL5 forbids references to array elements — assign fields directly
        m_records[m_count].ticket        = ticket;
        m_records[m_count].setupType     = setupType;
        m_records[m_count].isLong        = isLong;
        m_records[m_count].entryPrice    = entry;
        m_records[m_count].stopLoss      = sl;
        m_records[m_count].takeProfit    = tp;
        m_records[m_count].lots          = lots;
        m_records[m_count].pocAtEntry    = poc;
        m_records[m_count].vahAtEntry    = vah;
        m_records[m_count].valAtEntry    = val;
        m_records[m_count].htfPocAtEntry = htfPoc;
        m_records[m_count].wasBalanced   = balanced;
        m_records[m_count].entryTime     = TimeCurrent();
        m_records[m_count].exitPrice     = 0;
        m_records[m_count].exitTime      = 0;
        m_records[m_count].pnlR          = 0;
        m_records[m_count].exitReason    = "";
        m_records[m_count].exitLogged    = false;

        double slDist = MathAbs(entry - sl);
        double tpDist = MathAbs(tp - entry);
        m_records[m_count].rrRatio = (slDist > 0) ? tpDist / slDist : 0;

        m_count++;
    }

    //+------------------------------------------------------------------+
    //| Called when a position is closed (TP, SL, or forced)
    //+------------------------------------------------------------------+
    void LogExit(long ticket, double exitPrice, string reason) {
        int idx = FindByTicket(ticket);
        if (idx < 0) return;
        if (m_records[idx].exitLogged) return;

        m_records[idx].exitPrice  = exitPrice;
        m_records[idx].exitTime   = TimeCurrent();
        m_records[idx].exitReason = reason;
        m_records[idx].exitLogged = true;

        double slDist = MathAbs(m_records[idx].entryPrice - m_records[idx].stopLoss);
        if (slDist > 0) {
            double rawPnl = m_records[idx].isLong
                            ? (exitPrice - m_records[idx].entryPrice)
                            : (m_records[idx].entryPrice - exitPrice);
            m_records[idx].pnlR = rawPnl / slDist;
        }
    }

    //+------------------------------------------------------------------+
    //| Mark all still-open records as DEINIT (EA shutdown mid-trade)
    //+------------------------------------------------------------------+
    void LogOpenAsDeInit() {
        for (int i = 0; i < m_count; i++) {
            if (!m_records[i].exitLogged) {
                double exitPrice = m_records[i].isLong
                                   ? SymbolInfoDouble(Symbol(), SYMBOL_BID)
                                   : SymbolInfoDouble(Symbol(), SYMBOL_ASK);
                LogExit(m_records[i].ticket, exitPrice, "DEINIT");
            }
        }
    }

    int  GetTradeCount() const { return m_count; }

    bool GetRecord(int index, TradeRecord& out) const {
        if (index < 0 || index >= m_count) return false;
        out = m_records[index];
        return true;
    }

    //+------------------------------------------------------------------+
    //| Write journal to CSV in MQL5/Files/
    //+------------------------------------------------------------------+
    void FlushToCSV(string filename = "") {
        if (m_count == 0) {
            Print("[BacktestLogger] No trades to flush");
            return;
        }

        if (filename == "") {
            MqlDateTime dt;
            TimeToStruct(TimeCurrent(), dt);
            string safeSymbol = m_symbol;
            StringReplace(safeSymbol, "/", "_");  // brokers like IC Markets use BTC/USD
            filename = StringFormat("backtest_journal_%s_%04d%02d%02d.csv",
                                    safeSymbol, dt.year, dt.mon, dt.day);
        }

        int fh = FileOpen(filename, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
        if (fh == INVALID_HANDLE) {
            Print("[BacktestLogger] Cannot open file: ", filename,
                  " error: ", GetLastError());
            return;
        }

        FileWrite(fh,
            "Ticket", "SetupType", "Direction",
            "EntryPrice", "StopLoss", "TakeProfit", "Lots", "RR_Ratio",
            "POC_Entry", "VAH_Entry", "VAL_Entry", "HTF_POC_Entry", "Balanced",
            "ExitPrice", "PnL_R", "ExitReason",
            "EntryTime", "ExitTime");

        for (int i = 0; i < m_count; i++) {
            // Value copy for reading — safe in MQL5
            TradeRecord r = m_records[i];
            FileWrite(fh,
                (string)r.ticket,
                r.setupType,
                r.isLong ? "LONG" : "SHORT",
                DoubleToString(r.entryPrice,    5),
                DoubleToString(r.stopLoss,      5),
                DoubleToString(r.takeProfit,    5),
                DoubleToString(r.lots,          2),
                DoubleToString(r.rrRatio,       2),
                DoubleToString(r.pocAtEntry,    5),
                DoubleToString(r.vahAtEntry,    5),
                DoubleToString(r.valAtEntry,    5),
                DoubleToString(r.htfPocAtEntry, 5),
                r.wasBalanced ? "1" : "0",
                DoubleToString(r.exitPrice,     5),
                DoubleToString(r.pnlR,          3),
                r.exitReason,
                TimeToString(r.entryTime, TIME_DATE | TIME_MINUTES),
                r.exitTime > 0
                    ? TimeToString(r.exitTime, TIME_DATE | TIME_MINUTES)
                    : "OPEN"
            );
        }

        FileClose(fh);
        Print("[BacktestLogger] Flushed ", m_count, " trades → ", filename);
    }
};

#endif // __BACKTEST_LOGGER_MQH__
