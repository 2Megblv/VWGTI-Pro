//+------------------------------------------------------------------+
//| Dashboard_Indicator.mq5                                          |
//| Volume Profile Dashboard — Real-Time Performance Panel           |
//| Phase 5: Trade Data Visualisation and Reporting                  |
//|                                                                  |
//| Purpose:                                                         |
//|   Dedicated indicator running on separate chart window.          |
//|   Updates equity curve, P&L metrics, and summary stats on every  |
//|   bar close. Displays via ChartObjects in indicator subwindow.   |
//|                                                                  |
//| Integration:                                                     |
//|   - Reads from trading EA via extern PositionState[] array       |
//|   - Queries MT5 HistorySelect() for closed trades               |
//|   - Detects bar close via OnCalculate() time[] array            |
//|   - Updates ChartObjects once per bar (D-06)                    |
//|                                                                  |
//| Deployment:                                                      |
//|   Attach to dedicated MT5 chart (not the trading EA chart).      |
//|   EA and indicator run independently.                            |
//|                                                                  |
//+------------------------------------------------------------------+

#property indicator_separate_window
#property indicator_buffers 0
#property indicator_plots   0

#include "Include/Dashboard.mqh"
#include "Include/TradeExecution.mqh"

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+

DashboardMetrics g_metrics;
static datetime  g_lastBarTime  = 0;
static bool      g_initialized  = false;
static int       g_subwindow    = -1;   // indicator's own subwindow index

input int DashboardXOffset = 10;        // Panel X offset (pixels from left)
input int DashboardYOffset = 10;        // Panel Y offset (pixels from top)

//+------------------------------------------------------------------+
//| Panel layout constants                                           |
//+------------------------------------------------------------------+

#define PANEL_W       240           // panel width  (pixels)
#define PANEL_H       310           // panel height (pixels)
#define FONT_NAME     "Consolas"
#define FONT_TITLE    9
#define FONT_BODY     8
#define LINE_H        14            // pixels per text row
#define COL2_OFF      120           // x-offset for right column

// Colours
#define CLR_BG        C'12,18,32'   // dark navy background
#define CLR_BORDER    C'40,55,90'   // subtle border
#define CLR_TITLE     clrWhite
#define CLR_LABEL     C'140,155,180'
#define CLR_VALUE     clrWhite
#define CLR_PASS      clrLimeGreen
#define CLR_FAIL      clrTomato
#define CLR_XAUUSD    C'255,200,60'     // gold
#define CLR_EURUSD    C'100,160,255'    // cornflower blue
#define CLR_PNL_POS   clrLimeGreen
#define CLR_PNL_NEG   clrTomato
#define CLR_SEP       C'40,55,90'

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+

int OnInit()
{
    IndicatorSetString(INDICATOR_SHORTNAME, "Volume Profile Dashboard");
    InitializeDashboard(g_metrics);
    g_lastBarTime = 0;
    g_initialized = false;  // subwindow resolved on first calculate
    Print("Dashboard Indicator initialised — attach to dedicated chart window.");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnCalculate — bar-close detection (D-06)                         |
//+------------------------------------------------------------------+

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    // Resolve subwindow index once (needs chart to be fully initialised)
    if(!g_initialized)
    {
        long chartId = ChartID();
        g_subwindow  = ChartWindowFind(chartId, "Volume Profile Dashboard");
        if(g_subwindow < 0) g_subwindow = 0;
        g_initialized = true;
    }

    if(time[0] != g_lastBarTime)
    {
        g_lastBarTime = time[0];
        UpdateDashboard();
    }

    return(rates_total);
}

//+------------------------------------------------------------------+
//| UpdateDashboard                                                  |
//+------------------------------------------------------------------+

void UpdateDashboard()
{
    RefreshDashboardMetrics(g_metrics);
    LogDashboardState();
    RenderDashboard();
}

//+------------------------------------------------------------------+
//| LogDashboardState                                                |
//+------------------------------------------------------------------+

void LogDashboardState()
{
    Print(StringFormat(
        "Dashboard | %s | Equity=%.2f | Trades=%d WR=%.1f%% PF=%.2f MaxDD=%.2f%% | XAU=%d EUR=%d",
        TimeToString(TimeCurrent()),
        g_metrics.currentEquity,
        g_metrics.totalTrades,
        g_metrics.winRate * 100,
        g_metrics.profitFactor,
        g_metrics.maxDailyDrawdown * 100,
        g_metrics.symbolXAUUSD_trades,
        g_metrics.symbolEURUSD_trades));
}

//+------------------------------------------------------------------+
//| CreateBackground — dark navy rectangle behind the panel          |
//+------------------------------------------------------------------+

void CreateBackground(long chartId, int subwin, int x, int y, int w, int h)
{
    string name = "Dash_BG";
    if(ObjectFind(chartId, name) < 0)
    {
        ObjectCreate(chartId, name, OBJ_RECTANGLE_LABEL, subwin, 0, 0);
        ObjectSetInteger(chartId, name, OBJPROP_XDISTANCE,  x);
        ObjectSetInteger(chartId, name, OBJPROP_YDISTANCE,  y);
        ObjectSetInteger(chartId, name, OBJPROP_XSIZE,      w);
        ObjectSetInteger(chartId, name, OBJPROP_YSIZE,      h);
        ObjectSetInteger(chartId, name, OBJPROP_BGCOLOR,    CLR_BG);
        ObjectSetInteger(chartId, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(chartId, name, OBJPROP_COLOR,      CLR_BORDER);
        ObjectSetInteger(chartId, name, OBJPROP_WIDTH,      1);
        ObjectSetInteger(chartId, name, OBJPROP_BACK,       false);
        ObjectSetInteger(chartId, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(chartId, name, OBJPROP_HIDDEN,     true);
        ObjectSetInteger(chartId, name, OBJPROP_ANCHOR,     ANCHOR_LEFT_UPPER);
    }
    else
    {
        // Update size in case inputs changed
        ObjectSetInteger(chartId, name, OBJPROP_XSIZE, w);
        ObjectSetInteger(chartId, name, OBJPROP_YSIZE, h);
    }
}

//+------------------------------------------------------------------+
//| CreateSeparator — horizontal rule inside the panel               |
//+------------------------------------------------------------------+

void CreateSeparator(long chartId, int subwin, string name, int x, int y, int w)
{
    if(ObjectFind(chartId, name) < 0)
    {
        ObjectCreate(chartId, name, OBJ_RECTANGLE_LABEL, subwin, 0, 0);
        ObjectSetInteger(chartId, name, OBJPROP_XDISTANCE,  x);
        ObjectSetInteger(chartId, name, OBJPROP_YDISTANCE,  y);
        ObjectSetInteger(chartId, name, OBJPROP_XSIZE,      w);
        ObjectSetInteger(chartId, name, OBJPROP_YSIZE,      1);
        ObjectSetInteger(chartId, name, OBJPROP_BGCOLOR,    CLR_SEP);
        ObjectSetInteger(chartId, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(chartId, name, OBJPROP_COLOR,      CLR_SEP);
        ObjectSetInteger(chartId, name, OBJPROP_BACK,       false);
        ObjectSetInteger(chartId, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(chartId, name, OBJPROP_HIDDEN,     true);
        ObjectSetInteger(chartId, name, OBJPROP_ANCHOR,     ANCHOR_LEFT_UPPER);
    }
}

//+------------------------------------------------------------------+
//| PutLabel — create or update an OBJ_LABEL in the indicator window |
//+------------------------------------------------------------------+

void PutLabel(long chartId, int subwin, string name,
              int x, int y, string text, color clr, int fontSize = FONT_BODY)
{
    if(ObjectFind(chartId, name) >= 0)
    {
        ObjectSetString (chartId, name, OBJPROP_TEXT,  text);
        ObjectSetInteger(chartId, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(chartId, name, OBJPROP_FONTSIZE, fontSize);
    }
    else
    {
        if(!ObjectCreate(chartId, name, OBJ_LABEL, subwin, 0, 0))
        {
            Print("Dashboard: failed to create label '", name, "'");
            return;
        }
        ObjectSetInteger(chartId, name, OBJPROP_XDISTANCE,  x);
        ObjectSetInteger(chartId, name, OBJPROP_YDISTANCE,  y);
        ObjectSetString (chartId, name, OBJPROP_TEXT,       text);
        ObjectSetInteger(chartId, name, OBJPROP_COLOR,      clr);
        ObjectSetInteger(chartId, name, OBJPROP_FONTSIZE,   fontSize);
        ObjectSetString (chartId, name, OBJPROP_FONT,       FONT_NAME);
        ObjectSetInteger(chartId, name, OBJPROP_ANCHOR,     ANCHOR_LEFT_UPPER);
        ObjectSetInteger(chartId, name, OBJPROP_BACK,       false);
        ObjectSetInteger(chartId, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(chartId, name, OBJPROP_HIDDEN,     true);
    }
}

//+------------------------------------------------------------------+
//| RenderDashboard — full panel repaint, called once per bar        |
//+------------------------------------------------------------------+

void RenderDashboard()
{
    long chartId = ChartID();
    int  sw      = g_subwindow;
    int  px      = DashboardXOffset;
    int  py      = DashboardYOffset;
    int  cx      = px + 8;       // content x (inside panel padding)
    int  y       = py + 8;       // current row y

    // --- Background panel ---
    CreateBackground(chartId, sw, px, py, PANEL_W, PANEL_H);

    // === HEADER ===
    PutLabel(chartId, sw, "Dash_Title", cx, y,
             "VOLUME PROFILE", CLR_TITLE, FONT_TITLE);
    y += LINE_H;
    PutLabel(chartId, sw, "Dash_SubTitle", cx, y,
             "Performance Dashboard", CLR_LABEL, FONT_BODY);
    y += LINE_H + 4;

    CreateSeparator(chartId, sw, "Dash_Sep1", px, y, PANEL_W);
    y += 6;

    // === EQUITY & DAILY P&L ===
    PutLabel(chartId, sw, "Dash_EqLbl", cx, y,
             "Equity", CLR_LABEL, FONT_BODY);
    PutLabel(chartId, sw, "Dash_EqVal", cx + 70, y,
             StringFormat("$%.2f", g_metrics.currentEquity), CLR_VALUE, FONT_BODY);
    y += LINE_H;

    color pnlClr = (g_metrics.dailyPnL >= 0) ? CLR_PNL_POS : CLR_PNL_NEG;
    PutLabel(chartId, sw, "Dash_PnLLbl", cx, y,
             "Daily P&L", CLR_LABEL, FONT_BODY);
    PutLabel(chartId, sw, "Dash_PnLVal", cx + 70, y,
             StringFormat("%+.2f  %+.2f%%", g_metrics.dailyPnL, g_metrics.dailyPnLPercent),
             pnlClr, FONT_BODY);
    y += LINE_H + 4;

    CreateSeparator(chartId, sw, "Dash_Sep2", px, y, PANEL_W);
    y += 6;

    // === SUMMARY STATS ===
    PutLabel(chartId, sw, "Dash_StatsHdr", cx, y,
             "SUMMARY", CLR_LABEL, FONT_BODY);
    y += LINE_H;

    // Total Trades
    PutLabel(chartId, sw, "Dash_TradesLbl", cx, y, "Trades", CLR_LABEL, FONT_BODY);
    PutLabel(chartId, sw, "Dash_TradesVal", cx + 70, y,
             StringFormat("%d", g_metrics.totalTrades), CLR_VALUE, FONT_BODY);
    y += LINE_H;

    // Win Rate
    string wrMark = g_metrics.gateWinRatePassed ? "  PASS" : "  FAIL";
    color  wrClr  = g_metrics.gateWinRatePassed ? CLR_PASS : CLR_FAIL;
    PutLabel(chartId, sw, "Dash_WRLbl", cx, y, "Win Rate", CLR_LABEL, FONT_BODY);
    PutLabel(chartId, sw, "Dash_WRVal", cx + 70, y,
             StringFormat("%.1f%%%s", g_metrics.winRate * 100, wrMark), wrClr, FONT_BODY);
    y += LINE_H;

    // Profit Factor
    string pfMark = g_metrics.gateProfitFactorPassed ? "  PASS" : "  FAIL";
    color  pfClr  = g_metrics.gateProfitFactorPassed ? CLR_PASS : CLR_FAIL;
    PutLabel(chartId, sw, "Dash_PFLbl", cx, y, "Prof Fctr", CLR_LABEL, FONT_BODY);
    PutLabel(chartId, sw, "Dash_PFVal", cx + 70, y,
             StringFormat("%.2f%s", g_metrics.profitFactor, pfMark), pfClr, FONT_BODY);
    y += LINE_H;

    // Max Drawdown
    string ddMark = g_metrics.gateMaxDDPassed ? "  PASS" : "  FAIL";
    color  ddClr  = g_metrics.gateMaxDDPassed ? CLR_PASS : CLR_FAIL;
    PutLabel(chartId, sw, "Dash_DDLbl", cx, y, "Max DD", CLR_LABEL, FONT_BODY);
    PutLabel(chartId, sw, "Dash_DDVal", cx + 70, y,
             StringFormat("%.2f%%%s", g_metrics.maxDailyDrawdown * 100, ddMark), ddClr, FONT_BODY);
    y += LINE_H + 4;

    CreateSeparator(chartId, sw, "Dash_Sep3", px, y, PANEL_W);
    y += 6;

    // === PER-SYMBOL BREAKDOWN ===
    int xau = cx;
    int eur  = cx + COL2_OFF;

    // Column headers
    PutLabel(chartId, sw, "Dash_XAUHdr", xau, y, "XAUUSD", CLR_XAUUSD, FONT_BODY);
    PutLabel(chartId, sw, "Dash_EURHdr", eur, y, "EURUSD", CLR_EURUSD, FONT_BODY);
    y += LINE_H;

    // Trades
    PutLabel(chartId, sw, "Dash_XAUTrd", xau, y,
             StringFormat("Trd: %d", g_metrics.symbolXAUUSD_trades), CLR_LABEL, FONT_BODY);
    PutLabel(chartId, sw, "Dash_EURTrd", eur, y,
             StringFormat("Trd: %d", g_metrics.symbolEURUSD_trades), CLR_LABEL, FONT_BODY);
    y += LINE_H;

    // Win Rate per symbol
    PutLabel(chartId, sw, "Dash_XAUWR", xau, y,
             StringFormat("WR:  %.1f%%", g_metrics.symbolXAUUSD_winRate * 100), CLR_XAUUSD, FONT_BODY);
    PutLabel(chartId, sw, "Dash_EURWR", eur, y,
             StringFormat("WR:  %.1f%%", g_metrics.symbolEURUSD_winRate * 100), CLR_EURUSD, FONT_BODY);
    y += LINE_H;

    // Profit Factor per symbol
    PutLabel(chartId, sw, "Dash_XAUPF", xau, y,
             StringFormat("PF:  %.2f", g_metrics.symbolXAUUSD_profitFactor), CLR_XAUUSD, FONT_BODY);
    PutLabel(chartId, sw, "Dash_EURPF", eur, y,
             StringFormat("PF:  %.2f", g_metrics.symbolEURUSD_profitFactor), CLR_EURUSD, FONT_BODY);
    y += LINE_H;

    // Total P&L per symbol
    PutLabel(chartId, sw, "Dash_XAUPnL", xau, y,
             StringFormat("P&L: $%.2f", g_metrics.symbolXAUUSD_pnl), CLR_XAUUSD, FONT_BODY);
    PutLabel(chartId, sw, "Dash_EURPnL", eur, y,
             StringFormat("P&L: $%.2f", g_metrics.symbolEURUSD_pnl), CLR_EURUSD, FONT_BODY);
    y += LINE_H + 4;

    CreateSeparator(chartId, sw, "Dash_Sep4", px, y, PANEL_W);
    y += 6;

    // === TIMESTAMP ===
    PutLabel(chartId, sw, "Dash_Time", cx, y,
             StringFormat("Updated: %s", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)),
             CLR_LABEL, FONT_BODY - 1);

    ChartRedraw(chartId);
}

//+------------------------------------------------------------------+
//| CleanupDashboardObjects — called from OnDeinit                   |
//+------------------------------------------------------------------+

void CleanupDashboardObjects()
{
    long chartId = ChartID();
    string names[] = {
        "Dash_BG",
        "Dash_Sep1",     "Dash_Sep2",    "Dash_Sep3",     "Dash_Sep4",
        "Dash_Title",    "Dash_SubTitle",
        "Dash_EqLbl",    "Dash_EqVal",
        "Dash_PnLLbl",   "Dash_PnLVal",
        "Dash_StatsHdr",
        "Dash_TradesLbl","Dash_TradesVal",
        "Dash_WRLbl",    "Dash_WRVal",
        "Dash_PFLbl",    "Dash_PFVal",
        "Dash_DDLbl",    "Dash_DDVal",
        "Dash_XAUHdr",   "Dash_EURHdr",
        "Dash_XAUTrd",   "Dash_EURTrd",
        "Dash_XAUWR",    "Dash_EURWR",
        "Dash_XAUPF",    "Dash_EURPF",
        "Dash_XAUPnL",   "Dash_EURPnL",
        "Dash_Time"
    };

    for(int i = 0; i < ArraySize(names); i++)
    {
        if(ObjectFind(chartId, names[i]) >= 0)
            ObjectDelete(chartId, names[i]);
    }
    ChartRedraw(chartId);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+

void OnDeinit(const int reason)
{
    string reasonText = "";
    switch(reason)
    {
        case REASON_ACCOUNT:     reasonText = "Account change";   break;
        case REASON_CHARTCHANGE: reasonText = "Chart change";     break;
        case REASON_CHARTCLOSE:  reasonText = "Chart closed";     break;
        case REASON_PARAMETERS:  reasonText = "Parameters modified"; break;
        case REASON_RECOMPILE:   reasonText = "Recompilation";    break;
        case REASON_REMOVE:      reasonText = "Manually removed"; break;
        case REASON_TEMPLATE:    reasonText = "Template loaded";  break;
        default:                 reasonText = "Unknown reason";   break;
    }
    CleanupDashboardObjects();
    Print("Dashboard Indicator deinitialised: ", reasonText);
}

//+------------------------------------------------------------------+
//| DASHBOARD INDICATOR — FINAL STATUS                               |
//| Version: Phase 5 Visual Redesign                                 |
//|                                                                  |
//| Fixes applied in redesign:                                       |
//|  [x] Subwindow bug: ChartWindowFind() replaces hardcoded 0      |
//|  [x] Background: OBJ_RECTANGLE_LABEL dark navy panel            |
//|  [x] Separator lines between sections                           |
//|  [x] Consolas 8pt body font, 9pt title                         |
//|  [x] XAUUSD = gold, EURUSD = cornflower blue                   |
//|  [x] PASS/FAIL gate markers inline with stats                   |
//|  [x] Timestamp row at panel bottom                              |
//|  [x] CleanupDashboardObjects includes background + separators   |
//+------------------------------------------------------------------+
