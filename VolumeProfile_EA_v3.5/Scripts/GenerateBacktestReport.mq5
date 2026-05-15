//+------------------------------------------------------------------+
//| GenerateBacktestReport.mq5 - Post-Test Performance Report
//|
//| Run as a Script after one or more Strategy Tester passes.
//| Reads all backtest_journal_*.csv files from MQL5/Files/,
//| computes performance metrics, and writes an HTML report.
//|
//| Place this file in MQL5/Scripts/ (or compile via MetaEditor).
//+------------------------------------------------------------------+

#property copyright "VWGTI-Pro v3.5"
#property version   "1.0"
#property strict
#property script_show_inputs

// Path prefix adjusts automatically — Script runs from MQL5/Scripts/
#include "../Include/BacktestLogger.mqh"
#include "../Include/PerformanceMetrics.mqh"
#include "../Include/WalkForwardConfig.mqh"

input string  Symbol_Filter       = "";        // Filter by symbol (blank = all)
input string  Output_Filename     = "backtest_report"; // Output HTML filename (no ext)
input bool    Walk_Forward_Mode   = false;     // Group results by WF window
input double  Account_Balance     = 10000;     // Starting balance for drawdown %
input int     Trading_Days_Year   = 252;       // Annualisation factor for Sharpe

//+------------------------------------------------------------------+
//| CSV reading helpers
//+------------------------------------------------------------------+
bool ReadCSVToRecords(string filename, TradeRecord& records[], int& count) {
    int fh = FileOpen(filename, FILE_READ | FILE_CSV | FILE_ANSI, ',');
    if (fh == INVALID_HANDLE) {
        Print("[Report] Cannot open: ", filename);
        return false;
    }

    // Skip header row
    if (!FileIsEnding(fh)) {
        for (int col = 0; col < 18; col++) FileReadString(fh);
    }

    while (!FileIsEnding(fh)) {
        // Each row: Ticket,SetupType,Direction,EntryPrice,StopLoss,TakeProfit,
        //           Lots,RR_Ratio,POC_Entry,VAH_Entry,VAL_Entry,HTF_POC_Entry,
        //           Balanced,ExitPrice,PnL_R,ExitReason,EntryTime,ExitTime
        if (FileIsLineEnding(fh)) continue;

        TradeRecord r;
        r.ticket        = (long)StringToInteger(FileReadString(fh));
        r.setupType     = FileReadString(fh);
        string dir      = FileReadString(fh);
        r.isLong        = (dir == "LONG");
        r.entryPrice    = StringToDouble(FileReadString(fh));
        r.stopLoss      = StringToDouble(FileReadString(fh));
        r.takeProfit    = StringToDouble(FileReadString(fh));
        r.lots          = StringToDouble(FileReadString(fh));
        r.rrRatio       = StringToDouble(FileReadString(fh));
        r.pocAtEntry    = StringToDouble(FileReadString(fh));
        r.vahAtEntry    = StringToDouble(FileReadString(fh));
        r.valAtEntry    = StringToDouble(FileReadString(fh));
        r.htfPocAtEntry = StringToDouble(FileReadString(fh));
        r.wasBalanced   = (FileReadString(fh) == "1");
        r.exitPrice     = StringToDouble(FileReadString(fh));
        r.pnlR          = StringToDouble(FileReadString(fh));
        r.exitReason    = FileReadString(fh);
        string entryTs  = FileReadString(fh);
        string exitTs   = FileReadString(fh);

        r.entryTime  = StringToTime(entryTs);
        r.exitLogged = (exitTs != "OPEN" && exitTs != "");
        r.exitTime   = r.exitLogged ? StringToTime(exitTs) : 0;

        ArrayResize(records, count + 1);
        records[count] = r;
        count++;
    }

    FileClose(fh);
    return true;
}

//+------------------------------------------------------------------+
//| HTML generation helpers
//+------------------------------------------------------------------+
string HtmlHeader(string title) {
    return StringFormat(
        "<!DOCTYPE html><html><head><meta charset='utf-8'>"
        "<title>%s</title>"
        "<style>"
        "body{font-family:Segoe UI,Arial,sans-serif;background:#0d1117;color:#c9d1d9;margin:20px}"
        "h1{color:#58a6ff;border-bottom:1px solid #30363d;padding-bottom:8px}"
        "h2{color:#79c0ff;margin-top:24px}"
        "table{border-collapse:collapse;width:100%%;margin:12px 0}"
        "th{background:#161b22;color:#58a6ff;padding:8px 12px;text-align:left;border:1px solid #30363d}"
        "td{padding:7px 12px;border:1px solid #21262d}"
        "tr:nth-child(even){background:#161b22}"
        ".pos{color:#3fb950}.neg{color:#f85149}.neu{color:#e3b341}"
        ".metric-label{color:#8b949e;font-size:0.85em}"
        ".big{font-size:1.4em;font-weight:bold}"
        ".card{background:#161b22;border:1px solid #30363d;border-radius:6px;"
        "padding:16px;margin:8px;display:inline-block;min-width:140px;text-align:center}"
        ".cards{display:flex;flex-wrap:wrap;gap:4px;margin:12px 0}"
        "</style></head><body>"
        "<h1>%s</h1>",
        title, title);
}

string HtmlFooter() {
    return "</body></html>";
}

string ColorR(double r) {
    string cls = (r > 0) ? "pos" : ((r < 0) ? "neg" : "neu");
    return StringFormat("<span class='%s'>%s R</span>", cls, DoubleToString(r, 2));
}

string ColorPct(double pct) {
    string cls = (pct > 0) ? "pos" : ((pct < 0) ? "neg" : "neu");
    return StringFormat("<span class='%s'>%.1f%%</span>", cls, pct);
}

string MetricCard(string label, string value) {
    return StringFormat(
        "<div class='card'><div class='big'>%s</div>"
        "<div class='metric-label'>%s</div></div>",
        value, label);
}

string SummaryCards(const PerformanceReport& r) {
    string s = "<div class='cards'>";
    s += MetricCard("Total Trades",    (string)r.closedTrades);
    s += MetricCard("Win Rate",        StringFormat("%.1f%%", r.winRate));
    s += MetricCard("Profit Factor",   DoubleToString(r.profitFactor, 2));
    s += MetricCard("Expectancy",      DoubleToString(r.expectancy, 3) + "R");
    s += MetricCard("Total R",         DoubleToString(r.totalR, 2) + "R");
    s += MetricCard("Max DD",          DoubleToString(r.maxDrawdownR, 2) + "R");
    s += MetricCard("Sharpe",          DoubleToString(r.sharpeR, 2));
    s += MetricCard("Calmar",          DoubleToString(r.calmarR, 2));
    s += "</div>";
    return s;
}

string SetupTable(const PerformanceReport& r) {
    string s = "<h2>Setup Breakdown</h2>";
    s += "<table><tr><th>Setup</th><th>Trades</th><th>Win Rate</th>"
         "<th>Profit Factor</th><th>Expectancy</th><th>Avg Win</th><th>Avg Loss</th></tr>";
    SetupStats setups[2];
    setups[0] = r.setup1;
    setups[1] = r.setup2;
    for (int i = 0; i < 2; i++) {
        if (setups[i].count == 0) continue;
        s += StringFormat(
            "<tr><td><b>%s</b></td><td>%d</td><td>%s</td><td>%s</td>"
            "<td>%s</td><td>%s</td><td>%s</td></tr>",
            setups[i].name,
            setups[i].count,
            ColorPct(setups[i].winRate),
            DoubleToString(setups[i].profitFactor, 2),
            ColorR(setups[i].expectancy),
            ColorR(setups[i].avgWinR),
            ColorR(setups[i].avgLossR));
    }
    s += "</table>";
    return s;
}

string RegimeTable(const PerformanceReport& r) {
    string s = "<h2>Market Regime Breakdown</h2>";
    s += "<table><tr><th>Regime</th><th>Trades</th><th>Win Rate</th><th>Expectancy</th></tr>";
    RegimeStats regimes[2];
    regimes[0] = r.balanced;
    regimes[1] = r.imbalanced;
    for (int i = 0; i < 2; i++) {
        if (regimes[i].count == 0) continue;
        s += StringFormat(
            "<tr><td><b>%s</b></td><td>%d</td><td>%s</td><td>%s</td></tr>",
            regimes[i].label,
            regimes[i].count,
            ColorPct(regimes[i].winRate),
            ColorR(regimes[i].expectancy));
    }
    s += "</table>";
    return s;
}

string MonthlyTable(const PerformanceReport& r) {
    if (r.monthlyCount == 0) return "";
    string s = "<h2>Monthly P&amp;L (R)</h2>";
    s += "<table><tr>";
    for (int i = 0; i < r.monthlyCount; i++) {
        s += "<th>" + r.monthlyLabel[i] + "</th>";
    }
    s += "</tr><tr>";
    for (int i = 0; i < r.monthlyCount; i++) {
        s += "<td>" + ColorR(r.monthlyR[i]) + "</td>";
    }
    s += "</tr></table>";
    return s;
}

string EquityCurveSVG(const PerformanceReport& r, TradeRecord& records[], int count) {
    // Build cumulative R series from closed trades sorted by exitTime
    double cumR[];
    datetime exitTimes[];
    int n = 0;
    for (int i = 0; i < count; i++) {
        if (records[i].exitLogged) n++;
    }
    if (n == 0) return "";

    ArrayResize(cumR, n);
    ArrayResize(exitTimes, n);

    // Simple insertion sort by exitTime
    int j = 0;
    for (int i = 0; i < count; i++) {
        if (!records[i].exitLogged) continue;
        int pos = j;
        while (pos > 0 && exitTimes[pos-1] > records[i].exitTime) {
            cumR[pos]      = cumR[pos-1];
            exitTimes[pos] = exitTimes[pos-1];
            pos--;
        }
        cumR[pos]      = records[i].pnlR;
        exitTimes[pos] = records[i].exitTime;
        j++;
    }
    double running = 0;
    for (int i = 0; i < n; i++) { running += cumR[i]; cumR[i] = running; }

    double minR = cumR[0], maxR = cumR[0];
    for (int i = 1; i < n; i++) {
        if (cumR[i] < minR) minR = cumR[i];
        if (cumR[i] > maxR) maxR = cumR[i];
    }
    double rangeR = maxR - minR;
    if (rangeR < 0.01) rangeR = 1;

    int W = 800, H = 200, PAD = 20;
    string pts = "";
    for (int i = 0; i < n; i++) {
        double x = PAD + (double)i / (n - 1 > 0 ? n - 1 : 1) * (W - 2 * PAD);
        double y = H - PAD - (cumR[i] - minR) / rangeR * (H - 2 * PAD);
        pts += StringFormat("%.1f,%.1f ", x, y);
    }

    string zeroY = DoubleToString(H - PAD - (0 - minR) / rangeR * (H - 2 * PAD), 1);

    return StringFormat(
        "<h2>Equity Curve (cumulative R)</h2>"
        "<svg width='%d' height='%d' style='background:#161b22;border:1px solid #30363d;border-radius:4px'>"
        "<line x1='%d' y1='%s' x2='%d' y2='%s' stroke='#30363d' stroke-width='1' stroke-dasharray='4'/>"
        "<polyline points='%s' fill='none' stroke='#58a6ff' stroke-width='1.5'/>"
        "<text x='%d' y='15' fill='#8b949e' font-size='11'>+%.2fR</text>"
        "<text x='%d' y='%d' fill='#8b949e' font-size='11'>%.2fR</text>"
        "</svg>",
        W, H,
        PAD, zeroY, W - PAD, zeroY,
        pts,
        W - PAD - 40, maxR,
        PAD, H - 5, minR);
}

string TradeTable(TradeRecord& records[], int count) {
    string s = "<h2>Trade Journal</h2>";
    s += "<table><tr><th>Ticket</th><th>Setup</th><th>Dir</th>"
         "<th>Entry</th><th>SL</th><th>TP</th><th>R:R</th>"
         "<th>POC</th><th>VAH</th><th>VAL</th><th>Regime</th>"
         "<th>Exit</th><th>P&amp;L R</th><th>Reason</th>"
         "<th>Entry Time</th><th>Exit Time</th></tr>";
    for (int i = 0; i < count; i++) {
        TradeRecord r = records[i];   // value copy — MQL5 forbids array-element references
        string pnlCell = r.exitLogged ? ColorR(r.pnlR) : "<span class='neu'>OPEN</span>";
        s += StringFormat(
            "<tr><td>%d</td><td>%s</td><td>%s</td>"
            "<td>%.5f</td><td>%.5f</td><td>%.5f</td><td>%.2f</td>"
            "<td>%.5f</td><td>%.5f</td><td>%.5f</td><td>%s</td>"
            "<td>%.5f</td><td>%s</td><td>%s</td>"
            "<td>%s</td><td>%s</td></tr>",
            r.ticket, r.setupType, r.isLong ? "L" : "S",
            r.entryPrice, r.stopLoss, r.takeProfit, r.rrRatio,
            r.pocAtEntry, r.vahAtEntry, r.valAtEntry,
            r.wasBalanced ? "BAL" : "IMBAL",
            r.exitPrice, pnlCell, r.exitReason,
            TimeToString(r.entryTime, TIME_DATE | TIME_MINUTES),
            r.exitLogged ? TimeToString(r.exitTime, TIME_DATE | TIME_MINUTES) : "—");
    }
    s += "</table>";
    return s;
}

//+------------------------------------------------------------------+
//| Script entry point
//+------------------------------------------------------------------+
void OnStart() {
    Print("[Report] Scanning MQL5/Files/ for backtest_journal_*.csv ...");

    TradeRecord allRecords[];
    int totalCount = 0;
    int filesRead  = 0;

    string searchPattern = "backtest_journal_";
    if (Symbol_Filter != "") searchPattern += Symbol_Filter + "_";
    searchPattern += "*.csv";

    string fname;
    long   handle = FileFindFirst(searchPattern, fname);
    if (handle == INVALID_HANDLE) {
        Print("[Report] No journal files found matching: ", searchPattern);
        return;
    }

    do {
        Print("[Report] Reading: ", fname);
        TradeRecord batch[];
        int batchCount = 0;
        if (ReadCSVToRecords(fname, batch, batchCount)) {
            int oldTotal = totalCount;
            totalCount += batchCount;
            ArrayResize(allRecords, totalCount);
            for (int i = 0; i < batchCount; i++) {
                allRecords[oldTotal + i] = batch[i];
            }
            filesRead++;
            Print("[Report]   → ", batchCount, " trades loaded");
        }
    } while (FileFindNext(handle, fname));

    FileFindClose(handle);

    if (totalCount == 0) {
        Print("[Report] No trade records found. Exiting.");
        return;
    }

    Print("[Report] Total trades across ", filesRead, " file(s): ", totalCount);

    PerformanceMetrics pm;
    PerformanceReport  report = pm.Calculate(allRecords, totalCount,
                                             Account_Balance, Trading_Days_Year);
    pm.PrintReport(report);

    // Build HTML
    string title = StringFormat("VP EA v3.5 Backtest Report — %s (%d trades)",
                                Symbol_Filter != "" ? Symbol_Filter : "All Symbols",
                                report.closedTrades);

    string html = HtmlHeader(title);
    html += "<p style='color:#8b949e'>Generated: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + "</p>";
    html += SummaryCards(report);
    html += EquityCurveSVG(report, allRecords, totalCount);
    html += SetupTable(report);
    html += RegimeTable(report);
    html += MonthlyTable(report);
    html += TradeTable(allRecords, totalCount);

    if (Walk_Forward_Mode) {
        html += "<h2>Walk-Forward Schedule</h2><pre style='color:#8b949e'>";
        WalkForwardConfig wfc;
        wfc.BuildWindows(
            allRecords[0].entryTime,
            allRecords[totalCount - 1].exitTime > 0
                ? allRecords[totalCount - 1].exitTime
                : allRecords[totalCount - 1].entryTime,
            12, 3, 3);
        for (int i = 0; i < wfc.GetWindowCount(); i++) {
            WFWindow w = wfc.GetWindow(i);
            html += w.label + "\n";
        }
        html += "</pre>";
    }

    html += HtmlFooter();

    // Write HTML file
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    string outFile = StringFormat("%s_%04d%02d%02d.html",
                                  Output_Filename, dt.year, dt.mon, dt.day);
    int fh = FileOpen(outFile, FILE_WRITE | FILE_TXT | FILE_ANSI);
    if (fh == INVALID_HANDLE) {
        Print("[Report] Cannot write HTML: ", outFile, " error: ", GetLastError());
        return;
    }
    FileWriteString(fh, html);
    FileClose(fh);

    Print("[Report] HTML report written to MQL5/Files/", outFile);
    Print("[Report] Done.");
}
