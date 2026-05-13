//+------------------------------------------------------------------+
//| Dashboard.mqh                                                    |
//| Volume Profile Dashboard — Metrics Calculation Engine            |
//| Phase 5: Trade Data Visualisation and Reporting                  |
//|                                                                  |
//| Core Functions:                                                  |
//|   - InitializeDashboard()      - Reset metrics to defaults       |
//|   - RefreshDashboardMetrics()  - Master orchestrator (bar close) |
//|   - UpdateEquityCurve()        - Running equity from history     |
//|   - UpdateDailyPnL()           - Daily P&L aggregation           |
//|   - CalculateSummaryStats()    - Win rate, PF, trade count       |
//|   - CalculatePerSymbolStats()  - XAUUSD vs EURUSD split (D-04)   |
//|   - CalculateMaxDrawdown()     - Max DD validation (<=2% gate)   |
//|                                                                  |
//| Data Source:                                                     |
//|   - HistorySelect() + HistoryDealGet*() for closed trades        |
//|   - AccountInfoDouble(ACCOUNT_EQUITY) for running equity         |
//|   - DashboardMetrics struct for aggregated display data          |
//|                                                                  |
//| Phase 3 Gates (live metrics validation):                         |
//|   - Win rate >= 50%  (REQ-042)                                   |
//|   - Profit Factor >= 1.5  (REQ-042)                              |
//|   - Max daily drawdown <= 2%  (REQ-042)                          |
//|                                                                  |
//| D-06: Bar-close refresh cadence (no tick-level calculations)    |
//| D-04: Per-symbol breakdown (XAUUSD and EURUSD separate)         |
//|                                                                  |
//+------------------------------------------------------------------+

#ifndef __DASHBOARD_MQH__
#define __DASHBOARD_MQH__

#include "TradeExecution.mqh"
#include "RiskManager.mqh"
#include "Utils.mqh"
#include <Trade/Trade.mqh>

// ==================== CONSTANTS ====================

#define MIN_WIN_RATE 0.50           // 50% minimum (REQ-042)
#define MIN_PROFIT_FACTOR 1.5       // 1.5x minimum (REQ-042)
#define MAX_DAILY_DRAWDOWN 0.02     // 2% maximum (REQ-042)
#define EQUITY_CURVE_HISTORY 500    // Store up to 500 bar closes

// ==================== DATA STRUCTURES ====================

//+------------------------------------------------------------------+
//| DashboardMetrics — Aggregated dashboard data for display         |
//| All fields populated by calculation functions below              |
//+------------------------------------------------------------------+
struct DashboardMetrics
{
    // Equity curve data
    datetime equityTime[];          // Timestamps for equity values
    double equityValues[];          // Running equity at each bar
    int equityCount;                // Current equity array size

    // Daily P&L tracking
    datetime dailyPnLDates[];       // Daily date stamps
    double dailyPnLValues[];        // Daily P&L in currency
    int dailyCount;                 // Daily entries count

    // Summary statistics
    int totalTrades;                // Total executed trades
    int winningTrades;              // Trades with profit > 0
    int losingTrades;               // Trades with profit < 0
    double winRate;                 // winningTrades / totalTrades
    double profitFactor;            // sumWinPnL / abs(sumLossPnL)
    double maxDailyDrawdown;        // Lowest daily equity vs. peak
    double currentEquity;           // Current account equity
    double sessionStartEquity;      // Starting equity when panel initialized
    double totalRealizedPnL;        // Cumulative P&L from all closed trades

    // Per-symbol breakdown (D-04: XAUUSD and EURUSD separate)
    string symbolXAUUSD_name;       // "XAUUSD"
    int symbolXAUUSD_trades;        // Trade count on XAUUSD
    int symbolXAUUSD_wins;          // Winning trades
    double symbolXAUUSD_totalPnL;   // Total P&L currency
    double symbolXAUUSD_winRate;    // Win rate %
    double symbolXAUUSD_profitFactor; // Profit factor

    string symbolEURUSD_name;       // "EURUSD"
    int symbolEURUSD_trades;        // Trade count on EURUSD
    int symbolEURUSD_wins;          // Winning trades
    double symbolEURUSD_totalPnL;   // Total P&L currency
    double symbolEURUSD_winRate;    // Win rate %
    double symbolEURUSD_profitFactor; // Profit factor
};

// ==================== FUNCTION DECLARATIONS ====================

void InitializeDashboard(DashboardMetrics &metrics);
void RefreshDashboardMetrics(DashboardMetrics &metrics);
void UpdateEquityCurve(DashboardMetrics &metrics);
void UpdateDailyPnL(DashboardMetrics &metrics);
void CalculateSummaryStats(DashboardMetrics &metrics);
void CalculatePerSymbolStats(DashboardMetrics &metrics);
void CalculateMaxDrawdown(DashboardMetrics &metrics);

// ==================== END DECLARATIONS ====================

// ==================== FUNCTION IMPLEMENTATIONS ====================

//+------------------------------------------------------------------+
//| InitializeDashboard() — Reset all metrics to safe defaults       |
//| Called once on indicator OnInit() before any calculations        |
//+------------------------------------------------------------------+
void InitializeDashboard(DashboardMetrics &metrics)
{
    metrics.totalTrades = 0;
    metrics.winningTrades = 0;
    metrics.losingTrades = 0;
    metrics.winRate = 0.0;
    metrics.profitFactor = 0.0;
    metrics.maxDailyDrawdown = 0.0;
    metrics.currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    metrics.sessionStartEquity = metrics.currentEquity;
    metrics.totalRealizedPnL = 0.0;

    metrics.equityCount = 0;
    metrics.dailyCount = 0;

    // Per-symbol defaults
    metrics.symbolXAUUSD_name = "XAUUSD";
    metrics.symbolXAUUSD_trades = 0;
    metrics.symbolXAUUSD_wins = 0;
    metrics.symbolXAUUSD_totalPnL = 0.0;
    metrics.symbolXAUUSD_winRate = 0.0;
    metrics.symbolXAUUSD_profitFactor = 0.0;

    metrics.symbolEURUSD_name = "EURUSD";
    metrics.symbolEURUSD_trades = 0;
    metrics.symbolEURUSD_wins = 0;
    metrics.symbolEURUSD_totalPnL = 0.0;
    metrics.symbolEURUSD_winRate = 0.0;
    metrics.symbolEURUSD_profitFactor = 0.0;
}

//+------------------------------------------------------------------+
//| RefreshDashboardMetrics() — Master orchestrator (bar close)      |
//| D-06: Bar-close update cadence — no tick-level calculations      |
//| Calls all sub-functions in correct dependency order              |
//+------------------------------------------------------------------+
void RefreshDashboardMetrics(DashboardMetrics &metrics)
{
    // Update equity curve (running balance from history)
    UpdateEquityCurve(metrics);

    // Recalculate daily P&L
    UpdateDailyPnL(metrics);

    // Refresh summary statistics (win rate, PF, max DD)
    CalculateSummaryStats(metrics);

    // Per-symbol breakdown (XAUUSD vs EURUSD)
    CalculatePerSymbolStats(metrics);

    // Max drawdown validation (enforce <=2% gate)
    CalculateMaxDrawdown(metrics);
}

//+------------------------------------------------------------------+
//| UpdateEquityCurve() — Running equity from HistorySelect()        |
//| Accumulates realized P&L from closed deals since session start   |
//| D-06: Called once per bar close; no tick-level recalculation     |
//+------------------------------------------------------------------+
void UpdateEquityCurve(DashboardMetrics &metrics)
{
    // Session start = last 24 hours (simplification for Phase 5)
    // Phase 4 refinement: use midnight SGT (UTC+8) or attach time, whichever earlier
    datetime sessionStart = TimeCurrent() - 86400;  // Last 24 hours

    if (!HistorySelect(sessionStart, TimeCurrent()))
    {
        Print("UpdateEquityCurve: HistorySelect failed");
        return;
    }

    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double runningBalance = AccountInfoDouble(ACCOUNT_BALANCE);

    int dealCount = HistoryDealsTotal();

    // Calculate realized P&L from all closed deals in session
    double realizedPnL = 0;
    for (int i = 0; i < dealCount; i++)
    {
        ulong dealTicket = HistoryDealGetTicket(i);
        if (dealTicket == 0) continue;

        double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
        realizedPnL += dealProfit;
    }

    // Update totals
    metrics.totalRealizedPnL = realizedPnL;
    metrics.currentEquity = currentEquity;

    // Append equity curve entry (bounded by EQUITY_CURVE_HISTORY)
    if (metrics.equityCount < EQUITY_CURVE_HISTORY)
    {
        ArrayResize(metrics.equityTime, metrics.equityCount + 1);
        ArrayResize(metrics.equityValues, metrics.equityCount + 1);

        metrics.equityTime[metrics.equityCount] = TimeCurrent();
        metrics.equityValues[metrics.equityCount] = currentEquity;
        metrics.equityCount++;
    }
    else
    {
        // Ring buffer: shift oldest entry out, write newest at end
        // Prevents unbounded array growth (T5-02 mitigation)
        for (int i = 0; i < EQUITY_CURVE_HISTORY - 1; i++)
        {
            metrics.equityTime[i] = metrics.equityTime[i + 1];
            metrics.equityValues[i] = metrics.equityValues[i + 1];
        }
        metrics.equityTime[EQUITY_CURVE_HISTORY - 1] = TimeCurrent();
        metrics.equityValues[EQUITY_CURVE_HISTORY - 1] = currentEquity;
        // equityCount stays at EQUITY_CURVE_HISTORY
    }
}

//+------------------------------------------------------------------+
//| UpdateDailyPnL() — Daily P&L aggregation (calendar day UTC)     |
//| Aggregates closed deal profits per calendar day                  |
//| Phase 4: Refine timezone to SGT (UTC+8) if needed               |
//+------------------------------------------------------------------+
void UpdateDailyPnL(DashboardMetrics &metrics)
{
    // Midnight UTC today (simplification; Phase 4 can refine for SGT)
    datetime today00 = (TimeCurrent() / 86400) * 86400;

    if (!HistorySelect(today00, TimeCurrent()))
    {
        Print("UpdateDailyPnL: HistorySelect failed");
        return;
    }

    int dealCount = HistoryDealsTotal();
    double dailySum = 0;

    for (int i = 0; i < dealCount; i++)
    {
        ulong dealTicket = HistoryDealGetTicket(i);
        if (dealTicket == 0) continue;

        double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
        dailySum += dealProfit;
    }

    // Check if today's entry already exists and update, or append new
    if (metrics.dailyCount == 0 ||
        (metrics.dailyCount > 0 && metrics.dailyPnLDates[metrics.dailyCount - 1] != today00))
    {
        // New calendar day — append entry
        if (metrics.dailyCount >= 250)  // Max 250 days of history
        {
            // Shift array down to discard oldest day
            for (int i = 0; i < 249; i++)
            {
                metrics.dailyPnLDates[i] = metrics.dailyPnLDates[i + 1];
                metrics.dailyPnLValues[i] = metrics.dailyPnLValues[i + 1];
            }
            metrics.dailyCount = 249;
        }
        else
        {
            ArrayResize(metrics.dailyPnLDates, metrics.dailyCount + 1);
            ArrayResize(metrics.dailyPnLValues, metrics.dailyCount + 1);
        }

        metrics.dailyPnLDates[metrics.dailyCount] = today00;
        metrics.dailyPnLValues[metrics.dailyCount] = dailySum;
        metrics.dailyCount++;
    }
    else if (metrics.dailyCount > 0)
    {
        // Same calendar day — update today's running total
        metrics.dailyPnLValues[metrics.dailyCount - 1] = dailySum;
    }
}

//+------------------------------------------------------------------+
//| CalculateSummaryStats() — Win rate, profit factor, trade count   |
//| REQ-042: Win rate >=50%, Profit Factor >=1.5                     |
//| Phase 3 gate thresholds: MIN_WIN_RATE, MIN_PROFIT_FACTOR         |
//+------------------------------------------------------------------+
void CalculateSummaryStats(DashboardMetrics &metrics)
{
    datetime sessionStart = TimeCurrent() - 86400;  // Last 24 hours

    if (!HistorySelect(sessionStart, TimeCurrent()))
    {
        Print("CalculateSummaryStats: HistorySelect failed");
        return;
    }

    int dealCount = HistoryDealsTotal();

    metrics.totalTrades = dealCount;
    metrics.winningTrades = 0;
    metrics.losingTrades = 0;

    double sumWinPnL = 0;
    double sumLossPnL = 0;

    for (int i = 0; i < dealCount; i++)
    {
        ulong dealTicket = HistoryDealGetTicket(i);
        if (dealTicket == 0) continue;

        double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);

        if (dealProfit > 0)
        {
            metrics.winningTrades++;
            sumWinPnL += dealProfit;
        }
        else if (dealProfit < 0)
        {
            metrics.losingTrades++;
            sumLossPnL += MathAbs(dealProfit);
        }
        // dealProfit == 0: break-even trade; not counted in win or loss
    }

    // Win rate (REQ-042: must be >=50%)
    if (metrics.totalTrades > 0)
    {
        metrics.winRate = (double)metrics.winningTrades / metrics.totalTrades;
    }
    else
    {
        metrics.winRate = 0.0;
    }

    // Profit factor (REQ-042: must be >=1.5)
    if (sumLossPnL > 0)
    {
        metrics.profitFactor = sumWinPnL / sumLossPnL;
    }
    else if (sumWinPnL > 0)
    {
        metrics.profitFactor = 999.0;  // No losses — report as very high
    }
    else
    {
        metrics.profitFactor = 0.0;  // No trades executed yet
    }

    // Log gate status for Phase 3 validation
    if (metrics.totalTrades > 0)
    {
        if (metrics.winRate < MIN_WIN_RATE)
        {
            Print(StringFormat("WARNING: Win rate %.1f%% below gate of %.1f%%",
                              metrics.winRate * 100, MIN_WIN_RATE * 100));
        }
        if (metrics.profitFactor < MIN_PROFIT_FACTOR && sumLossPnL > 0)
        {
            Print(StringFormat("WARNING: Profit factor %.2f below gate of %.2f",
                              metrics.profitFactor, MIN_PROFIT_FACTOR));
        }
    }
}

//+------------------------------------------------------------------+
//| CalculatePerSymbolStats() — Per-symbol breakdown (D-04)          |
//| Separates XAUUSD vs EURUSD performance metrics                   |
//| Each symbol gets independent win rate and profit factor          |
//+------------------------------------------------------------------+
void CalculatePerSymbolStats(DashboardMetrics &metrics)
{
    datetime sessionStart = TimeCurrent() - 86400;

    if (!HistorySelect(sessionStart, TimeCurrent()))
    {
        Print("CalculatePerSymbolStats: HistorySelect failed");
        return;
    }

    // Reset per-symbol counters before re-aggregation
    metrics.symbolXAUUSD_trades = 0;
    metrics.symbolXAUUSD_wins = 0;
    metrics.symbolXAUUSD_totalPnL = 0;
    metrics.symbolXAUUSD_winRate = 0;
    metrics.symbolXAUUSD_profitFactor = 0;

    metrics.symbolEURUSD_trades = 0;
    metrics.symbolEURUSD_wins = 0;
    metrics.symbolEURUSD_totalPnL = 0;
    metrics.symbolEURUSD_winRate = 0;
    metrics.symbolEURUSD_profitFactor = 0;

    double xauWinPnL = 0, xauLossPnL = 0;
    double eurWinPnL = 0, eurLossPnL = 0;

    int dealCount = HistoryDealsTotal();
    for (int i = 0; i < dealCount; i++)
    {
        ulong dealTicket = HistoryDealGetTicket(i);
        if (dealTicket == 0) continue;

        string dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
        double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);

        if (dealSymbol == "XAUUSD")
        {
            metrics.symbolXAUUSD_trades++;
            metrics.symbolXAUUSD_totalPnL += dealProfit;
            if (dealProfit > 0)
            {
                metrics.symbolXAUUSD_wins++;
                xauWinPnL += dealProfit;
            }
            else if (dealProfit < 0)
            {
                xauLossPnL += MathAbs(dealProfit);
            }
        }
        else if (dealSymbol == "EURUSD")
        {
            metrics.symbolEURUSD_trades++;
            metrics.symbolEURUSD_totalPnL += dealProfit;
            if (dealProfit > 0)
            {
                metrics.symbolEURUSD_wins++;
                eurWinPnL += dealProfit;
            }
            else if (dealProfit < 0)
            {
                eurLossPnL += MathAbs(dealProfit);
            }
        }
    }

    // Calculate per-symbol win rate and profit factor
    if (metrics.symbolXAUUSD_trades > 0)
    {
        metrics.symbolXAUUSD_winRate = (double)metrics.symbolXAUUSD_wins / metrics.symbolXAUUSD_trades;
        if (xauLossPnL > 0)
            metrics.symbolXAUUSD_profitFactor = xauWinPnL / xauLossPnL;
        else if (xauWinPnL > 0)
            metrics.symbolXAUUSD_profitFactor = 999.0;
    }

    if (metrics.symbolEURUSD_trades > 0)
    {
        metrics.symbolEURUSD_winRate = (double)metrics.symbolEURUSD_wins / metrics.symbolEURUSD_trades;
        if (eurLossPnL > 0)
            metrics.symbolEURUSD_profitFactor = eurWinPnL / eurLossPnL;
        else if (eurWinPnL > 0)
            metrics.symbolEURUSD_profitFactor = 999.0;
    }
}

//+------------------------------------------------------------------+
//| CalculateMaxDrawdown() — Maximum daily drawdown from equity curve |
//| REQ-042: Max daily drawdown must be <=2%                         |
//| T5-02: Operates on bounded equityValues[] (EQUITY_CURVE_HISTORY) |
//+------------------------------------------------------------------+
void CalculateMaxDrawdown(DashboardMetrics &metrics)
{
    if (metrics.equityCount == 0)
    {
        metrics.maxDailyDrawdown = 0;
        return;
    }

    double peakEquity = metrics.equityValues[0];
    double maxDD = 0;

    for (int i = 1; i < metrics.equityCount; i++)
    {
        // Track running peak
        if (metrics.equityValues[i] > peakEquity)
        {
            peakEquity = metrics.equityValues[i];
        }

        // Drawdown = (peak - current) / peak
        if (peakEquity > 0)
        {
            double drawdown = (peakEquity - metrics.equityValues[i]) / peakEquity;
            if (drawdown > maxDD)
            {
                maxDD = drawdown;
            }
        }
    }

    metrics.maxDailyDrawdown = maxDD;

    // Log warning if gate exceeded (REQ-042: <=2%)
    if (metrics.maxDailyDrawdown > MAX_DAILY_DRAWDOWN)
    {
        Print(StringFormat("WARNING: Max drawdown %.2f%% exceeds gate of %.2f%%",
                          metrics.maxDailyDrawdown * 100, MAX_DAILY_DRAWDOWN * 100));
    }
}

// ==================== END IMPLEMENTATIONS ====================

#endif  // __DASHBOARD_MQH__
