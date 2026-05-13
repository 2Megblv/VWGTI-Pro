//+------------------------------------------------------------------+
//| Dashboard_Indicator.mq5                                          |
//| Volume Profile Dashboard — Real-Time Performance Panel           |
//| Phase 5: Trade Data Visualisation and Reporting                  |
//|                                                                  |
//| Purpose:                                                         |
//|   Dedicated indicator running on separate chart window.          |
//|   Updates equity curve, P&L metrics, and summary stats on every  |
//|   bar close. Displays via ChartObjects.                          |
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

DashboardMetrics g_metrics;                    // Master metrics struct
static datetime g_lastBarTime = 0;             // Bar-close detection
static bool g_initialized = false;             // Initialization flag

input int DashboardXOffset = 50;               // Panel X position (pixels from left)
input int DashboardYOffset = 100;              // Panel Y position (pixels from top)

//+------------------------------------------------------------------+
//| Custom indicator initialization function (OnInit)                |
//+------------------------------------------------------------------+

int OnInit()
{
    // Initialize indicator properties
    IndicatorSetString(INDICATOR_SHORTNAME, "Volume Profile Dashboard");

    // Initialize dashboard metrics
    InitializeDashboard(g_metrics);

    // Set initial bar time (will update on first OnCalculate)
    g_lastBarTime = 0;
    g_initialized = true;

    Print("Dashboard Indicator initialized. Attach to dedicated chart window.");
    Print(StringFormat("Dashboard position: X=%d, Y=%d", DashboardXOffset, DashboardYOffset));

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function (OnCalculate)                |
//|                                                                  |
//| D-06: Bar-close refresh cadence                                  |
//| Called once per tick; detects bar close and updates once per bar |
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
    // CRITICAL: Bar-close detection (D-06 pattern from RESEARCH.md Pattern 1)
    // Only update dashboard when new bar completes, not every tick

    if (time[0] != g_lastBarTime)
    {
        // New bar detected; update dashboard
        g_lastBarTime = time[0];
        UpdateDashboard();
    }

    return(rates_total);  // Return total number of bars processed
}

//+------------------------------------------------------------------+
//| Update Dashboard (called once per completed bar)                 |
//|                                                                  |
//| Sequence:                                                        |
//|   1. Refresh all metrics via Dashboard.mqh functions             |
//|   2. Format metrics for display                                  |
//|   3. Prepare data for ChartObject rendering (Plan 03)            |
//+------------------------------------------------------------------+

void UpdateDashboard()
{
    // Step 1: Refresh all dashboard metrics (single master function call)
    RefreshDashboardMetrics(g_metrics);

    // Step 2: Log current state to MT5 Journal (optional, for debugging)
    LogDashboardState();

    // Step 3: Render all ChartObjects (Plan 03)
    RenderDashboard();
}

//+------------------------------------------------------------------+
//| Log Dashboard State (debug/audit trail)                          |
//+------------------------------------------------------------------+

void LogDashboardState()
{
    string msg = StringFormat(
        "Dashboard Update | Time=%s | Equity=%.2f | "
        "Trades=%d (Win=%.1f%%) | PF=%.2f | MaxDD=%.2f%% | "
        "XAUUSD=%d | EURUSD=%d",
        TimeToString(TimeCurrent()),
        g_metrics.currentEquity,
        g_metrics.totalTrades,
        g_metrics.winRate * 100,
        g_metrics.profitFactor,
        g_metrics.maxDailyDrawdown * 100,
        g_metrics.symbolXAUUSD_trades,
        g_metrics.symbolEURUSD_trades
    );

    Print(msg);  // Output to MT5 Journal
}

//+------------------------------------------------------------------+
//| Extern linkages (optional — for live position data from EA)      |
//| NOTE: These will only link if trading EA exposes these externs   |
//|       If not linked, dashboard still functions using only        |
//|       HistorySelect() for closed trades                          |
//+------------------------------------------------------------------+

// Uncomment if trading EA exposes PositionState:
// extern PositionState positions[MAX_POSITIONS];
// extern int positionCount;

// Alternative: Use local copies for dashboard use
// (Dashboard only needs read access; doesn't modify EA state)

// === CHARTOBJECT HELPER (Plan 03 - Pitfall Mitigation) ===
// Handles object creation/update without flicker or duplication.
// Implements RESEARCH.md Pitfall 5 mitigation: check existence before create.

void UpdateDashboardLabel(long chartId, string objectName, int xDistance, int yDistance,
                          string text, color textColor = clrWhite, int fontSize = 10)
{
    if(ObjectFind(chartId, objectName) >= 0)
    {
        // Object exists — update text and color only (faster, no flicker)
        ObjectSetString(chartId, objectName, OBJPROP_TEXT, text);
        ObjectSetInteger(chartId, objectName, OBJPROP_COLOR, textColor);
    }
    else
    {
        // Object doesn't exist — create it
        if(!ObjectCreate(chartId, objectName, OBJ_LABEL, 0, 0, 0))
        {
            Print(StringFormat("Dashboard: failed to create label '%s'", objectName));
            return;
        }
        ObjectSetInteger(chartId, objectName, OBJPROP_XDISTANCE, xDistance);
        ObjectSetInteger(chartId, objectName, OBJPROP_YDISTANCE, yDistance);
        ObjectSetString(chartId, objectName, OBJPROP_TEXT, text);
        ObjectSetInteger(chartId, objectName, OBJPROP_COLOR, textColor);
        ObjectSetInteger(chartId, objectName, OBJPROP_FONTSIZE, fontSize);
        ObjectSetString(chartId, objectName, OBJPROP_FONT, "Arial");
        ObjectSetInteger(chartId, objectName, OBJPROP_ANCHOR, ANCHOR_LEFT_TOP);
        ObjectSetInteger(chartId, objectName, OBJPROP_BACK, false);
    }
}

// === RENDERING LAYER (Plan 03) ===
// RenderDashboard() and UpdateDashboardLabel() handle all visual display.
// Called once per bar from UpdateDashboard() (Plan 02).
// Data source: g_metrics struct (populated by Dashboard.mqh Plan 01).

void RenderDashboard()
{
    long   chartId    = ChartID();
    int    xPos       = DashboardXOffset;
    int    yPos       = DashboardYOffset;
    const int lineH   = 20;               // pixels between lines
    const color titleClr   = clrWhite;
    const color okClr      = clrLimeGreen;
    const color failClr    = clrRed;
    const color neutralClr = clrSilver;

    // --- HEADER ---
    UpdateDashboardLabel(chartId, "Dash_Title", xPos, yPos,
                         "VOLUME PROFILE DASHBOARD", titleClr, 12);
    yPos += (int)(lineH * 1.5);

    // --- EQUITY ---
    UpdateDashboardLabel(chartId, "Dash_Equity", xPos, yPos,
                         StringFormat("Equity: $%.2f", g_metrics.currentEquity),
                         okClr, 10);
    yPos += lineH;

    // --- DAILY P&L ---
    color pnlClr = (g_metrics.dailyPnL >= 0) ? okClr : failClr;
    UpdateDashboardLabel(chartId, "Dash_DailyPnL", xPos, yPos,
                         StringFormat("Daily P&L: $%.2f (%.2f%%)",
                                      g_metrics.dailyPnL,
                                      g_metrics.dailyPnLPercent),
                         pnlClr, 10);
    yPos += (int)(lineH * 1.5);

    // --- SUMMARY STATS HEADER ---
    UpdateDashboardLabel(chartId, "Dash_StatsHdr", xPos, yPos,
                         "SUMMARY STATS", titleClr, 11);
    yPos += lineH;

    // Total Trades
    UpdateDashboardLabel(chartId, "Dash_Trades", xPos, yPos,
                         StringFormat("Total Trades: %d", g_metrics.totalTrades),
                         neutralClr, 10);
    yPos += lineH;

    // Win Rate — Phase 3 gate >=50%
    string wrCheck = g_metrics.gateWinRatePassed ? " \x2713" : " \x2717";
    color  wrClr   = g_metrics.gateWinRatePassed ? okClr : failClr;
    UpdateDashboardLabel(chartId, "Dash_WinRate", xPos, yPos,
                         StringFormat("Win Rate: %.1f%%%s", g_metrics.winRate * 100, wrCheck),
                         wrClr, 10);
    yPos += lineH;

    // Profit Factor — Phase 3 gate >=1.5
    string pfCheck = g_metrics.gateProfitFactorPassed ? " \x2713" : " \x2717";
    color  pfClr   = g_metrics.gateProfitFactorPassed ? okClr : failClr;
    UpdateDashboardLabel(chartId, "Dash_PF", xPos, yPos,
                         StringFormat("Profit Factor: %.2f%s", g_metrics.profitFactor, pfCheck),
                         pfClr, 10);
    yPos += lineH;

    // Max Daily Drawdown — Phase 3 gate <=2%
    string ddCheck = g_metrics.gateMaxDDPassed ? " \x2713" : " \x2717";
    color  ddClr   = g_metrics.gateMaxDDPassed ? okClr : failClr;
    UpdateDashboardLabel(chartId, "Dash_MaxDD", xPos, yPos,
                         StringFormat("Max DD: %.2f%%%s", g_metrics.maxDailyDrawdown * 100, ddCheck),
                         ddClr, 10);
    yPos += (int)(lineH * 1.5);

    // --- PER-SYMBOL BREAKDOWN ---
    int xauCol = xPos;
    int eurCol = xPos + 185;   // EURUSD column offset

    UpdateDashboardLabel(chartId, "Dash_XAUHdr", xauCol, yPos, "XAUUSD", titleClr, 11);
    UpdateDashboardLabel(chartId, "Dash_EURHdr", eurCol, yPos, "EURUSD", titleClr, 11);
    yPos += lineH;

    UpdateDashboardLabel(chartId, "Dash_XAUTrades", xauCol, yPos,
                         StringFormat("Trades: %d", g_metrics.symbolXAUUSD_trades), neutralClr, 10);
    UpdateDashboardLabel(chartId, "Dash_EURTrades", eurCol, yPos,
                         StringFormat("Trades: %d", g_metrics.symbolEURUSD_trades), neutralClr, 10);
    yPos += lineH;

    UpdateDashboardLabel(chartId, "Dash_XAUWR", xauCol, yPos,
                         StringFormat("Win Rate: %.1f%%", g_metrics.symbolXAUUSD_winRate * 100),
                         neutralClr, 10);
    UpdateDashboardLabel(chartId, "Dash_EURWR", eurCol, yPos,
                         StringFormat("Win Rate: %.1f%%", g_metrics.symbolEURUSD_winRate * 100),
                         neutralClr, 10);
    yPos += lineH;

    UpdateDashboardLabel(chartId, "Dash_XAUPF", xauCol, yPos,
                         StringFormat("Profit Factor: %.2f", g_metrics.symbolXAUUSD_profitFactor),
                         neutralClr, 10);
    UpdateDashboardLabel(chartId, "Dash_EURPF", eurCol, yPos,
                         StringFormat("Profit Factor: %.2f", g_metrics.symbolEURUSD_profitFactor),
                         neutralClr, 10);
    yPos += lineH;

    UpdateDashboardLabel(chartId, "Dash_XAUPnL", xauCol, yPos,
                         StringFormat("Total P&L: $%.2f", g_metrics.symbolXAUUSD_pnl),
                         neutralClr, 10);
    UpdateDashboardLabel(chartId, "Dash_EURPnL", eurCol, yPos,
                         StringFormat("Total P&L: $%.2f", g_metrics.symbolEURUSD_pnl),
                         neutralClr, 10);

    ChartRedraw(chartId);
}

void CleanupDashboardObjects()
{
    long chartId = ChartID();
    string prefixes[] = {
        "Dash_Title", "Dash_Equity", "Dash_DailyPnL", "Dash_StatsHdr",
        "Dash_Trades", "Dash_WinRate", "Dash_PF", "Dash_MaxDD",
        "Dash_XAUHdr", "Dash_EURHdr", "Dash_XAUTrades", "Dash_EURTrades",
        "Dash_XAUWR", "Dash_EURWR", "Dash_XAUPF", "Dash_EURPF",
        "Dash_XAUPnL", "Dash_EURPnL"
    };
    for(int i = 0; i < ArraySize(prefixes); i++)
    {
        if(ObjectFind(chartId, prefixes[i]) >= 0)
            ObjectDelete(chartId, prefixes[i]);
    }
    ChartRedraw(chartId);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function (OnDeinit)            |
//+------------------------------------------------------------------+

void OnDeinit(const int reason)
{
    string reasonText = "";

    switch(reason)
    {
        case REASON_ACCOUNT:     reasonText = "Account change"; break;
        case REASON_CHARTCHANGE: reasonText = "Chart change"; break;
        case REASON_CHARTCLOSE:  reasonText = "Chart closed"; break;
        case REASON_PARAMETERS:  reasonText = "Parameters modified"; break;
        case REASON_RECOMPILE:   reasonText = "Recompilation"; break;
        case REASON_REMOVE:      reasonText = "Manually removed"; break;
        case REASON_TEMPLATE:    reasonText = "Template loaded"; break;
        default:                 reasonText = "Unknown reason"; break;
    }

    // Clean up all ChartObject labels created by RenderDashboard()
    CleanupDashboardObjects();

    Print(StringFormat("Dashboard Indicator deinitialized: %s", reasonText));
}

//+------------------------------------------------------------------+
//| DASHBOARD INDICATOR — FINAL STATUS                               |
//| INDICATOR_VERSION: Phase 5 Plan 03 Final                        |
//| MQL5 Standard: MT5 Build 4000+                                  |
//| Dependencies: Dashboard.mqh (Plan 01), TradeExecution.mqh       |
//|                                                                  |
//| Functionality:                                                   |
//|  [x] Attaches to dedicated chart window (separate_window mode)  |
//|  [x] Bar-close detection (time[0] != g_lastBarTime)             |
//|  [x] Dashboard refresh once per bar (not every tick) — D-06    |
//|  [x] Phase 3 gates displayed (WR>=50%, PF>=1.5, DD<=2%)         |
//|  [x] Per-symbol breakdown (XAUUSD vs EURUSD two-column)         |
//|  [x] ChartObject rendering via UpdateDashboardLabel()           |
//|  [x] Object cleanup on OnDeinit via CleanupDashboardObjects()   |
//|  [x] No interference with trading EA (separate window)          |
//|                                                                  |
//| Requirements Covered:                                            |
//|  REQ-042: win rate, profit factor, max DD calculated & displayed|
//|                                                                  |
//| === FINAL VALIDATION CHECKLIST ===                              |
//|  [x] Dashboard.mqh created (Plan 01) — 550 lines               |
//|  [x] Dashboard_Indicator.mq5 (Plans 02-03) — 360+ lines        |
//|  [x] Bar-close detection: time[0] != g_lastBarTime             |
//|  [x] Dashboard updates: once per bar, not every tick            |
//|  [x] ChartObject rendering: UpdateDashboardLabel() create/update|
//|  [x] Phase 3 gates: WR>=50%, PF>=1.5, MaxDD<=2% with markers   |
//|  [x] Per-symbol: XAUUSD and EURUSD separate columns            |
//|  [x] Zero-lag: separate window, EA on main chart unaffected     |
//|  [x] Pitfall 2: object names prefixed "Dash_*"                 |
//|  [x] Pitfall 3: positioning via extern DashboardXOffset/YOffset |
//|  [x] Pitfall 5: ObjectSetString() update, not delete+recreate  |
//|                                                                  |
//| Phase 5 Deliverables (COMPLETE):                                |
//|  [x] Plan 01 — Dashboard.mqh (metrics engine + gate constants)  |
//|  [x] Plan 02 — Dashboard_Indicator.mq5 (lifecycle + bar-close)  |
//|  [x] Plan 03 — ChartObject rendering (visual layer)            |
//|                                                                  |
//+------------------------------------------------------------------+
