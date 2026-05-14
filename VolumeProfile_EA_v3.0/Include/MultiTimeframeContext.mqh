//+------------------------------------------------------------------+
//|                  MultiTimeframeContext.mqh                       |
//|     15M Profile, Session Filtering, Liquidity Validation         |
//|                      Phase 2, Wave 1                              |
//|                                                                  |
//| Description:                                                     |
//|   Implements 15M multi-timeframe context (VAH, VAL, PoC) loading |
//|   for direction bias validation. Implements session filtering to |
//|   block entries during grave hour (NY 16:00–17:00) and pre-Tokyo |
//|   (Sun 23:00–Mon 00:00). Implements liquidity validation to      |
//|   check bid-ask spread and tick volume before entries.           |
//|                                                                  |
//| Exported Functions:                                              |
//|   - void Load15MProfile()                                        |
//|   - double Get15MVAHContext()                                    |
//|   - double Get15MVALContext()                                    |
//|   - bool Validate15MDirectionBias(bool isLongEntry)             |
//|   - bool IsSessionAllowed()                                      |
//|   - bool ValidateLiquidity()                                     |
//|                                                                  |
//| Exported Structures:                                             |
//|   - struct Profile15M                                            |
//|                                                                  |
//+------------------------------------------------------------------+

#ifndef __MULTITIMEFRAME_CONTEXT_MQH__
#define __MULTITIMEFRAME_CONTEXT_MQH__

// ==================== STRUCTURES ====================

//+------------------------------------------------------------------+
//| 15M Profile Structure                                            |
//+------------------------------------------------------------------+
struct Profile15M
{
    double vahPrice;           // Value Area High on 15M timeframe
    double valPrice;           // Value Area Low on 15M timeframe
    double pocPrice;           // Point of Control on 15M timeframe
    datetime lastUpdateTime;   // Last update timestamp
};

// ==================== GLOBAL VARIABLES ====================

Profile15M profile15M = {0, 0, 0, 0};  // 15M profile cache

// ==================== 15M PROFILE LOADING & CONTEXT ====================

//+------------------------------------------------------------------+
//| Load15MProfile()                                                 |
//| Recalculates 15M profile using 150-bar lookback on PERIOD_M15   |
//| Provides higher-timeframe context for direction bias validation  |
//|                                                                  |
//| Calculation approach (MVP):                                      |
//|   - VAL: 25th percentile of 150-bar range (low support)         |
//|   - VAH: 75th percentile of 150-bar range (high resistance)     |
//|   - PoC: Midpoint of range (simplified; full calculation deferred)|
//+------------------------------------------------------------------+
void Load15MProfile()
{
    // Recalculate 15M profile using 150-bar lookback on PERIOD_M15
    // This provides higher-timeframe context for direction bias

    // Get 15M profile data (300 bars back on 15M = 75 hours of data)
    double high15M = iHighest(Symbol(), PERIOD_M15, MODE_HIGH, 150, 0);
    double low15M = iLowest(Symbol(), PERIOD_M15, MODE_LOW, 150, 0);

    // Simplified 15M profile: Use iLowest/iHighest as VAL/VAH proxies
    // Full calculation would use CalculateCurrentVolumeProfile on 15M data
    // For MVP: approximate VAL as 25th percentile of range, VAH as 75th percentile

    double range15M = high15M - low15M;
    profile15M.valPrice = low15M + range15M * 0.25;
    profile15M.vahPrice = high15M - range15M * 0.25;
    profile15M.pocPrice = (high15M + low15M) / 2.0;  // POC as midpoint (simplified)
    profile15M.lastUpdateTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Get15MVAHContext()                                               |
//| Returns 15M Value Area High for direction bias reference         |
//+------------------------------------------------------------------+
double Get15MVAHContext()
{
    return profile15M.vahPrice;
}

//+------------------------------------------------------------------+
//| Get15MVALContext()                                               |
//| Returns 15M Value Area Low for direction bias reference          |
//+------------------------------------------------------------------+
double Get15MVALContext()
{
    return profile15M.valPrice;
}

//+------------------------------------------------------------------+
//| Validate15MDirectionBias()                                       |
//| Prevents counter-trend entries by checking 15M context           |
//|                                                                  |
//| For LONG entries: Don't enter if current price too close to      |
//|                   15M VAL (downside risk)                        |
//| For SHORT entries: Don't enter if current price too close to     |
//|                    15M VAH (upside risk)                         |
//|                                                                  |
//| Conservative buffer: 50 pips above/below profile boundary        |
//+------------------------------------------------------------------+
bool Validate15MDirectionBias(bool isLongEntry)
{
    // Get current bid/ask prices
    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double mid = (bid + ask) / 2.0;

    if (isLongEntry)
    {
        // LONG: require at least 50 pips above 15M VAL (conservative buffer)
        return (mid > profile15M.valPrice + 50 * Point);
    }
    else
    {
        // SHORT: require at least 50 pips below 15M VAH (conservative buffer)
        return (mid < profile15M.vahPrice - 50 * Point);
    }
}

// ==================== SESSION FILTERING ====================

//+------------------------------------------------------------------+
//| IsSessionAllowed()                                               |
//| Blocks entries during low-liquidity, high-volatility sessions:   |
//|   1. GRAVE HOUR: NY 16:00–17:00 (daily)                         |
//|   2. PRE-TOKYO: Sun 23:00 NY – Mon 00:00 NY (weekly)            |
//|                                                                  |
//| Assumes broker server time = NY time (typical forex)            |
//+------------------------------------------------------------------+
bool IsSessionAllowed()
{
    // Get current time in broker server time (NY time or GMT, depending on broker)
    // Assume broker uses NY time (typical for Forex brokers)

    MqlDateTime timeStruct;
    TimeToStruct(TimeCurrent(), timeStruct);

    int currentHour = timeStruct.hour;
    int currentMinute = timeStruct.min;
    int dayOfWeek = timeStruct.day_of_week;  // 0=Sunday, 1=Monday, ..., 5=Friday, 6=Saturday

    // GRAVE HOUR BLOCK: NY 16:00–17:00 (4 PM – 5 PM NY close, low liquidity, high volatility)
    // This occurs daily Monday–Friday
    if (currentHour == 16)
    {
        return false;  // Block all entries during this hour
    }

    // PRE-TOKYO BLOCK: Sunday 23:00 NY through Monday 00:00 NY (minimal liquidity before Tokyo open)
    // Sunday 23:00 = Sunday close, Monday 00:00 = early Monday before Asian open
    bool isPreTokyoSunday = (dayOfWeek == 0 && currentHour == 23);  // Sunday 11 PM
    bool isPreTokyoMonday = (dayOfWeek == 1 && currentHour == 0);   // Monday midnight

    if (isPreTokyoSunday || isPreTokyoMonday)
    {
        return false;  // Block all entries
    }

    // Otherwise: trading allowed (Europe, Asia-Pacific, or US hours)
    return true;
}

// ==================== LIQUIDITY VALIDATION ====================

//+------------------------------------------------------------------+
//| ValidateLiquidity()                                              |
//| Checks bid-ask spread and tick volume before entry               |
//|                                                                  |
//| D-14 Requirements:                                               |
//|   - Spread ≤ 3 pips for Gold (XAUUSD)                           |
//|   - Spread ≤ 5 pips for EURUSD                                  |
//|   - Tick volume ≥ 10 (minimum liquidity threshold)              |
//|                                                                  |
//| Returns: true if all liquidity conditions met; false otherwise   |
//+------------------------------------------------------------------+
bool ValidateLiquidity()
{
    // Check bid-ask spread and tick volume before entry

    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double spread = ask - bid;

    // Get broker tick value to convert spread to pips
    double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
    double spreadPips = spread / tickSize;

    // Symbol-specific spread threshold
    double spreadLimit = 5.0;  // Default 5 pips (EURUSD)

    if (StringFind(Symbol(), "XAUUSD") >= 0)
    {
        spreadLimit = 3.0;  // Gold: 3 pips limit
    }

    if (spreadPips > spreadLimit)
    {
        return false;  // Spread too wide; reject
    }

    // Check tick volume (minimum 10)
    long tickVolume = SymbolInfoInteger(Symbol(), SYMBOL_VOLUME);
    if (tickVolume < 10)
    {
        return false;  // Insufficient volume; reject
    }

    return true;  // Liquidity acceptable
}

#endif // __MULTITIMEFRAME_CONTEXT_MQH__
