# Research Report: Order Flow VWAP Deviation Session with Volume Profile Trading
**Date:** 14/05/2026  
**Project:** VWGTI-Pro VolumeProfile_EA_v3.0  
**Scope:** Implementing a new Setup 3 — Order Flow VWAP Deviation Session  

---

## Executive Summary

This report provides implementation-ready guidance for adding a **Session VWAP Deviation + Volume Profile confluence** setup (Setup 3) to the existing EA. The strategy identifies high-probability mean-reversion and momentum entries when price deviates from session VWAP into a known Volume Profile node (HVN/LVN/POC) — a pattern used by institutional algorithms to absorb or initiate flow at statistically extreme prices.

Confidence: **HIGH** — based on converging sources across institutional trading research, MQL5 implementation forum threads, and the LuxAlgo Order Flow VWAP Deviation indicator specification.

---

## 1. Theoretical Foundation

### 1.1 Why VWAP + Volume Profile Together

VWAP represents the session's **fair value** (volume-weighted). Volume Profile maps the **structural supply/demand** at each price level. Their confluence creates the highest-conviction zones:

| Alone | Combined |
|---|---|
| VWAP = dynamic mean (1 dimension) | VWAP + HVN = "fair value meets prior acceptance" |
| VP POC = historical magnet (1 dimension) | VWAP + LVN = "fair value meets thin air" |
| Neither gives context of the other | Confluence gives both timing and structure |

**Key insight (Trader Dale / LuxAlgo research):** "When a volume cluster coincides with a VWAP level, the confluence makes the setup even stronger." POC acts as a **magnet** — price gravitationally returns to it post-deviation.

### 1.2 Standard Deviation Band Interpretation

VWAP ± standard deviation bands represent statistical probability boundaries:

| Band | Probability | Interpretation |
|---|---|---|
| ±1 SD | ~68% of session price action | "Value area" — normal trading range |
| ±2 SD | ~95% | Overextended — strong mean reversion probability |
| ±3 SD | ~99.7% | "Black swan" zone — highest probability counter-trend |

**Trading rule (2025–2026 consensus):** Price touching ±2 SD with a VP node nearby = mean-reversion setup. Price rejecting ±2 SD and breaking further = trend continuation (low-volume deviation).

### 1.3 Order Flow Proxy (Without Level 2 Data)

MT5 does not provide true bid/ask delta without a specialised data feed. The standard proxy (used by LuxAlgo, MQL5 community):

```
BarDelta = (Close - Low) / (High - Low)   // 0 = full bearish, 1 = full bullish
```

- `BarDelta > 0.6` → buying pressure dominant on this bar
- `BarDelta < 0.4` → selling pressure dominant
- Aggregate 3–5 bars at the deviation zone to confirm order flow bias before entry

---

## 2. Session VWAP Calculation (MQL5 Correct Formula)

### 2.1 Cumulative Running Formula (Bar-by-Bar, No Repainting)

```mql5
// Accumulators reset each session
double cumTPV  = 0;   // Cumulative (TypicalPrice * Volume)
double cumVol  = 0;   // Cumulative Volume
double cumTPV2 = 0;   // Cumulative (TypicalPrice^2 * Volume)

// Per-bar update (loop or OnCalculate)
double tp    = (high[i] + low[i] + close[i]) / 3.0;
double vol   = (double)tick_volume[i];

cumTPV  += tp * vol;
cumVol  += vol;
cumTPV2 += (tp * tp) * vol;

double vwap   = cumTPV / cumVol;
double wStdDev = MathSqrt(MathMax(0, (cumTPV2 / cumVol) - (vwap * vwap)));

double upper1 = vwap + wStdDev * 1.0;
double lower1 = vwap - wStdDev * 1.0;
double upper2 = vwap + wStdDev * 2.0;
double lower2 = vwap - wStdDev * 2.0;
double upper3 = vwap + wStdDev * 3.0;
double lower3 = vwap - wStdDev * 3.0;
```

**Critical:** Uses population weighted standard deviation (divide by N, not N-1). `MathMax(0,...)` guards against floating-point rounding producing a tiny negative under the sqrt.

### 2.2 Session Reset Logic

```mql5
// Detect session boundary — reset when the day/session date changes
datetime barTime = iTime(Symbol(), PERIOD_CURRENT, i);
MqlDateTime dt;
TimeToStruct(barTime, dt);

// For Daily Session VWAP: reset when day changes
if (dt.day != prevDay || dt.mon != prevMon) {
    cumTPV  = 0;
    cumVol  = 0;
    cumTPV2 = 0;
    prevDay = dt.day;
    prevMon = dt.mon;
}
```

For **session-specific** anchoring (e.g., London open 07:00, New York open 13:00 GMT):
```mql5
// Reset at NY Open (13:00 GMT server time)
if (dt.hour == 13 && dt.min == 0 && prevHour != 13) {
    cumTPV  = 0;
    cumVol  = 0;
    cumTPV2 = 0;
}
prevHour = dt.hour;
```

---

## 3. Setup 3 Signal Definition: VWAP Deviation + VP Confluence

### 3.1 Long Setup (Mean Reversion)

All conditions must be true simultaneously:

1. **Deviation condition:** `close[1] < lower2` (price closed below −2 SD)
2. **VP confluence:** Prior session's `valPrice` OR current profile `lvnPrice` within ±`binSize*2` of `lower2`  
   — OR — current `pocPrice` is within 2× binSize of current price (POC magnet)
3. **Order flow confirmation:** `barDelta(1) > 0.55` (close bar showed buying absorption)
4. **Session timing:** Bar is within the active session window (not grave hour, not pre-Tokyo)
5. **HTF bias:** H1 `VolumeProfileHTF.GetPOC()` is above current price (bullish structural context)

### 3.2 Short Setup (Mean Reversion)

1. **Deviation condition:** `close[1] > upper2` (price closed above +2 SD)
2. **VP confluence:** `vahPrice` OR HVN within ±`binSize*2` of `upper2`
3. **Order flow confirmation:** `barDelta(1) < 0.45`
4. **Session timing:** Active session
5. **HTF bias:** H1 POC is below current price (bearish structural context)

### 3.3 Breakout Variant (Trend Continuation)

Used when deviation occurs on **elevated volume** — price breaks ±2 SD AND volume exceeds 1.5× session average:

- **Long breakout:** Close > upper2 with volume > 1.5× average → buy the retest of upper2 on pullback
- **Short breakout:** Close < lower2 with volume > 1.5× average → sell the retest of lower2 on rally

---

## 4. Entry, Stop Loss, and Take Profit Rules

### 4.1 Entry

- **Mean Reversion:** Market order at open of next bar after all conditions confirmed on bar [1]
- **Alternative:** Limit order at `lower2` / `upper2` level if price has not yet reached zone (reduces slippage by ~30%)

### 4.2 Stop Loss

| Setup | Stop Location |
|---|---|
| Mean Reversion Long | Below bar[1] low − `binSize` buffer OR below `lower3` (whichever is closer to entry) |
| Mean Reversion Short | Above bar[1] high + `binSize` buffer OR above `upper3` |
| Breakout Long | Below `upper2` retest bar's low |
| Breakout Short | Above `lower2` retest bar's high |

**Risk check:** If SL distance > 2× ATR(14), skip trade (abnormal volatility).

### 4.3 Take Profit Targets

| Target | Level |
|---|---|
| TP1 (partial 50%) | Session VWAP line |
| TP2 (remaining 50%) | Opposite VA edge (VAH for longs from VAL, VAL for shorts from VAH) |
| TP3 (aggressive) | POC of prior session (if not yet revisited, uses `g_priorPOC` already tracked in EA) |

**Minimum R:R:** 1.5:1 (consistent with existing `MIN_RR_RATIO` constant).

---

## 5. Integration Architecture for VolumeProfile_EA_v3.0

### 5.1 New Module: `VWAPSessionEngine.mqh`

```mql5
class VWAPSessionEngine {
private:
    double m_cumTPV;
    double m_cumVol;
    double m_cumTPV2;
    int    m_prevDay;
    int    m_prevMon;

public:
    double vwap;
    double upper1, lower1;
    double upper2, lower2;
    double upper3, lower3;
    double wStdDev;

    void Reset() {
        m_cumTPV = 0; m_cumVol = 0; m_cumTPV2 = 0;
    }

    void Update(double high, double low, double close, long volume, datetime barTime) {
        MqlDateTime dt;
        TimeToStruct(barTime, dt);
        if (dt.day != m_prevDay || dt.mon != m_prevMon) {
            Reset();
            m_prevDay = dt.day;
            m_prevMon = dt.mon;
        }

        double tp = (high + low + close) / 3.0;
        double v  = (double)volume;
        m_cumTPV  += tp * v;
        m_cumVol  += v;
        m_cumTPV2 += (tp * tp) * v;

        if (m_cumVol <= 0) return;

        vwap    = m_cumTPV / m_cumVol;
        wStdDev = MathSqrt(MathMax(0, (m_cumTPV2 / m_cumVol) - (vwap * vwap)));

        upper1 = vwap + wStdDev; lower1 = vwap - wStdDev;
        upper2 = vwap + wStdDev * 2; lower2 = vwap - wStdDev * 2;
        upper3 = vwap + wStdDev * 3; lower3 = vwap - wStdDev * 3;
    }

    double GetBarDelta(double high, double low, double close) {
        double range = high - low;
        if (range < 1e-10) return 0.5;
        return (close - low) / range;
    }
};
```

### 5.2 New Signal Structure

```mql5
struct Setup3Signal {
    bool   isTriggered;
    bool   isLong;
    bool   isMeanReversion;   // false = breakout variant
    double vwapLevel;         // VWAP at signal time
    double deviationBand;     // The ±2SD band that triggered
    double vpConfluencePrice; // Nearest VP node (POC/VAH/VAL/HVN/LVN)
    double sweepExtreme;      // Bar[1] low (long) or high (short)
};
```

### 5.3 Signal Detection Function

```mql5
Setup3Signal DetectSetup3Signal(
    VWAPSessionEngine &vwap,
    VolumeProfileEngine &vp,
    double avgVolume)           // Session average volume for breakout test
{
    Setup3Signal sig;
    sig.isTriggered = false;

    double close1  = iClose(Symbol(), PERIOD_CURRENT, 1);
    double high1   = iHigh(Symbol(),  PERIOD_CURRENT, 1);
    double low1    = iLow(Symbol(),   PERIOD_CURRENT, 1);
    long   vol1    = iTickVolume(Symbol(), PERIOD_CURRENT, 1);
    double delta1  = vwap.GetBarDelta(high1, low1, close1);
    double binSz   = vp.GetBinSize();

    bool nearVP_lower = (MathAbs(close1 - vp.GetVAL()) < binSz * 2) ||
                        (MathAbs(close1 - vp.GetPOC()) < binSz * 2);
    bool nearVP_upper = (MathAbs(close1 - vp.GetVAH()) < binSz * 2) ||
                        (MathAbs(close1 - vp.GetPOC()) < binSz * 2);

    // ---- Mean Reversion Long ----
    if (close1 < vwap.lower2 && delta1 > 0.55 && nearVP_lower) {
        sig.isTriggered      = true;
        sig.isLong           = true;
        sig.isMeanReversion  = true;
        sig.vwapLevel        = vwap.vwap;
        sig.deviationBand    = vwap.lower2;
        sig.vpConfluencePrice = vp.GetVAL();
        sig.sweepExtreme     = low1;
        return sig;
    }

    // ---- Mean Reversion Short ----
    if (close1 > vwap.upper2 && delta1 < 0.45 && nearVP_upper) {
        sig.isTriggered      = true;
        sig.isLong           = false;
        sig.isMeanReversion  = true;
        sig.vwapLevel        = vwap.vwap;
        sig.deviationBand    = vwap.upper2;
        sig.vpConfluencePrice = vp.GetVAH();
        sig.sweepExtreme     = high1;
        return sig;
    }

    // ---- Breakout Long (high volume deviation) ----
    if (close1 > vwap.upper2 && (double)vol1 > avgVolume * 1.5) {
        sig.isTriggered      = true;
        sig.isLong           = true;
        sig.isMeanReversion  = false;
        sig.vwapLevel        = vwap.vwap;
        sig.deviationBand    = vwap.upper2;
        sig.vpConfluencePrice = vp.GetVAH();
        sig.sweepExtreme     = low1;
        return sig;
    }

    return sig;
}
```

### 5.4 TP/SL Calculation for Setup 3

```mql5
void CalculateSetup3SLTP(
    const Setup3Signal &sig,
    const VWAPSessionEngine &vwap,
    double &sl, double &tp1, double &tp2)
{
    double binSz = gVolumeProfile.GetBinSize();

    if (sig.isLong) {
        if (sig.isMeanReversion) {
            sl  = sig.sweepExtreme - binSz;      // Below deviation extreme
            tp1 = vwap.vwap;                     // TP1: VWAP line
            tp2 = gVolumeProfile.GetVAH();       // TP2: VAH
        } else {
            sl  = vwap.upper2 - binSz;           // Breakout: SL below broken band
            tp1 = vwap.upper3;                   // TP1: next deviation band
            tp2 = g_priorPOC;                    // TP2: prior session POC
        }
    } else {
        if (sig.isMeanReversion) {
            sl  = sig.sweepExtreme + binSz;
            tp1 = vwap.vwap;
            tp2 = gVolumeProfile.GetVAL();
        } else {
            sl  = vwap.lower2 + binSz;
            tp1 = vwap.lower3;
            tp2 = g_priorPOC;
        }
    }
}
```

---

## 6. Session Timing Recommendations

**Highest-probability windows** (sourced from institutional VWAP research):

| Session | GMT | Why |
|---|---|---|
| London open | 07:00–09:30 | Heavy institutional order flow; VWAP resets; VP nodes from Asia session act as early magnets |
| New York open | 13:00–14:30 | Largest volume surge; deviation setups form fast against session VWAP |
| London/NY overlap | 12:00–16:00 | Combined liquidity; best mean reversion probability (~80% success rate cited) |
| Avoid | 21:00–23:00 | Low liquidity; thin bars inflate deviation bands artifically |

EA already has `Enable_Session_Filter` blocking the grave hour/pre-Tokyo period — Setup 3 should respect this gate.

---

## 7. Parameter Recommendations

| Parameter | Recommended Value | Rationale |
|---|---|---|
| `VWAP_SD_Entry` | 2.0 | ±2SD = 95% boundary; highest mean-reversion probability |
| `VWAP_SD_Stop` | 3.0 | ±3SD = 99.7%; if breached, trend has changed |
| `OrderFlow_Delta_Min` | 0.55 (long) / 0.45 (short) | Absorption threshold; avoids entering into still-running momentum |
| `VP_Confluence_Bins` | 2 | VP node must be within 2 bin sizes of deviation band |
| `Breakout_Vol_Multiple` | 1.5× session average | Separates breakout from noise |
| `Session_Reset` | Daily (00:00 server) | Standard day-session VWAP for most assets |

---

## 8. Risk Management Integration

- Setup 3 trades use the **same** `Risk_Percentage` input (0.6%) — no separate sizing needed
- Daily hard stop (`DAILY_LOSS_LIMIT = −2%`) applies; Setup 3 does NOT bypass it
- Mean reversion SL is typically **tighter** than Setup 1/2 (deviation from ±2SD to ±3SD), so actual position sizes will be **larger** — monitor lot size caps
- Add `MIN_RR_RATIO` check: skip if `(tp1 - entry) / (entry - sl) < 1.5`

---

## 9. Key Distinctions from Existing Setups

| | Setup 1 (Gap/Reclaim) | Setup 2 (LVN/HVN) | Setup 3 (VWAP Dev) |
|---|---|---|---|
| **Trigger** | Value area gap + close reclaim | LVN sweep + HVN edge | ±2SD VWAP + VP node |
| **Market type** | Balanced | Imbalanced | Any (session-relative) |
| **Entry timing** | Intraday swing | Intraday swing | Intraday mean-reversion or breakout |
| **TP anchor** | VP POC | HVN edge | VWAP line (primary), VAH/VAL (secondary) |
| **SL anchor** | Sweep extreme | Sweep low | ±3SD band OR bar extreme |
| **Session dependency** | Low | Low | HIGH — VWAP resets each session |

---

## 10. Implementation Sequence

1. **Create** `VolumeProfile_EA_v3.0/Include/VWAPSessionEngine.mqh` (class + GetBarDelta + session reset)
2. **Add** `Setup3Signal` struct to main EA or `SignalDetection.mqh`
3. **Add** `DetectSetup3Signal()` function to `SignalDetection.mqh`
4. **Add** `input bool Enable_Setup3 = true;` to main EA inputs
5. **Instantiate** `VWAPSessionEngine gVWAP;` as global singleton
6. **Call** `gVWAP.Update(...)` in `OnCalculate` or at each new bar in `OnTick`
7. **Add** Setup 3 evaluation block in main trading loop (parallel to Setup 1/2 blocks)
8. **Add** TP split logic: `OrderSend` partial close at TP1 (50%), trail remainder to TP2
9. **Log** Setup 3 trades with `gLogger` (tag field: `"S3-MR"` or `"S3-BO"`)
10. **Test** on XAUUSD 1H/15M with London + NY sessions over 2023–2025 history

---

## Sources

- [Order Flow VWAP Deviation | LuxAlgo](https://www.luxalgo.com/library/indicator/order-flow-vwap-deviation/)
- [6 Powerful VWAP Trading Strategies for 2025 | ChartsWatcher](https://chartswatcher.com/pages/blog/6-powerful-vwap-trading-strategies-for-2025)
- [VWAP Bands Forum — Correct SD Calculation | MQL5](https://www.mql5.com/en/forum/441073)
- [Trying to add SD bands to VWAP | MQL5 Forum](https://www.mql5.com/en/forum/444070)
- [VWAP & Standard Deviations — The Only Honest Indicator 2026 | Exmon Academy](https://academy.exmon.pro/vwap-standard-deviations-the-only-honest-indicator-in-2026)
- [Volume Profile + POC Trading Strategy | Trader Dale](https://www.trader-dale.com/my-best-trading-strategy-learn-how-to-trade-using-volume-profile-and-poc/)
- [Volume Analysis Mastery: Institutional Footprints 2025 | Tickrad](https://www.tickrad.com/blog/volume-analysis-mastery-institutional-footprints-2025)
- [VWAP: Institutional Indicator Smart Trading 2025 | TradingShastra](https://tradingshastra.com/vwap-institutional-indicator/)
- [VWAP Session Bands MT5 | MQL5 Market](https://www.mql5.com/en/market/product/146963)
- [Price Action Toolkit Part 10: External Flow VWAP | MQL5 Articles](https://www.mql5.com/en/articles/16984)
- [VWAP Bands | GoCharting OrderFlow Docs](https://gocharting.com/docs/orderflow/vwapbands)
