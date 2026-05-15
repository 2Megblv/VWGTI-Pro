//+------------------------------------------------------------------+
//|                    TradeExecution.mqh                            |
//|               Trade Execution and Position Management             |
//|                    Phase 2 Wave 2: Execution                     |
//|                                                                  |
//| Description:                                                     |
//|   Handles order placement via CTrade with post-execution         |
//|   slippage validation, position state tracking, and position     |
//|   monitoring. Implements position state machine using            |
//|   remaining lots tracking method. Single TP per position         |
//|   (opposite profile edge: VAH for LONG, VAL for SHORT).          |
//|                                                                  |
//| Key Functions:                                                   |
//|   - PlaceMarketOrder() - CTrade order placement with validation  |
//|   - UpdatePositionState() - Track remaining lots on closes      |
//|   - MonitorPositionExits() - Check TP/SL every tick             |
//|   - ClosePosition() - Close position and update state           |
//|   - CalculateRiskRewardRatio() - R:R calculation                |
//|                                                                  |
//+------------------------------------------------------------------+

#ifndef __TRADEEXECUTION_MQH__
#define __TRADEEXECUTION_MQH__

#include <Trade/Trade.mqh>

// ==================== CONSTANTS ====================

#define MAX_POSITIONS 10           // Max simultaneous positions
#define SLIPPAGE_LIMIT 50          // 50-pip tolerance (D-07)
#define RETRY_ATTEMPTS 3           // Order placement retry attempts
#define RETRY_DELAY 100            // Milliseconds between retries

// ==================== DATA STRUCTURES ====================

// Result of order placement attempt
struct OrderResult
{
    bool success;                  // Order filled successfully
    long ticket;                   // Position ticket number
    double fillPrice;              // Actual fill price
    double slippage;               // Actual slippage in pips
};

// Position state tracking (remaining lots method per D-03/D-06)
struct PositionState
{
    long ticket;                   // Position ticket
    string symbol;                 // Trading symbol
    bool isLong;                   // True=LONG, False=SHORT
    double entryPrice;             // Entry execution price
    double stopLoss;               // SL price (below sweep low + buffer)
    double takeProfit;             // TP price (opposite profile edge)
    double originalLots;           // Original position size at entry
    double remainingLots;          // Remaining lots (decrements on partial closes)
    datetime entryTime;            // Entry timestamp
    string setupType;              // "Setup1" or "Setup2"
    double riskRewardRatio;        // R:R ratio at entry
};

// ==================== GLOBAL VARIABLES ====================

CTrade trade;                      // Global CTrade instance
PositionState positions[MAX_POSITIONS];  // Position tracking array
int positionCount = 0;             // Number of active positions

// ==================== FUNCTION DECLARATIONS ====================

// Order placement with post-execution slippage validation
OrderResult PlaceMarketOrder(ENUM_ORDER_TYPE orderType, double lots,
                             double intendedPrice, double stopLoss,
                             double takeProfit);

// Add position to tracking array
void AddPosition(long ticket, string symbol, bool isLong, double entryPrice,
                 double stopLoss, double takeProfit, double lots,
                 string setupType, double riskRewardRatio);

// Update position remaining lots on partial close
bool UpdatePositionState(long ticket, double partialCloseLots);

// Remove position from tracking array
void RemovePosition(int index);

// Find position by ticket in array
int FindPositionByTicket(long ticket);

// Monitor all positions for TP/SL hits every tick
void MonitorPositionExits();

// Close position and update state
void ClosePosition(long ticket, double exitPrice, string exitReason, double closeLots);

// Calculate Risk/Reward ratio
double CalculateRiskRewardRatio(double entryPrice, double stopLossPrice,
                                double takeProfitPrice);

// ==================== FUNCTION IMPLEMENTATIONS ====================

//+------------------------------------------------------------------+
//| Place Market Order with Post-Execution Slippage Validation      |
//| Per D-07: Reject fills >50 pips from intended entry; close bad   |
//| fills immediately. Retry logic for transient errors.             |
//+------------------------------------------------------------------+
OrderResult PlaceMarketOrder(ENUM_ORDER_TYPE orderType, double lots,
                             double intendedPrice, double stopLoss,
                             double takeProfit)
{
    OrderResult result = {false, 0, 0, 0};

    // Retry logic: up to 3 attempts for transient errors
    for (int attempt = 0; attempt < RETRY_ATTEMPTS; attempt++)
    {
        // Prepare trade request
        MqlTradeRequest request;
        ZeroMemory(request);
        request.action = TRADE_ACTION_DEAL;
        request.symbol = Symbol();
        request.volume = lots;
        request.type = orderType;
        request.price = intendedPrice;
        request.sl = stopLoss;
        request.tp = takeProfit;
        request.deviation = 500;   // 50 pips (5 decimal places)
        request.magic = EA_MAGIC_NUMBER;
        request.comment = (orderType == ORDER_TYPE_BUY) ? "Setup-LONG" : "Setup-SHORT";

        // Execute via native OrderSend (CTrade.Send does not exist in MQL5)
        MqlTradeResult tradeResult;
        ZeroMemory(tradeResult);
        if (!OrderSend(request, tradeResult))
        {
            uint retcode = tradeResult.retcode;
            LogError(StringFormat("OrderSend failed. Retcode=%d, Attempt=%d/%d",
                                retcode, attempt + 1, RETRY_ATTEMPTS));

            // Retry transient errors (not terminal retcodes)
            if (attempt < RETRY_ATTEMPTS - 1)
            {
                Sleep(RETRY_DELAY);
                continue;
            }
            else
            {
                result.success = false;
                return result;
            }
        }

        // Order executed; check return code
        uint retcode = tradeResult.retcode;

        if (retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_PLACED)
        {
            // Successful execution; validate slippage
            result.ticket = (long)tradeResult.order;
            result.fillPrice = tradeResult.price;

            // D-07: Validate slippage (50-pip tolerance)
            double slippagePips = MathAbs(result.fillPrice - intendedPrice) / _Point;

            if (slippagePips <= SLIPPAGE_LIMIT)
            {
                // Slippage acceptable
                result.success = true;
                result.slippage = slippagePips;

                LogAlert("ORDER_FILLED",
                        StringFormat("Ticket=%ld, Price=%.5f, Slippage=%.1f pips, Intent=%.5f",
                                    result.ticket, result.fillPrice, result.slippage, intendedPrice));

                return result;
            }
            else
            {
                // Slippage exceeds 50 pips; reject and close position immediately
                LogError(StringFormat("Slippage exceeds limit (%.1f pips > %d pips). Closing position ticket=%ld",
                                    slippagePips, SLIPPAGE_LIMIT, result.ticket));

                // Close the position at market (avoid locking in bad fill)
                trade.PositionClose(result.ticket);

                result.success = false;
                result.slippage = slippagePips;
                return result;
            }
        }
        else
        {
            // Transient error; may retry
            LogError(StringFormat("OrderSend retcode=%d, Attempt=%d/%d",
                                retcode, attempt + 1, RETRY_ATTEMPTS));

            if (attempt < RETRY_ATTEMPTS - 1)
            {
                Sleep(RETRY_DELAY);
                continue;
            }
            else
            {
                result.success = false;
                return result;
            }
        }
    }

    result.success = false;
    return result;
}

//+------------------------------------------------------------------+
//| Add new position to tracking array                               |
//+------------------------------------------------------------------+
void AddPosition(long ticket, string symbol, bool isLong, double entryPrice,
                 double stopLoss, double takeProfit, double lots,
                 string setupType, double riskRewardRatio)
{
    if (positionCount >= MAX_POSITIONS)
    {
        LogError("Position array full; cannot add new position");
        return;
    }

    positions[positionCount].ticket = ticket;
    positions[positionCount].symbol = symbol;
    positions[positionCount].isLong = isLong;
    positions[positionCount].entryPrice = entryPrice;
    positions[positionCount].stopLoss = stopLoss;
    positions[positionCount].takeProfit = takeProfit;
    positions[positionCount].originalLots = lots;
    positions[positionCount].remainingLots = lots;
    positions[positionCount].entryTime = TimeCurrent();
    positions[positionCount].setupType = setupType;
    positions[positionCount].riskRewardRatio = riskRewardRatio;

    positionCount++;

    LogAlert("POSITION_ADDED",
            StringFormat("Ticket=%ld, Symbol=%s, Side=%s, Entry=%.5f, SL=%.5f, TP=%.5f, Lots=%.2f, Setup=%s, RR=%.2f:1",
                        ticket, symbol, isLong ? "LONG" : "SHORT", entryPrice, stopLoss, takeProfit, lots, setupType, riskRewardRatio));
}

//+------------------------------------------------------------------+
//| Update position state on partial close (decrement remaining lots)|
//+------------------------------------------------------------------+
bool UpdatePositionState(long ticket, double partialCloseLots)
{
    // Find position in array and decrement remaining lots
    for (int i = 0; i < positionCount; i++)
    {
        if (positions[i].ticket == ticket)
        {
            positions[i].remainingLots -= partialCloseLots;

            // Log partial close
            LogAlert("PARTIAL_CLOSE",
                    StringFormat("Ticket=%ld, ClosedLots=%.2f, RemainingLots=%.2f",
                                ticket, partialCloseLots, positions[i].remainingLots));

            if (positions[i].remainingLots <= 0)
            {
                // Position fully closed; remove from tracking
                RemovePosition(i);
                return true;
            }

            return true;
        }
    }

    return false;  // Position not found
}

//+------------------------------------------------------------------+
//| Remove position from tracking array                              |
//+------------------------------------------------------------------+
void RemovePosition(int index)
{
    if (index < 0 || index >= positionCount)
    {
        LogError(StringFormat("Invalid index for RemovePosition: %d", index));
        return;
    }

    // Shift remaining positions down
    for (int i = index; i < positionCount - 1; i++)
    {
        positions[i] = positions[i + 1];
    }
    positionCount--;

    LogAlert("POSITION_REMOVED",
            StringFormat("Array index %d removed; positionCount now %d", index, positionCount));
}

//+------------------------------------------------------------------+
//| Find position by ticket number                                   |
//+------------------------------------------------------------------+
int FindPositionByTicket(long ticket)
{
    for (int i = 0; i < positionCount; i++)
    {
        if (positions[i].ticket == ticket)
            return i;
    }
    return -1;  // Not found
}

//+------------------------------------------------------------------+
//| Monitor all open positions for TP/SL hits (called every tick)    |
//+------------------------------------------------------------------+
void MonitorPositionExits()
{
    // Check all open positions every tick for TP/SL hits
    for (int i = 0; i < positionCount; i++)
    {
        // Get current bid/ask
        double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

        // Check TP hit (entire remaining position closes)
        if (positions[i].isLong && bid >= positions[i].takeProfit)
        {
            // LONG position TP hit
            LogAlert("TP_HIT",
                    StringFormat("LONG ticket=%ld at TP=%.5f (bid=%.5f)",
                                positions[i].ticket, positions[i].takeProfit, bid));
            ClosePosition(positions[i].ticket, bid, "TP", positions[i].remainingLots);
            return;  // Exit loop (position was removed by ClosePosition)
        }

        if (!positions[i].isLong && ask <= positions[i].takeProfit)
        {
            // SHORT position TP hit
            LogAlert("TP_HIT",
                    StringFormat("SHORT ticket=%ld at TP=%.5f (ask=%.5f)",
                                positions[i].ticket, positions[i].takeProfit, ask));
            ClosePosition(positions[i].ticket, ask, "TP", positions[i].remainingLots);
            return;
        }

        // Check SL hit (entire remaining position closes)
        if (positions[i].isLong && bid <= positions[i].stopLoss)
        {
            // LONG position SL hit
            LogAlert("SL_HIT",
                    StringFormat("LONG ticket=%ld at SL=%.5f (bid=%.5f)",
                                positions[i].ticket, positions[i].stopLoss, bid));
            ClosePosition(positions[i].ticket, bid, "SL", positions[i].remainingLots);
            return;
        }

        if (!positions[i].isLong && ask >= positions[i].stopLoss)
        {
            // SHORT position SL hit
            LogAlert("SL_HIT",
                    StringFormat("SHORT ticket=%ld at SL=%.5f (ask=%.5f)",
                                positions[i].ticket, positions[i].stopLoss, ask));
            ClosePosition(positions[i].ticket, ask, "SL", positions[i].remainingLots);
            return;
        }
    }
}

//+------------------------------------------------------------------+
//| Close position and update state                                  |
//+------------------------------------------------------------------+
void ClosePosition(long ticket, double exitPrice, string exitReason, double closeLots)
{
    // Find position in array
    int idx = FindPositionByTicket(ticket);
    if (idx < 0)
    {
        LogError(StringFormat("Position ticket=%ld not found for close", ticket));
        return;
    }

    PositionState pos = positions[idx];  // copy — MQL5 does not allow local references

    // Calculate P&L for this trade
    double pnlPips = (exitPrice - pos.entryPrice) / _Point;
    if (!pos.isLong)
        pnlPips = (pos.entryPrice - exitPrice) / _Point;  // SHORT P&L inverted

    // Close position via CTrade
    bool closed = trade.PositionClose(ticket);

    if (closed)
    {
        LogAlert("POSITION_CLOSED",
                StringFormat("Ticket=%ld, Setup=%s, Entry=%.5f, Exit=%.5f, PnL=%.1f pips, Reason=%s, RR=%.2f:1",
                            ticket, pos.setupType, pos.entryPrice, exitPrice, pnlPips, exitReason, pos.riskRewardRatio));

        // Update position state (remove from tracking)
        UpdatePositionState(ticket, closeLots);
    }
    else
    {
        LogError(StringFormat("Failed to close position ticket=%ld", ticket));
    }
}

//+------------------------------------------------------------------+
//| Calculate Risk/Reward Ratio (REQ-028)                            |
//| Formula: R:R = (TP distance in pips) / (SL distance in pips)     |
//+------------------------------------------------------------------+
double CalculateRiskRewardRatio(double entryPrice, double stopLossPrice,
                                double takeProfitPrice)
{
    // R:R = (TP distance in pips) / (SL distance in pips)

    double riskDistancePips = MathAbs(entryPrice - stopLossPrice) / _Point;
    double rewardDistancePips = MathAbs(takeProfitPrice - entryPrice) / _Point;

    if (riskDistancePips <= 0)
    {
        LogError("Risk distance is zero; invalid SL placement");
        return 0;
    }

    double rrRatio = rewardDistancePips / riskDistancePips;

    return rrRatio;
}

#endif // __TRADEEXECUTION_MQH__
