//+------------------------------------------------------------------+
//| JournalLogger.mqh
//| Comprehensive journal logging for all trades, errors, and events
//| Phase 2 Wave 3: Full audit trail for compliance and analysis
//+------------------------------------------------------------------+

#ifndef JOURNAL_LOGGER_MQH
#define JOURNAL_LOGGER_MQH

#include "Utils.mqh"

//+------------------------------------------------------------------+
//| Trade Journal Record Structure
//+------------------------------------------------------------------+

struct TradeJournalRecord
{
  datetime entryTime;
  string symbol;
  string direction;           // "BUY" or "SELL"
  double entryPrice;
  double lotSize;
  string setupType;           // "Setup1", "Setup2", "REVERSAL"
  double stopLoss;
  double takeProfit;
  double riskRewardRatio;
  datetime exitTime;
  double exitPrice;
  string exitReason;          // "TP", "SL", "HARD_STOP", "PROFIT_CAP", "FRIDAY_CLOSE", "REVERSAL"
  double pnlPips;
  double pnlCurrency;
  double slippage;
};

//+------------------------------------------------------------------+
//| Log Trade Entry
//| Logs entry details: time, symbol, direction, price, lot, setup, SL, TP, R:R
//+------------------------------------------------------------------+

void LogTradeEntry(string direction, double entryPrice, double lotSize, string setupType,
                   double stopLoss, double takeProfit, double riskRewardRatio,
                   double slippage, long ticket)
{
  string logMsg = StringFormat(
    "%s | ENTRY | %s | Ticket=%lld | Price=%.5f | Lot=%.2f | Setup=%s | "
    "SL=%.5f | TP=%.5f | R:R=%.2f:1 | Slippage=%.1f pips",
    TimeToString(TimeCurrent()), direction, ticket, entryPrice, lotSize, setupType,
    stopLoss, takeProfit, riskRewardRatio, slippage);

  Print(logMsg);  // Output to MT5 Journal
}

//+------------------------------------------------------------------+
//| Log Trade Exit
//| Logs exit details: time, symbol, setup, entry/exit price, reason, P&L, lot
//+------------------------------------------------------------------+

void LogTradeExit(long ticket, string symbol, string setupType, double entryPrice,
                  double exitPrice, string exitReason, double pnlPips, double closeLots)
{
  // Calculate P&L in currency
  double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
  double pnlCurrency = pnlPips * closeLots * tickValue;

  string logMsg = StringFormat(
    "%s | EXIT | %s | Ticket=%lld | Setup=%s | Entry=%.5f | Exit=%.5f | "
    "Reason=%s | PnL=%.1f pips (%.2f) | Lot=%.2f",
    TimeToString(TimeCurrent()), symbol, ticket, setupType, entryPrice, exitPrice,
    exitReason, pnlPips, pnlCurrency, closeLots);

  Print(logMsg);  // Output to MT5 Journal
}

//+------------------------------------------------------------------+
//| Log Order Rejection
//| Logs rejected orders with reason and order details
//+------------------------------------------------------------------+

void LogOrderRejection(double intendedPrice, double stopLoss, double takeProfit,
                       double lots, string reason, long errorCode)
{
  string logMsg = StringFormat(
    "%s | REJECTION | Entry=%.5f | SL=%.5f | TP=%.5f | Lot=%.2f | Reason=%s | ErrorCode=%lld",
    TimeToString(TimeCurrent()), intendedPrice, stopLoss, takeProfit, lots, reason, errorCode);

  Print(logMsg);  // Output to MT5 Journal
}

// LogAlert() and LogError() are defined in Utils.mqh (included above)

//+------------------------------------------------------------------+
//| Log Reversal Detection
//| Logs when reversal candle is detected
//+------------------------------------------------------------------+

void LogReversalDetection(bool isLong, double reversalPrice, double confirmationPrice)
{
  string direction = isLong ? "LONG" : "SHORT";
  string logMsg = StringFormat(
    "%s | REVERSAL_DETECT | Direction=%s | ReversalPrice=%.5f | ConfirmPrice=%.5f",
    TimeToString(TimeCurrent()), direction, reversalPrice, confirmationPrice);

  Print(logMsg);
}

//+------------------------------------------------------------------+
//| Log Position Flip Execution
//| Logs when position flip completes (close old + enter new)
//+------------------------------------------------------------------+

void LogPositionFlip(long oldTicket, long newTicket, bool newIsLong, double newEntryPrice)
{
  string direction = newIsLong ? "LONG" : "SHORT";
  string logMsg = StringFormat(
    "%s | POSITION_FLIP | OldTicket=%lld | NewTicket=%lld | NewDir=%s | NewEntry=%.5f",
    TimeToString(TimeCurrent()), oldTicket, newTicket, direction, newEntryPrice);

  Print(logMsg);
}

//+------------------------------------------------------------------+
//| Log Daily Summary
//| Logs end-of-day summary with P&L, win rate, etc.
//+------------------------------------------------------------------+

void LogDailySummary(double closedPnL, double openPnL, double totalPnL,
                     int tradesExecuted, int tradesWon, double winRate)
{
  string logMsg = StringFormat(
    "%s | DAILY_SUMMARY | ClosedPnL=%.2f | OpenPnL=%.2f | Total=%.2f | "
    "Trades=%d | Wins=%d | WinRate=%.1f%%",
    TimeToString(TimeCurrent()), closedPnL, openPnL, totalPnL,
    tradesExecuted, tradesWon, winRate);

  Print(logMsg);
}

//+------------------------------------------------------------------+
//| Log Liquidity/Session Check
//| Logs when session or liquidity checks reject entry
//+------------------------------------------------------------------+

void LogSessionCheck(string checkType, string reason)
{
  string logMsg = StringFormat(
    "%s | SESSION_CHECK | Type=%s | Reason=%s | Entry rejected",
    TimeToString(TimeCurrent()), checkType, reason);

  Print(logMsg);
}

#endif
