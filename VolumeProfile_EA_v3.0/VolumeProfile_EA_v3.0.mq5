//+------------------------------------------------------------------+
//|                      VolumeProfile_EA_v3.0.mq5                  |
//|                  Volume Profile Swing Trading EA                |
//|                   Production-Grade Architecture                 |
//|                                                                  |
//| Version: 3.0 (Modular, Robust, Production-Ready)                |
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
//|   - Daily hard stop (-2%) and profit cap (+5%)                 |
//|   - Multi-timeframe validation (15M direction bias)            |
//|   - Session filtering (grave hour, pre-Tokyo block)            |
//|   - Reversal detection with position flips                     |
//|                                                                  |
//+------------------------------------------------------------------+

#property copyright "VWGTI-Pro v3.0 - Production Grade"
#property link      "https://github.com/sgunamijaya/VWGTI-Pro"
#property version   "3.0"
#property strict

// ==================== INCLUDES ====================

#include <Trade/Trade.mqh>
#include <VolumeProfile_EA_v3.0/VolumeProfileEngine.mqh>
#include <VolumeProfile_EA_v3.0/PositionManager.mqh>
#include <VolumeProfile_EA_v3.0/OrderExecutor.mqh>

// ==================== GLOBAL CONSTANTS ====================

#define EA_MAGIC_NUMBER 99001
#define LOOKBACK_BARS 150
#define LOOKBACK_BARS_15M 150
#define RISK_PERCENT 0.6
#define DAILY_LOSS_LIMIT -2.0
#define DAILY_PROFIT_CAP 5.0
#define VALUE_AREA_PERCENT 0.70
#define HVN_PERCENTILE 1.3
#define LVN_PERCENTILE 0.7
#define SLIPPAGE_LIMIT_PIPS 50
#define FRIDAY_CLOSE_HOUR 21
#define FRIDAY_CLOSE_MINUTE 45

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
input bool   Enable_Reversals      = true;     // Reversal flips
input bool   Enable_Friday_Close   = true;     // Friday 21:45 close
input bool   Enable_Session_Filter = true;     // Block grave hour/pre-Tokyo

// ==================== GLOBAL INSTANCES (SINGLETONS) ====================

VolumeProfileEngine  gVolumeProfile;          // Current timeframe profile
VolumeProfileEngine  gVolumeProfile15M;       // 15M timeframe profile
PositionManager      gPositionManager;        // Position tracking + broker sync
OrderExecutor        gOrderExecutor;          // Order placement + recovery
CTrade               gTrade;                  // MT5 trade API

// ==================== GLOBAL STATE ====================

double g_pipSize = 0.0001;                    // Auto-detect at OnInit
int    g_maxSpreadPoints = 50;               // Set in OnInit based on asset class
bool   g_sessionAllowed = true;
bool   g_dailyHardStop = false;
bool   g_dailyProfitCap = false;
datetime g_lastDailyReset = 0;

// ==================== STRUCTURES ====================

struct Setup1Signal {
    bool   isTriggered;
    bool   isLong;
    double confirmationClose;
    double sweepLow;
};

struct Setup2Signal {
    bool   isTriggered;
    bool   isLong;
    double hvnEdgePrice;
    double sweepLow;
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
//| Calculate account P&L from today's trades
//+------------------------------------------------------------------+
double GetDailyPnL() {
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
    
    // Add open positions P&L
    double openPnL = gPositionManager.GetOpenPnL();
    
    return closedPnL + openPnL;
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
            gPositionManager.CloseAll();
        }
        return false;
    }
    
    // Profit cap (+5%)
    if (dailyPnL > profitCapThreshold) {
        if (!g_dailyProfitCap) {
            Print("[ALERT] Profit cap reached! Daily P&L=", dailyPnL, " Cap=", profitCapThreshold);
            g_dailyProfitCap = true;
            
            // Close 60% of positions
            int posCount = gPositionManager.GetPositionCount();
            int closeCount = (int)MathCeil(posCount * 0.6);
            
            for (int i = 0; i < closeCount && i < posCount; i++) {
                long ticket = 0;
                string symbol = "";
                bool isLong = false;
                double entry = 0, sl = 0, tp = 0, lots = 0;
                string setup = "";
                
                if (gPositionManager.GetPosition(i, ticket, symbol, isLong, entry, sl, tp, lots, setup)) {
                    gTrade.PositionClose(symbol);
                }
            }
        }
        return false;
    }
    
    // Reset flags at session boundary
    if (TimeCurrent() - g_lastDailyReset > 86400) {  // 24 hours
        g_dailyHardStop = false;
        g_dailyProfitCap = false;
        g_lastDailyReset = TimeCurrent();
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
    
    long barVolume = iVolume(Symbol(), PERIOD_CURRENT, 1);
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
    // Doji: open ≈ close, wicks both sides
    else if (bodySize <= 1 * Point() && lowerWick > 0 && upperWick > 0) {
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
    
    double openPrice = iOpen(Symbol(), PERIOD_CURRENT, 1);
    double closePrice = iClose(Symbol(), PERIOD_CURRENT, 1);
    double lowPrice = iLow(Symbol(), PERIOD_CURRENT, 1);
    
    double previousVAH = gVolumeProfile.GetVAH();
    double previousVAL = gVolumeProfile.GetVAL();
    
    // Gap detection
    bool gappedAbove = (openPrice > previousVAH);
    bool gappedBelow = (openPrice < previousVAL);
    
    if (!gappedAbove && !gappedBelow) return result;
    
    // Reclaim detection
    bool reclaimingUp = (gappedBelow && closePrice >= previousVAL);
    bool reclaimingDown = (gappedAbove && closePrice <= previousVAH);
    
    if (!reclaimingUp && !reclaimingDown) return result;
    
    // Confirmation: close fully inside VA
    bool closeInsideVA = (closePrice >= previousVAL && closePrice <= previousVAH);
    
    if (!closeInsideVA) return result;
    
    result.isTriggered = true;
    result.isLong = reclaimingUp;
    result.confirmationClose = closePrice;
    result.sweepLow = lowPrice;
    
    return result;
}

//+------------------------------------------------------------------+
//| Setup 2: LVN/HVN/Pattern/Volume (Long + Short)
//+------------------------------------------------------------------+
Setup2Signal DetectSetup2Signal() {
    Setup2Signal result = {false, false, 0, 0};

    if (!Enable_Setup2) return result;

    // Pattern must be confirmed before sweep check — avoids wasted work
    CandlePattern pattern = DetectCandlePattern();
    if (!pattern.isValid) return result;
    if (pattern.patternType == CandlePattern::DOJI) return result;  // No directional edge on doji

    bool isLongSetup = (pattern.patternType == CandlePattern::HAMMER);

    // Volume spike (≥ 1.3x previous bar)
    long currentVolume = iVolume(Symbol(), PERIOD_CURRENT, 1);
    long previousVolume = iVolume(Symbol(), PERIOD_CURRENT, 2);
    if (previousVolume <= 0 || currentVolume < previousVolume * 1.3) return result;

    double currentHigh = iHigh(Symbol(), PERIOD_CURRENT, 1);
    double currentLow  = iLow(Symbol(), PERIOD_CURRENT, 1);

    if (isLongSetup) {
        // LONG: bar swept below lowest LVN then closed with a hammer — expect bounce to HVN
        double lowestLVN = 999999;
        for (int i = 0; i < gVolumeProfile.GetLVNCount(); i++) {
            double lvnPrice = gVolumeProfile.GetLVNPrice(i);
            if (lvnPrice < lowestLVN) lowestLVN = lvnPrice;
        }
        if (currentLow > lowestLVN) return result;  // No LVN sweep

        // Entry reference: nearest HVN above sweep low
        double hvnEdge = 999999;
        for (int i = 0; i < gVolumeProfile.GetHVNCount(); i++) {
            double hvnPrice = gVolumeProfile.GetHVNPrice(i);
            if (hvnPrice > currentLow && hvnPrice < hvnEdge) hvnEdge = hvnPrice;
        }
        if (hvnEdge == 999999) return result;

        result.isTriggered = true;
        result.isLong     = true;
        result.hvnEdgePrice = hvnEdge;
        result.sweepLow    = currentLow;  // SL reference: below this
    } else {
        // SHORT: bar swept above highest HVN then closed with a shooting star — expect drop to LVN
        double highestHVN = 0;
        for (int i = 0; i < gVolumeProfile.GetHVNCount(); i++) {
            double hvnPrice = gVolumeProfile.GetHVNPrice(i);
            if (hvnPrice > highestHVN) highestHVN = hvnPrice;
        }
        if (highestHVN == 0 || currentHigh < highestHVN) return result;  // No HVN sweep

        // Entry reference: nearest LVN below sweep high (TP target)
        double lvnEdge = 0;
        for (int i = 0; i < gVolumeProfile.GetLVNCount(); i++) {
            double lvnPrice = gVolumeProfile.GetLVNPrice(i);
            if (lvnPrice < currentHigh && lvnPrice > lvnEdge) lvnEdge = lvnPrice;
        }
        if (lvnEdge == 0) return result;

        result.isTriggered = true;
        result.isLong      = false;
        result.hvnEdgePrice = lvnEdge;   // TP target for short
        result.sweepLow    = currentHigh; // SL reference: above this (field repurposed)
    }

    return result;
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
    
    if (lotSize < minLot || lotSize > maxLot) return 0;
    
    lotSize = MathFloor(lotSize / lotStep) * lotStep;
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Calculate Risk/Reward ratio
//+------------------------------------------------------------------+
double CalculateRiskRewardRatio(double entryPrice, double stopLossPrice, double takeProfitPrice) {
    double riskPips = MathAbs(entryPrice - stopLossPrice) / Point();
    double rewardPips = MathAbs(takeProfitPrice - entryPrice) / Point();
    
    if (riskPips <= 0) return 0;
    
    return rewardPips / riskPips;
}

//+------------------------------------------------------------------+
//| Monitor position exits (TP/SL)
//+------------------------------------------------------------------+
void MonitorPositionExits() {
    for (int i = 0; i < gPositionManager.GetPositionCount(); i++) {
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
            Print("[TP_HIT] Ticket=", ticket, " Setup=", setup);
            gTrade.PositionClose(symbol);
            gPositionManager.ClosePosition(ticket, lots);
            break;
        }

        // SL check — guard sl > 0 prevents false trigger on orphaned positions with no SL set
        if (sl > 0 && ((isLong && bid <= sl) || (!isLong && ask >= sl))) {
            Print("[SL_HIT] Ticket=", ticket, " Setup=", setup);
            gTrade.PositionClose(symbol);
            gPositionManager.ClosePosition(ticket, lots);
            break;
        }
    }
}

// ==================== EVENT HANDLERS ====================

//+------------------------------------------------------------------+
//| Expert initialization
//+------------------------------------------------------------------+
int OnInit() {
    Print("========== VWGTI-Pro v3.0 - Production Grade ==========");
    Print("EA Magic: ", EA_MAGIC_NUMBER);
    Print("Symbol: ", Symbol(), " Asset: ", Asset_Class);
    
    // Validate connection
    if (!IsConnected()) {
        Print("[ERROR] Broker not connected");
        return INIT_FAILED;
    }
    
    // Auto-detect pip size
    int digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
    g_pipSize = ((digits == 5 || digits == 3) ? 10.0 : 1.0) * Point();
    Print("Pip Size: ", g_pipSize);
    
    // Initialize CTrade
    gTrade.SetExpertMagicNumber(EA_MAGIC_NUMBER);
    g_maxSpreadPoints = DetectMaxSpreadPoints();
    gOrderExecutor.SetMaxSpreadPoints(g_maxSpreadPoints);
    Print("Asset class spread limit: ", g_maxSpreadPoints, " pts");
    
    // Initialize PositionManager (broker reconciliation)
    if (!gPositionManager.Initialize()) {
        Print("[ERROR] Failed to initialize PositionManager");
        return INIT_FAILED;
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
        Comment(StringFormat("VWGTI-Pro v3.0 | %s | Positions: %d | Daily P&L: %s | Session: %s",
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
        // Calculate volume profiles
        if (!gVolumeProfile.Calculate(LOOKBACK_BARS)) {
            Print("[ERROR] Failed to calculate volume profile");
            return;
        }
        
        if (!gVolumeProfile.IdentifyNodes(HVN_PERCENTILE, LVN_PERCENTILE)) {
            Print("[ERROR] Failed to identify volume nodes");
            return;
        }
        
        // Load 15M profile (every 15M)
        static datetime last15MTime = 0;
        if (iTime(Symbol(), PERIOD_M15, 0) != last15MTime) {
            gVolumeProfile15M.Calculate(LOOKBACK_BARS_15M);
            gVolumeProfile15M.IdentifyNodes(HVN_PERCENTILE, LVN_PERCENTILE);
            last15MTime = iTime(Symbol(), PERIOD_M15, 0);
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
        
        // Determine market context
        int highIdx = iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, 20, 0);
        int lowIdx = iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, 20, 0);
        double recentHigh = iHigh(Symbol(), PERIOD_CURRENT, highIdx);
        double recentLow = iLow(Symbol(), PERIOD_CURRENT, lowIdx);
        double recentRange = recentHigh - recentLow;
        double vaWidth = gVolumeProfile.GetVAH() - gVolumeProfile.GetVAL();
        
        bool balanced = (vaWidth < recentRange * 0.6);
        
        if (balanced) {
            // SETUP 1: Gap/Reclaim/Confirmation
            Setup1Signal sig1 = DetectSetup1Signal();

            if (sig1.isTriggered) {
                // Fix 1: use live market price for lot sizing, not bar close
                double marketPrice = sig1.isLong
                    ? SymbolInfoDouble(Symbol(), SYMBOL_ASK)
                    : SymbolInfoDouble(Symbol(), SYMBOL_BID);

                // Fix 2: 100-pip SL buffer (was 10); direction-aware for short
                double barHigh1 = iHigh(Symbol(), PERIOD_CURRENT, 1);
                double stopLoss = sig1.isLong
                    ? sig1.sweepLow - (100 * g_pipSize)
                    : barHigh1     + (100 * g_pipSize);

                double takeProfit = sig1.isLong ? gVolumeProfile.GetVAH() : gVolumeProfile.GetVAL();

                double lotSize = CalculateLotSize(marketPrice, stopLoss);

                if (lotSize > 0) {
                    double rr = CalculateRiskRewardRatio(marketPrice, stopLoss, takeProfit);

                    // Fix 4: R:R gate — minimum 1.5:1 required
                    if (rr < 1.5) {
                        Print("[SKIP] Setup1 R:R too low: ", DoubleToString(rr, 2), ":1 (min 1.5)");
                    } else {
                        OrderExecutor::ExecutionRecord result = gOrderExecutor.PlaceOrder(
                            sig1.isLong, lotSize, marketPrice, stopLoss, takeProfit, EA_MAGIC_NUMBER);

                        if (result.status == OrderExecutor::STATUS_FILLED) {
                            gPositionManager.RegisterFill(result.ticket, sig1.isLong, result.fillPrice,
                                                          stopLoss, takeProfit, lotSize, "Setup1");
                            Print("[ENTRY] Setup1 LONG=", sig1.isLong, " Entry=", result.fillPrice,
                                  " SL=", stopLoss, " TP=", takeProfit, " RR=", DoubleToString(rr, 2), ":1");
                        }
                    }
                }
            }
        } else {
            // SETUP 2: LVN/HVN/Pattern/Volume
            Setup2Signal sig2 = DetectSetup2Signal();

            if (sig2.isTriggered) {
                // Fix 1: use live market price for lot sizing
                double marketPrice = sig2.isLong
                    ? SymbolInfoDouble(Symbol(), SYMBOL_ASK)
                    : SymbolInfoDouble(Symbol(), SYMBOL_BID);

                // Fix 2: 100-pip SL buffer; direction-aware (sweepLow = sweep high for shorts)
                double stopLoss = sig2.isLong
                    ? sig2.sweepLow - (100 * g_pipSize)
                    : sig2.sweepLow + (100 * g_pipSize);

                double takeProfit = sig2.isLong ? gVolumeProfile.GetVAH() : gVolumeProfile.GetVAL();

                double lotSize = CalculateLotSize(marketPrice, stopLoss);

                if (lotSize > 0) {
                    double rr = CalculateRiskRewardRatio(marketPrice, stopLoss, takeProfit);

                    // Fix 4: R:R gate — minimum 1.5:1 required
                    if (rr < 1.5) {
                        Print("[SKIP] Setup2 R:R too low: ", DoubleToString(rr, 2), ":1 (min 1.5)");
                    } else {
                        OrderExecutor::ExecutionRecord result = gOrderExecutor.PlaceOrder(
                            sig2.isLong, lotSize, marketPrice, stopLoss, takeProfit, EA_MAGIC_NUMBER);

                        if (result.status == OrderExecutor::STATUS_FILLED) {
                            gPositionManager.RegisterFill(result.ticket, sig2.isLong, result.fillPrice,
                                                          stopLoss, takeProfit, lotSize, "Setup2");
                            Print("[ENTRY] Setup2 LONG=", sig2.isLong, " Entry=", result.fillPrice,
                                  " SL=", stopLoss, " TP=", takeProfit, " RR=", DoubleToString(rr, 2), ":1");
                        }
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| OnTrade event (real-time position sync)
//+------------------------------------------------------------------+
void OnTrade() {
    gPositionManager.OnTrade();
    Print("[EVENT] OnTrade fired - Position manager synced");
}

//+------------------------------------------------------------------+
//| Expert deinitialization
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("[DEINIT] EA shutting down. Reason: ", reason);
    Print("[FINAL] Positions: ", gPositionManager.GetPositionCount(), 
          " Daily P&L: ", GetDailyPnL());
}

//+------------------------------------------------------------------+
// END OF EA v3.0
//+------------------------------------------------------------------+
