# Phase 1: Volume Profile Core - Context

**Gathered:** 2026-05-13  
**Status:** Ready for planning

---

<domain>

## Phase Boundary

**Volume Profile Engine + Risk Management Framework**

This phase delivers the foundational calculation engine for the EA: accurate 400-bin volume profile with POC/VAH/VAL/HVN/LVN detection, plus position sizing and daily risk limit enforcement. No entry/exit logic (deferred to Phase 2). Trader can attach EA to XAUUSD/EURUSD charts and see correct position sizing, daily limit enforcement, and risk framework working correctly.

**In Scope:**
- 400-bin volume distribution calculation from 150-bar lookback
- POC (Point of Control) identification
- VAH/VAL (Value Area High/Low) calculation at 70% cumulative volume
- HVN (High Volume Node) detection — price magnets
- LVN (Low Volume Node) detection — liquidity vacuums
- Position sizing formula: (Account Balance × 0.6%) / (SL distance × Point value)
- Daily hard stop loss: -2% account loss → cease all trading
- Daily profit cap: +5% account gain → close all positions
- Friday hard close: All positions closed at 21:45 broker server time
- Support for Gold (XAUUSD) and EURUSD on 5M/1M timeframes

**Out of Scope (Phase 2+):**
- Setup 1 (80% Rule Mean Reversion) entry logic
- Setup 2 (HVN Edge Momentum) entry logic
- Trade execution and order placement
- Journal logging of trades
- Multi-asset expansion (Oil, GBPJPY, DAX)

</domain>

---

<decisions>

## Implementation Decisions

### Volume Profile Calculation

**D-01: Volume Proration Method**
- **Approach:** Proportional to range
- **Rationale:** When a single candle spans multiple price bins, distribute its volume based on the actual price distance of the body and wicks within the candle's range. Body volume allocated to the body's price extent, wick volume allocated to wick extents. More accurate than fixed percentage splits (60/40) because it adapts to candle shape.
- **Downstream Impact:** Affects POC/VAH/VAL precision. Directly impacts Phase 2 entry signal accuracy.

### HVN/LVN Detection

**D-02: Node Detection Algorithm**
- **Approach:** Local clustering (exact peak detection)
- **Rationale:** Identify local maxima (peaks) and minima (valleys) in the 400-bin volume distribution. Mark tight clusters around each peak/valley as HVN/LVN zones. Most accurate method for identifying price magnets and liquidity vacuums. Accuracy prioritized over calculation speed in Phase 1 (validation phase).
- **Performance:** Acceptable for Phase 1; no hard latency constraint. Optimization deferred to Phase 2 if needed.
- **Downstream Impact:** Phase 2 signal detection (Setup 2) depends on accurate HVN/LVN identification for entry targeting.

### Risk Framework

**D-03: Position Sizing Inputs**
- **Approach:** Hardcoded constants (not user-editable in Phase 1)
- **Rationale:** 0.6% risk per trade, -2% daily hard stop, +5% daily profit cap locked as code constants. Simplest approach during validation phase. Flexibility to expose these as EA input parameters deferred to Phase 2 if trader wants live adjustment.
- **Constants:**
  - Risk percentage: 0.6% of account balance per trade
  - Daily hard stop: -2% (all trading halted, positions not forcefully closed yet)
  - Daily profit cap: +5% (all open positions closed to lock wins)
  - Friday close time: 21:45 broker server time
- **Downstream Impact:** Phase 2 execution logic (CTrade order placement) will read these constants for actual order sizing.

**D-04: Daily Limit Session Boundary**
- **Approach:** Session-based reset at market open (configurable, default: Tokyo Session 00:00 SGT)
- **Rationale:** Hard-coded reset time aligns with actual trading windows. Daily P&L tracked from session open to session close. Ensures consistency with trading logic.
- **Implementation Note:** Drawdown tracking accumulates daily loss from session open. When -2% breached, set a flag (do NOT close positions in Phase 1; Phase 2 will handle actual position closure). Profit cap works similarly: when +5% reached, set flag; Phase 2 executes position closure.

### Code Structure & Testing

**D-05: Code Organization**
- **Approach:** Single .mq5 file in Phase 1, refactored to modular .mqh includes before Phase 2
- **Rationale:** Keeps Phase 1 focused and unblocks development quickly. All code (Profile engine, Risk manager, helpers) in one file. Before Phase 2 begins, refactor into separate modules (VolumeProfile.mqh, RiskManager.mqh, Utils.mqh, main EA.mq5) for maintainability as complexity grows.
- **Downstream Impact:** Phase 2 development will be cleaner if modules already separated.

**D-06: Unit Test Strategy**
- **Approach:** Hybrid validation
  1. **Embedded Unit Tests:** Add test scenarios to EA initialization (OnInit). Hard-code known volume distributions (test fixtures), calculate POC/VAH/VAL/HVN/LVN, compare against expected values. Print results to Journal for verification.
  2. **Manual Backtest Validation:** Run EA on 1-month historical backtest (XAUUSD + EURUSD combined). Manually verify that calculated profile levels (POC, VAH, VAL) match chart analysis or reference calculations. Spot-check 10-15 bars to confirm accuracy within ±1 pip.
- **Coverage Target:** 90%+ coverage via combination of both unit tests (code path coverage) + integration validation (real data accuracy).
- **Success Criteria:** 
  - All POC calculations match manual chart analysis within ±1 pip
  - VAH/VAL expansion calculations accurate to ±1-2 pips
  - HVN/LVN detection identifies realistic price levels (no spurious clusters)
  - Zero crashes or exceptions during 1-month backtest
  - All daily limits (hard stop -2%, profit cap +5%) activate correctly

### Claude's Discretion

- **Multi-level candle edge cases:** If a candle's close price lands exactly on a bin boundary, Claude may choose to allocate rounding volume to adjacent bins or apply deterministic rounding rules. Not specified; reasonable engineering choice.
- **HVN/LVN threshold sensitivity:** If peak detection produces excessive clusters (e.g., 50+ HVN zones), Claude may add a minimum cluster size filter (e.g., clusters must span ≥2 consecutive bins). Reasonable optimization during implementation.

</decisions>

---

<canonical_refs>

## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Volume Profile Theory & Calculation
- `.planning/PROJECT.md` §Core Algorithms — Official calculation specifications (POC, VA 70%, HVN/LVN detection)
- `.planning/REQUIREMENTS.md` — All Phase 1 acceptance criteria (REQ-001–010, REQ-029–037)
- `docs/Volume Profile Trading Handbook/Volume_Profile_EA_Code_Framework.mq5` — Reference MQL5 implementation patterns

### Risk Management Framework
- `.planning/PROJECT.md` §Risk Framework — Position sizing formula, daily limits, Friday hard close logic
- `.planning/REQUIREMENTS.md` §Position Sizing & Risk Management — REQ-029–035 specifications

### MT5 Platform Details
- `.planning/PROJECT.md` §Technical Implementation — Tick Volume (MT5 native), array storage (no visual objects), performance requirements
- `.planning/REQUIREMENTS.md` §Execution & Monitoring — REQ-036–037 (symbol support), REQ-040 (broker connectivity checks)

### Architecture Reference
- `.planning/ROADMAP.md` — Phase dependencies and success criteria for Phase 1

</canonical_refs>

---

<code_context>

## Existing Code Insights

### Reference Materials
- **Volume_Profile_EA_Code_Framework.mq5** — Located in `docs/Volume Profile Trading Handbook/`. Provides MQL5 pattern examples for array handling, calculation structure. Use as a starting point for understanding MT5 idioms (struct definitions, array management). This is reference material only; Phase 1 will build from scratch.

### Established Patterns
- **Array-based storage:** No visual objects (Chart objects avoided). All profile data, levels, and calculations stored in double[] or struct arrays for performance.
- **Event-driven calculation:** Volume profile recalculated at OnTick (on new bar close). Efficient refresh via delta updates where possible.
- **Risk tracking:** Separate arrays for daily P&L, position state, drawdown history.

### Integration Points (for Phase 2)
- **Entry Logic:** Phase 2 will read calculated POC/VAH/VAL/HVN/LVN arrays and trigger Setup 1 & 2 logic.
- **Order Placement:** Phase 2 will use position sizing constants and risk limits from Phase 1 to calculate CTrade lot sizes.
- **Daily Reset:** Phase 2 execution will clear position arrays at session reset (same boundary as Phase 1 drawdown tracking).

</code_context>

---

<specifics>

## Specific Requirements & Implementation Notes

### Volume Profile Precision
- **400 bins:** Discrete price levels from Highest High - Lowest Low across 150-bar lookback. No fractional bins.
- **POC Definition:** Single price level (bin) with the absolute highest accumulated volume across all lookback bars. If tie exists, use the first (highest-price) bin with maximum volume.
- **VAH/VAL Calculation:** From POC, expand upward and downward to capture exactly 70% of total volume. If 70% cannot be reached exactly, accept the bin where cumulative % is closest to 70% without dropping below 70%. VAH = highest bin in VA, VAL = lowest bin in VA.
- **Rounding:** All price levels rounded to nearest pip (for Gold/FX, 0.01 or 0.001 depending on pair). No fractional pips in output.

### HVN/LVN Sensitivity
- **HVN Definition (per requirements):** Local volume peaks > 85th percentile of the 400-bin distribution.
- **LVN Definition (per requirements):** Local volume valleys < 25th percentile.
- **Implementation Clarification:** Local clustering may identify these percentiles within clusters (not globally), or use a sliding window approach. Claude discretion: as long as identified levels are realistic price magnets/vacuums and match the 85%/25% concept, implementation is acceptable.

### Risk Limits Enforcement (Phase 1 Responsibility)
- **Daily Loss Tracking:** Accumulate realized + unrealized P&L from session open. When cumulative loss reaches -2% of account balance, set a flag: `dailyHardStopHit = true`. Do NOT close positions in Phase 1; that's Phase 2's responsibility. Just enforce the flag logic.
- **Daily Profit Cap Tracking:** Similarly, when cumulative gain reaches +5%, set flag: `dailyProfitCapReached = true`. Phase 2 will close all positions when this flag is true.
- **Position Sizing:** Formula = (Account Balance × 0.6%) / (SL distance in points × Point Value). Calculate per trade; Phase 2 will use this for CTrade.SendBuy/SendSell lot size.

### Friday Hard Close
- **Implementation:** At 21:45 broker server time, any open positions must be closed. Phase 1 won't execute closes, but Phase 2 will check this time daily and close on Friday.

### Symbol Support
- **XAUUSD:** Gold, micro-sized (0.01 per lot = 0.01 ounce). 5M/1M setup and confirmation.
- **EURUSD:** Forex pair, standard lot sizing. 5M/1M setup and confirmation.

</specifics>

---

<deferred>

## Deferred Ideas

**Multi-timeframe confirmation (1H/4H alignment)** — Mentioned in PROJECT.md as v2+ enhancement. Requires live data validation; Phase 1 focuses on single-timeframe calculation accuracy first.

**Adaptive strategy selection (auto balanced/imbalanced detection)** — Proposed for Phase 2 enhancement. Phase 1 just calculates profile; Phase 2 will detect market condition based on VA width.

**News event filtering** — Out of scope per PROJECT.md. External dependency; manual filtering sufficient for MVP.

**Parameter optimization** — Deferred to Phase 4+. Phase 1 locks 400-bin, 70% VA, 1.3x threshold; no tuning in MVP.

**Multi-asset expansion (Oil, GBPJPY, DAX, Nasdaq)** — Phase 4 milestone. Phase 1 focuses on Gold + EURUSD validation.

</deferred>

---

*Phase: 01-volume-profile-core*  
*Context gathered: 2026-05-13*  
*Status: Ready for Phase 1 Planning*
