//+------------------------------------------------------------------+
//|                       RiskManager.mqh                            |
//|                    Risk Management Module                         |
//|                          Phase 2 Refactor                         |
//|                                                                  |
//| Description:                                                     |
//|   Modular extraction of all risk management logic from Phase 1   |
//|   monolithic EA. Handles position sizing, daily P&L tracking,    |
//|   daily limits enforcement, and Friday hard close.               |
//|                                                                  |
//| Functions:                                                       |
//|   - CalculateLotSize(entryPrice, stopLossPrice)                 |
//|   - CalculateDailyPnL()                                          |
//|   - EnforceDailyLimits()                                         |
//|   - CheckFridayHardClose()                                       |
//|                                                                  |
//+------------------------------------------------------------------+

#ifndef __RISKMANAGER_MQH__
#define __RISKMANAGER_MQH__

// ==================== CONSTANTS ====================

#define RISK_PERCENT 0.6        // D-03: hardcoded 0.6% per trade
#define DAILY_LOSS_LIMIT 0.02   // -2% hard stop
#define DAILY_PROFIT_CAP 0.05   // +5% profit cap
#define FRIDAY_CLOSE_HOUR 21
#define FRIDAY_CLOSE_MIN 45

// ==================== DATA STRUCTURES ====================

struct DailyLimitState {
    double closedPnL;                   // Closed profit/loss today
    double openPnL;                     // Open position P&L
    double totalPnL;                    // Total P&L today
    bool hardStopHit;                   // -2% loss limit triggered
    bool profitCapReached;              // +5% profit cap triggered
};

struct PositionRecord {
    long   ticket;                      // Order ticket number
    string symbol;                      // Trading symbol
    double entryPrice;                  // Entry price
    double stopLoss;                    // Stop loss price
    double takeProfit1;                 // First take profit (65%)
    double takeProfit2;                 // Second take profit (35%)
    double lots;                        // Position size
    datetime entryTime;                 // Entry timestamp
};

// ==================== GLOBAL STATE (to be declared in main EA) ====================
// extern: PositionRecord positions[3];
// extern: int positionCount;
// extern: DailyLimitState dailyLimits;
// extern: int EA_MAGIC_NUMBER;

// ==================== FUNCTION DECLARATIONS ====================

// Calculate position size based on risk (REQ-029, REQ-030)
double CalculateLotSize(double entryPrice, double stopLossPrice);

// Recalculate daily P&L by rescanning OrdersHistoryTotal and open positions
DailyLimitState CalculateDailyPnL();

// Check if hard stop (-2%) or profit cap (+5%) reached; enforce if needed
bool EnforceDailyLimits();

// Check if Friday 21:45 hard close time reached; force-close all if true
bool CheckFridayHardClose();

// ==================== FUNCTION IMPLEMENTATIONS ====================

//+------------------------------------------------------------------+
//| Calculate position size based on risk (REQ-029, REQ-030)         |
//| Formula: Lot Size = (Balance × 0.6%) / (SL Distance × Pip Value) |
//+------------------------------------------------------------------+
double CalculateLotSize(double entryPrice, double stopLossPrice)
{
    // REQ-029: Risk-based sizing formula

    // Step 1: Calculate risk amount in account currency
    double accountBalance = AccountBalance();
    double riskAmount = accountBalance * (RISK_PERCENT / 100.0);  // 0.6% locked

    if (riskAmount <= 0)
    {
        Print("ERROR: Invalid account balance for lot sizing");
        return 0;
    }

    // Step 2: Calculate SL distance in pips (broker's point units)
    double slDistancePoints = MathAbs(entryPrice - stopLossPrice) / Point;

    if (slDistancePoints <= 0)
    {
        Print("ERROR: Invalid SL distance for lot sizing");
        return 0;
    }

    // Step 3: Fetch pip value for this symbol
    // CRITICAL: Use SymbolInfoDouble() to get broker-specific pip value
    // DO NOT hardcode; brokers differ on XAUUSD tick value

    double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);

    if (tickValue <= 0 || tickSize <= 0)
    {
        Print("ERROR: Invalid tick value/size for symbol ", Symbol());
        return 0;
    }

    double pipValue = tickValue / tickSize;

    // Step 4: Calculate lot size
    double lotSize = riskAmount / (slDistancePoints * pipValue);

    if (lotSize <= 0)
    {
        Print("ERROR: Calculated lot size <= 0");
        return 0;
    }

    // Step 5: Apply broker constraints (REQ-029 acceptance criteria)
    double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

    if (minLot <= 0 || maxLot <= 0 || lotStep <= 0)
    {
        Print("ERROR: Invalid broker lot constraints");
        return 0;
    }

    // Validate minimum lot
    if (lotSize < minLot)
    {
        Print("WARNING: Calculated lot size ", lotSize, " < minimum ", minLot,
              "; rejecting trade");
        return 0;  // Reject trade; too small
    }

    // Cap at maximum lot (if position would be too large)
    if (lotSize > maxLot)
    {
        Print("WARNING: Calculated lot size ", lotSize, " > maximum ", maxLot,
              "; capping at max");
        lotSize = maxLot;
    }

    // Round to lot step (e.g., 0.01 for Forex)
    lotSize = MathFloor(lotSize / lotStep) * lotStep;

    return lotSize;
}

//+------------------------------------------------------------------+
//| Recalculate daily P&L by rescanning OrdersHistoryTotal and      |
//| open positions (REQ-032, REQ-033, REQ-035)                      |
//+------------------------------------------------------------------+
DailyLimitState CalculateDailyPnL()
{
    DailyLimitState state;
    double closedPnL = 0;
    double openPnL = 0;

    // Step 1: Scan closed trades today (OrdersHistoryTotal)
    // Recalculate every call (NOT cached) to ensure persistence across restarts

    int magicNumber = 99001;  // Default; should be passed or globally available

    for (int i = OrdersHistoryTotal() - 1; i >= 0; i--)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
            continue;

        // Filter for this EA's trades (magic number range)
        if (OrderMagicNumber() < magicNumber ||
            OrderMagicNumber() > magicNumber + 10)
            continue;

        // Check if closed TODAY (within last 24 hours)
        if (TimeCurrent() - OrderCloseTime() < 86400)
        {
            closedPnL += OrderProfit();
        }
    }

    // Step 2: Scan open positions for floating P&L
    // Note: This relies on main EA maintaining a positions[] array
    // For now, we scan all open orders
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;

        if (OrderMagicNumber() < magicNumber ||
            OrderMagicNumber() > magicNumber + 10)
            continue;

        openPnL += OrderProfit();
    }

    // Step 3: Calculate daily total P&L
    state.closedPnL = closedPnL;
    state.openPnL = openPnL;
    state.totalPnL = closedPnL + openPnL;
    state.hardStopHit = false;
    state.profitCapReached = false;

    return state;
}

//+------------------------------------------------------------------+
//| Check and enforce daily limits (REQ-032, REQ-033, REQ-035)       |
//| Returns false if hard stop or profit cap hit; blocks new entries |
//+------------------------------------------------------------------+
bool EnforceDailyLimits()
{
    // REQ-032: Daily hard stop loss at -2%
    // REQ-033: Daily profit cap at +5%
    // REQ-035: Drawdown tracking persistent across restarts

    DailyLimitState limits = CalculateDailyPnL();
    double dailyLossLimit = AccountBalance() * DAILY_LOSS_LIMIT;   // 0.02 = -2%
    double profitCapLimit = AccountBalance() * DAILY_PROFIT_CAP;   // 0.05 = +5%

    // Step 1: Check if hard stop (-2%) breached
    if (limits.totalPnL < -dailyLossLimit)
    {
        limits.hardStopHit = true;

        LogAlert("HARD_STOP_HIT", StringFormat("closed=%.2f open=%.2f total=%.2f limit=%.2f",
            limits.closedPnL, limits.openPnL, limits.totalPnL, -dailyLossLimit));
        Print("WARNING: DAILY_HARD_STOP_HIT");
        Print("  Current Loss: ", limits.totalPnL, " (Limit: -", dailyLossLimit, ")");
        Print("  No new trades allowed for remainder of day");

        return false;  // Block new entries
    }

    // Step 2: Check if profit cap (+5%) breached
    if (limits.totalPnL > profitCapLimit)
    {
        limits.profitCapReached = true;

        Print("WARNING: DAILY_PROFIT_CAP_REACHED");
        Print("  Current Gain: ", limits.totalPnL, " (Cap: +", profitCapLimit, ")");
        Print("  All positions will be closed by Phase 2 logic");

        return false;  // Block new entries
    }

    // Log normal daily limits status periodically
    static int limitsLogCounter = 0;
    if (++limitsLogCounter % 100 == 0)
    {
        LogAlert("DAILY_LIMITS", StringFormat("closed=%.2f open=%.2f total=%.2f limit=%.2f status=OK",
            limits.closedPnL, limits.openPnL, limits.totalPnL, -dailyLossLimit));
    }

    return true;  // Trading allowed
}

//+------------------------------------------------------------------+
//| Check if Friday 21:45 hard close time reached (REQ-034)          |
//| Force close all positions Friday 21:45 broker server time        |
//+------------------------------------------------------------------+
bool CheckFridayHardClose()
{
    // REQ-034: Force close all positions Friday 21:45 broker server time

    MqlDateTime timeStruct;
    TimeToStruct(TimeCurrent(), timeStruct);  // Broker server time

    // Friday = day_of_week 5 (0=Sunday, 5=Friday)
    // Time = 21:45

    if (timeStruct.day_of_week == 5)  // Friday
    {
        int currentMinutes = timeStruct.hour * 60 + timeStruct.min;
        int closeTime = FRIDAY_CLOSE_HOUR * 60 + FRIDAY_CLOSE_MIN;  // 21*60+45 = 1305

        if (currentMinutes >= closeTime)
        {
            Print("WARNING: FRIDAY_HARD_CLOSE_TIME");
            Print("  Current time: ", timeStruct.hour, ":",
                  (timeStruct.min < 10 ? "0" : ""), timeStruct.min);
            Print("  All positions must be closed before weekend gap");

            return true;  // Signal to close all positions
        }
    }

    return false;  // Not Friday close time
}

#endif  // __RISKMANAGER_MQH__
