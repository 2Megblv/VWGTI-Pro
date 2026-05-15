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

#include "Trade/Trade.mqh"

class PositionManager {
private:
    CTrade m_trade;

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
        bool     isRecovered;
    };

    PositionRecord positions[];
    int  positionCount;

    // ==================== PRIVATE HELPERS ====================

    int FindByTicket(long ticket) const {
        for (int i = 0; i < positionCount; i++) {
            if (positions[i].ticket == ticket) return i;
        }
        return -1;
    }

    bool ReconcileWithBroker() {
        Print("[PositionManager] Starting broker reconciliation...");

        int orphanedCount = 0;

        // Step 1: Recover orphaned broker positions not in memory
        for (int i = 0; i < PositionsTotal(); i++) {
            long ticket = (long)PositionGetTicket(i);
            if (ticket > 0 && FindByTicket(ticket) < 0) {
                PositionSelectByTicket(ticket);

                PositionRecord pr;
                pr.ticket        = PositionGetInteger(POSITION_TICKET);
                pr.symbol        = PositionGetString(POSITION_SYMBOL);
                pr.isLong        = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
                pr.entryPrice    = PositionGetDouble(POSITION_PRICE_OPEN);
                pr.stopLoss      = PositionGetDouble(POSITION_SL);
                pr.takeProfit    = PositionGetDouble(POSITION_TP);
                pr.remainingLots = PositionGetDouble(POSITION_VOLUME);
                pr.originalLots  = pr.remainingLots;
                pr.entryTime     = TimeCurrent();
                pr.setupType     = "ORPHANED";
                pr.isRecovered   = true;

                ArrayResize(positions, positionCount + 1);
                positions[positionCount] = pr;
                positionCount++;
                orphanedCount++;

                Print("[PositionManager] Recovered orphaned position: Ticket=", ticket,
                      " Symbol=", pr.symbol, " Lots=", pr.remainingLots);
            }
        }

        // Step 2: Remove stale positions (in memory but closed at broker)
        for (int i = positionCount - 1; i >= 0; i--) {
            if (!PositionSelectByTicket(positions[i].ticket)) {
                Print("[PositionManager] Stale position ", positions[i].ticket,
                      " not at broker; removing from memory");
                for (int j = i; j < positionCount - 1; j++) {
                    positions[j] = positions[j + 1];
                }
                ArrayResize(positions, positionCount - 1);
                positionCount--;
            }
        }

        Print("[PositionManager] Reconciliation complete. Orphaned=", orphanedCount,
              " Total=", positionCount);

        return true;
    }

public:
    PositionManager() : positionCount(0) {
        ArrayResize(positions, 0);
    }

    ~PositionManager() {
        ArrayFree(positions);
    }

    bool Initialize() {
        Print("[PositionManager] Initializing...");
        if (!ReconcileWithBroker()) {
            Print("[ERROR] Failed to reconcile with broker");
            return false;
        }
        Print("[PositionManager] Ready. ", positionCount, " positions tracked.");
        return true;
    }

    //+------------------------------------------------------------------+
    //| Register a confirmed fill — creates a new tracking entry.
    //| Called directly after OrderExecutor reports STATUS_FILLED.
    //| (OpenPosition() is no longer required as a pre-call.)
    //+------------------------------------------------------------------+
    void RegisterFill(long ticket, bool isLong, double entryPrice,
                      double stopLoss, double takeProfit, double lots,
                      string setupType) {
        PositionRecord pr;
        pr.ticket        = ticket;
        pr.symbol        = Symbol();
        pr.isLong        = isLong;
        pr.entryPrice    = entryPrice;
        pr.stopLoss      = stopLoss;
        pr.takeProfit    = takeProfit;
        pr.originalLots  = lots;
        pr.remainingLots = lots;
        pr.setupType     = setupType;
        pr.entryTime     = TimeCurrent();
        pr.isRecovered   = false;

        ArrayResize(positions, positionCount + 1);
        positions[positionCount] = pr;
        positionCount++;

        Print("[PositionManager] Registered fill. Ticket=", ticket,
              " Setup=", setupType, " Total=", positionCount);
    }

    bool ModifyPosition(long ticket, double newSL, double newTP) {
        int idx = FindByTicket(ticket);
        if (idx < 0) {
            Print("[ERROR] ModifyPosition: Ticket=", ticket, " not found");
            return false;
        }
        positions[idx].stopLoss   = newSL;
        positions[idx].takeProfit = newTP;
        Print("[PositionManager] Modified Ticket=", ticket, " SL=", newSL, " TP=", newTP);
        return true;
    }

    bool ClosePosition(long ticket, double closeLots) {
        int idx = FindByTicket(ticket);
        if (idx < 0) {
            Print("[ERROR] ClosePosition: Ticket=", ticket, " not found");
            return false;
        }

        positions[idx].remainingLots -= closeLots;

        if (positions[idx].remainingLots <= 0) {
            for (int i = idx; i < positionCount - 1; i++) {
                positions[i] = positions[i + 1];
            }
            ArrayResize(positions, positionCount - 1);
            positionCount--;
            Print("[PositionManager] Removed Ticket=", ticket, ". Total=", positionCount);
        } else {
            Print("[PositionManager] Partial close Ticket=", ticket,
                  " Remaining=", positions[idx].remainingLots);
        }

        return true;
    }

    int GetPositionCount() const { return positionCount; }

    bool GetPosition(int index, long& ticket, string& symbol, bool& isLong,
                     double& entry, double& sl, double& tp, double& lots,
                     string& setup) {
        if (index < 0 || index >= positionCount) return false;

        ticket = positions[index].ticket;
        symbol = positions[index].symbol;
        isLong = positions[index].isLong;
        entry  = positions[index].entryPrice;
        sl     = positions[index].stopLoss;
        tp     = positions[index].takeProfit;
        lots   = positions[index].remainingLots;
        setup  = positions[index].setupType;

        return true;
    }

    void OnTrade() {
        ReconcileWithBroker();
    }

    bool Reconcile() {
        return ReconcileWithBroker();
    }

    //+------------------------------------------------------------------+
    //| Get total unrealised P&L using broker's own POSITION_PROFIT value
    //+------------------------------------------------------------------+
    double GetOpenPnL() {
        double totalPnL = 0;
        for (int i = 0; i < positionCount; i++) {
            if (PositionSelectByTicket(positions[i].ticket)) {
                totalPnL += PositionGetDouble(POSITION_PROFIT);
            }
        }
        return totalPnL;
    }

    //+------------------------------------------------------------------+
    //| Close all positions (emergency shutdown / Friday close)
    //+------------------------------------------------------------------+
    int CloseAll() {
        int closedCount = 0;
        for (int i = positionCount - 1; i >= 0; i--) {
            if (PositionSelectByTicket(positions[i].ticket)) {
                if (m_trade.PositionClose(positions[i].symbol)) {
                    ClosePosition(positions[i].ticket, positions[i].remainingLots);
                    closedCount++;
                }
            }
        }
        Print("[PositionManager] CloseAll complete. Closed=", closedCount);
        return closedCount;
    }
};

#endif // __POSITION_MANAGER_MQH__
