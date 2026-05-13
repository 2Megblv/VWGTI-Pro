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
// NOTE: DailyLimitState and PositionState are now defined in:
//   - RiskLimits.mqh (DailyLimitState)
//   - TradeExecution.mqh (PositionState)
// Do NOT duplicate here to avoid conflicts

// ==================== GLOBAL STATE (defined in main EA and TradeExecution.mqh) ====================
// extern: PositionState positions[MAX_POSITIONS];  (from TradeExecution.mqh)
// extern: int positionCount;  (from TradeExecution.mqh)
// extern: DailyLimitState dailyLimits;  (from RiskLimits.mqh)
// extern: CTrade trade;  (from TradeExecution.mqh)

// ==================== FUNCTION DECLARATIONS ====================

// Calculate position size based on risk (REQ-029, REQ-030)
double CalculateLotSize(double entryPrice, double stopLossPrice);

// NOTE: Daily limit enforcement moved to RiskLimits.mqh:
//   - CalculateDailyPnL()
//   - EnforceDailyLimits()
//   - CheckFridayHardClose()

// ==================== FUNCTION IMPLEMENTATIONS ====================

//+------------------------------------------------------------------+
//| Calculate position size based on risk (REQ-029, REQ-030)         |
//| Formula: Lot Size = (Balance × 0.6%) / (SL Distance × Pip Value) |
//+------------------------------------------------------------------+
double CalculateLotSize(double entryPrice, double stopLossPrice)
{
    // REQ-029: Risk-based sizing formula

    // Step 1: Calculate risk amount in account currency
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
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

// NOTE: CalculateDailyPnL(), EnforceDailyLimits(), and CheckFridayHardClose()
// are implemented in RiskLimits.mqh with proper MT5 Positions API.
// RiskManager.mqh provides only CalculateLotSize() for position sizing.

#endif  // __RISKMANAGER_MQH__
