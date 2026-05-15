//+------------------------------------------------------------------+
//|                         Utils.mqh                                |
//|                      Utility Functions Module                     |
//|                          Phase 2 Refactor                         |
//|                                                                  |
//| Description:                                                     |
//|   Modular extraction of all utility functions and constants      |
//|   from Phase 1 monolithic EA. Centralizes broker connection      |
//|   checks, session boundary calculations, error logging, and      |
//|   all hardcoded magic numbers.                                   |
//|                                                                  |
//| Constants:                                                       |
//|   - EA_MAGIC_NUMBER, VOLUME_BINS, LOOKBACK_BARS, RISK_PERCENT   |
//|   - DAILY_LOSS_LIMIT, DAILY_PROFIT_CAP, HVN_PERCENTILE, etc.    |
//|                                                                  |
//| Functions:                                                       |
//|   - IsConnected()                                                |
//|   - GetSessionBoundary()                                         |
//|   - LogError(message)                                            |
//|   - LogAlert(alertType, message)                                 |
//|   - NewBar()                                                     |
//|                                                                  |
//+------------------------------------------------------------------+

#ifndef __UTILS_MQH__
#define __UTILS_MQH__

// ==================== GLOBAL CONSTANTS ====================
// All magic numbers and hardcoded values centralized here

#define EA_MAGIC_NUMBER 99001
#define VOLUME_BINS 400
#define LOOKBACK_BARS 150
#define RISK_PERCENT 0.6
#define DAILY_LOSS_LIMIT 0.02
#define DAILY_PROFIT_CAP 0.05
#define HVN_PERCENTILE 0.85
#define LVN_PERCENTILE 0.25
#define SLIPPAGE_TOLERANCE_PIPS 50
#define FRIDAY_CLOSE_HOUR 21
#define FRIDAY_CLOSE_MINUTE 45
#define VALUE_AREA_PERCENT 0.70

// ==================== FUNCTION DECLARATIONS ====================

// Check broker connection before order placement
bool IsConnected();

// Get session boundary time (Tokyo open, 00:00 SGT / 17:00 Friday ET)
datetime GetSessionBoundary();

// Log error to Journal
void LogError(string message);

// Log alert to Journal
void LogAlert(string alertType, string message);

// Detect new bar (on PERIOD_CURRENT timeframe)
bool NewBar();

// ==================== FUNCTION IMPLEMENTATIONS ====================

//+------------------------------------------------------------------+
//| Check broker connection and symbol validity                      |
//+------------------------------------------------------------------+
bool IsConnected()
{
    if (!TerminalInfoInteger(TERMINAL_CONNECTED))
    {
        LogError("Terminal not connected to broker");
        return false;
    }

    double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);

    if (tickValue <= 0 || tickSize <= 0)
    {
        LogError("Invalid symbol or broker data not available - " + Symbol());
        LogAlert("ERROR", "SYMBOL_TRADE_TICK_VALUE = " + DoubleToString(tickValue, 8));
        LogAlert("ERROR", "SYMBOL_TRADE_TICK_SIZE = " + DoubleToString(tickSize, 8));
        return false;
    }

    LogAlert("INFO", "Connected to broker, symbol=" + Symbol() +
             " tick_value=" + DoubleToString(tickValue, 8) +
             " tick_size=" + DoubleToString(tickSize, 8));

    return true;
}

//+------------------------------------------------------------------+
//| Get session boundary time (Tokyo open, 00:00 SGT / 17:00 Fri ET) |
//| Used for daily limit resets and previous session data            |
//+------------------------------------------------------------------+
datetime GetSessionBoundary()
{
    // Session boundary: 00:00 SGT (Singapore) = 17:00 Friday ET (New York)
    // This marks when daily limits reset

    MqlDateTime timeStruct;
    TimeToStruct(TimeCurrent(), timeStruct);

    // For now, return midnight broker server time
    // TODO: Implement proper timezone-aware session boundary

    timeStruct.hour = 0;
    timeStruct.min = 0;
    timeStruct.sec = 0;

    return StructToTime(timeStruct);
}

//+------------------------------------------------------------------+
//| Log error to Journal                                             |
//+------------------------------------------------------------------+
void LogError(string message)
{
    Print("[ERROR] ", message);
}

//+------------------------------------------------------------------+
//| Log alert to Journal                                             |
//+------------------------------------------------------------------+
void LogAlert(string alertType, string message)
{
    Print("[", alertType, "] ", message);
}

//+------------------------------------------------------------------+
//| Detect new bar on current timeframe                              |
//| Returns true if a new bar has formed since last call             |
//+------------------------------------------------------------------+
bool NewBar()
{
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(Symbol(), PERIOD_CURRENT, 0);

    if (currentBarTime != lastBarTime)
    {
        lastBarTime = currentBarTime;
        return true;
    }

    return false;
}

#endif  // __UTILS_MQH__
