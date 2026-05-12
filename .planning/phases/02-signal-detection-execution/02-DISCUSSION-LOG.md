# Phase 2: Signal Detection & Execution - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the discussion flow and alternatives considered.

**Date:** 2026-05-13  
**Phase:** 02-signal-detection-execution  
**Mode:** Interactive discussion  
**Participants:** User (trader/visionary), Claude (builder)

---

## Discussion Summary

Phase 2 context was gathered through focused discussion on 5 critical implementation areas:

1. **TP Structure Clarification** — Initial Phase 2 requirements specified 65%/35% partial TP split, but user's research materials indicated full edge-to-edge targeting per Volume Profile methodology. Confirmed both Setup 1 and Setup 2 use full edge-to-edge TP (no partial split).

2. **Entry Execution Timing** — For both setups, established immediate market order execution on confirmation bar close (no pullback wait, no next-bar delay). Fast execution maximizes capture of mean reversion (Setup 1) and momentum (Setup 2).

3. **Daily Limit Behavior** — Asymmetric enforcement: Hard stop (-2%) force-closes all positions. Profit cap (+5%) closes 50–70% of positions, moves SL to profit, lets remainder run. Reflects risk management (fear) vs. opportunity management (greed).

4. **Slippage Tolerance** — Strict 50-pip rejection. If order fill deviates >50 pips from intended, trade is rejected entirely. Preserves risk/reward integrity.

5. **Market Context Switching** — EA intelligently switches Setup 1 ↔ Setup 2 based on Value Area width (balanced vs. imbalanced). Only one position per asset at a time.

---

## Area 1: TP Structure (Partial vs. Full Edge-to-Edge)

| Question | Options Presented | User Selection | Rationale |
|----------|---|---|---|
| "Should both setups use different TP structures, or the same?" | Setup 1: full + Setup 2: full; Setup 1: partial + Setup 2: full; Both: partial | **Both setups: full edge-to-edge** | User's research materials (Volume Profile Trading Handbook) confirm edge-to-edge rule for both setups. Partial TP (65%/35%) was initially proposed but contradicts professional methodology. |

**Key Clarification:** The 65% figure in Phase 2 requirements was misinterpreted. It refers to an aggressive win rate target from backtesting, NOT a partial TP split. Phase 2 will implement full edge-to-edge targeting for both setups.

---

## Area 2: Setup 1 Entry Timing

| Question | Options Presented | User Selection | Context |
|----------|---|---|---|
| "When should Setup 1 BUY/SELL order be placed after confirmation candle close?" | Immediately (market); Limit order at close; Next bar open | **Immediately at market price** | Confirmation candle closure = acceptance proven. Entry triggered right then. No pullback needed. Fast execution. |

**Execution Method:** Market order at or immediately after close of confirmation bar. Accept market price at that moment. Subject to 50-pip slippage tolerance (Area 4).

---

## Area 3: Daily Limit Enforcement

| Question | Options Presented | User Selection | Details |
|----------|---|---|---|
| "Hard stop (-2%) and profit cap (+5%) behavior?" | Force-close all; Stop new trades only; Different logic per limit | **Asymmetric: Hard stop force-closes all; Profit cap closes 50–70% + adjusts SL + lets remainder run** | Hard stop = risk protection (strict). Profit cap = opportunity protection (flexible). Reflects trading psychology. |

**Hard Stop (-2%):** 
- Force-close ALL open positions immediately.
- Set trading halt flag until session reset.
- Non-negotiable.

**Profit Cap (+5%):**
- Close 50–70% of open positions (lock wins).
- Move SL of remainder into profit (breakeven or +5–10 pips).
- Let remaining position(s) run to full TP.
- Stop accepting new trades but allow existing to complete.

---

## Area 4: Slippage Tolerance & Order Rejection

| Question | Options Presented | User Selection | Rationale |
|----------|---|---|---|
| "If order fill exceeds 50-pip slippage tolerance?" | Reject entirely; Execute + immediate exit; Execute + adjust TP; Decide during implementation | **Reject entirely** | Slippage >50 pips indicates execution problem or liquidity absence. Trade rejected. Wait for next setup. Preserves risk/reward ratio. |

**Order Rejection Handling:**
- Log error code, intended price, actual fill, reason to Journal.
- Retry logic (frequency, backoff) left to Claude discretion.
- Recommended: Exponential backoff (retry at tick, +1 tick, +2 ticks) up to 3 attempts if signal still valid.
- Abort after 3 failures or signal expiry.

---

## Area 5: Setup 2 Entry & Market Context Switching

| Question | Options Presented | User Selection | Details |
|----------|---|---|---|
| "Setup 2 entry order placement at HVN edge?" | Market immediately; Limit at close; Market next bar | **Market order immediately on trigger candle close** | Same as Setup 1. Trigger pattern validation + 1.3x volume must be confirmed (full candle close), then entry at market. No pullback wait. |
| "Setup 1 + Setup 2 concurrent positions on same asset?" | Both allowed; Max 2 (one each); Max 1 per asset | **Max 1 per asset. EA switches Setup 1 ↔ Setup 2 based on market condition** | Value Area width determines strategy: narrow = balanced = Setup 1 active. Wide = imbalanced = Setup 2 active. Only one strategy optimal per market state. |

**Market Context Switching (Adaptive Auto Strategy):**
- At each OnTick, calculate VA width.
- If VA < 0.6–0.7x recent range → market is balanced → Setup 1 active, Setup 2 ignored.
- If VA ≥ 0.6–0.7x recent range → market is imbalanced → Setup 2 active, Setup 1 ignored.
- If existing position, close if market context flips.

---

## Area 6: Setup 2 Trigger Pattern Recognition

| Question | Options Presented | User Details Provided |
|----------|---|---|
| "How should Hammer/Shooting Star/Doji trigger patterns be validated?" | Exact thresholds; Volume-only; Pattern + volume required | **Pattern + volume (both required together).** Hammer: reversal pattern at HVN edge, close near high, lower wick >2x body. Shooting Star: close near low, upper wick >2x body. Doji: open ≈ close, wicks both directions. PLUS volume ≥1.3x previous candle. ALL conditions on same candle. |

**Validated Candle Close Requirement:** Full candle closure (no front-running on open). Pattern + volume confirmed only after close.

---

## Area 7: Journal Logging Detail

| Question | Options Presented | User Selection |
|----------|---|---|
| "What should be logged for each trade?" | Full audit; Essential only; Minimal | **Full audit:** Entry (time, symbol, direction, price, lot size), setup type, exit (time, price, reason), P&L (pips + currency), SL price, TP price, R:R ratio, slippage |

**Log Format (Recommended):**
```
TIMESTAMP | SYMBOL | DIRECTION | ENTRY_PRICE | LOT_SIZE | SETUP_TYPE | EXIT_TIME | EXIT_PRICE | EXIT_REASON | PL_PIPS | PL_CURRENCY | SL_PRICE | TP_PRICE | RR_RATIO | SLIPPAGE_PIPS
```

**Exit Reasons:** TP, SL, Daily Hard Stop, Daily Profit Cap, Friday Close

---

## Area 8: Balanced Market Detection Threshold

| Question | Options Presented | User Selection |
|----------|---|---|
| "VA width threshold for balanced market detection?" | <0.5x (strict); <1.0x (loose); Decide during implementation (0.6–0.7 range) | **0.6–0.7 range, finalize during implementation** | Balance between strict consolidation signal (0.5x) and loose range (1.0x). Exact value refined during backtest validation. |

**Calculation:**
- Recent average range = ATR or manual N-bar average range
- Balanced market = VA width < (0.6 to 0.7) × recent average range
- Threshold refined during Phase 3 backtesting for win rate sensitivity

---

## Notes & Clarifications

### Key Research Materials Referenced
- User referenced `docs/Volume Profile Trading Handbook/MT5 Volume Profile Analysis and Execution Strategy.pdf`
- User referenced `docs/Volume Profile Trading Handbook/Swing Volume Profile Indicator.pdf` for calculation validation
- These materials provided professional methodology confirmation and reconciled Phase 2 requirements with actual trading strategy

### Critical Insight: Methodology Reconciliation
Original Phase 2 requirements specified "Partial TP structure executes (65% at first resistance, 35% at Value Area opposite extreme)" but this contradicted the edge-to-edge rule from professional Volume Profile sources. User's research confirmed:
- Setup 1 (80% Rule): Target opposite VA extreme (full edge-to-edge)
- Setup 2 (HVN Edge): Target opposite profile boundary (full edge-to-edge)
- No partial TP split. Single unified target per setup.

### Deferred Items
- Advanced retry/recovery logic (Phase 3+)
- Multi-timeframe confirmation filters (Phase 2+ enhancement)
- Parameter optimization / tuning (Phase 4+)
- News event filtering (Phase 4+)

---

## Summary of Decisions Locked

| Decision | Locked Value | Impact |
|----------|---|---|
| TP Structure | Full edge-to-edge (both setups) | Single TP target per position |
| Entry Timing | Immediate market order on bar close | Fast execution, subject to slippage check |
| Slippage Tolerance | Reject if >50 pips | Trade security; avoids bad fills |
| Daily Hard Stop | Force-close all + stop trading | Strict risk cap (-2%) |
| Daily Profit Cap | Close 50–70% + adjust SL + let remainder run | Opportunity balance (+5%) |
| Position Limit | Max 1/asset. Adaptive switch Setup 1 ↔ 2 | Single coherent strategy per market state |
| Journal Logging | Full audit trail (12 fields) | Complete traceability for Phase 3 validation |
| Balanced Market Threshold | 0.6–0.7x recent range (finalize during implementation) | Trigger point for Setup 1 vs. Setup 2 |

---

*Discussion completed: 2026-05-13*  
*Status: All gray areas resolved. Ready for planning phase.*
