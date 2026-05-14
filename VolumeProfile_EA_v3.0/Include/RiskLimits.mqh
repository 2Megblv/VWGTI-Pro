//+------------------------------------------------------------------+
//| RiskLimits.mqh
//| Daily risk enforcement: hard stop (-2%), profit cap (+5%), Friday close
//| Phase 2 Wave 3: Risk management and daily limit enforcement
//+------------------------------------------------------------------+

#ifndef RISK_LIMITS_MQH
#define RISK_LIMITS_MQH

#include "Utils.mqh"
#include "TradeExecution.mqh"

//+------------------------------------------------------------------+
//| Structures for Daily Risk Enforcement
//+------------------------------------------------------------------+

struct DailyLimitState
{
  double closedPnL;           // P&L from closed trades today
  double openPnL;             // P&L from open positions
  double totalPnL;            // closedPnL + openPnL
  bool hardStopHit;           // -2% threshold breached
  bool profitCapReached;      // +5% threshold reached
  datetime lastCalculation;   // Last calculation time
};

// Global daily limits state
DailyLimitState dailyLimits = {0, 0, 0, false, false, 0};

//+------------------------------------------------------------------+
//| Calculate Daily P&L (persistent across ticks)
//| Rescans OrdersHistoryTotal to find trades closed today
//| Adds open position P&L for unrealized gain/loss
//+------------------------------------------------------------------+

DailyLimitState CalculateDailyPnL()
{
  DailyLimitState result = {0, 0, 0, false, false, TimeCurrent()};

  // Get session boundary (today's open in broker server time)
  datetime sessionStart = GetSessionBoundary();

  // Step 1: Scan closed trades from order history
  // Use OrdersHistoryTotal() to find all completed trades

  int ordersHistoryCount = OrdersHistoryTotal();
  for (int i = 0; i < ordersHistoryCount; i++)
  {
    ulong ticket = OrderGetTicket(i);
    if (ticket == 0)
      continue;

    // Filter for this EA's trades via magic number
    // Positions API: check if position's magic matches
    if (OrderGetInteger(ORDER_MAGIC) != EA_MAGIC_NUMBER)
      continue;

    // Only include trades closed in current session
    datetime closeTime = (datetime)OrderGetInteger(ORDER_TIME_DONE);
    if (closeTime == 0 || closeTime < sessionStart)
      continue;

    // Add profit from this closed position
    // In MT5, profit is in account currency
    double profit = OrderGetDouble(ORDER_NET_PROFIT);
    result.closedPnL += profit;
  }

  // Step 2: Scan open positions for current P&L
  // Loop through all open positions in positionCount array
  for (int i = 0; i < positionCount; i++)
  {
    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

    // Calculate unrealized P&L for this position
    double pnl = 0;
    double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);

    if (positions[i].isLong)
    {
      // For LONG: P&L = (Bid - Entry) * Lots * TickValue
      pnl = (bid - positions[i].entryPrice) * positions[i].remainingLots * tickValue;
    }
    else
    {
      // For SHORT: P&L = (Entry - Ask) * Lots * TickValue
      pnl = (positions[i].entryPrice - ask) * positions[i].remainingLots * tickValue;
    }

    result.openPnL += pnl;
  }

  result.totalPnL = result.closedPnL + result.openPnL;

  return result;
}

//+------------------------------------------------------------------+
//| Enforce Daily Risk Limits
//| Returns: true if trading allowed, false if hard stop or profit cap hit
//+------------------------------------------------------------------+

bool EnforceDailyLimits()
{
  // Recalculate daily P&L on this tick
  DailyLimitState limits = CalculateDailyPnL();
  dailyLimits = limits;

  double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
  double hardStopThreshold = accountBalance * (DAILY_LOSS_LIMIT / 100.0);      // -2%
  double profitCapThreshold = accountBalance * (DAILY_PROFIT_CAP / 100.0);     // +5%

  // Check D-09: Hard stop loss (-2%)
  if (limits.totalPnL < -hardStopThreshold)
  {
    // Only log once per hard stop
    if (!dailyLimits.hardStopHit)
    {
      LogAlert("HARD_STOP_HIT",
               StringFormat("Daily loss=%.2f (balance=%.2f), limit=-%.2f. Closing all positions.",
                           limits.totalPnL, accountBalance, hardStopThreshold));
    }

    dailyLimits.hardStopHit = true;

    // Force-close ALL open positions immediately
    for (int i = positionCount - 1; i >= 0; i--)
    {
      // Use market order to close
      trade.PositionClose(positions[i].ticket);
      ClosePosition(positions[i].ticket, SymbolInfoDouble(Symbol(), SYMBOL_BID),
                   "HARD_STOP", positions[i].remainingLots);
    }

    return false;  // Block new entries
  }

  // Check D-10: Daily profit cap (+5%)
  if (limits.totalPnL > profitCapThreshold)
  {
    // Only log once per profit cap
    if (!dailyLimits.profitCapReached)
    {
      LogAlert("PROFIT_CAP_REACHED",
               StringFormat("Daily profit=%.2f (balance=%.2f), cap=+%.2f. Closing 60%% of positions.",
                           limits.totalPnL, accountBalance, profitCapThreshold));
    }

    dailyLimits.profitCapReached = true;

    // Close 60% of positions (midpoint between 50-70% per D-10)
    int closeCount = (int)MathCeil(positionCount * 0.6);

    for (int i = 0; i < closeCount && i < positionCount; i++)
    {
      trade.PositionClose(positions[i].ticket);
      ClosePosition(positions[i].ticket, SymbolInfoDouble(Symbol(), SYMBOL_BID),
                   "PROFIT_CAP_CLOSE", positions[i].remainingLots);
    }

    // Move SL of remaining positions to profit (breakeven + 5 pips)
    for (int i = closeCount; i < positionCount; i++)
    {
      double newSL = positions[i].entryPrice;  // Breakeven

      if (positions[i].isLong)
        newSL += 5 * Point;  // +5 pips profit
      else
        newSL -= 5 * Point;  // -5 pips for SHORT

      // Update position SL via CTrade
      MqlTradeRequest request = {0};
      request.action = TRADE_ACTION_SLTP;
      request.symbol = Symbol();
      request.position = positions[i].ticket;
      request.sl = newSL;
      request.tp = positions[i].takeProfit;

      MqlTradeResult result;
      trade.Send(request, result);

      if (result.retcode == TRADE_RETCODE_DONE)
      {
        positions[i].stopLoss = newSL;
      }
    }

    return false;  // Block new entries
  }

  return true;  // Trading allowed
}

//+------------------------------------------------------------------+
//| Check Friday Hard Close (21:45 Broker Server Time)
//| Returns: true if close was executed, false otherwise
//+------------------------------------------------------------------+

bool CheckFridayHardClose()
{
  // Get current time in broker server time
  datetime currentTime = TimeCurrent();
  MqlDateTime timeStruct;
  TimeToStruct(currentTime, timeStruct);

  // Check if Friday (day_of_week: 0=Sunday, ..., 5=Friday, 6=Saturday)
  bool isFriday = (timeStruct.day_of_week == 5);

  // Check if time >= 21:45
  int currentTimeMinutes = timeStruct.hour * 60 + timeStruct.min;
  int closeTimeMinutes = 21 * 60 + 45;  // 21:45 = 1305 minutes
  bool isCloseTime = (currentTimeMinutes >= closeTimeMinutes);

  if (isFriday && isCloseTime)
  {
    // Force-close ALL open positions
    if (positionCount > 0)
    {
      LogAlert("FRIDAY_HARD_CLOSE",
               StringFormat("Time=%02d:%02d. Closing all %d positions before weekend.",
                           timeStruct.hour, timeStruct.min, positionCount));
    }

    // Close all positions
    for (int i = positionCount - 1; i >= 0; i--)
    {
      trade.PositionClose(positions[i].ticket);
      ClosePosition(positions[i].ticket, SymbolInfoDouble(Symbol(), SYMBOL_BID),
                   "FRIDAY_CLOSE", positions[i].remainingLots);
    }

    return true;  // Hard close executed
  }

  return false;
}

//+------------------------------------------------------------------+
//| Reset Daily Limits at Session Boundary
//| Called at start of each trading day
//+------------------------------------------------------------------+

void ResetDailyLimits()
{
  dailyLimits.closedPnL = 0;
  dailyLimits.openPnL = 0;
  dailyLimits.totalPnL = 0;
  dailyLimits.hardStopHit = false;
  dailyLimits.profitCapReached = false;
  dailyLimits.lastCalculation = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Get Current Daily Limits State
//+------------------------------------------------------------------+

DailyLimitState GetDailyLimitsState()
{
  return dailyLimits;
}

#endif
