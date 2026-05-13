# MT5 Volume Profile Swing Trading EA — Project Context

⚠️ **SCOPE LOCKED: MQL5 CODEBASE ONLY** — See [SCOPE.md](.planning/SCOPE.md) for immutable boundaries  
**Do NOT expand scope to fix issues. Ask user before making changes outside stated scope.**

**Project ID:** VWGTI-PRO-VP-EA  
**Initiative:** Automated swing trading using Volume Profile methodology  
**Code Language:** MQL5 ONLY (no other languages permitted)
**Status:** Initialization Phase  
**Last Updated:** 2026-05-13

---

## What This Is

A **production-grade MetaTrader 5 Expert Advisor** that automates swing trading using **Volume Profile entry/exit signals** with disciplined risk management. The EA trades high-conviction setups across multiple asset classes using a mathematical Volume Profile framework validated against professional trading sources.

**Core Value Proposition:**
> Detect and execute Volume Profile swing trades automatically across Gold, Oil, and FX pairs with consistent risk-adjusted returns, eliminating emotional decision-making and capturing time-sensitive price rejections.

---

## Strategy Overview

### Volume Profile Foundation
- **Core Methodology:** Auction Market Theory (AMT) — price gravitation toward high-volume price levels
- **Calculation:** 400-bin price distribution of cumulative volume across lookback period (150 bars default)
- **Key Levels:**
  - **POC (Point of Control):** Single price level with highest traded volume
  - **Value Area (VA):** Price range containing 70% of all volume (VAH = High, VAL = Low)
  - **HVN (High Volume Nodes):** Clusters of heavy trading activity (price magnets)
  - **LVN (Low Volume Nodes):** Vacuum zones with minimal activity (liquidity grabs)

### Entry Logic (Confirmation-Based)
1. **Price hits VAL** → Sweeps lower (liquidity grab beyond VAL) → **Rejects upward**
2. **Reclaims into Value Area** → Waits for confirmation candle **closure inside VA**
3. **Entry executes** on confirmed candle close (NOT wick touch)
4. **Stop Loss:** BELOW the sweep low (not at VAL — prevents whipsaw)
5. **Take Profit:** 
   - **Partial TP (65%):** First identified resistance level
   - **Remainder (35%):** Value Area High (VAH)

### Exit Rules (Disciplined Risk Management)
- **Daily Hard Stop:** -2% account loss → cease all trading
- **Daily Profit Cap:** +2-3% account gain → stop trading (secure wins)
- **Overnight Positions:** Max 1-2 positions, prefer holding winners only
- **Friday Close:** All open trades forcefully closed Friday 21:45 broker server time
- **Position Size:** 0.6% risk per trade per asset class (one position per asset)

---

## Trading Setup

### Asset Classes (MVP Phase 1)
| Asset | Type | Session Window | Timeframe | Volume Source |
|-------|------|-----------------|-----------|----------------|
| Gold (XAUUSD) | Commodity CFD | Tokyo → London → NY | 5M setup, 1M confirm | Tick Volume |
| EURUSD | Forex pair | Tokyo → London → NY | 5M setup, 1M confirm | Tick Volume |

**Future Expansion (Phase 2):** Oil (XTIUSD), GBPJPY, DAX30, Nasdaq (same structure)

### Trading Sessions
- **Active Window:** Tokyo Session open (00:00 SGT) through NY Session close (21:00 ET)
- **No Trading After:** 21:45 Broker Server Time Friday
- **Overnight Holds:** Allowed if profitable; next opportunity at Tokyo open next trading day
- **Weekend:** No trading (market closed)

### Confirmation Timeframe Strategy
- **5M Chart:** Identifies swing setup and VAL/VAH levels
- **1M Chart:** Provides confirmation on reclaim into Value Area
- **Both align:** Entry triggered only when both timeframes show acceptance into VA

---

## Core Algorithms

### Volume Profile Calculation
```
Lookback Period: 150 bars (configurable by timeframe)
Price Bins: 400 discrete levels
Bin Width: (Highest High - Lowest Low) / 400
Volume Aggregation: 
  - Distribute each candle's volume proportionally across price levels it spans
  - Handle body (60-70% volume) and wicks (30-40% volume) separately
  - Multi-level candles prorate volume contribution
```

### Key Level Detection
```
POC = Price level with absolute highest accumulated volume
VA = 70% cumulative volume centered on POC
  - VAH = highest price within VA boundary
  - VAL = lowest price within VA boundary

HVN = Local volume peaks > 85th percentile (price magnets)
LVN = Local volume valleys < 25th percentile (liquidity voids)
```

### Market Condition Detection
```
Balanced Market (Setup 1 priority):
  - Value Area width < 0.5x average recent range
  - Narrow consolidation zone
  - Mean reversion bias (target opposite extreme)

Imbalanced Market (Setup 2 priority):
  - Value Area width > 1.5x average recent range
  - Wide trending structure
  - Momentum/breakout bias (target direction continuation)
```

---

## Trading Setups

### Setup 1: Value Area Mean Reversion (80% Rule)
**Conditions:**
1. Market in balanced state (narrow VA, consolidating)
2. Price opens outside previous session's Value Area
3. Price re-enters Value Area boundary (crosses VAL for upside)
4. **Confirmation:** Price closes (real candle, not wick touch) inside VA
5. Entry only after confirmation candle closes

**Execution:**
- **LONG:** Buy after confirmation close, Target = VAH (opposite extreme)
- **SHORT:** Sell after confirmation close, Target = VAL (opposite extreme)
- **SL:** Just outside VA boundary where entry occurred

---

### Setup 2: HVN Edge Trading with Volume Confirmation
**Conditions:**
1. Price sweeps into LVN (low volume vacuum zone)
2. Price reclaims and touches HVN (high volume cluster edge)
3. Trigger candle forms: Hammer (longs), Shooting Star (shorts), or Doji
4. **Volume Confirmation:** Trigger candle volume ≥ 1.3x previous candle volume
5. Trigger candle must fully close (no front-running)

**Execution:**
- **LONG:** Enter after trigger close at HVN edge, Target = opposite profile edge, SL = below LVN sweep
- **SHORT:** Enter after trigger close at HVN edge, Target = opposite profile edge, SL = above LVN sweep

**Special Rules:**
- LVN sweep creates liquidity vacuum
- HVN acts as price magnet (reversal zone)
- Volume spike confirms institutional conviction
- Edge-to-edge targeting maximizes risk/reward

---

## Risk Framework (LOCKED)

### Per-Trade Risk
```
Risk Percentage: 0.6% per trade per asset class
Position Size Calculation:
  Lot Size = (Account Balance × 0.6%) / (SL Distance × Point Value)

Example:
  Account: $1,000 → Risk: $6 per trade
  SL Distance: 50 pips → Lot Size ≈ 0.01 (micro lot)
```

### Daily Limits (Non-Negotiable)
```
Daily Hard Stop Loss: -2% account loss
  → If account drops $20 (on $1,000), STOP ALL TRADING

Daily Profit Cap: +2-3% account gain
  → If account reaches +$20-30, CLOSE DAY (secure wins)

Max Open Positions: 2 (one per asset class MVP)
Max Overnight Positions: 1-2 (reduce exposure unless profitable)
Friday Hard Close: All positions closed Friday 21:45 broker server time
```

### Position Structure
```
Entry: At VAL/VAH confirmation or HVN edge confirmation
Partial TP: 65% of position at first resistance target
Remainder TP: 35% of position at Value Area opposite extreme (VAH/VAL)
Stop Loss: Below sweep low (not at VAL) or below LVN (Setup 2)
  → Prevents whipsaw stops during liquidity grabs
```

---

## Technical Implementation

### Language & Platform
- **Language:** MQL5 (MetaTrader 5 native)
- **Volume Data:** Tick Volume (Forex/CFD - no custom indicator needed, MT5 provides native)
- **Chart Data:** OHLCV bars (standard MT5 data)

### Calculation Architecture
- **No Visual Objects:** All calculations in arrays (memory-only, no chart drawing)
- **Array Storage:** Volume profile data, POC/VAH/VAL levels, HVN/LVN zones in double[] arrays
- **Efficiency:** Optimized loops, no nested complexity
- **Performance:** Designed for simultaneous multi-chart execution

### Data Requirements
```
Historical Data: Full OHLCV bars for lookback period
Lookback Length: 150 bars (configurable)
Volume Source: MT5 native Tick Volume (Forex)
Real-time Updates: New candle close trigger calculation refresh
```

### Error Handling & Logging
- Trade execution validation (slippage tolerance: max 50 points)
- Broker connectivity checks
- Order send failure recovery
- Journal logging for all events (entries, exits, errors, calculations)
- Graceful degradation (skip trades if conditions not met vs. error state)

---

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| **400-Bin Volume Profile** | Professional-grade granularity (industry standard); balances precision vs. calculation speed | Validated against academic sources |
| **70% Value Area** | Institutional standard capturing majority activity; 68% also acceptable | POC-centered VA expansion |
| **Confirmation Candle Closure** | Prevents false entries on wick touches; requires actual price acceptance | Reduces whipsaws vs. wick-based entries |
| **SL Below Sweep Low** | Protects against liquidity grab punches; VAL-based stops get repeatedly hit | Professional risk management |
| **1.3x Volume Threshold (Setup 2)** | Filters out noise; 30% increase indicates genuine conviction vs. random tick | Reduces false triggers |
| **0.6% Risk Per Trade** | Conservative position sizing for discovery phase; scales with confidence | Sustainable equity curve |
| **Daily Hard Stops (-2%, +2-3%)** | Prevents emotional revenge trading and drift; locks wins when rare | Behavioral risk management |
| **No Visual Objects** | Enables silent background operation; prevents chart lag on multi-asset EA | Scalability across 10+ charts |
| **Tick Volume (Forex)** | MT5 native, 90%+ correlation with real institutional volume; no custom indicator cost | Immediate implementation |

---

## Requirements

### Validated
- ✅ Volume Profile mathematics (POC, VA 70%, HVN/LVN detection)
- ✅ Entry logic (confirmation candle, sweep dynamics, LVN/HVN targeting)
- ✅ Risk management (0.6% per trade, daily stops, position structure)
- ✅ MT5 platform capability (Tick Volume native, MQL5 language, order execution)

### Active (v1 MVP)
- [ ] POC/VAH/VAL calculation engine
- [ ] Confirmation candle detection logic
- [ ] Liquidity sweep identification
- [ ] Entry/exit execution with partial TP structure
- [ ] Daily limit enforcement (-2% / +2-3%)
- [ ] Friday hard close automation
- [ ] Gold and EURUSD asset class support
- [ ] Journal logging and error handling

### Out of Scope (v2+)
- Multi-asset expansion (Oil, GBPJPY, DAX30, Nasdaq)
- Advanced MTF confirmation (1H/4H higher timeframe alignment)
- Adaptive strategy switching (balanced vs. imbalanced auto-detect)
- Historical backtesting framework
- Performance dashboard / reporting
- Equity curve optimization

---

## Success Criteria (v1 MVP)

**Functional:**
- EA compiles and runs on MT5 without errors
- Correctly calculates POC, VAH, VAL from 150-bar lookback
- Detects HVN/LVN zones algorithmically
- Executes buy/sell orders at confirmation levels
- Partial TP structure functional (65% / 35% split)
- Daily hard stops (-2%) and profit caps (+2-3%) enforced
- Friday 21:45 automated close functional

**Operational:**
- Handles Gold (XAUUSD) and EURUSD on 5M/1M timeframes
- No visual clutter (arrays only)
- Journal logs all trade entries, exits, calculations
- Slippage within 50-point tolerance
- Handles gaps and low-liquidity periods gracefully

**Quality:**
- 90%+ test coverage (unit tests for calculations)
- Zero missed closes due to technical failure
- Performance: calculation time < 100ms per bar
- Memory efficient (no memory leaks on 48-hour continuous operation)

---

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---

## Context

### Research Materials
- **Pine Script Reference:** `docs/Volume Profile Trading Handbook/Swing Volume Profile - Pine Script/` 
  - Swing Volume Profile Indicator.pdf — Core calculation reference
- **MT5 Strategy:** `docs/Volume Profile Trading Handbook/` 
  - MT5 Volume Profile Analysis and Execution Strategy.pdf
  - Accuracy_Check_Volume_Profile_MT5_Strategy.md — Implementation validation
- **Professional Sources:** 9 comprehensive documents validating methodology

### Team & Ownership
- **Author:** Sugi Gunamijaya
- **Role:** Trader & Developer
- **Expertise:** Volume Profile trading, MQL5 development
- **Goal:** Production EA for consistent swing trading execution

### Timeline & Constraints
- **Phase 1 (MVP):** Gold + EURUSD EA functional
- **Phase 2+:** Expand to full asset class portfolio
- **No Hard Deadline:** Discovery stage allows iterative refinement
- **Budget:** Self-funded (no external constraints)

---

*Last updated: 2026-05-13 after deep questioning and research review*
