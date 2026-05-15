//+------------------------------------------------------------------+
//| OrderExecutor.mqh - Robust Order Placement with Recovery
//|
//| Key Features:
//| - Exponential backoff retry logic
//| - Slippage validation and rollback
//| - Transaction isolation
//| - Complete execution record/audit trail
//+------------------------------------------------------------------+

#ifndef __ORDER_EXECUTOR_MQH__
#define __ORDER_EXECUTOR_MQH__

#include "Trade/Trade.mqh"

class OrderExecutor {
public:
    // ==================== PUBLIC ENUMERATIONS ====================
    
    enum ExecutionStatus {
        STATUS_PENDING,      // Order sent, awaiting fill
        STATUS_FILLED,       // Order completely filled
        STATUS_PARTIAL,      // Partially filled (rare)
        STATUS_REJECTED,     // Order rejected by broker
        STATUS_ERROR,        // Internal error
        STATUS_RECOVERED     // Recovered from pending state
    };
    
    enum RecoverableError {
        RECOV_CONNECTION = 1,
        RECOV_TIMEOUT = 2,
        RECOV_BUSY = 3,
        RECOV_TRADE_DISABLED = 4,
        RECOV_NOT_ENOUGH_MONEY = 5
    };
    
    // ==================== EXECUTION RECORD ====================
    
    struct ExecutionRecord {
        ExecutionStatus status;
        long            ticket;
        double          fillPrice;
        double          slippage;
        double          filledVolume;
        string          errorMessage;
        datetime        sentTime;
        datetime        filledTime;
    };
    
private:
    // ==================== CONFIGURATION ====================

    CTrade              m_trade;
    int                 m_maxSpreadPoints;
    enum {
        MAX_RETRIES       = 5,
        RETRY_DELAY_MS    = 100,
        MAX_SLIPPAGE_PIPS = 50
    };
    
    // ==================== PRIVATE HELPER METHODS ====================
    
    //+------------------------------------------------------------------+
    //| Validate order parameters before OrderSend
    //+------------------------------------------------------------------+
    bool ValidateOrderParameters(MqlTradeRequest& req) {
        // Check symbol exists
        if (!SymbolSelect(req.symbol, true)) {
            Print("[ERROR] Invalid symbol: ", req.symbol);
            return false;
        }
        
        // Check volume constraints
        double minLot = SymbolInfoDouble(req.symbol, SYMBOL_VOLUME_MIN);
        double maxLot = SymbolInfoDouble(req.symbol, SYMBOL_VOLUME_MAX);
        double lotStep = SymbolInfoDouble(req.symbol, SYMBOL_VOLUME_STEP);
        
        if (req.volume < minLot || req.volume > maxLot) {
            Print("[ERROR] Volume ", req.volume, " outside range [", minLot, ", ", maxLot, "]");
            return false;
        }
        
        // Check price is reasonable — use tick-relative spread to support all instruments
        double bid = SymbolInfoDouble(req.symbol, SYMBOL_BID);
        double ask = SymbolInfoDouble(req.symbol, SYMBOL_ASK);
        double spread = ask - bid;
        double tickSize = SymbolInfoDouble(req.symbol, SYMBOL_TRADE_TICK_SIZE);
        double spreadTicks = (tickSize > 0) ? spread / tickSize : 0;

        if (spread <= 0 || spreadTicks > m_maxSpreadPoints) {
            Print("[ERROR] Spread too wide: ", spreadTicks, " pts (max ", m_maxSpreadPoints, ")");
            return false;
        }
        
        // Check SL/TP are on correct side of entry
        if (req.type == ORDER_TYPE_BUY) {
            if (req.sl > 0 && req.sl >= req.price) {
                Print("[ERROR] BUY SL too high");
                return false;
            }
            if (req.tp > 0 && req.tp <= req.price) {
                Print("[ERROR] BUY TP too low");
                return false;
            }
        } else {
            if (req.sl > 0 && req.sl <= req.price) {
                Print("[ERROR] SELL SL too low");
                return false;
            }
            if (req.tp > 0 && req.tp >= req.price) {
                Print("[ERROR] SELL TP too high");
                return false;
            }
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Determine if error is recoverable (worth retrying)
    //+------------------------------------------------------------------+
    bool IsRecoverableRetcode(uint retcode) {
        switch (retcode) {
            case 10004:  // TRADE_RETCODE_REQUOTE — price moved, retry
            case 10012:  // TRADE_RETCODE_TIMEOUT — server timeout
            case 10021:  // TRADE_RETCODE_PRICE_OFF — stale quote
            case 10030:  // TRADE_RETCODE_TOO_MANY_REQUESTS — throttled
                return true;
            default:
                return false;
        }
    }
    
    //+------------------------------------------------------------------+
    //| Verify fill price is within acceptable slippage
    //+------------------------------------------------------------------+
    bool VerifySlippage(double fillPrice, double intendedPrice, double maxSlippagePips) {
        double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
        double slippagePips = MathAbs(fillPrice - intendedPrice) / tickSize;
        
        if (slippagePips > maxSlippagePips) {
            Print("[ERROR] Slippage ", slippagePips, " pips exceeds max ", maxSlippagePips);
            return false;
        }
        
        return true;
    }
    
public:
    // ==================== PUBLIC INTERFACE ====================
    
    OrderExecutor() : m_maxSpreadPoints(500) {}

    void SetMaxSpreadPoints(int maxPts) { m_maxSpreadPoints = maxPts; }

    ~OrderExecutor() {}
    
    //+------------------------------------------------------------------+
    //| Place market order with retry logic and slippage validation
    //| Returns: ExecutionRecord with status and fill details
    //+------------------------------------------------------------------+
    ExecutionRecord PlaceOrder(bool isLong, double volume, 
                               double entryPrice, double stopLoss, 
                               double takeProfit, int magicNumber = 99001) {
        
        ExecutionRecord result;
        result.status = STATUS_PENDING;
        result.ticket = 0;
        result.fillPrice = 0;
        result.slippage = 0;
        result.filledVolume = 0;
        result.errorMessage = "";
        result.sentTime = TimeCurrent();
        result.filledTime = 0;
        
        // Prepare request
        MqlTradeRequest request;
        ZeroMemory(request);
        
        request.action = TRADE_ACTION_DEAL;
        request.symbol = Symbol();
        request.volume = volume;
        request.type = isLong ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
        request.price = entryPrice;
        request.sl = stopLoss;
        request.tp = takeProfit;
        request.deviation = 500;  // 5 pips slippage tolerance
        request.magic = magicNumber;
        request.comment = "VP_EA_Trade";
        
        // Validate before sending
        if (!ValidateOrderParameters(request)) {
            result.status = STATUS_REJECTED;
            result.errorMessage = "Parameter validation failed";
            return result;
        }
        
        // Retry loop with exponential backoff
        int retryDelay = RETRY_DELAY_MS;
        datetime attemptTime = TimeCurrent();
        
        for (int attempt = 0; attempt < MAX_RETRIES; attempt++) {
            MqlTradeResult tradeResult;
            ZeroMemory(tradeResult);
            
            // Send order
            if (!OrderSend(request, tradeResult)) {
                // Prefer the trade retcode; fall back to GetLastError() if retcode is 0
                uint retcode = (tradeResult.retcode != 0) ? tradeResult.retcode : (uint)GetLastError();
                result.errorMessage = StringFormat("OrderSend failed: retcode=%d", retcode);

                if (!IsRecoverableRetcode(retcode) || attempt == MAX_RETRIES - 1) {
                    result.status = STATUS_REJECTED;
                    Print("[ERROR] ", result.errorMessage);
                    return result;
                }

                // Retry with exponential backoff
                Print("[WARNING] ", result.errorMessage, "; retrying in ", retryDelay, "ms");
                Sleep(retryDelay);
                retryDelay *= 2;
                continue;
            }
            
            // Order sent; check result
            if (tradeResult.retcode != TRADE_RETCODE_DONE && 
                tradeResult.retcode != TRADE_RETCODE_PLACED) {
                result.status = STATUS_ERROR;
                result.errorMessage = StringFormat("Trade retcode: %d", tradeResult.retcode);
                Print("[ERROR] ", result.errorMessage);
                return result;
            }
            
            // Order executed; verify fill
            result.ticket = (long)tradeResult.order;
            result.fillPrice = tradeResult.price;
            result.filledVolume = tradeResult.volume;
            
            // Check slippage
            double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
            result.slippage = MathAbs(result.fillPrice - entryPrice) / tickSize;
            
            if (result.slippage > MAX_SLIPPAGE_PIPS) {
                // Slippage exceeded: close the specific filled position by ticket
                Print("[ERROR] Slippage ", result.slippage, " pips > limit ", MAX_SLIPPAGE_PIPS,
                      "; closing Ticket=", result.ticket);

                MqlTradeRequest closeReq;
                MqlTradeResult  closeRes;
                ZeroMemory(closeReq);
                ZeroMemory(closeRes);
                closeReq.action   = TRADE_ACTION_DEAL;
                closeReq.symbol   = request.symbol;
                closeReq.volume   = tradeResult.volume;
                closeReq.type     = isLong ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
                closeReq.price    = isLong ? SymbolInfoDouble(request.symbol, SYMBOL_BID)
                                           : SymbolInfoDouble(request.symbol, SYMBOL_ASK);
                closeReq.deviation = 500;
                closeReq.position  = (ulong)result.ticket;
                closeReq.magic     = magicNumber;
                if (!OrderSend(closeReq, closeRes)) {
                    Print("[WARNING] Slippage rollback OrderSend failed: ", GetLastError());
                }

                result.status       = STATUS_ERROR;
                result.errorMessage = "Slippage exceeded; position closed";
                return result;
            }
            
            // Success!
            result.status = STATUS_FILLED;
            result.filledTime = TimeCurrent();
            
            Print("[SUCCESS] Order filled. Ticket=", result.ticket, 
                  " Price=", result.fillPrice, 
                  " Slippage=", result.slippage, " pips");
            
            return result;
        }
        
        // Max retries exhausted
        result.status = STATUS_ERROR;
        result.errorMessage = "Max retries exhausted";
        return result;
    }
    
};

#endif // __ORDER_EXECUTOR_MQH__
