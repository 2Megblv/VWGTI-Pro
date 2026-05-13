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

extern int DashboardXOffset = 50;              // Panel X position (pixels from left)
extern int DashboardYOffset = 100;             // Panel Y position (pixels from top)

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

    // Step 3: Update ChartObjects (handled in Plan 03)
    // For now, just signal that data is ready
    // ChartObjects will be created/updated in RenderDashboard() (Plan 03)
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
