//+------------------------------------------------------------------+
//| ReversalExit.mqh
//| Reversal candle detection and position flip logic
//| Phase 2 Wave 3: Extended market move capture via reversal trading
//+------------------------------------------------------------------+

#ifndef REVERSAL_EXIT_MQH
#define REVERSAL_EXIT_MQH

#include "Utils.mqh"
#include "TradeExecution.mqh"
#include "JournalLogger.mqh"

//+------------------------------------------------------------------+
//| Reversal Signal Structure
//+------------------------------------------------------------------+

struct ReversalSignal
{
  bool isTriggered;          // Reversal candle detected
  bool isConfirmed;          // 1M confirmation validated
  bool isLong;               // Direction of reversal (true=LONG reversal, false=SHORT)
  double reversalPrice;      // Price level of reversal candle (high or low)
  double confirmationPrice;  // Price level of 1M confirmation
};

//+------------------------------------------------------------------+
//| Detect 5M Reversal Candle
//| For LONG position: detects lower high (rejection of VAH)
//| For SHORT position: detects higher low (rejection of VAL)
//+------------------------------------------------------------------+

ReversalSignal DetectReversalCandle(bool currentLong)
{
  ReversalSignal result = {false, false, false, 0, 0};

  // Get current 5M candle (completed bar 1) and previous bar 2
  double currentHigh = iHigh(Symbol(), PERIOD_CURRENT, 1);  // Previous 5M bar high
  double currentLow = iLow(Symbol(), PERIOD_CURRENT, 1);    // Previous 5M bar low
  double previousHigh = iHigh(Symbol(), PERIOD_CURRENT, 2); // Bar 2 high
  double previousLow = iLow(Symbol(), PERIOD_CURRENT, 2);   // Bar 2 low

  if (currentLong)
  {
    // LONG position reversal: lower high
    // This indicates rejection of the higher level (VAH)
    if (currentHigh < previousHigh)
    {
      result.isTriggered = true;
      result.isLong = false;  // Reversal direction is SHORT
      result.reversalPrice = currentHigh;
      return result;
    }
  }
  else
  {
    // SHORT position reversal: higher low
    // This indicates rejection of the lower level (VAL)
    if (currentLow > previousLow)
    {
      result.isTriggered = true;
      result.isLong = true;   // Reversal direction is LONG
      result.reversalPrice = currentLow;
      return result;
    }
  }

  return result;
}

//+------------------------------------------------------------------+
//| Confirm Reversal on 1M Structure
//| For LONG reversal: price breaks above 1M recent high + buffer
//| For SHORT reversal: price breaks below 1M recent low - buffer
//+------------------------------------------------------------------+

bool ConfirmReversal1M(bool reversalIsLong)
{
  // Get 1M price levels
  double high1M = iHighest(Symbol(), PERIOD_M1, MODE_HIGH, 5, 0);  // Highest in last 5 1M bars
  double low1M = iLowest(Symbol(), PERIOD_M1, MODE_LOW, 5, 0);     // Lowest in last 5 1M bars

  double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
  double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

  if (reversalIsLong)
  {
    // LONG reversal: price must break above 1M recent high + 10 pips buffer
    // Using ask price for entry perspective
    return (ask > high1M + 10 * Point);
  }
  else
  {
    // SHORT reversal: price must break below 1M recent low - 10 pips buffer
    // Using bid price for entry perspective
    return (bid < low1M - 10 * Point);
  }
}

//+------------------------------------------------------------------+
//| Execute Position Flip
//| Closes current position and enters new position in opposite direction
//+------------------------------------------------------------------+

bool ExecutePositionFlip(long oldTicket, bool newLongEntry, double newEntryPrice,
                         double newStopLoss, double newTakeProfit)
{
  // Step 1: Close current position
  if (!trade.PositionClose(oldTicket))
  {
    LogError(StringFormat("Failed to close position %lld for flip. Error: %d",
                         oldTicket, GetLastError()));
    return false;
  }

  // Find position in our tracking array and update state
  int oldIdx = FindPositionByTicket(oldTicket);
  if (oldIdx >= 0)
  {
    double exitPrice = newLongEntry ? SymbolInfoDouble(Symbol(), SYMBOL_ASK)
                                    : SymbolInfoDouble(Symbol(), SYMBOL_BID);
    ClosePosition(oldTicket, exitPrice, "REVERSAL_EXIT", positions[oldIdx].remainingLots);
  }

  // Step 2: Enter new position (opposite direction)
  double lotSize = CalculateLotSize(newEntryPrice, newStopLoss);

  OrderResult result = PlaceMarketOrder(
    newLongEntry ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
    lotSize,
    newEntryPrice,
    newStopLoss,
    newTakeProfit);

  if (result.success)
  {
    double rr = CalculateRiskRewardRatio(result.fillPrice, newStopLoss, newTakeProfit);
    AddPosition(result.ticket, Symbol(), newLongEntry, result.fillPrice,
               newStopLoss, newTakeProfit, lotSize, "REVERSAL", rr);

    LogPositionFlip(oldTicket, result.ticket, newLongEntry, result.fillPrice);

    LogTradeEntry(newLongEntry ? "BUY" : "SELL", result.fillPrice, lotSize, "REVERSAL",
                 newStopLoss, newTakeProfit, rr, result.slippage, result.ticket);

    return true;
  }
  else
  {
    LogError(StringFormat("Failed to place new position after flip. Old ticket: %lld", oldTicket));
    return false;
  }
}

//+------------------------------------------------------------------+
//| Check if Position is Near Take Profit
//| Returns distance in pips to TP, or negative if past TP
//+------------------------------------------------------------------+

double GetDistanceToTP(int positionIndex)
{
  if (positionIndex < 0 || positionIndex >= positionCount)
    return -1;

  double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
  double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
  double currentPrice = positions[positionIndex].isLong ? bid : ask;

  double distanceInPrice = MathAbs(positions[positionIndex].takeProfit - currentPrice);
  return distanceInPrice / Point;  // Convert to pips
}

//+------------------------------------------------------------------+
//| Monitor Positions for Reversals
//| Called from OnTick after position monitoring but before new signals
//| Checks if position near TP and if reversal conditions are met
//+------------------------------------------------------------------+

void MonitorReversals()
{
  // Loop through all positions
  for (int i = 0; i < positionCount; i++)
  {
    // Check if position is near TP (within 50 pips)
    double distanceToTP = GetDistanceToTP(i);

    if (distanceToTP > 0 && distanceToTP < 50)
    {
      // Position near TP; check for reversal candle
      ReversalSignal revSignal = DetectReversalCandle(positions[i].isLong);

      if (revSignal.isTriggered)
      {
        // 5M reversal detected; now confirm on 1M
        if (ConfirmReversal1M(revSignal.isLong))
        {
          // Both 5M and 1M conditions met; reversal is confirmed
          LogReversalDetection(revSignal.isLong, revSignal.reversalPrice, 0);

          // In a full implementation, check if a Setup 1 or 2 signal
          // forms in the opposite direction before flipping

          // For now, log the detection; flip logic would integrate with signal detection
          LogAlert("REVERSAL_CONFIRMED",
                  StringFormat("Position %lld near TP (%.1f pips). Reversal detected, awaiting signal.",
                              positions[i].ticket, distanceToTP));
        }
      }
    }
  }
}

#endif
