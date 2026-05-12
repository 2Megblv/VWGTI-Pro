# Feature Landscape: Volume Profile EA

**Project:** VWGTI-PRO-VP-EA  
**Researched:** 2026-05-13  
**Scope:** MVP Phase 1 (XAUUSD + EURUSD on 5M/1M)  
**Confidence:** HIGH

---

## Executive Summary

The Volume Profile EA delivers a focused, disciplined swing trading system. Features are strictly scoped to **core functionality needed for production trading** — no feature bloat, no nice-to-haves, no speculative enhancements.

**MVP Philosophy:** Simplicity beats complexity. The EA does ONE thing exceptionally well: identify Volume Profile confirmation signals and execute with strict risk management.

---

## Table of Stakes Features

Features users expect. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Phase |
|---------|--------------|-----------|-------|
| **400-Bin Volume Profile Calculation** | Core trading foundation; professional standard granularity | Medium | MVP |
| **POC/VAH/VAL Identification** | Standard terminology; enables all entry/exit logic | Medium | MVP |
| **HVN/LVN Detection** | Professional analysis; Setup 2 depends entirely on this | Medium | MVP |
| **Setup 1: 80% Rule (Mean Reversion)** | Core entry signal for balanced markets | High | MVP |
| **Setup 2: HVN Edge Trading** | Core entry signal for momentum; volume spike validation | High | MVP |
| **Entry Execution (Market Orders)** | EA's primary purpose | Medium | MVP |
| **Exit Management: Partial TP (65/35 Split)** | Risk discipline; 65% first target, 35% final | High | MVP |
| **Stop Loss Placement (Sweep Low / Below LVN)** | Risk control; prevents VAL whipsaws | Medium | MVP |
| **Daily Hard Stop Loss (-2% Account)** | Behavioral risk; prevents revenge trading | Low | MVP |
| **Daily Profit Cap (+2-3% Account)** | Behavioral risk; locks wins | Low | MVP |
| **Risk-Percentage Position Sizing (0.6%)** | Professional risk management | Medium | MVP |
| **Trade Logging to Journal** | Compliance + debugging | Low | MVP |
| **Slippage Tolerance Control (50 pips)** | Execution quality; prevents rejections | Low | MVP |
| **Multi-Timeframe Context (5M/1M Alignment)** | Confirmation requirement per spec | High | MVP |
| **Session Context Storage (Previous Session)** | Setup 1 requires prior session's VA | High | MVP |

---

## MVP Core Features

**Phase 1 Implementation (Required):**

### Volume Profile Calculation
- 400-bin distribution with multi-level candle proration
- POC identification (highest volume bin)
- VAH/VAL calculation (70% cumulative expansion)
- HVN detection (local maxima > 85th percentile)
- LVN detection (local minima < 25th percentile)
- Market state classification (balanced vs imbalanced)
- Previous session profile storage (Setup 1 context)

### Trading Setups

**Setup 1: Value Area Mean Reversion (80% Rule)**
- Detect balanced market (VA width < 0.5x average range)
- Check price opened outside previous session VA
- Wait for confirmation candle closure inside VA
- Execute LONG (if opened below VAL) or SHORT (if opened above VAH)
- Target opposite extreme (VAH or VAL)

**Setup 2: HVN Edge Trading with Volume Confirmation**
- Detect LVN sweep (liquidity vacuum creation)
- Identify HVN edge proximity
- Recognize candle pattern (Hammer/Shooting Star/Doji)
- Confirm volume spike (≥1.3x previous candle)
- Execute with edge-to-edge targeting

### Risk Management
- Position sizing: Risk-percentage (0.6% per trade) or fixed lots
- Stop Loss: Below sweep low (Setup 1) or outside HVN (Setup 2)
- Take Profit: 65% first target + 35% opposite extreme
- Daily hard stop: -2% account loss → cease trading
- Daily profit cap: +2-3% account gain → secure wins
- Slippage tolerance: Max 50 points on execution
- Daily trade limit: Max 3 trades per day
- Friday hard close: 21:45 automatic position close

### Execution & Monitoring
- Market order execution (CTrade class)
- Async order processing (non-blocking)
- Trade logging to MT5 Journal
- Error handling with graceful degradation
- Broker connectivity checks
- Performance metrics logging

### Asset Support
- XAUUSD (Gold) with Tick Volume
- EURUSD (Forex) with Tick Volume
- 5M timeframe setup + 1M timeframe confirmation

---

## Anti-Features (Explicitly NOT Building)

| What | Why Avoid | Alternative |
|------|-----------|-------------|
| **Visual Dashboard / Chart Objects** | CPU overhead; breaks multi-chart operation | Use MT5 Journal + external dashboard (Phase 3) |
| **Custom VP Indicator Download** | Unnecessary dependency; adds visual rendering cost | Calculations embedded natively in EA |
| **Machine Learning Optimization** | Black-box trading (dangerous); fixed rules proven | Use validated 400-bin, 70% VA, 1.3x thresholds |
| **Trailing Stop Logic** | Out of scope; partial TP + hard stop sufficient | Standard SL/TP structure only |
| **Martingale Position Doubling** | Violates risk discipline; exponential drawdown risk | Fixed 0.6% sizing always |
| **Grid Trading / Averaging Down** | Against risk philosophy; violates "one position per asset" | Single entry only; no pyramiding |
| **Backtesting Engine** | MT5 Strategy Tester built-in | Use native MT5 backtest feature |
| **Advanced MTF Alignment (4H+)** | Phase 2+ enhancement; MVP is 5M/1M only | Start simple; expand later |
| **Cloud Sync / Real-Time Dashboard** | Over-engineering for MVP | Use local Journal + manual review |

---

## Success Criteria (MVP Phase)

### Functional Requirements
- [ ] POC/VAH/VAL calculated correctly (verify on 3+ candles manually)
- [ ] HVN/LVN nodes identified (match visual analysis)
- [ ] Setup 1 triggers on balanced market + confirmation
- [ ] Setup 2 triggers on HVN edge + pattern + volume
- [ ] Exits execute 65% TP + 35% final TP correctly
- [ ] Stop losses placed correctly (sweep low / outside HVN)
- [ ] Daily hard stop (-2%) prevents further trading
- [ ] Daily profit cap (+2-3%) closes positions
- [ ] Friday hard close executes at 21:45 broker time

### Testing Requirements
- [ ] Backtest EURUSD 5M (1 year): 20-50 trades minimum
- [ ] Backtest XAUUSD 5M (1 year): 20-50 trades minimum
- [ ] Win rate > 50%
- [ ] Profit factor > 1.5
- [ ] Max drawdown < 2% per day
- [ ] Slippage within 50-point tolerance

---

**Research Date:** 2026-05-13  
**Status:** FEATURES APPROVED FOR DEVELOPMENT
