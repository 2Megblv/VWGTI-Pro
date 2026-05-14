#property copyright "VWGTI-Pro v3.0"
#property version   "3.0"

//+------------------------------------------------------------------+
//| PositionManager.mqh - Broker-Synchronized Position Tracking
//|
//| Key Features:
//| - Automatic broker reconciliation on startup
//| - Orphaned position detection
//| - Dynamic position array (no fixed limit)
//| - OnTrade() event integration
//| - Safe array modifications
//+------------------------------------------------------------------+

#ifndef __POSITION_MANAGER_MQH__
#define __POSITION_MANAGER_MQH__

#include <Trade/Trade.mqh>

class PositionManager {
private:
    CTrade m_trade;
    // ==================== POSITION RECORD STRUCTURE ====================
    struct PositionRecord {
        long     ticket;
        string   symbol;
        bool     isLong;
        double   entryPrice;
        double   stopLoss;
        double   takeProfit;
        double   originalLots;
        double   remainingLots;
        string   setupType;
        datetime entryTime;
        bool     isRecovered;      // true = recovered from broker on startup
    };
    
    // ==================== INTERNAL STATE ====================
    PositionRecord positions[];    // Dynamic array
    int positionCount;
    long lastReconciliationTime;
    
    // ==================== PRIVATE HELPER METHODS ====================
    
    //+------------------------------------------------------------------+
    //| Find position index by ticket
    //+------------------------------------------------------------------+
    int FindByTicket(long ticket) const {
        for (int i = 0; i < positionCount; i++) {
            if (positions[i].ticket == ticket) {
                return i;
            }
        }
        return -1;
    }
    
    //+------------------------------------------------------------------+
    //| Synchronize in-memory positions with broker's live positions
    //| Called on startup and periodically for safety
    //+------------------------------------------------------------------+
    bool ReconcileWithBroker() {
        Print("[PositionManager] Starting broker reconciliation...");
        
        int orphanedCount = 0;
        int recoveredCount = 0;
        
        // Step 1: Check for orphaned positions (live but not in memory)
        if (PositionsTotal() > positionCount) {
            Print("[PositionManager] WARNING: Broker has ", PositionsTotal(), 
                  " live positions, but EA memory has ", positionCount);
            
            for (int i = 0; i < PositionsTotal(); i++) {
                long ticket = (long)PositionGetTicket(i);
                
                if (ticket > 0 && FindByTicket(ticket) < 0) {
                    // Orphaned position found
                    PositionSelectByTicket(ticket);
                    
                    PositionRecord pr;
                    pr.ticket = PositionGetInteger(POSITION_TICKET);
                    pr.symbol = PositionGetString(POSITION_SYMBOL);
                    pr.isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
                    pr.entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                    pr.stopLoss = PositionGetDouble(POSITION_SL);
                    pr.takeProfit = PositionGetDouble(POSITION_TP);
                    pr.remainingLots = PositionGetDouble(POSITION_VOLUME);
                    pr.originalLots = pr.remainingLots;
                    pr.entryTime = TimeCurrent();
                    pr.setupType = "ORPHANED";
                    pr.isRecovered = true;
                    
                    ArrayResize(positions, positionCount + 1);
                    positions[positionCount] = pr;
                    positionCount++;
                    orphanedCount++;
                    
                    Print("[PositionManager] Recovered orphaned position: Ticket=", ticket, 
                          " Symbol=", pr.symbol, " Lots=", pr.remainingLots);
                }
            }
        }
        
        // Step 2: Check for stale positions (in memory but not at broker)
        for (int i = positionCount - 1; i >= 0; i--) {
            if (!PositionSelectByTicket(positions[i].ticket)) {
                Print("[PositionManager] WARNING: Position ", positions[i].ticket, 
                      " not found at broker; removing from memory");
                
                // Shift array down
                for (int j = i; j < positionCount - 1; j++) {
                    positions[j] = positions[j + 1];
                }
                ArrayResize(positions, positionCount - 1);
                positionCount--;
            }
        }
        
        lastReconciliationTime = TimeCurrent();
        
        Print("[PositionManager] Reconciliation complete. Orphaned: ", orphanedCount, 
              ", Recovered: ", recoveredCount, ", Total: ", positionCount);
        
        return true;
    }
    
public:
    // ==================== PUBLIC INTERFACE ====================
    
    PositionManager() : positionCount(0), lastReconciliationTime(0) {
        ArrayResize(positions, 0);
    }
    
    ~PositionManager() {
        ArrayFree(positions);
    }
    
    //+------------------------------------------------------------------+
    //| Initialize: Recover positions from broker on startup
    //+------------------------------------------------------------------+
    bool Initialize() {
        Print("[PositionManager] Initializing...");
        
        // Reconcile with broker to recover any live positions
        if (!ReconcileWithBroker()) {
            Print("[ERROR] Failed to reconcile with broker");
            return false;
        }
        
        Print("[PositionManager] Ready. ", positionCount, " positions tracked.");
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Open a new position and add to tracking
    //+------------------------------------------------------------------+
    long OpenPosition(bool isLong, double entryPrice, double stopLoss, 
                      double takeProfit, double lots, string setupType = "MANUAL") {
        
        if (lots <= 0) {
            Print("[ERROR] Invalid lot size: ", lots);
            return 0;
        }
        
        // Create record (assume OrderExecutor already placed the order)
        PositionRecord pr;
        pr.isLong = isLong;
        pr.entryPrice = entryPrice;
        pr.stopLoss = stopLoss;
        pr.takeProfit = takeProfit;
        pr.originalLots = lots;
        pr.remainingLots = lots;
        pr.setupType = setupType;
        pr.entryTime = TimeCurrent();
        pr.isRecovered = false;
        
        // Note: ticket will be set by OrderExecutor
        // This function adds to tracking AFTER successful order fill
        
        ArrayResize(positions, positionCount + 1);
        positions[positionCount] = pr;
        positionCount++;
        
        Print("[PositionManager] Added position. Total: ", positionCount);
        
        return pr.ticket;
    }
    
    //+------------------------------------------------------------------+
    //| Register filled position (called by OrderExecutor after fill)
    //+------------------------------------------------------------------+
    void RegisterFill(long ticket, bool isLong, double entryPrice, 
                      double stopLoss, double takeProfit, double lots, 
                      string setupType) {
        
        // Find last position (just added)
        if (positionCount > 0) {
            positions[positionCount - 1].ticket = ticket;
            positions[positionCount - 1].symbol = Symbol();
            positions[positionCount - 1].isLong = isLong;
            positions[positionCount - 1].entryPrice = entryPrice;
            positions[positionCount - 1].stopLoss = stopLoss;
            positions[positionCount - 1].takeProfit = takeProfit;
            positions[positionCount - 1].originalLots = lots;
            positions[positionCount - 1].remainingLots = lots;
            positions[positionCount - 1].setupType = setupType;
            positions[positionCount - 1].isRecovered = false;
        }
    }
    
    //+------------------------------------------------------------------+
    //| Modify position SL/TP
    //+------------------------------------------------------------------+
    bool ModifyPosition(long ticket, double newSL, double newTP) {
        int idx = FindByTicket(ticket);
        
        if (idx < 0) {
            Print("[ERROR] Position ", ticket, " not found");
            return false;
        }
        
        if (!PositionSelectByTicket(ticket)) {
            Print("[ERROR] Failed to select position ", ticket);
            return false;
        }
        
        // Update in memory
        positions[idx].stopLoss = newSL;
        positions[idx].takeProfit = newTP;
        
        Print("[PositionManager] Modified position ", ticket, 
              " SL=", newSL, " TP=", newTP);
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Close position (decrement remaining lots)
    //+------------------------------------------------------------------+
    bool ClosePosition(long ticket, double closeLots) {
        int idx = FindByTicket(ticket);
        
        if (idx < 0) {
            Print("[ERROR] Position ", ticket, " not found");
            return false;
        }
        
        positions[idx].remainingLots -= closeLots;
        
        if (positions[idx].remainingLots <= 0) {
            // Remove from tracking
            for (int i = idx; i < positionCount - 1; i++) {
                positions[i] = positions[i + 1];
            }
            ArrayResize(positions, positionCount - 1);
            positionCount--;
            
            Print("[PositionManager] Removed position ", ticket, 
                  ". Total: ", positionCount);
        } else {
            Print("[PositionManager] Partial close. Remaining: ", 
                  positions[idx].remainingLots, " lots");
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Get total open positions
    //+------------------------------------------------------------------+
    int GetPositionCount() const {
        return positionCount;
    }
    
    //+------------------------------------------------------------------+
    //| Get position by index
    //+------------------------------------------------------------------+
    bool GetPosition(int index, long& ticket, string& symbol, bool& isLong, 
                    double& entry, double& sl, double& tp, double& lots, 
                    string& setup) {
        
        if (index < 0 || index >= positionCount) {
            return false;
        }
        
        ticket = positions[index].ticket;
        symbol = positions[index].symbol;
        isLong = positions[index].isLong;
        entry = positions[index].entryPrice;
        sl = positions[index].stopLoss;
        tp = positions[index].takeProfit;
        lots = positions[index].remainingLots;
        setup = positions[index].setupType;
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| OnTrade() event callback (real-time position sync)
    //+------------------------------------------------------------------+
    void OnTrade() {
        // Called when position fills or closes
        // Update memory to match broker state
        ReconcileWithBroker();
    }
    
    //+------------------------------------------------------------------+
    //| Manual reconciliation (call periodically for safety)
    //+------------------------------------------------------------------+
    bool Reconcile() {
        return ReconcileWithBroker();
    }
    
    //+------------------------------------------------------------------+
    //| Get total P&L from open positions
    //+------------------------------------------------------------------+
    double GetOpenPnL() {
        double totalPnL = 0;
        double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
        double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
        
        for (int i = 0; i < positionCount; i++) {
            double pnl = 0;
            
            if (positions[i].isLong) {
                pnl = (bid - positions[i].entryPrice) * positions[i].remainingLots * tickValue;
            } else {
                pnl = (positions[i].entryPrice - ask) * positions[i].remainingLots * tickValue;
            }
            
            totalPnL += pnl;
        }
        
        return totalPnL;
    }
    
    //+------------------------------------------------------------------+
    //| Close all positions (for emergency shutdown)
    //+------------------------------------------------------------------+
    int CloseAll() {
        int closedCount = 0;
        double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        
        for (int i = positionCount - 1; i >= 0; i--) {
            if (PositionSelectByTicket(positions[i].ticket)) {
                if (m_trade.PositionClose(positions[i].symbol)) {
                    ClosePosition(positions[i].ticket, positions[i].remainingLots);
                    closedCount++;
                }
            }
        }
        
        Print("[PositionManager] Closed all positions. Count: ", closedCount);
        return closedCount;
    }
};

#endif // __POSITION_MANAGER_MQH__
