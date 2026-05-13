//+------------------------------------------------------------------+
//| Dashboard.mqh                                                     |
//| Volume Profile Dashboard — Core Metrics Calculation Engine       |
//| Phase 5: Trade Data Visualisation and Reporting                  |
//|                                                                  |
//| Purpose:                                                         |
//|   Centralises all dashboard metric calculations in one module.   |
//|   Aggregates trade history via HistorySelect(), computes equity  |
//|   curves, win rate, profit factor, max drawdown, and per-symbol  |
//|   breakdowns. Decouples metrics logic from ChartObject rendering. |
//|                                                                  |
//| Integration:                                                     |
//|   - Called from Dashboard_Indicator.mq5 on every bar close       |
//|   - Reads closed trades from MT5 HistorySelect()                 |
//|   - Displays metrics validated against Phase 3 success gates     |
//|   - Per-symbol: XAUUSD and EURUSD tracked separately             |
//|                                                                  |
//| Phase 3 Gate Thresholds (displayed live):                        |
//|   - Win Rate   >= 50%                                            |
//|   - Profit Factor >= 1.5                                         |
//|   - Max Daily Drawdown <= 2%                                     |
//|                                                                  |
//+------------------------------------------------------------------+

#ifndef __DASHBOARD_MQH__
#define __DASHBOARD_MQH__

#include "JournalLogger.mqh"
#include "TradeExecution.mqh"
#include "RiskManager.mqh"

//+------------------------------------------------------------------+
//| Constants                                                        |
//+------------------------------------------------------------------+

#define DASHBOARD_MAX_EQUITY_POINTS 500    // Max equity curve history points
#define DASHBOARD_MAX_DAILY_RECORDS 365    // Max daily P&L records (1 year)

// Phase 3 success gate thresholds (REQ-042)
#define GATE_MIN_WIN_RATE     0.50         // 50% minimum win rate
#define GATE_MIN_PROFIT_FACTOR 1.50        // 1.5 minimum profit factor
#define GATE_MAX_DAILY_DD     0.02         // 2% maximum daily drawdown

//+------------------------------------------------------------------+
//| DashboardMetrics Struct                                          |
//|                                                                  |
//| Master container for all dashboard display data.                 |
//| Updated once per bar close by RefreshDashboardMetrics().         |
//+------------------------------------------------------------------+

struct DashboardMetrics
{
    // Equity Curve
    double  startingBalance;            // Balance at indicator attach time
    double  currentEquity;             // Current account equity (real-time)
    double  currentBalance;            // Current account balance
    double  equityPnL;                 // currentEquity - startingBalance
    double  equityPnLPercent;          // equityPnL / startingBalance * 100

    // Daily P&L (resets each trading day)
    double  dailyPnL;                  // Today's realised P&L (currency)
    double  dailyPnLPercent;           // dailyPnL / startingBalance * 100
    double  dailyStartBalance;         // Balance at session start today
    datetime dailyResetTime;           // Timestamp of last daily reset

    // Summary Statistics
    int     totalTrades;               // Total completed trades
    int     winningTrades;             // Trades with pnlCurrency > 0
    int     losingTrades;              // Trades with pnlCurrency <= 0
    double  winRate;                   // winningTrades / totalTrades
    double  grossProfit;               // Sum of winning trade P&L
    double  grossLoss;                 // Sum of losing trade P&L (absolute value)
    double  profitFactor;              // grossProfit / grossLoss
    double  maxDailyDrawdown;          // Worst single-day drawdown (percent)
    double  averageWin;                // Average winning trade P&L
    double  averageLoss;               // Average losing trade P&L (absolute)

    // Per-Symbol Breakdown — XAUUSD
    int     symbolXAUUSD_trades;       // Total XAUUSD trades
    int     symbolXAUUSD_wins;         // XAUUSD winning trades
    double  symbolXAUUSD_winRate;      // XAUUSD win rate
    double  symbolXAUUSD_pnl;          // XAUUSD total P&L
    double  symbolXAUUSD_profitFactor; // XAUUSD profit factor

    // Per-Symbol Breakdown — EURUSD
    int     symbolEURUSD_trades;       // Total EURUSD trades
    int     symbolEURUSD_wins;         // EURUSD winning trades
    double  symbolEURUSD_winRate;      // EURUSD win rate
    double  symbolEURUSD_pnl;          // EURUSD total P&L
    double  symbolEURUSD_profitFactor; // EURUSD profit factor

    // Gate Validation Flags (Phase 3 thresholds)
    bool    gateWinRatePassed;         // winRate >= GATE_MIN_WIN_RATE
    bool    gateProfitFactorPassed;    // profitFactor >= GATE_MIN_PROFIT_FACTOR
    bool    gateMaxDDPassed;           // maxDailyDrawdown <= GATE_MAX_DAILY_DD
    bool    allGatesPassed;            // All three gates met

    // Equity Curve History (ring buffer)
    double  equityCurve[DASHBOARD_MAX_EQUITY_POINTS];
    datetime equityTimes[DASHBOARD_MAX_EQUITY_POINTS];
    int     equityCurveCount;          // Current number of points in history
};

//+------------------------------------------------------------------+
//| Function Declarations                                            |
//+------------------------------------------------------------------+

// Core lifecycle
void InitializeDashboard(DashboardMetrics &metrics);
void RefreshDashboardMetrics(DashboardMetrics &metrics);

// Equity and balance
void UpdateEquityCurve(DashboardMetrics &metrics);

// Trade history aggregation (HistorySelect)
void CalculateDailyPnL(DashboardMetrics &metrics);
void CalculateSummaryStats(DashboardMetrics &metrics);
void CalculatePerSymbolStats(DashboardMetrics &metrics);
void CalculateMaxDrawdown(DashboardMetrics &metrics);

// Gate validation
void ValidatePhase3Gates(DashboardMetrics &metrics);

//+------------------------------------------------------------------+
//| InitializeDashboard                                              |
//|                                                                  |
//| Reset all metrics to default state. Called once at OnInit().     |
//+------------------------------------------------------------------+

void InitializeDashboard(DashboardMetrics &metrics)
{
    // Equity snapshot at attach time
    metrics.startingBalance    = AccountInfoDouble(ACCOUNT_BALANCE);
    metrics.currentEquity      = AccountInfoDouble(ACCOUNT_EQUITY);
    metrics.currentBalance     = AccountInfoDouble(ACCOUNT_BALANCE);
    metrics.equityPnL          = 0.0;
    metrics.equityPnLPercent   = 0.0;

    // Daily P&L initialisation
    metrics.dailyPnL           = 0.0;
    metrics.dailyPnLPercent    = 0.0;
    metrics.dailyStartBalance  = metrics.startingBalance;
    metrics.dailyResetTime     = TimeCurrent();

    // Summary stats — clear
    metrics.totalTrades        = 0;
    metrics.winningTrades      = 0;
    metrics.losingTrades       = 0;
    metrics.winRate            = 0.0;
    metrics.grossProfit        = 0.0;
    metrics.grossLoss          = 0.0;
    metrics.profitFactor       = 0.0;
    metrics.maxDailyDrawdown   = 0.0;
    metrics.averageWin         = 0.0;
    metrics.averageLoss        = 0.0;

    // Per-symbol XAUUSD — clear
    metrics.symbolXAUUSD_trades       = 0;
    metrics.symbolXAUUSD_wins         = 0;
    metrics.symbolXAUUSD_winRate      = 0.0;
    metrics.symbolXAUUSD_pnl          = 0.0;
    metrics.symbolXAUUSD_profitFactor = 0.0;

    // Per-symbol EURUSD — clear
    metrics.symbolEURUSD_trades       = 0;
    metrics.symbolEURUSD_wins         = 0;
    metrics.symbolEURUSD_winRate      = 0.0;
    metrics.symbolEURUSD_pnl          = 0.0;
    metrics.symbolEURUSD_profitFactor = 0.0;

    // Gate flags — clear
    metrics.gateWinRatePassed      = false;
    metrics.gateProfitFactorPassed = false;
    metrics.gateMaxDDPassed        = false;
    metrics.allGatesPassed         = false;

    // Equity curve — initialise ring buffer
    metrics.equityCurveCount = 0;
    ArrayInitialize(metrics.equityCurve, 0.0);

    Print(StringFormat("Dashboard initialised. Starting balance: %.2f", metrics.startingBalance));
}

//+------------------------------------------------------------------+
//| RefreshDashboardMetrics                                          |
//|                                                                  |
//| Master update function called once per bar close.               |
//| Sequence: equity → daily P&L → summary stats → per-symbol →     |
//|           max drawdown → gate validation                         |
//+------------------------------------------------------------------+

void RefreshDashboardMetrics(DashboardMetrics &metrics)
{
    // Step 1: Snapshot current equity
    UpdateEquityCurve(metrics);

    // Step 2: Calculate today's realised P&L
    CalculateDailyPnL(metrics);

    // Step 3: Aggregate all-time summary statistics
    CalculateSummaryStats(metrics);

    // Step 4: Per-symbol performance breakdown
    CalculatePerSymbolStats(metrics);

    // Step 5: Maximum daily drawdown across all trading days
    CalculateMaxDrawdown(metrics);

    // Step 6: Validate Phase 3 gates
    ValidatePhase3Gates(metrics);
}

//+------------------------------------------------------------------+
//| UpdateEquityCurve                                                |
//|                                                                  |
//| Appends current equity to ring buffer history.                  |
//| Ring buffer overwrites oldest entry when full.                  |
//+------------------------------------------------------------------+

void UpdateEquityCurve(DashboardMetrics &metrics)
{
    metrics.currentEquity  = AccountInfoDouble(ACCOUNT_EQUITY);
    metrics.currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    metrics.equityPnL      = metrics.currentEquity - metrics.startingBalance;

    if (metrics.startingBalance > 0)
    {
        metrics.equityPnLPercent = (metrics.equityPnL / metrics.startingBalance) * 100.0;
    }

    // Append to ring buffer (rotate when full)
    int idx = metrics.equityCurveCount % DASHBOARD_MAX_EQUITY_POINTS;
    metrics.equityCurve[idx]  = metrics.currentEquity;
    metrics.equityTimes[idx]  = TimeCurrent();
    metrics.equityCurveCount++;
}

//+------------------------------------------------------------------+
//| CalculateDailyPnL                                                |
//|                                                                  |
//| Queries HistorySelect() for today's closed deals.               |
//| Resets daily counter at midnight (TimeCurrent day change).      |
//| Mitigates Pitfall 1: HistorySelect called once per bar only.    |
//+------------------------------------------------------------------+

void CalculateDailyPnL(DashboardMetrics &metrics)
{
    // Determine today's midnight boundary
    datetime now = TimeCurrent();
    datetime todayMidnight = now - (now % 86400);  // Floor to day boundary

    // Reset if new trading day
    if (todayMidnight > metrics.dailyResetTime)
    {
        metrics.dailyResetTime    = todayMidnight;
        metrics.dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        metrics.dailyPnL          = 0.0;
        metrics.dailyPnLPercent   = 0.0;
    }

    // Select today's deal history (D-06: called once per bar, not every tick)
    if (!HistorySelect(todayMidnight, now))
    {
        Print("WARNING: HistorySelect() failed for daily P&L calculation");
        return;
    }

    // Aggregate realised P&L from completed deals
    int totalDeals = HistoryDealsTotal();
    double todayPnL = 0.0;

    for (int i = 0; i < totalDeals; i++)
    {
        ulong dealTicket = HistoryDealGetTicket(i);
        if (dealTicket == 0) continue;

        // Only count DEAL_ENTRY_OUT (closing deals) for realised P&L
        ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
        if (dealEntry != DEAL_ENTRY_OUT) continue;

        todayPnL += HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
        todayPnL += HistoryDealGetDouble(dealTicket, DEAL_SWAP);
        todayPnL += HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
    }

    metrics.dailyPnL = todayPnL;

    if (metrics.dailyStartBalance > 0)
    {
        metrics.dailyPnLPercent = (metrics.dailyPnL / metrics.dailyStartBalance) * 100.0;
    }
}

//+------------------------------------------------------------------+
//| CalculateSummaryStats                                            |
//|                                                                  |
//| Aggregates all-time win rate, profit factor, average win/loss   |
//| from full MT5 history (from account open to now).               |
//+------------------------------------------------------------------+

void CalculateSummaryStats(DashboardMetrics &metrics)
{
    // Select full account history
    datetime fromTime = 0;  // From the beginning
    datetime toTime   = TimeCurrent();

    if (!HistorySelect(fromTime, toTime))
    {
        Print("WARNING: HistorySelect() failed for summary stats");
        return;
    }

    int totalDeals = HistoryDealsTotal();

    // Reset counters before re-aggregating
    metrics.totalTrades    = 0;
    metrics.winningTrades  = 0;
    metrics.losingTrades   = 0;
    metrics.grossProfit    = 0.0;
    metrics.grossLoss      = 0.0;

    for (int i = 0; i < totalDeals; i++)
    {
        ulong dealTicket = HistoryDealGetTicket(i);
        if (dealTicket == 0) continue;

        // Only count DEAL_ENTRY_OUT (closing deals)
        ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
        if (dealEntry != DEAL_ENTRY_OUT) continue;

        double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                      + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                      + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);

        metrics.totalTrades++;

        if (profit > 0)
        {
            metrics.winningTrades++;
            metrics.grossProfit += profit;
        }
        else
        {
            metrics.losingTrades++;
            metrics.grossLoss += MathAbs(profit);
        }
    }

    // Compute derived metrics
    if (metrics.totalTrades > 0)
    {
        metrics.winRate = (double)metrics.winningTrades / (double)metrics.totalTrades;
    }

    if (metrics.grossLoss > 0)
    {
        metrics.profitFactor = metrics.grossProfit / metrics.grossLoss;
    }
    else if (metrics.grossProfit > 0)
    {
        metrics.profitFactor = 999.99;  // No losses — show cap value
    }

    if (metrics.winningTrades > 0)
        metrics.averageWin = metrics.grossProfit / metrics.winningTrades;

    if (metrics.losingTrades > 0)
        metrics.averageLoss = metrics.grossLoss / metrics.losingTrades;
}

//+------------------------------------------------------------------+
//| CalculatePerSymbolStats                                          |
//|                                                                  |
//| Splits aggregated stats by XAUUSD and EURUSD.                   |
//| Satisfies D-04: per-symbol breakdown requirement.               |
//+------------------------------------------------------------------+

void CalculatePerSymbolStats(DashboardMetrics &metrics)
{
    datetime fromTime = 0;
    datetime toTime   = TimeCurrent();

    if (!HistorySelect(fromTime, toTime))
    {
        Print("WARNING: HistorySelect() failed for per-symbol stats");
        return;
    }

    int totalDeals = HistoryDealsTotal();

    // Reset per-symbol counters
    metrics.symbolXAUUSD_trades = 0;
    metrics.symbolXAUUSD_wins   = 0;
    metrics.symbolXAUUSD_pnl    = 0.0;
    double xauusd_gross_profit  = 0.0;
    double xauusd_gross_loss    = 0.0;

    metrics.symbolEURUSD_trades = 0;
    metrics.symbolEURUSD_wins   = 0;
    metrics.symbolEURUSD_pnl    = 0.0;
    double eurusd_gross_profit  = 0.0;
    double eurusd_gross_loss    = 0.0;

    for (int i = 0; i < totalDeals; i++)
    {
        ulong dealTicket = HistoryDealGetTicket(i);
        if (dealTicket == 0) continue;

        // Only closing deals
        ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
        if (dealEntry != DEAL_ENTRY_OUT) continue;

        string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
        double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                      + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                      + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);

        if (StringFind(symbol, "XAUUSD") >= 0)
        {
            metrics.symbolXAUUSD_trades++;
            metrics.symbolXAUUSD_pnl += profit;
            if (profit > 0)
            {
                metrics.symbolXAUUSD_wins++;
                xauusd_gross_profit += profit;
            }
            else
            {
                xauusd_gross_loss += MathAbs(profit);
            }
        }
        else if (StringFind(symbol, "EURUSD") >= 0)
        {
            metrics.symbolEURUSD_trades++;
            metrics.symbolEURUSD_pnl += profit;
            if (profit > 0)
            {
                metrics.symbolEURUSD_wins++;
                eurusd_gross_profit += profit;
            }
            else
            {
                eurusd_gross_loss += MathAbs(profit);
            }
        }
    }

    // XAUUSD derived metrics
    if (metrics.symbolXAUUSD_trades > 0)
    {
        metrics.symbolXAUUSD_winRate = (double)metrics.symbolXAUUSD_wins
                                      / (double)metrics.symbolXAUUSD_trades;
    }
    if (xauusd_gross_loss > 0)
        metrics.symbolXAUUSD_profitFactor = xauusd_gross_profit / xauusd_gross_loss;
    else if (xauusd_gross_profit > 0)
        metrics.symbolXAUUSD_profitFactor = 999.99;

    // EURUSD derived metrics
    if (metrics.symbolEURUSD_trades > 0)
    {
        metrics.symbolEURUSD_winRate = (double)metrics.symbolEURUSD_wins
                                      / (double)metrics.symbolEURUSD_trades;
    }
    if (eurusd_gross_loss > 0)
        metrics.symbolEURUSD_profitFactor = eurusd_gross_profit / eurusd_gross_loss;
    else if (eurusd_gross_profit > 0)
        metrics.symbolEURUSD_profitFactor = 999.99;
}

//+------------------------------------------------------------------+
//| CalculateMaxDrawdown                                             |
//|                                                                  |
//| Computes worst single-day drawdown across all trading history.  |
//| Uses daily balance snapshots from HistoryDealGetDouble().        |
//+------------------------------------------------------------------+

void CalculateMaxDrawdown(DashboardMetrics &metrics)
{
    // Scan daily P&L records to find worst drawdown day
    // Simplified approach: compare daily balance drop vs daily start balance

    double worstDailyDrop = 0.0;

    // Calculate running peak balance through all closed deals
    datetime fromTime = 0;
    datetime toTime   = TimeCurrent();

    if (!HistorySelect(fromTime, toTime))
    {
        Print("WARNING: HistorySelect() failed for max drawdown calculation");
        return;
    }

    int totalDeals = HistoryDealsTotal();
    double peakBalance = metrics.startingBalance;
    double runningBalance = metrics.startingBalance;

    for (int i = 0; i < totalDeals; i++)
    {
        ulong dealTicket = HistoryDealGetTicket(i);
        if (dealTicket == 0) continue;

        ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
        if (dealEntry != DEAL_ENTRY_OUT) continue;

        double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                      + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                      + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);

        runningBalance += profit;

        // Track peak and drawdown
        if (runningBalance > peakBalance)
        {
            peakBalance = runningBalance;
        }

        if (peakBalance > 0)
        {
            double drawdown = (peakBalance - runningBalance) / peakBalance;
            if (drawdown > worstDailyDrop)
            {
                worstDailyDrop = drawdown;
            }
        }
    }

    metrics.maxDailyDrawdown = worstDailyDrop;
}

//+------------------------------------------------------------------+
//| ValidatePhase3Gates                                              |
//|                                                                  |
//| Checks if current metrics meet Phase 3 success thresholds.      |
//| Gate status flags drive visual indicators in Plan 03 rendering. |
//+------------------------------------------------------------------+

void ValidatePhase3Gates(DashboardMetrics &metrics)
{
    metrics.gateWinRatePassed      = (metrics.winRate >= GATE_MIN_WIN_RATE);
    metrics.gateProfitFactorPassed = (metrics.profitFactor >= GATE_MIN_PROFIT_FACTOR);
    metrics.gateMaxDDPassed        = (metrics.maxDailyDrawdown <= GATE_MAX_DAILY_DD);

    metrics.allGatesPassed = metrics.gateWinRatePassed
                           && metrics.gateProfitFactorPassed
                           && metrics.gateMaxDDPassed;
}

#endif // __DASHBOARD_MQH__
