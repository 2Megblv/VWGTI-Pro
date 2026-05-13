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
