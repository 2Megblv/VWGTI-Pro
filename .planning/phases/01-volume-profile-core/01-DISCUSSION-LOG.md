# Phase 1: Volume Profile Core - Discussion Log

> **Audit trail only.** Decisions are captured in CONTEXT.md — this log preserves the alternatives considered and rationale.

**Date:** 2026-05-13  
**Phase:** 01-volume-profile-core  
**Areas discussed:** Volume distribution strategy, HVN/LVN detection algorithm, Risk & position sizing inputs, Code structure & testing strategy

---

## Area 1: Volume Distribution & Bin Allocation

**Question:** For multi-level candles that span multiple price bins, how should candle volume be split across those bins?

| Option | Description | Selected |
|--------|-------------|----------|
| Body/wick split (60%/40%) | Current spec: body occupies middle 60%, wicks 40%. Simple, deterministic. | |
| Proportional to range | Volume split proportional to actual price distance: body pixels/wick pixels. More granular. | ✓ |
| Simple uniform distribution | Divide total volume equally across all bins. Simplest, possibly less accurate. | |
| Claude's discretion | Claude picks best approach for accuracy vs. simplicity. | |

**User's choice:** Proportional to range  
**Notes:** Adopting proportional allocation ensures volume is distributed based on actual candle shape and price extent, not fixed percentages. This yields more accurate POC/VAH/VAL calculations.

---

## Area 2: HVN/LVN Detection Algorithm

**Question:** Which detection method for identifying High Volume Nodes and Low Volume Nodes?

| Option | Description | Selected |
|--------|-------------|----------|
| Percentile-based (85th/25th) | Current spec. HVN = bins > 85th percentile, LVN = bins < 25th percentile. | |
| Standard deviation from mean | HVN = (mean + 1.5σ), LVN = (mean - 1.5σ). More statistical, adapts to volatility. | |
| Local clustering (peak detection) | Identify local maxima/minima, mark clusters. Most accurate but computationally heavier. | ✓ |
| Claude's discretion | Claude picks best balance: accuracy vs. simplicity. | |

**User's choice:** Local clustering (peak detection)

**Follow-up — Performance vs. Accuracy:**

| Option | Description | Selected |
|--------|-------------|----------|
| Optimize for accuracy (exact peaks) | Identify exact local maxima/minima, mark tight clusters. Slowest but most accurate. | ✓ |
| Optimize for speed (good-enough peaks) | Sliding window or convolution approximation. Acceptable accuracy, much faster. | |
| Performance doesn't matter for Phase 1 | Just do it right. Optimize later if needed. | |

**User's choice:** Optimize for accuracy (exact peaks)

**Notes:** User prioritizes accuracy in Phase 1 (validation phase). Exact peak detection ensures HVN/LVN identification will be reliable for Phase 2 entry logic. Performance optimization deferred to Phase 2 if needed.

---

## Area 3: Risk & Position Sizing Inputs

**Question:** Should risk parameters (0.6%, -2%, +5%) be hardcoded or exposed as configurable inputs?

| Option | Description | Selected |
|--------|-------------|----------|
| Hardcoded in code | Constants locked as code. Simplest during Phase 1. Easy to change (recompile). | ✓ |
| EA input parameters (user-editable) | Expose in EA Inputs tab. Trader adjusts without recompiling. Adds complexity now. | |
| Hybrid: core locked, adjust later | Hardcode for Phase 1, add user inputs in Phase 2. Best balance. | |
| External config file | Read parameters from .ini/JSON. Maximum flexibility, some overhead. | |

**User's choice:** Hybrid approach (core locked, adjust later)

**Notes:** Interpreted as "Hardcode for Phase 1 validation, add user inputs in Phase 2 if flexibility needed." Simplest approach during discovery phase.

---

## Area 4: Code Structure & Testing Strategy

**Question A: File Organization**

| Option | Description | Selected |
|--------|-------------|----------|
| Single .mq5 file | Everything in one file. Simplest, easy to read start-to-finish. | |
| Main .mq5 + includes (.mqh) | Modular: VolumeProfile.mqh, RiskManager.mqh, Utils.mqh. Easier to test pieces. | |
| Single now, refactor later | Start single for Phase 1, split into modules before Phase 2. | ✓ |

**User's choice:** Single .mq5 file in Phase 1, refactor to modules before Phase 2

**Notes:** Keeps Phase 1 focused and unblocks development. Modularization will happen before Phase 2 to ensure cleaner architecture as complexity grows.

---

**Question B: Testing Strategy**

| Option | Description | Selected |
|--------|-------------|----------|
| Embedded unit tests in EA | Call test functions at startup, validate on injected data, print to Journal. | |
| Standalone test harness | Separate test EA. Decouples testing from production code. | |
| Manual backtest validation | Run 1-month backtest, manually verify profile levels match chart analysis. | ✓ |
| Claude's discretion | Claude picks approach balancing 90%+ coverage requirement with practicality. | |

**User's choice:** Manual backtest validation

**Follow-up — Addressing 90%+ Coverage Requirement:**

| Option | Description | Selected |
|--------|-------------|----------|
| Hardcode test data in EA, run at startup | Add test scenarios to OnInit. Validates POC/VAH/VAL on fixtures. | |
| Manual backtest IS sufficient coverage | Real data validation = sufficient for Phase 1. Skip formal metric. | |
| Both: embedded tests + backtest | Unit tests (code coverage) + integration testing (real data accuracy). | ✓ |

**User's choice:** Both embedded unit tests + backtest

**Notes:** Hybrid approach ensures both unit test code coverage (via embedded OnInit test functions) AND practical integration validation (via manual backtest spot-checking). Meets 90%+ requirement on paper and in practice.

---

## Claude's Discretion

None — all key decisions were made by user selection. No areas deferred to Claude.

---

## Deferred Ideas

**Multi-timeframe confirmation (1H/4H)** — Phase 2+ enhancement. Phase 1 focuses on single-TF calculation.

**Adaptive strategy selection** — Phase 2+ (after validation that core logic works).

**News filtering** — Out of scope (external dependency).

**Parameter optimization** — Phase 4+ (after live validation).

**Multi-asset expansion** — Phase 4+ (after MVP validation on Gold/EURUSD).

---

*Discussion completed: 2026-05-13*  
*All 4 gray areas resolved*  
*Status: Ready for planning*
