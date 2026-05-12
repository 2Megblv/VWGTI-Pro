# Phase 2: Signal Detection & Execution - Context

**Gathered:** 2026-05-13  
**Status:** Ready for planning

---

<domain>

## Phase Boundary

**Setup 1 & 2 Entry Logic + Trade Execution + Partial Exit Management + Journal Logging**

This phase delivers end-to-end trade execution for both entry setups (Setup 1: 80% Rule Mean Reversion, Setup 2: HVN Edge Momentum). The EA detects market conditions (balanced vs. imbalanced via Value Area width), identifies entry signals algorithmically, executes trades at correct prices with strict slippage control, manages position exits via full edge-to-edge targeting, and logs all trades with complete audit trail.

**In Scope:**
- Setup 1 (80% Rule) detection: balanced market identification, gap detection, reclaim detection, confirmation candle validation, entry execution
- Setup 2 (HVN Edge) detection: LVN sweep detection, HVN edge identification, trigger pattern recognition (Hammer/Shooting Star/Doji), volume spike confirmation (≥1.3x)
- Entry order placement for both setups with 50-pip slippage rejection
- Full edge-to-edge TP targeting (opposite profile boundary) for both setups
- Stop loss placement (below sweep low for Setup 1, below LVN for Setup 2)
- Partial position management: 50-70% close at daily profit cap with SL adjustment, remainder runs to TP
- Daily hard stop (-2%) enforcement: force-close all positions + stop trading
- Daily profit cap (+5%) enforcement: close partial positions, move SL to profit, let remainder run
- Friday hard close (21:45) execution
- Market context switching: intelligently select Setup 1 (balanced) vs Setup 2 (imbalanced) based on VA width
- Full audit journal logging: entry details, setup type, exit details, P&L, risk/reward, slippage tracking
- Order rejection error handling with logging

**Out of Scope (Phase 3+):**
- Backtesting framework or historical performance analysis
- Live trading deployment or account validation
- Multi-asset expansion beyond Gold/EURUSD
- Indicator visualization or chart objects

</domain>

---

<decisions>

## Implementation Decisions

### Setup 1: 80% Rule Mean Reversion

**D-01: Balanced Market Detection Algorithm**
- **Approach:** Value Area width < 0.6–0.7x average recent range
- **Rationale:** When VA is narrow relative to recent price movement, market is consolidating (balanced). Setup 1 targets mean reversion in these conditions. Exact threshold (0.6x vs 0.7x) to be finalized during implementation based on backtest sensitivity.
- **Downstream Impact:** Determines when Setup 1 signals are evaluated vs. Setup 2 ignored. Critical for market context switching.

**D-02: Confirmation Candle Entry Execution**
- **Approach:** Market order immediately on confirmation candle close
- **Rationale:** Once a candle closes fully inside VA (proving acceptance, not just a wick touch), entry signal is triggered immediately. No pullback wait needed. Fast execution captures mean reversion momentum.
- **Execution:** Place BUY/SELL market order at or immediately after close of confirmation bar. Accept market price at that moment.
- **Downstream Impact:** Entry timing is precise and immediate. Slippage tolerance (D-07) applies.

**D-03: Setup 1 Take Profit Target**
- **Approach:** Full edge-to-edge targeting to opposite Value Area extreme
- **Rationale:** Once market accepts back into VA (balanced condition), it rotates to the opposite extreme (VAH for LONG, VAL for SHORT) majority of the time. Full position targets opposite edge rather than partial split.
- **No Partial TP:** Previous requirement of 65%/35% partial TP is replaced with single unified edge-to-edge target.
- **Downstream Impact:** Single TP order per position, cleaner position tracking.

### Setup 2: HVN Edge Momentum

**D-04: Trigger Pattern + Volume Spike Validation**
- **Approach:** Three conditions must align: (1) Reversal candle pattern at HVN boundary (Hammer for LONG, Shooting Star for SHORT, Doji for either), (2) Volume ≥1.3x previous candle, (3) Full candle closure (no front-running on open)
- **Pattern Thresholds:** Claude discretion during implementation for exact body/wick ratios
- **Rationale:** Trigger patterns indicate institutional participation. Volume spike (1.3x) confirms conviction. Full closure prevents false entries.
- **Downstream Impact:** High-conviction entry signals. Reduces false triggers vs. pattern-only or volume-only detection.

**D-05: Setup 2 Entry Order Placement**
- **Approach:** Market order immediately on trigger candle close
- **Rationale:** Once trigger candle closes with volume confirmation at HVN edge, entry is executed at market. No pullback wait. Captures momentum into opposite profile edge.
- **Execution:** Place BUY/SELL market order at or immediately after close of trigger bar.
- **Downstream Impact:** Same as D-02 — immediate execution subject to slippage tolerance.

**D-06: Setup 2 Take Profit Target**
- **Approach:** Full edge-to-edge targeting to opposite profile boundary
- **Rationale:** HVN Edge trades target the opposite structural boundary. Price rotates across balanced zones rapidly through low-volume fast lanes. Full position rides to opposite edge rather than partial exits.
- **No Partial TP:** Same as D-03.
- **Downstream Impact:** Single unified TP per position.

### Execution & Risk Control

**D-07: Slippage Tolerance & Rejection**
- **Approach:** Reject any order fill that deviates >50 pips from intended entry price
- **Rationale:** Slippage >50 pips indicates liquidity absence or execution problems. Reject to preserve risk/reward ratio. Skip the trade; wait for next setup.
- **Logging:** Log rejected orders with reason and intended vs. actual price to Journal.
- **Downstream Impact:** No "bad slippage" trades execute. Preserves strategy integrity.

**D-08: Position Limit per Asset (Market Context Switching)**
- **Approach:** Max 1 position per asset at a time. EA intelligently switches Setup 1 ↔ Setup 2 based on market condition (VA width)
- **Rationale:** Only one strategy is optimal for current market state. Balanced = Setup 1 active. Imbalanced = Setup 2 active. No simultaneous Setup 1+2 positions on same asset.
- **Implementation:** At each bar, calculate VA width. If balanced → watch for Setup 1 signals, ignore Setup 2. If imbalanced → watch for Setup 2 signals, ignore Setup 1. Close existing position if market context flips.
- **Downstream Impact:** Single, coherent strategy per market condition. Eliminates conflicting signals.

**D-09: Daily Hard Stop Loss (-2% Account Loss)**
- **Approach:** When cumulative daily loss reaches -2% of account balance, force-close ALL open positions + cease all trading for remainder of session
- **Rationale:** Prevents emotional revenge trading and uncontrolled drawdown. Non-negotiable hard stop (same as Phase 1 concept, now enforced).
- **Execution:** Check daily P&L at each OnTick. If cumulative loss ≤ -2%, immediately close all positions at market + set trading halt flag until session reset.
- **Downstream Impact:** Daily losses capped at -2%. Account protected.

**D-10: Daily Profit Cap (+5% Account Gain)**
- **Approach:** When cumulative daily profit reaches +5%, execute tiered position management: (1) Close 50–70% of positions, (2) Move SL of remainder into profit (breakeven or +5–10 pips), (3) Let remainder ride to TP, (4) Stop accepting new trades
- **Rationale:** Locks wins at +5% while allowing final positions to extend for larger wins. Disciplined profit taking with upside optionality.
- **Execution:** Check daily P&L at each OnTick. When +5% reached, close majority, adjust SL upward, set flag to block new entries.
- **Downstream Impact:** Daily wins secured at +5% milestone with potential for larger wins on remainder.

**D-11: Friday Hard Close (21:45 Broker Server Time)**
- **Approach:** At 21:45 Friday broker server time, force-close all open positions
- **Rationale:** Prevents weekend gap risk (Sunday market open could gap dramatically). All capital in cash Friday evening.
- **Execution:** Time check at OnTick Friday. If time ≥ 21:45, close all positions at market immediately.
- **Downstream Impact:** No weekend gap exposure.

### Journal Logging & Audit

**D-12: Full Audit Trail Logging**
- **Approach:** Log all trades with complete details: entry (time, symbol, direction, price, lot size), setup type (Setup 1 or 2), exit (time, exit price, exit reason: TP/SL/Daily Limit/Friday Close), realized P&L (pips + currency), SL price, TP price, R:R ratio, slippage (if any)
- **Rationale:** Complete audit trail for post-trade analysis, strategy validation, and compliance. Enables win rate, profit factor, and performance tracking.
- **Logging Format:** One line per trade in Journal. Structured: timestamp | symbol | direction | entry_price | lot_size | setup_type | exit_time | exit_price | exit_reason | P&L_pips | P&L_currency | SL_price | TP_price | RR_ratio | slippage_pips
- **Downstream Impact:** Full traceability for Phase 3 backtesting metrics (win rate, profit factor, max drawdown).

**D-13: Order Rejection & Error Handling**
- **Approach:** If order placement fails (broker rejection, connection loss, etc.), log error to Journal with timestamp, intended price, reason code, and trade details. Retry mechanism (frequency, backoff strategy) left to Claude discretion during implementation.
- **Rationale:** Errors are tracked and visible for post-trading analysis. Enables debugging and strategy refinement.
- **Retry Logic:** Recommended: exponential backoff (retry at next tick, then +1 tick, then +2 ticks, etc.) up to 3 attempts if signal still valid.
- **Downstream Impact:** Operational visibility. No silent failures.

### Claude's Discretion

- **Balanced Market Threshold Tuning:** Exact value within 0.6–0.7 range may shift during backtest. Reasonable engineering choice.
- **Retry Logic Detail:** Backoff frequency, max attempts, timeout conditions if signal validity expires.
- **Partial Close Percentage:** 50–70% range for D-10. Exact percentage to optimize for win rate / profit factor during implementation.
- **SL Adjustment Formula:** When moving SL into profit (D-10), exact formula (breakeven vs. +5–10 pips) reasonable engineering choice.
- **Pattern Threshold Details:** Exact Hammer/Shooting Star/Doji body/wick ratios (e.g., wick >2x body) to be defined during implementation.

</decisions>

---

<canonical_refs>

## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Volume Profile Entry Logic (Setup 1 & 2)
- `.planning/PROJECT.md` §Trading Setups — Setup 1 (80% Rule) and Setup 2 (HVN Edge) detailed specifications
- `.planning/REQUIREMENTS.md` §Setup 1 & 2 & Exit & Position Management — REQ-011–028 acceptance criteria
- `docs/Volume Profile Trading Handbook/MT5 Volume Profile Analysis and Execution Strategy.pdf` — Professional trading methodology reference
- `docs/Volume Profile Trading Handbook/Swing Volume Profile - Pine Script/Swing Volume Profile Indicator.pdf` — Calculation reference for VAL/VAH/HVN/LVN concepts

### Execution & Risk Management
- `.planning/ROADMAP.md` — Phase 2 success criteria (Setup execution, partial TP, logging, slippage validation)
- `.planning/PROJECT.md` §Risk Framework — Position sizing, daily limits, Friday close
- `.planning/REQUIREMENTS.md` §Position Sizing & Risk Management — REQ-029–035 (carried from Phase 1)

### Logging & Monitoring
- `.planning/REQUIREMENTS.md` §Execution & Monitoring — REQ-038–042 (Journal logging, slippage tolerance, broker connectivity, error recovery, metrics)

### Phase 1 Integration
- `.planning/phases/01-volume-profile-core/01-CONTEXT.md` — Phase 1 decisions on profile calculation, risk constants, code structure (refactored to modules before Phase 2 implementation)

</canonical_refs>

---

<code_context>

## Existing Code Insights

### From Phase 1 (Reusable)
- **Volume Profile Arrays:** POC, VAH, VAL, HVN[], LVN[] calculated and stored in Phase 1. Available for Phase 2 signal detection.
- **Position Sizing Constants:** Risk percentage (0.6%), daily hard stop (-2%), daily profit cap (+5%), Friday close time (21:45) defined in Phase 1. Phase 2 reads these for order sizing and enforcement.
- **Daily Reset Logic:** Session boundary (Tokyo open, 00:00 SGT) defined in Phase 1. Phase 2 uses same boundary for daily P&L tracking.

### Established Patterns (from Phase 1)
- **Array-based storage:** No visual objects. All calculations and position state in arrays for performance.
- **Event-driven updates:** OnTick recalculates profiles and checks entry signals.
- **Risk tracking:** Daily P&L accumulated; flags set when limits hit.

### Integration Points (Phase 2 → Phase 1)
- **Read profile levels:** Use VAH, VAL, HVN[], LVN[] from Phase 1 calculations for entry detection.
- **Position sizing:** Use risk percentage constant from Phase 1 to calculate lot size = (Balance × 0.6%) / (SL pips × point value).
- **Daily reset:** Use Phase 1 session boundary to reset daily P&L counter.
- **Refactor before Phase 2 starts:** Phase 1 code should be split into modules (VolumeProfile.mqh, RiskManager.mqh, Utils.mqh) for cleaner Phase 2 integration.

### New Code Patterns (Phase 2)
- **Market context switching:** Function to detect balanced vs. imbalanced (VA width calculation).
- **Setup 1 detection:** Function to identify balanced market, gap, reclaim, confirmation candle.
- **Setup 2 detection:** Function to identify LVN sweep, HVN edge, trigger pattern + volume.
- **Order placement:** CTrade wrapper for market orders with slippage validation and retry logic.
- **Position state machine:** Track OPEN → PARTIAL_CLOSED → FULLY_CLOSED or equivalent tracking method (remaining lots).
- **Journal logging:** Structured format with all audit details per trade.

</code_context>

---

<specifics>

## Specific Implementation Notes

### Setup 1: Confirmation Candle Definition
- **Confirmation:** A candle that fully closes (not just wick touch) inside the Value Area after price opens outside VA and reclaims back in.
- **No Wick Trades:** Entry is only triggered when the actual close price is inside VA, not when a wick touches VA and rejects.

### Setup 2: Trigger Pattern Criteria
- **Hammer (LONG):** Close near high of candle, lower wick significantly longer than body (typically >2x body length). Indicates reversal up.
- **Shooting Star (SHORT):** Close near low of candle, upper wick significantly longer than body. Indicates reversal down.
- **Doji (Either direction):** Open ≈ close (within ~1 pip), wicks extending both directions. Indicates indecision that can resolve either way.
- **Volume Requirement:** Trigger candle volume must be ≥1.3x previous candle volume (30% minimum spike).
- **Location:** Trigger pattern must form AT the HVN edge (price proximity to high-volume cluster).

### Entry Price Precision
- **Market Orders:** Execute at market price at close of confirmation or trigger bar. Accept whatever fill price the broker provides, subject to 50-pip slippage tolerance.
- **Rounding:** Entry prices rounded to nearest pip (0.01 for XAUUSD, 0.0001 for EURUSD).

### Stop Loss Placement
- **Setup 1:** Below the sweep low (the lowest price when price swept outside VA), not at VAL. Typically 5–15 pips below sweep low. Prevents whipsaw stops.
- **Setup 2:** Below LVN sweep low. Protects against structural failure.

### Take Profit Target
- **Both Setups:** Single TP target at opposite profile boundary. No partial 65%/35% split. Full position runs to opposite extreme.
- **Setup 1 LONG TP:** VAH (Value Area High)
- **Setup 1 SHORT TP:** VAL (Value Area Low)
- **Setup 2 LONG TP:** Opposite edge of profile (if entry is at lower HVN, TP is highest significant level)
- **Setup 2 SHORT TP:** Opposite edge of profile

### Risk/Reward Calculation
- **Formula:** RR Ratio = (TP distance in pips) / (SL distance in pips)
- **Minimum Acceptable:** RR ≥ 1.5 (risk 1 to make 1.5) recommended for positive expectancy
- **Log:** Include RR ratio in journal entry for each trade

### Daily Limit Enforcement Asymmetry
- **Hard Stop (-2%):** Strict. Force-close all positions. Stop all trading.
- **Profit Cap (+5%):** Flexible. Close 50–70%, adjust SL to profit, let remainder run. Stop new entries but let existing positions finish naturally.
- **Rationale:** Hard stop is risk management (fear). Profit cap is opportunity management (greed balance); let winners extend.

### Position State After Daily Limits
- **After -2%:** Set flag `DailyHardStopHit = true`. New orders blocked until session reset.
- **After +5%:** Set flag `DailyProfitCapReached = true`. New orders blocked. Existing positions continue.
- **Session Reset:** At next session boundary (Tokyo open), clear both flags. Resume normal trading.

### Friday Hard Close
- **Time Check:** At OnTick, evaluate broker server time. If Friday AND time ≥ 21:45, force-close all.
- **Timezone:** Broker server time (typically GMT or NY time depending on broker). Confirm broker's timezone convention.

### Symbol Support
- **XAUUSD (Gold):** Micro lot (0.01 per lot = 0.01 ounce). 5M/1M timeframes. Typical point value 0.01, pip width 0.1.
- **EURUSD:** Standard lots. 5M/1M timeframes. Typical point value 0.0001, pip width 0.0001.
- **Point Value:** Calculate correctly for each symbol. Critical for position sizing formula.

### Slippage Tolerance Detail
- **50-pip threshold:** If intended entry price is 1.3500 (Gold), and broker fills at 1.3550 or worse, reject.
- **Logging:** Record intended price, actual fill, slippage amount, rejection reason.

### Order Rejection & Retry
- **Trigger:** OrderSend() returns error code (e.g., ERR_TRADE_DISABLED, ERR_INSUFFICIENT_FUNDS, ERR_NO_MONEY).
- **Logging:** Log error code, trade details, timestamp to Journal immediately.
- **Retry:** Recommended exponential backoff (next tick, +1 tick, +2 ticks) up to 3 attempts if setup signal still valid.
- **Abort:** After 3 failed attempts or signal expiry (e.g., next bar closes), skip the trade.

</specifics>

---

<deferred>

## Deferred Ideas

**Multi-timeframe confirmation (1H/4H alignment)** — Phase 2+ enhancement. Current phase uses 5M/1M only. Higher timeframe filter can improve signal quality in future.

**Adaptive parameter optimization** — Phase 4+. 400-bin, 70% VA, 1.3x volume threshold locked in v1 MVP. No tuning in Phase 2.

**Advanced error recovery** — Phase 3+. Current phase logs errors and retries simply. Advanced recovery (e.g., partial fills, reroute orders) deferred.

**News event filtering** — Phase 4+. Manual filtering sufficient. Automated news API integration out of scope.

**Performance dashboard** — Phase 4+. Journal logging sufficient for MVP. Visual reporting dashboard deferred.

</deferred>

---

*Phase: 02-signal-detection-execution*  
*Context gathered: 2026-05-13*
