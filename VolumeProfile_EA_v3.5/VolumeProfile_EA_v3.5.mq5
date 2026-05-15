//+------------------------------------------------------------------+
//|                      VolumeProfile_EA_v3.5.mq5                  |
//|                  Volume Profile Swing Trading EA                |
//|                   Production-Grade Architecture                 |
//|                                                                  |
//| Version: 3.5 (Modular, Robust, Production-Ready)                |
//| Description:                                                     |
//|   Enterprise-grade EA using modular architecture with:           |
//|   - Separated concerns (Volume Profile, Position Management,    |
//|     Order Execution, Risk Management)                           |
//|   - Broker reconciliation on startup                            |
//|   - Exponential backoff retry logic for order placement         |
//|   - OnTrade() event integration for real-time sync             |
//|   - Comprehensive error handling and recovery                   |
//|   - Full audit trail logging                                    |
//|                                                                  |
//| Core Features:                                                   |
//|   - 400-bin volume distribution (POC, VAH/VAL)                 |
//|   - Setup 1: Gap/Reclaim/Confirmation signals                  |
//|   - Setup 2: LVN/HVN/Pattern/Volume signals                    |
//|   - Setup 3: VWAP Deviation + VP confluence (London/NY)        |
//|   - Daily hard stop (-2%) and profit cap (+5%)                 |
//|   - Multi-timeframe validation (15M direction bias)            |
//|   - Session filtering (grave hour, pre-Tokyo block)            |
//|   - Reversal detection with position flips                     |
//|                                                                  |
//+------------------------------------------------------------------+

#property copyright "VWGTI-Pro v3.5 - Production Grade"
#property link      "https://github.com/sgunamijaya/VWGTI-Pro"
#property version   "3.5"
#property strict

// ==================== INCLUDES ====================

#include "Include/Trade/Trade.mqh"
#include "Include/VolumeProfileEngine.mqh"
#include "Include/VWAPSessionEngine.mqh"
#include "Include/PositionManager.mqh"
#include "Include/OrderExecutor.mqh"
#include "Include/BacktestLogger.mqh"
#include "Include/PerformanceMetrics.mqh"

// ==================== GLOBAL CONSTANTS ====================

#define EA_MAGIC_NUMBER 99001
#define DAILY_LOSS_LIMIT -2.0
#define DAILY_PROFIT_CAP 5.0
#define HVN_PERCENTILE 1.3
#define LVN_PERCENTILE 0.7
#define FRIDAY_CLOSE_HOUR 21
#define FRIDAY_CLOSE_MINUTE 45
#define MIN_RR_RATIO 1.5
#define VWAP_AVG_VOL_BARS 20

// ==================== INPUT PARAMETERS ====================

input int    Lookback_Period      = 150;      // Number of bars for volume profile
input double Risk_Percentage      = 0.6;      // Risk per trade (%)
input group "=== Spread Limits by Asset Class (MT5 Points) ==="
input int    Spread_Forex_Points    = 30;     // FX majors: EURUSD, GBPUSD, USDJPY etc.
input int    Spread_Metals_Points   = 50;     // Metals: XAUUSD, XAGUSD etc.
input int    Spread_Indices_Points  = 100;    // Indices: US30, NAS100, GER40 etc.
input int    Spread_Oil_Points      = 50;     // Oil: XTIUSD, XBRUSD, USOIL, UKOIL etc.
input int    Spread_Crypto_Points   = 200;    // Crypto: BTCUSD, ETHUSD etc.
input string Asset_Class          = "XAUUSD"; // Trading asset
input bool   Enable_Setup1         = true;     // Gap/Reclaim signals
input bool   Enable_Setup2         = true;     // LVN/HVN signals
input bool             Enable_Friday_Close   = true;          // Friday 21:45 close
input bool             Enable_Session_Filter = true;          // Block grave hour/pre-Tokyo
input ENUM_TIMEFRAMES  Bias_Timeframe        = PERIOD_H1;     // Higher TF for direction bias
input group "=== Setup 3: VWAP Deviation Session ==="
input bool   Enable_Setup3             = true;  // VWAP Deviation session trades
input double VWAP_SD_Entry             = 2.0;   // Entry SD band trigger (±N×StdDev)
input double VWAP_SD_Stop              = 3.0;   // Stop loss SD band (±N×StdDev)
input double VWAP_Breakout_Vol_Mult    = 1.5;   // Volume multiple for breakout variant
input double VWAP_Delta_Min            = 0.55;  // Min bar-delta for long absorption
input int    VWAP_VP_Confluence_Bins   = 2;     // VP node within N bins of deviation band
input int    London_Open_Hour          = 7;     // London open GMT hour (default 07:00)
input int    London_Close_Hour         = 9;     // London close GMT hour (default 09:30)
input int    London_Close_Min          = 30;    // London close GMT minute
input int    NY_Open_Hour              = 13;    // New York open GMT hour (default 13:00)
input int    NY_Close_Hour             = 16;    // New York close GMT hour (default 16:00)

// ==================== GLOBAL INSTANCES (SINGLETONS) ====================

VolumeProfileEngine  gVolumeProfile;          // Current timeframe profile
VolumeProfileEngine  gVolumeProfileHTF;       // Higher-TF bias profile (Bias_Timeframe input)
VWAPSessionEngine    gVWAP;                   // Session VWAP + weighted SD bands
PositionManager      gPositionManager;        // Position tracking + broker sync
OrderExecutor        gOrderExecutor;          // Order placement + recovery
CTrade               gTrade;                  // MT5 trade API
BacktestLogger       gLogger;                 // Trade journal (tester + live)

// ==================== GLOBAL STATE ====================

int    g_maxSpreadPoints = 50;               // Set in OnInit based on asset class
bool   g_dailyHardStop = false;
bool   g_dailyProfitCap = false;
datetime g_lastDailyReset = 0;
double g_priorPOC = 0;                        // Prior session's POC — acts as TP magnet until revisited

// ==================== STRUCTURES ====================

struct Setup1Signal {
    bool   isTriggered;
    bool   isLong;
    double confirmationClose;
    double sweepExtreme;
};

struct Setup2Signal {
    bool   isTriggered;
    bool   isLong;
    double hvnEdgePrice;
    double sweepExtreme;
};

struct Setup3Signal {
    bool   isTriggered;
    bool   isLong;
    bool   isMeanReversion;   // false = breakout variant
    double deviationBand;     // The ±N×SD band that triggered
    double vpConfluencePrice; // Nearest VP node used for confluence check
    double sweepExtreme;      // bar[1] low (long) or high (short) for SL anchor
};

struct CandlePattern {
    enum Type { NONE = 0, HAMMER = 1, SHOOTING_STAR = 2, DOJI = 3 };
    Type patternType;
    bool isValid;
};

// ==================== UTILITY FUNCTIONS ====================

//+------------------------------------------------------------------+
//| Detect asset class and return appropriate spread limit
//+------------------------------------------------------------------+
int DetectMaxSpreadPoints() {
    string sym = Symbol();
    int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

    if (StringFind(sym, "XAU") >= 0 || StringFind(sym, "XAG") >= 0 ||
        StringFind(sym, "XPT") >= 0 || StringFind(sym, "XPD") >= 0)
        return Spread_Metals_Points;

    if (StringFind(sym, "XTI") >= 0 || StringFind(sym, "XBR") >= 0 ||
        StringFind(sym, "OIL") >= 0 || StringFind(sym, "WTI") >= 0 ||
        StringFind(sym, "BRENT") >= 0 || StringFind(sym, "CRUDE") >= 0)
        return Spread_Oil_Points;

    if (StringFind(sym, "BTC") >= 0 || StringFind(sym, "ETH") >= 0 ||
        StringFind(sym, "LTC") >= 0 || StringFind(sym, "XRP") >= 0)
        return Spread_Crypto_Points;

    if (digits <= 2)   // Indices: US30=0dp, GER40=1dp, NAS100=2dp
        return Spread_Indices_Points;

    return Spread_Forex_Points;   // FX majors/minors: 4 or 5 digit
}

//+------------------------------------------------------------------+
//| Check broker connection
//+------------------------------------------------------------------+
bool IsConnected() {
    if (!TerminalInfoInteger(TERMINAL_CONNECTED)) {
        Print("[ERROR] Terminal not connected");
        return false;
    }
    
    double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
    
    if (tickValue <= 0 || tickSize <= 0) {
        Print("[ERROR] Invalid broker data for ", Symbol());
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Detect new bar
//+------------------------------------------------------------------+
bool NewBar() {
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(Symbol(), PERIOD_CURRENT, 0);
    
    if (currentBarTime != lastBarTime) {
        lastBarTime = currentBarTime;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get session boundary (midnight broker time)
//+------------------------------------------------------------------+
datetime GetSessionBoundary() {
    MqlDateTime timeStruct;
    TimeToStruct(TimeCurrent(), timeStruct);
    
    timeStruct.hour = 0;
    timeStruct.min = 0;
    timeStruct.sec = 0;
    
    return StructToTime(timeStruct);
}

//+------------------------------------------------------------------+
//| Calculate account P&L from today's trades.
//| HistorySelect is O(n) over broker history — cache the closed-trade
//| component per-bar so it is not re-scanned on every tick.
//| Open P&L is always live (no broker round-trip, just a loop).
//+------------------------------------------------------------------+
double GetDailyPnL() {
    static datetime s_lastBarTime  = 0;
    static double   s_cachedClosed = 0;

    datetime currentBarTime = iTime(Symbol(), PERIOD_CURRENT, 0);
    if (currentBarTime != s_lastBarTime) {
        double closedPnL = 0;
        datetime sessionStart = GetSessionBoundary();
        if (HistorySelect(sessionStart, TimeCurrent())) {
            for (int i = 0; i < HistoryDealsTotal(); i++) {
                ulong ticket = HistoryDealGetTicket(i);
                if (HistoryDealGetInteger(ticket, DEAL_MAGIC) == EA_MAGIC_NUMBER) {
                    closedPnL += HistoryDealGetDouble(ticket, DEAL_PROFIT);
                }
            }
        }
        s_cachedClosed  = closedPnL;
        s_lastBarTime   = currentBarTime;
    }

    return s_cachedClosed + gPositionManager.GetOpenPnL();
}

//+------------------------------------------------------------------+
//| Check if trading is allowed (session filter)
//+------------------------------------------------------------------+
bool IsSessionAllowed() {
    if (!Enable_Session_Filter) return true;
    
    MqlDateTime timeStruct;
    TimeToStruct(TimeCurrent(), timeStruct);
    
    // Block grave hour (NY 16:00-17:00)
    if (timeStruct.hour == 16) return false;
    
    // Block pre-Tokyo (Sun 23:00, Mon 00:00)
    bool isPreTokyoSunday = (timeStruct.day_of_week == 0 && timeStruct.hour == 23);
    bool isPreTokyoMonday = (timeStruct.day_of_week == 1 && timeStruct.hour == 0);
    
    if (isPreTokyoSunday || isPreTokyoMonday) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Returns true when current time is inside the London or NY session|
//| windows where VWAP Deviation setups are highest probability.    |
//| Uses broker server time directly (same as TimeCurrent()).        |
//+------------------------------------------------------------------+
bool IsVWAPSessionWindow() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    int nowMin = dt.hour * 60 + dt.min;

    bool inLondon = (nowMin >= London_Open_Hour * 60) &&
                    (nowMin <  London_Close_Hour * 60 + London_Close_Min);
    bool inNY     = (nowMin >= NY_Open_Hour * 60) &&
                    (nowMin <  NY_Close_Hour * 60);

    return (inLondon || inNY);
}

//+------------------------------------------------------------------+
//| Rolling average tick-volume over VWAP_AVG_VOL_BARS bars.        |
//+------------------------------------------------------------------+
double GetSessionAvgVolume() {
    double total = 0;
    for (int i = 1; i <= VWAP_AVG_VOL_BARS; i++)
        total += (double)iTickVolume(Symbol(), PERIOD_CURRENT, i);
    return total / VWAP_AVG_VOL_BARS;
}

//+------------------------------------------------------------------+
//| Check Friday hard close (21:45)
//+------------------------------------------------------------------+
bool CheckFridayHardClose() {
    if (!Enable_Friday_Close) return false;
    
    MqlDateTime timeStruct;
    TimeToStruct(TimeCurrent(), timeStruct);
    
    bool isFriday = (timeStruct.day_of_week == 5);
    int currentTimeMinutes = timeStruct.hour * 60 + timeStruct.min;
    int closeTimeMinutes = FRIDAY_CLOSE_HOUR * 60 + FRIDAY_CLOSE_MINUTE;
    
    if (isFriday && currentTimeMinutes >= closeTimeMinutes) {
        if (gPositionManager.GetPositionCount() > 0) {
            Print("[WARNING] Friday ", timeStruct.hour, ":", timeStruct.min,
                  " - Closing all positions");
            for (int i = gPositionManager.GetPositionCount() - 1; i >= 0; i--) {
                long t=0; string sym=""; bool lng=false;
                double en=0,sl=0,tp=0,lots=0; string stp="";
                if (gPositionManager.GetPosition(i,t,sym,lng,en,sl,tp,lots,stp))
                    gLogger.LogExit(t, lng ? SymbolInfoDouble(sym,SYMBOL_BID)
                                           : SymbolInfoDouble(sym,SYMBOL_ASK), "FRIDAY");
            }
            gPositionManager.CloseAll();
        }
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check daily risk limits
//+------------------------------------------------------------------+
bool EnforceDailyLimits() {
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double dailyPnL = GetDailyPnL();
    
    double hardStopThreshold = accountBalance * (DAILY_LOSS_LIMIT / 100.0);
    double profitCapThreshold = accountBalance * (DAILY_PROFIT_CAP / 100.0);
    
    // Hard stop (-2%)
    if (dailyPnL < hardStopThreshold) {
        if (!g_dailyHardStop) {
            Print("[ALERT] Hard stop hit! Daily P&L=", dailyPnL, " Limit=", hardStopThreshold);
            g_dailyHardStop = true;
            for (int i = gPositionManager.GetPositionCount() - 1; i >= 0; i--) {
                long t=0; string sym=""; bool lng=false;
                double en=0,sl=0,tp=0,lots=0; string stp="";
                if (gPositionManager.GetPosition(i,t,sym,lng,en,sl,tp,lots,stp))
                    gLogger.LogExit(t, lng ? SymbolInfoDouble(sym,SYMBOL_BID)
                                           : SymbolInfoDouble(sym,SYMBOL_ASK), "HARD_STOP");
            }
            gPositionManager.CloseAll();
        }
        return false;
    }
    
    // Profit cap (+5%)
    if (dailyPnL > profitCapThreshold) {
        if (!g_dailyProfitCap) {
            Print("[ALERT] Profit cap reached! Daily P&L=", dailyPnL, " Cap=", profitCapThreshold);
            g_dailyProfitCap = true;
            
            // Close 60% of positions — iterate backward so array shrink doesn't skip entries
            int posCount   = gPositionManager.GetPositionCount();
            int closeCount = (int)MathCeil(posCount * 0.6);
            int closed     = 0;

            for (int i = posCount - 1; i >= 0 && closed < closeCount; i--) {
                long   ticket = 0;
                string symbol = "";
                bool   isLong = false;
                double entry = 0, sl = 0, tp = 0, lots = 0;
                string setup  = "";

                if (gPositionManager.GetPosition(i, ticket, symbol, isLong, entry, sl, tp, lots, setup)) {
                    gLogger.LogExit(ticket, isLong ? SymbolInfoDouble(symbol, SYMBOL_BID)
                                                   : SymbolInfoDouble(symbol, SYMBOL_ASK), "PROFIT_CAP");
                    if (gTrade.PositionClose((ulong)ticket)) {
                        gPositionManager.ClosePosition(ticket, lots);
                        closed++;
                    }
                }
            }
        }
        return false;
    }
    
    // Reset flags at midnight broker boundary; snapshot POC as prior-session reference
    datetime todayMidnight = GetSessionBoundary();
    if (g_lastDailyReset < todayMidnight) {
        g_priorPOC       = gVolumeProfile.IsValid() ? gVolumeProfile.GetPOC() : 0;
        g_dailyHardStop  = false;
        g_dailyProfitCap = false;
        g_lastDailyReset = todayMidnight;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Validate liquidity (spread + volume)
//+------------------------------------------------------------------+
bool ValidateLiquidity() {
    long spreadPoints = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);

    if (spreadPoints > g_maxSpreadPoints) {
        Print("[WARNING] Spread too wide: ", spreadPoints, " pts (max ", g_maxSpreadPoints, ")");
        return false;
    }
    
    long barVolume = iTickVolume(Symbol(), PERIOD_CURRENT, 1);
    if (barVolume < 100) {
        Print("[WARNING] Bar volume too low: ", barVolume, " (prev completed bar)");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Detect candle pattern (Hammer/Shooting Star/Doji)
//+------------------------------------------------------------------+
CandlePattern DetectCandlePattern() {
    CandlePattern result = {CandlePattern::NONE, false};
    
    double open = iOpen(Symbol(), PERIOD_CURRENT, 1);
    double high = iHigh(Symbol(), PERIOD_CURRENT, 1);
    double low = iLow(Symbol(), PERIOD_CURRENT, 1);
    double close = iClose(Symbol(), PERIOD_CURRENT, 1);
    
    double bodySize = MathAbs(close - open);
    double lowerWick = open < close ? open - low : close - low;
    double upperWick = close > open ? high - close : high - open;

    // Zero-body candle: only DOJI applies — 2x bodySize == 0 would falsely match HAMMER/SS
    if (bodySize <= _Point) {
        if (lowerWick > 0 && upperWick > 0) {
            result.patternType = CandlePattern::DOJI;
            result.isValid = true;
        }
        return result;
    }

    // Hammer: lower wick > 2x body, upper wick < 0.1x body
    if (lowerWick > 2.0 * bodySize && upperWick < 0.1 * bodySize && close > (open + bodySize * 0.5)) {
        result.patternType = CandlePattern::HAMMER;
        result.isValid = true;
    }
    // Shooting Star: upper wick > 2x body, lower wick < 0.1x body
    else if (upperWick > 2.0 * bodySize && lowerWick < 0.1 * bodySize && close < (open - bodySize * 0.5)) {
        result.patternType = CandlePattern::SHOOTING_STAR;
        result.isValid = true;
    }
    // Doji: open ≈ close (within 3 points), wicks both sides
    else if (bodySize <= 3 * _Point && lowerWick > 0 && upperWick > 0) {
        result.patternType = CandlePattern::DOJI;
        result.isValid = true;
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Setup 1: Gap/Reclaim/Confirmation
//+------------------------------------------------------------------+
Setup1Signal DetectSetup1Signal() {
    Setup1Signal result = {false, false, 0, 0};
    
    if (!Enable_Setup1) return result;
    
    double openPrice  = iOpen (Symbol(), PERIOD_CURRENT, 1);
    double closePrice = iClose(Symbol(), PERIOD_CURRENT, 1);
    double lowPrice   = iLow  (Symbol(), PERIOD_CURRENT, 1);
    double highPrice  = iHigh (Symbol(), PERIOD_CURRENT, 1);

    double previousVAH = gVolumeProfile.GetVAH();
    double previousVAL = gVolumeProfile.GetVAL();

    // Gap detection
    bool gappedAbove = (openPrice > previousVAH);
    bool gappedBelow = (openPrice < previousVAL);

    if (!gappedAbove && !gappedBelow) return result;

    // Reclaim detection
    bool reclaimingUp   = (gappedBelow && closePrice >= previousVAL);
    bool reclaimingDown = (gappedAbove && closePrice <= previousVAH);

    if (!reclaimingUp && !reclaimingDown) return result;

    // REQ-014: close FULLY inside VA — strict inequality excludes boundary touches
    bool closeInsideVA = (closePrice > previousVAL && closePrice < previousVAH);

    if (!closeInsideVA) return result;

    // 80% rule: require bar[2] to have also opened outside VA and closed inside VA.
    // Two consecutive closes inside the VA raises probability to ~80% of filling it.
    double open2    = iOpen (Symbol(), PERIOD_CURRENT, 2);
    double close2   = iClose(Symbol(), PERIOD_CURRENT, 2);
    double bar2Low  = iLow  (Symbol(), PERIOD_CURRENT, 2);
    double bar2High = iHigh (Symbol(), PERIOD_CURRENT, 2);

    bool bar2GappedSameWay  = reclaimingUp ? (open2 < previousVAL) : (open2 > previousVAH);
    bool bar2ClosedInsideVA = (close2 > previousVAL && close2 < previousVAH);

    if (!bar2GappedSameWay || !bar2ClosedInsideVA) return result;

    result.isTriggered       = true;
    result.isLong            = reclaimingUp;
    result.confirmationClose = closePrice;
    // SL anchor: most extreme point across the full 2-bar setup
    result.sweepExtreme = reclaimingUp
        ? MathMin(lowPrice, bar2Low)
        : MathMax(highPrice, bar2High);

    return result;
}

//+------------------------------------------------------------------+
//| Setup 2: LVN/HVN/Pattern/Volume
//+------------------------------------------------------------------+
Setup2Signal DetectSetup2Signal() {
    Setup2Signal result = {false, false, 0, 0};

    if (!Enable_Setup2) return result;

    double currentLow  = iLow (Symbol(), PERIOD_CURRENT, 1);
    double currentHigh = iHigh(Symbol(), PERIOD_CURRENT, 1);

    // Pattern first — determines direction; Doji is ambiguous so skip it
    CandlePattern pattern = DetectCandlePattern();
    if (!pattern.isValid || pattern.patternType == CandlePattern::DOJI) return result;

    bool isLong = (pattern.patternType == CandlePattern::HAMMER);

    // LVN sweep: the bar must have physically passed through an LVN — the node
    // must lie within the bar's high-low range so a distant LVN cannot trigger.
    bool lvnSwept = false;
    if (isLong) {
        // Downward sweep (hammer): LVN must be inside the bar's range
        for (int i = 0; i < gVolumeProfile.GetLVNCount(); i++) {
            double p = gVolumeProfile.GetLVNPrice(i);
            if (p >= currentLow && p <= currentHigh) { lvnSwept = true; break; }
        }
    } else {
        // Upward sweep (shooting star): LVN must be inside the bar's range
        for (int i = 0; i < gVolumeProfile.GetLVNCount(); i++) {
            double p = gVolumeProfile.GetLVNPrice(i);
            if (p >= currentLow && p <= currentHigh) { lvnSwept = true; break; }
        }
    }
    if (!lvnSwept) return result;

    // HVN edge: nearest HVN on the reversal side
    double hvnEdge;
    if (isLong) {
        // Nearest HVN above current low — support to buy at
        hvnEdge = DBL_MAX;
        for (int i = 0; i < gVolumeProfile.GetHVNCount(); i++) {
            double p = gVolumeProfile.GetHVNPrice(i);
            if (p > currentLow && p < hvnEdge) hvnEdge = p;
        }
        if (hvnEdge == DBL_MAX) return result;
    } else {
        // Nearest HVN below current high — resistance to sell at
        hvnEdge = -DBL_MAX;
        for (int i = 0; i < gVolumeProfile.GetHVNCount(); i++) {
            double p = gVolumeProfile.GetHVNPrice(i);
            if (p < currentHigh && p > hvnEdge) hvnEdge = p;
        }
        if (hvnEdge == -DBL_MAX) return result;
    }

    // Volume spike (≥ 1.3x previous bar)
    long currentVolume  = iTickVolume(Symbol(), PERIOD_CURRENT, 1);
    long previousVolume = iTickVolume(Symbol(), PERIOD_CURRENT, 2);
    if (previousVolume <= 0 || currentVolume < previousVolume * 1.3) return result;

    result.isTriggered  = true;
    result.isLong       = isLong;
    result.hvnEdgePrice = hvnEdge;
    result.sweepExtreme = isLong ? currentLow : currentHigh;

    return result;
}

//+------------------------------------------------------------------+
//| Setup 3: VWAP Deviation + Volume Profile confluence              |
//|                                                                  |
//| Mean-reversion long : close[1] < VWAP−N×SD, barDelta absorbing, |
//|                       VP node (VAL/POC/LVN) within confluence    |
//| Mean-reversion short: close[1] > VWAP+N×SD, barDelta selling,   |
//|                       VP node (VAH/POC/HVN) within confluence    |
//| Breakout long       : close[1] > VWAP+N×SD with vol spike       |
//| Breakout short      : close[1] < VWAP−N×SD with vol spike       |
//+------------------------------------------------------------------+
Setup3Signal DetectSetup3Signal() {
    Setup3Signal result;
    result.isTriggered       = false;
    result.isLong            = false;
    result.isMeanReversion   = true;
    result.deviationBand     = 0;
    result.vpConfluencePrice = 0;
    result.sweepExtreme      = 0;

    if (!Enable_Setup3)              return result;
    if (!gVWAP.IsValid())            return result;
    if (gVWAP.wStdDev <= 0)          return result;
    if (!gVolumeProfile.IsValid())   return result;

    double close1 = iClose     (Symbol(), PERIOD_CURRENT, 1);
    double high1  = iHigh      (Symbol(), PERIOD_CURRENT, 1);
    double low1   = iLow       (Symbol(), PERIOD_CURRENT, 1);
    long   vol1   = iTickVolume(Symbol(), PERIOD_CURRENT, 1);

    double entryBandLow  = gVWAP.GetLowerBand(VWAP_SD_Entry);
    double entryBandHigh = gVWAP.GetUpperBand(VWAP_SD_Entry);
    double delta1        = VWAPSessionEngine::BarDelta(high1, low1, close1);
    double avgVol        = GetSessionAvgVolume();
    double binSz         = gVolumeProfile.GetBinSize();
    if (binSz <= 0) return result;
    double vpWindow      = binSz * VWAP_VP_Confluence_Bins;

    // VP confluence helpers: nearest node to a reference price
    double poc = gVolumeProfile.GetPOC();
    double val = gVolumeProfile.GetVAL();
    double vah = gVolumeProfile.GetVAH();

    // ---- Mean-Reversion LONG (price below lower entry band) ----
    if (close1 < entryBandLow && delta1 >= VWAP_Delta_Min) {
        // Track the actual matching node so vpConfluencePrice in the signal
        // reflects which VP level provided the confluence (VAL, POC, or LVN).
        double vpMatch = 0;
        if      (MathAbs(entryBandLow - val) <= vpWindow) vpMatch = val;
        else if (MathAbs(entryBandLow - poc) <= vpWindow) vpMatch = poc;
        else {
            for (int i = 0; i < gVolumeProfile.GetLVNCount(); i++) {
                if (MathAbs(entryBandLow - gVolumeProfile.GetLVNPrice(i)) <= vpWindow) {
                    vpMatch = gVolumeProfile.GetLVNPrice(i);
                    break;
                }
            }
        }
        if (vpMatch > 0) {
            result.isTriggered       = true;
            result.isLong            = true;
            result.isMeanReversion   = true;
            result.deviationBand     = entryBandLow;
            result.vpConfluencePrice = vpMatch;
            result.sweepExtreme      = low1;
            return result;
        }
    }

    // ---- Mean-Reversion SHORT (price above upper entry band) ----
    if (close1 > entryBandHigh && delta1 <= (1.0 - VWAP_Delta_Min)) {
        double vpMatch = 0;
        if      (MathAbs(entryBandHigh - vah) <= vpWindow) vpMatch = vah;
        else if (MathAbs(entryBandHigh - poc) <= vpWindow) vpMatch = poc;
        else {
            for (int i = 0; i < gVolumeProfile.GetHVNCount(); i++) {
                if (MathAbs(entryBandHigh - gVolumeProfile.GetHVNPrice(i)) <= vpWindow) {
                    vpMatch = gVolumeProfile.GetHVNPrice(i);
                    break;
                }
            }
        }
        if (vpMatch > 0) {
            result.isTriggered       = true;
            result.isLong            = false;
            result.isMeanReversion   = true;
            result.deviationBand     = entryBandHigh;
            result.vpConfluencePrice = vpMatch;
            result.sweepExtreme      = high1;
            return result;
        }
    }

    // ---- Breakout LONG (close above upper band + bullish delta + volume surge) ----
    // Delta filter ensures momentum is directionally confirmed: a distribution bar (high
    // volume, bearish close) at the upper band is a fade candidate, not a breakout.
    if (close1 > entryBandHigh && delta1 >= VWAP_Delta_Min &&
        avgVol > 0 && (double)vol1 >= avgVol * VWAP_Breakout_Vol_Mult) {
        result.isTriggered       = true;
        result.isLong            = true;
        result.isMeanReversion   = false;
        result.deviationBand     = entryBandHigh;
        result.vpConfluencePrice = 0;
        result.sweepExtreme      = low1;
        return result;
    }

    // ---- Breakout SHORT (close below lower band + bearish delta + volume surge) ----
    if (close1 < entryBandLow && delta1 <= (1.0 - VWAP_Delta_Min) &&
        avgVol > 0 && (double)vol1 >= avgVol * VWAP_Breakout_Vol_Mult) {
        result.isTriggered       = true;
        result.isLong            = false;
        result.isMeanReversion   = false;
        result.deviationBand     = entryBandLow;
        result.vpConfluencePrice = 0;
        result.sweepExtreme      = high1;
        return result;
    }

    return result;
}

//+------------------------------------------------------------------+
//| Derive SL and TP for a confirmed Setup 3 signal.                 |
//| SL = tighter of (sweep extreme ± binSize) vs stop SD band.      |
//| TP = VWAP for mean-reversion; stop SD band for breakout.        |
//+------------------------------------------------------------------+
void CalculateSetup3SLTP(const Setup3Signal &sig, double &sl, double &tp) {
    double binSz   = gVolumeProfile.GetBinSize();
    double stopLow = gVWAP.GetLowerBand(VWAP_SD_Stop);
    double stopHi  = gVWAP.GetUpperBand(VWAP_SD_Stop);

    if (sig.isLong) {
        double slExtreme = sig.sweepExtreme - binSz;
        sl = MathMax(slExtreme, stopLow);   // tightest = highest value below entry
        tp = sig.isMeanReversion ? gVWAP.vwap : stopHi;
    } else {
        double slExtreme = sig.sweepExtreme + binSz;
        sl = MathMin(slExtreme, stopHi);    // tightest = lowest value above entry
        tp = sig.isMeanReversion ? gVWAP.vwap : stopLow;
    }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk
//+------------------------------------------------------------------+
double CalculateLotSize(double entryPrice, double stopLossPrice) {
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * (Risk_Percentage / 100.0);
    
    double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
    double slDistanceTicks = MathAbs(entryPrice - stopLossPrice) / tickSize;
    
    if (slDistanceTicks <= 0) return 0;
    
    double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    if (tickValue <= 0) return 0;
    
    double lotSize = riskAmount / (slDistanceTicks * tickValue);
    
    double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
    
    if (lotSize < minLot) return 0;
    if (lotSize > maxLot) lotSize = maxLot;

    lotSize = MathFloor(lotSize / lotStep) * lotStep;

    // Floor can push a marginal lot below minLot when lotStep > minLot
    if (lotSize < minLot) return 0;

    return lotSize;
}

//+------------------------------------------------------------------+
//| Calculate Risk/Reward ratio
//+------------------------------------------------------------------+
double CalculateRiskRewardRatio(double entryPrice, double stopLossPrice, double takeProfitPrice) {
    double riskPips = MathAbs(entryPrice - stopLossPrice) / _Point;
    double rewardPips = MathAbs(takeProfitPrice - entryPrice) / _Point;
    
    if (riskPips <= 0) return 0;
    
    return rewardPips / riskPips;
}

//+------------------------------------------------------------------+
//| Find the nearest HVN above (isLong) or below (!isLong) a reference
//| price. Falls back to VAH/VAL when no qualifying HVN exists.
//+------------------------------------------------------------------+
double FindNearestHVN(bool isLong, double referencePrice) {
    double best = isLong ? DBL_MAX : -DBL_MAX;
    for (int i = 0; i < gVolumeProfile.GetHVNCount(); i++) {
        double p = gVolumeProfile.GetHVNPrice(i);
        if (isLong  && p > referencePrice && p < best) best = p;
        if (!isLong && p < referencePrice && p > best) best = p;
    }
    if (isLong  && best == DBL_MAX)  return gVolumeProfile.GetVAH();
    if (!isLong && best == -DBL_MAX) return gVolumeProfile.GetVAL();
    return best;
}

//+------------------------------------------------------------------+
//| Common entry execution path shared by Setup1 and Setup2.
//| Validates HTF bias, sizes the position, checks R:R, places the
//| order, and registers everything in one place.
//+------------------------------------------------------------------+
// isMeanReversion: passed through to ValidateHTFBias so MR signals bypass the
//                  trend-following POC gate (the 2SD band is the directional signal).
void TryExecuteEntry(bool isLong, double entryPrice, double stopLoss,
                     double takeProfit, string setupTag, bool balanced,
                     bool isMeanReversion = false) {
    // FIX: use current bid/ask as the fill proxy — all pre-execution checks are
    // based on where the order will actually fill, not the prior bar's close.
    double fillProxy = isLong ? SymbolInfoDouble(Symbol(), SYMBOL_BID)
                              : SymbolInfoDouble(Symbol(), SYMBOL_ASK);

    // Prior-session POC cap: evaluated against fill proxy so the path check reflects
    // the actual fill price rather than the potentially stale signal-bar close.
    if (g_priorPOC > 0) {
        bool pocInPath = isLong
            ? (g_priorPOC > fillProxy && g_priorPOC < takeProfit)
            : (g_priorPOC < fillProxy && g_priorPOC > takeProfit);
        if (pocInPath) takeProfit = g_priorPOC;
    }

    if (!ValidateHTFBias(isLong, isMeanReversion)) {
        Print("[FILTER] ", setupTag, " rejected — HTF bias opposes entry direction");
        return;
    }

    double lotSize = CalculateLotSize(entryPrice, stopLoss);
    if (lotSize <= 0) return;

    // FIX: R:R gate evaluated at fill proxy, not signal-bar close.
    // On volatile instruments the bar open can gap 10-20 pts from the prior close,
    // making a geometrically sound signal into an inverted trade at execution time.
    double rr = CalculateRiskRewardRatio(fillProxy, stopLoss, takeProfit);
    if (rr < MIN_RR_RATIO) {
        Print("[FILTER] ", setupTag, " R:R=", DoubleToString(rr, 2),
              " (at fill price) below minimum ", MIN_RR_RATIO, ":1");
        return;
    }

    // FIX: Minimum TP distance from fill proxy — prevents near-zero reward trades
    // that survive the R:R ratio check only because a POC cap collapsed the TP.
    double minTPDist = gVolumeProfile.GetBinSize() * 3.0;
    if (MathAbs(takeProfit - fillProxy) < minTPDist) {
        Print("[FILTER] ", setupTag, " TP too close to fill after POC cap (",
              DoubleToString(MathAbs(takeProfit - fillProxy), _Digits),
              " < min ", DoubleToString(minTPDist, _Digits), ")");
        return;
    }

    OrderExecutor::ExecutionRecord result = gOrderExecutor.PlaceOrder(
        isLong, lotSize, entryPrice, stopLoss, takeProfit, EA_MAGIC_NUMBER);

    if (result.status != OrderExecutor::STATUS_FILLED) return;

    gPositionManager.RegisterFill(result.ticket, isLong, result.fillPrice,
                                  stopLoss, takeProfit, lotSize, setupTag);
    gLogger.LogEntry(result.ticket, setupTag, isLong, result.fillPrice,
                     stopLoss, takeProfit, lotSize,
                     gVolumeProfile.GetPOC(), gVolumeProfile.GetVAH(), gVolumeProfile.GetVAL(),
                     gVolumeProfileHTF.IsValid() ? gVolumeProfileHTF.GetPOC() : 0, balanced);
    Print("[ENTRY] ", setupTag, " LONG=", isLong, " Entry=", result.fillPrice,
          " RR=", DoubleToString(rr, 2), ":1 (fill-proxy)");
}

//+------------------------------------------------------------------+
//| Monitor position exits (TP/SL) — iterate backwards so ClosePosition
//| array-shrink does not skip or double-visit entries
//+------------------------------------------------------------------+
void MonitorPositionExits() {
    for (int i = gPositionManager.GetPositionCount() - 1; i >= 0; i--) {
        long ticket = 0;
        string symbol = "";
        bool isLong = false;
        double entry = 0, sl = 0, tp = 0, lots = 0;
        string setup = "";

        if (!gPositionManager.GetPosition(i, ticket, symbol, isLong, entry, sl, tp, lots, setup)) {
            continue;
        }

        double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

        // TP check — guard tp > 0 prevents false trigger on orphaned positions with no TP set
        if (tp > 0 && ((isLong && bid >= tp) || (!isLong && ask <= tp))) {
            double exitPrice = isLong ? bid : ask;
            Print("[TP_HIT] Ticket=", ticket, " Setup=", setup);
            gLogger.LogExit(ticket, exitPrice, "TP");
            if (gTrade.PositionClose((ulong)ticket)) {
                gPositionManager.ClosePosition(ticket, lots);
            } else {
                Print("[WARNING] TP close failed for Ticket=", ticket,
                      "; broker retcode=", gTrade.ResultRetcode(),
                      " — position remains tracked");
            }
            continue;
        }

        // SL check — guard sl > 0 prevents false trigger on orphaned positions with no SL set
        if (sl > 0 && ((isLong && bid <= sl) || (!isLong && ask >= sl))) {
            double exitPrice = isLong ? bid : ask;
            Print("[SL_HIT] Ticket=", ticket, " Setup=", setup);
            gLogger.LogExit(ticket, exitPrice, "SL");
            if (gTrade.PositionClose((ulong)ticket)) {
                gPositionManager.ClosePosition(ticket, lots);
            } else {
                Print("[WARNING] SL close failed for Ticket=", ticket,
                      "; broker retcode=", gTrade.ResultRetcode(),
                      " — position remains tracked");
            }
            continue;
        }
    }
}

//+------------------------------------------------------------------+
//| Validate higher-TF direction bias before entry
//| LONG : bid must be above HTF POC  (price accepted above fair value)
//| SHORT: ask must be below HTF POC  (price accepted below fair value)
//| Falls back to true if HTF profile not yet computed.
//+------------------------------------------------------------------+
// isMeanReversion=true  → price is extended against the HTF trend; the 2SD band is
//                          the directional signal, so skip the trend-following POC gate.
// isMeanReversion=false → breakout / structure trade; require price on the correct side
//                          of the HTF POC before entering.
bool ValidateHTFBias(bool isLongEntry, bool isMeanReversion = false) {
    if (!gVolumeProfileHTF.IsValid()) return true;
    if (isMeanReversion)              return true;

    double poc = gVolumeProfileHTF.GetPOC();

    return isLongEntry
        ? (SymbolInfoDouble(Symbol(), SYMBOL_BID) > poc)
        : (SymbolInfoDouble(Symbol(), SYMBOL_ASK) < poc);
}

// ==================== EVENT HANDLERS ====================

//+------------------------------------------------------------------+
//| Expert initialization
//+------------------------------------------------------------------+
int OnInit() {
    Print("========== VWGTI-Pro v3.5 - Production Grade ==========");
    Print("EA Magic: ", EA_MAGIC_NUMBER);
    Print("Symbol: ", Symbol(), " Asset: ", Asset_Class);
    
    // Validate connection
    if (!IsConnected()) {
        Print("[ERROR] Broker not connected");
        return INIT_FAILED;
    }
    
    // Initialize CTrade
    gTrade.SetExpertMagicNumber(EA_MAGIC_NUMBER);
    g_maxSpreadPoints = DetectMaxSpreadPoints();
    gOrderExecutor.SetMaxSpreadPoints(g_maxSpreadPoints);
    Print("Asset class spread limit: ", g_maxSpreadPoints, " pts");
    
    // Anchor daily reset to today's midnight so first-tick check doesn't spuriously reset
    g_lastDailyReset = GetSessionBoundary();

    // Initialize trade journal
    gLogger.Init(Symbol());

    // Wire the configurable higher-TF bias profile
    gVolumeProfileHTF.SetTimeframe(Bias_Timeframe);
    Print("HTF bias timeframe: ", EnumToString(Bias_Timeframe));

    // Initialize PositionManager (broker reconciliation)
    if (!gPositionManager.Initialize()) {
        Print("[ERROR] Failed to initialize PositionManager");
        return INIT_FAILED;
    }

    // Bootstrap session VWAP from today's bars so state is correct after EA reload
    if (Enable_Setup3) {
        gVWAP.RecalculateFromSessionStart();
        Print("[VWAP] Session window — London: ", London_Open_Hour, ":00–",
              London_Close_Hour, ":", London_Close_Min < 10 ? "0" : "", London_Close_Min,
              " | NY: ", NY_Open_Hour, ":00–", NY_Close_Hour, ":00 GMT");
    }

    Print("[SUCCESS] EA initialized");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert tick function
//+------------------------------------------------------------------+
void OnTick() {
    // Connection check
    if (!IsConnected()) {
        Print("[ERROR] Broker disconnected");
        return;
    }
    
    // Broker reconciliation every 5 minutes (time-gated to prevent log spam on fast symbols)
    static datetime lastReconcileTime = 0;
    if (TimeCurrent() - lastReconcileTime >= 300) {
        gPositionManager.Reconcile();
        lastReconcileTime = TimeCurrent();
    }
    
    // Update heartbeat comment
    static int commentCounter = 0;
    if (++commentCounter % 30 == 0) {
        string status = (IsSessionAllowed() ? "ALLOWED" : "BLOCKED");
        string pnl = DoubleToString(GetDailyPnL(), 2);
        Comment(StringFormat("VWGTI-Pro v3.5 | %s | Positions: %d | Daily P&L: %s | Session: %s",
                            TimeToString(TimeCurrent()),
                            gPositionManager.GetPositionCount(),
                            pnl,
                            status));
    }
    
    // Check daily limits FIRST
    if (!EnforceDailyLimits()) {
        Print("[WARNING] Daily limits hit; trading blocked");
        return;
    }
    
    // Check Friday close
    if (CheckFridayHardClose()) {
        return;
    }
    
    // Monitor open positions (every tick)
    MonitorPositionExits();
    
    // ===== NEW BAR PROCESSING =====
    if (NewBar()) {
        // Feed completed bar[1] into the session VWAP engine (cumulative, no repainting)
        gVWAP.UpdateBar(
            iTime      (Symbol(), PERIOD_CURRENT, 1),
            iHigh      (Symbol(), PERIOD_CURRENT, 1),
            iLow       (Symbol(), PERIOD_CURRENT, 1),
            iClose     (Symbol(), PERIOD_CURRENT, 1),
            iTickVolume(Symbol(), PERIOD_CURRENT, 1)
        );

        // Calculate volume profiles
        if (!gVolumeProfile.Calculate(Lookback_Period)) {
            Print("[ERROR] Failed to calculate volume profile");
            return;
        }

        if (!gVolumeProfile.IdentifyNodes(HVN_PERCENTILE, LVN_PERCENTILE)) {
            Print("[ERROR] Failed to identify volume nodes");
            return;
        }

        // Reload HTF profile whenever a new bar opens on Bias_Timeframe
        static datetime lastHTFTime = 0;
        if (iTime(Symbol(), Bias_Timeframe, 0) != lastHTFTime) {
            gVolumeProfileHTF.Calculate(Lookback_Period);
            gVolumeProfileHTF.IdentifyNodes(HVN_PERCENTILE, LVN_PERCENTILE);
            lastHTFTime = iTime(Symbol(), Bias_Timeframe, 0);
        }

        // Session filter
        if (!IsSessionAllowed()) {
            Print("[WARNING] Session blocked; no entries");
            return;
        }

        // Validate liquidity
        if (!ValidateLiquidity()) {
            Print("[WARNING] Liquidity check failed");
            return;
        }

        // ===== SIGNAL DETECTION =====

        // FIX: one position at a time — prevents concurrent positions from
        // separate setups firing on the same bar (e.g. Setup 1 + Setup 3 both long).
        if (gPositionManager.GetPositionCount() > 0) return;

        // Determine market context
        int highIdx = iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, 20, 0);
        int lowIdx = iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, 20, 0);
        double recentHigh = iHigh(Symbol(), PERIOD_CURRENT, highIdx);
        double recentLow = iLow(Symbol(), PERIOD_CURRENT, lowIdx);
        double recentRange = recentHigh - recentLow;
        double vaWidth = gVolumeProfile.GetVAH() - gVolumeProfile.GetVAL();

        bool balanced = (vaWidth < recentRange * 0.6);

        double slBinBuffer = gVolumeProfile.GetBinSize();

        if (balanced) {
            // SETUP 1: Gap/Reclaim/Confirmation
            Setup1Signal sig1 = DetectSetup1Signal();
            if (sig1.isTriggered) {
                double entryPrice = sig1.confirmationClose;
                double stopLoss   = sig1.isLong ? sig1.sweepExtreme - slBinBuffer
                                                : sig1.sweepExtreme + slBinBuffer;
                double takeProfit = sig1.isLong ? gVolumeProfile.GetVAH() : gVolumeProfile.GetVAL();
                TryExecuteEntry(sig1.isLong, entryPrice, stopLoss, takeProfit, "SETUP1", balanced);
            }
        } else {
            // SETUP 2: LVN/HVN/Pattern/Volume
            Setup2Signal sig2 = DetectSetup2Signal();
            if (sig2.isTriggered) {
                double entryPrice = sig2.hvnEdgePrice;
                double stopLoss   = sig2.isLong ? sig2.sweepExtreme - slBinBuffer
                                                : sig2.sweepExtreme + slBinBuffer;
                // Target nearest HVN beyond entry — more precise than raw VAH/VAL
                double takeProfit = FindNearestHVN(sig2.isLong, entryPrice);
                TryExecuteEntry(sig2.isLong, entryPrice, stopLoss, takeProfit, "SETUP2", balanced);
            }
        }

        // SETUP 3: VWAP Deviation + VP Confluence (London/NY sessions only)
        // Runs regardless of balanced/imbalanced — session-relative, not structure-relative
        if (Enable_Setup3 && gVWAP.IsValid() && IsVWAPSessionWindow()) {
            Setup3Signal sig3 = DetectSetup3Signal();
            if (sig3.isTriggered) {
                // Market order entry at the open of the new bar
                double entryPrice = iOpen(Symbol(), PERIOD_CURRENT, 0);
                double stopLoss, takeProfit;
                CalculateSetup3SLTP(sig3, stopLoss, takeProfit);
                string tag = sig3.isMeanReversion
                    ? (sig3.isLong ? "S3-MR-L" : "S3-MR-S")
                    : (sig3.isLong ? "S3-BO-L" : "S3-BO-S");
                Print("[S3] Signal: ", tag,
                      " Band=", DoubleToString(sig3.deviationBand, _Digits),
                      " VP=",   DoubleToString(sig3.vpConfluencePrice, _Digits),
                      " VWAP=", DoubleToString(gVWAP.vwap, _Digits),
                      " SD=",   DoubleToString(gVWAP.wStdDev, _Digits));
                // FIX: pass isMeanReversion so HTF bias is skipped for MR signals —
                // MR shorts were blocked in the prior bull-trend run because the HTF POC
                // gate required ASK < POC, which is never true in an uptrend.
                TryExecuteEntry(sig3.isLong, entryPrice, stopLoss, takeProfit, tag, false,
                                sig3.isMeanReversion);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| OnTrade event (real-time position sync)
//+------------------------------------------------------------------+
void OnTrade() {
    gPositionManager.OnTrade();
}

//+------------------------------------------------------------------+
//| Expert deinitialization
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("[DEINIT] EA shutting down. Reason: ", reason);
    Print("[FINAL] Positions: ", gPositionManager.GetPositionCount(),
          " Daily P&L: ", GetDailyPnL());

    // Mark any positions still open at shutdown (e.g. tester end)
    gLogger.LogOpenAsDeInit();

    // Print console summary and persist journal CSV
    if (gLogger.GetTradeCount() > 0) {
        TradeRecord records[];
        int count = gLogger.GetTradeCount();
        ArrayResize(records, count);
        for (int i = 0; i < count; i++) gLogger.GetRecord(i, records[i]);

        PerformanceMetrics pm;
        PerformanceReport  rep = pm.Calculate(records, count,
                                              AccountInfoDouble(ACCOUNT_BALANCE));
        pm.PrintReport(rep);
        gLogger.FlushToCSV();
    }
}

//+------------------------------------------------------------------+
// END OF EA v3.5
//+------------------------------------------------------------------+
