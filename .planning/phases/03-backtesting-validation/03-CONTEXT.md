# Phase 3: Backtesting & Validation - Context

**Gathered:** 2026-05-13  
**Status:** Ready for planning

---

<domain>

## Phase Boundary

**Historical Backtest Validation (1-year × 2 market regimes)**

This phase delivers quantitative validation that the EA rules work across diverse market conditions: 1-year backtest on 2024 (one market regime) and separate 1-year backtest on 2025 (different market regime). Success gates must be met in BOTH years independently to prove strategy robustness and absence of curve-fitting. Trader gains confidence that EA can perform consistently across different market environments before deploying live capital.

**In Scope:**
- Two separate 1-year backtests: Jan–Dec 2024 and Jan–Dec 2025
- Real tick data (MT5 Every Tick mode) for maximum accuracy
- Backtest on both XAUUSD and EURUSD (combined trade count)
- Trade-by-trade audit trail from Phase 2 EA (setup type, entry/exit price, P&L, slippage)
- Minimum 200+ combined trades across both symbols in each year
- Trade type validation: 50+ Setup 1 trades AND 50+ Setup 2 trades per year
- Win rate ≥50%, Profit Factor ≥1.5, Max daily drawdown ≤2% gates (each year)
- Regime robustness validation: BOTH 2024 and 2025 must independently meet all gates
- P&L variance assessment: actual backtest P&L within ±20% of conservative estimate (validates no overfitting)

**Out of Scope (Phase 4):**
- Live trading deployment or account validation
- Real broker slippage or connection latency simulation
- Multi-asset expansion (Oil, GBPJPY, DAX) testing
- Parameter optimization or tuning
- Walk-forward or rolling window backtests (single 1-year window per year)

</domain>

---

<decisions>

## Implementation Decisions

### Backtesting Strategy

**D-01: Two Separate 1-Year Backtests (2024 and 2025)**
- **Approach:** Run independent backtests on Jan–Dec 2024 and Jan–Dec 2025 separately; compare results
- **Rationale:** Two different market regimes (2024 trending, 2025 potentially different conditions) prove strategy is robust, not curve-fitted to a single market. If strategy works only in 2024 but fails in 2025, indicates Phase 2 code is over-tuned to 2024 market conditions.
- **Validation:** Both years must independently meet ALL success gates (50% WR, 1.5 PF, 2% DD) to proceed to Phase 4. If either year fails any metric, STOP and return to Phase 2 for code diagnosis and fix.
- **Downstream Impact:** Confidence that EA will work in Phase 4 live trading across varying market conditions.

**D-02: MT5 Native Backtest with Real Tick Data (Every Tick Mode)**
- **Approach:** Use MT5's native backtester with "Every Tick" (real tick data) mode, not Bar Open mode
- **Rationale:** Real tick data simulates actual intrabar fills, slippage, and price rejection scenarios. Maximum accuracy for validation. Slower execution time acceptable during validation phase (not production constraint).
- **Data Source:** MT5 downloads tick history directly from broker using native "Download Data" feature
- **Verification:** Manual spot-checks comparing calculated profiles (POC, VAH, VAL) against known chart reference points to confirm data accuracy
- **Downstream Impact:** Backtest results closely simulate real Phase 4 live trading conditions, increasing confidence that Phase 4 performance matches backtest.

### Success Gate Enforcement

**D-03: Hard Success Gates (Must Meet ALL Criteria)**
- **Approach:** Both 2024 AND 2025 backtests must independently achieve:
  - Win Rate ≥50% (50+ Setup 1 trades AND 50+ Setup 2 trades combined)
  - Profit Factor ≥1.5 (sum of winning trades / sum of losing trades)
  - Maximum Daily Drawdown ≤2% (enforced by EA daily -2% hard stop logic)
  - 200+ total trades across XAUUSD + EURUSD combined
- **Rationale:** No flexibility. These gates are the difference between a strategy that works (50%+ win rate, 1.5+ PF) and one that doesn't. If Phase 2 code passes 2024 but fails 2025, indicates regime-specific weakness that must be fixed before live trading.
- **Failed Gate Handling (D-04):** If either 2024 or 2025 fails any gate → STOP backtesting → Return to Phase 2 → Diagnose entry/exit logic issue → Fix → Backtest again
- **Downstream Impact:** Phase 4 (live trading) only begins after BOTH years validate success. Prevents deploying broken or regime-dependent strategy.

**D-04: Failed Gate Diagnosis Protocol**
- **Approach:** If any year fails to meet gates (e.g., 48% win rate when 50% required), assume Phase 2 code has a logic bug in entry detection, exit management, or daily limit enforcement. Do NOT adjust backtest parameters.
- **Diagnostic Steps:**
  1. Compare 2024 vs 2025 results — if both fail, issue is code logic (not regime)
  2. Parse backtest journal for rejected trades, slippage rejections, or missed Setup 1 vs Setup 2 detection
  3. Return to Phase 2 — revise entry detection logic, exit validation, or risk enforcement
  4. Re-run backtest on same data to verify fix
- **Rationale:** Backtests are immutable historical data. If results don't match expectations, implementation has a flaw.
- **Downstream Impact:** Ensures Phase 2 EA code is correct before proceeding to Phase 4 live.

### Trade Validation

**D-05: MT5 Journal Auto-Categorization by Setup Type**
- **Approach:** Phase 2 EA logs every trade in MT5 Journal with `setup_type` field set to "Setup 1" or "Setup 2". After backtest completes, parse MT5 Journal, count trades by setup type.
- **Validation Criteria:**
  - 50+ trades labeled "Setup 1" (80% Rule Mean Reversion)
  - 50+ trades labeled "Setup 2" (HVN Edge Momentum)
  - Total ≥200 combined trades across both symbols
- **Verification:** Count trades automatically from Journal. If either setup type has <50 trades, indicates either:
  - Market conditions didn't trigger that setup enough (regime-dependent)
  - Setup detection logic has a bug (Phase 2 issue)
- **Downstream Impact:** Validates both entry strategies work in practice, not just in theory.

**D-06: Trade-by-Trade Audit Trail from Phase 2 Logging**
- **Approach:** Every trade logged in MT5 Journal includes:
  - Entry time, symbol, direction (LONG/SHORT)
  - Entry price, lot size, setup type (Setup 1 or 2)
  - Exit time, exit price, exit reason (TP/SL/Daily Limit/Friday Close)
  - Realized P&L (pips and currency), Risk/Reward ratio
  - Slippage (actual fill – intended entry price)
- **Rationale:** Full audit trail enables post-backtest analysis to identify patterns (e.g., all Setup 1 losses in volatile sessions, all Setup 2 wins during calm hours) and validate strategy robustness.
- **Downstream Impact:** Confidence that backtest results are traceable and verifiable, not black-box numbers.

### Robustness & No Overfitting

**D-07: Two-Year Regime Robustness Validation**
- **Approach:** 
  - Run 2024 backtest independently → calculate WR, PF, DD
  - Run 2025 backtest independently → calculate WR, PF, DD
  - Compare results
  - If BOTH years meet gates → strategy is robust, not curve-fitted
  - If one year fails → strategy has regime-dependent weakness
- **Interpretation:**
  - BOTH 2024 ≥50% WR AND 2025 ≥50% WR → Strategy works across markets → Proceed to Phase 4
  - 2024 ≥50% WR BUT 2025 <50% WR → Strategy breaks in 2025 regime → Return to Phase 2 (Phase 2 code may be over-tuned to 2024)
  - 2024 <50% WR OR 2025 <50% WR → Strategy doesn't work generally → Return to Phase 2
- **Downstream Impact:** Confidence that Phase 4 live trading performance will match backtest across varying market regimes.

**D-08: P&L Variance Check (Within ±20% of Conservative Estimate)**
- **Approach:** Before backtest, estimate conservative annualized P&L based on assumptions (e.g., 200 trades/year × 50% win rate × 1.5 PF × per-trade risk). After backtest, compare actual P&L to estimate.
- **Validation:** If actual backtest P&L is within ±20% of conservative estimate, strategy is not overfitted. If actual P&L is significantly higher (>120% of estimate), indicates possible curve-fitting (strategy may not replicate in Phase 4 live).
- **Downstream Impact:** Confidence that backtest results are realistic projections for Phase 4 live performance, not optimistic artifacts of historical data curve-fitting.

### Claude's Discretion

- **Regime Boundary Between 2024 and 2025:** If market regime shifts occur within the year (e.g., mid-2024 transition from trending to ranging), Claude may note the transition but still enforce 1-year gate requirements per year (don't split 2024 into sub-periods).
- **Manual Spot-Check Sampling:** For data accuracy verification, Claude may manually compare 5–10 calculated profiles (POC, VAH, VAL) against chart analysis or alternative data sources. Reasonable engineering choice if data has gaps or anomalies.
- **Journal Parsing Automation:** Claude may choose to write a script or manual export (MT5 Export to CSV) to parse journal entries and count Setup 1 vs Setup 2 trades, or count them by hand. Reasonable as long as final counts are verified.

</decisions>

---

<canonical_refs>

## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Backtesting Framework & Success Criteria
- `.planning/ROADMAP.md` §Phase 3: Backtesting & Validation — Success criteria (50% WR, 1.5 PF, 2% DD, 200+ trades)
- `.planning/REQUIREMENTS.md` §Requirement Status Tracking — All 42 v1 requirements must be validated through backtest scenarios

### Phase 2 Integration & EA Output
- `.planning/phases/02-signal-detection-execution/02-CONTEXT.md` — Phase 2 decisions on entry logic (Setup 1 & 2), trade execution, daily limits, journal logging format
- `.planning/phases/02-signal-detection-execution/02-CONTEXT.md` §specifics — Journal logging format (entry details, setup type, exit reason, P&L, slippage)

### Phase 1 Risk Framework (Locked)
- `.planning/phases/01-volume-profile-core/01-CONTEXT.md` — Phase 1 decisions on position sizing, daily hard stop (-2%), daily profit cap (+5%), Friday close time (21:45)

### Project Context & Strategy
- `.planning/PROJECT.md` — Volume Profile methodology, risk framework, entry/exit rules, success criteria for v1 MVP
- `.planning/REQUIREMENTS.md` — All 42 locked v1 requirements for validation

### MT5 Technical Details
- `.planning/PROJECT.md` §Technical Implementation — MT5 platform requirements, tick volume, symbol support (XAUUSD, EURUSD)
- `.planning/REQUIREMENTS.md` §Execution & Monitoring — REQ-036–037 (symbol support), REQ-038 (journal logging), REQ-042 (metrics calculation)

</canonical_refs>

---

<code_context>

## Existing Code Insights

### Phase 2 EA Outputs (Consumed by Phase 3)
- **MT5 Journal entries:** Every trade logged with setup type, entry/exit details, P&L, slippage (Phase 2 responsibility)
- **Backtest compatibility:** EA compiles and runs in MT5 Strategy Tester without errors
- **Position sizing formula:** EA calculates lot size based on Phase 1 risk constants (0.6% per trade)
- **Daily limit enforcement:** EA enforces -2% hard stop and +5% profit cap via flags/position closure

### Phase 3 Testing Artifacts
- **2024 backtest results:** Backtest report with win rate, profit factor, max drawdown, trade count, journal export
- **2025 backtest results:** Same metrics as 2024 for comparison
- **Journal files:** MT5 exports journal entries to .txt or .csv for trade-by-trade validation
- **Gate validation checklist:** Verify both 2024 and 2025 independently meet 50% WR, 1.5 PF, 2% DD

### Integration Points (Phase 3 → Phase 4)
- **Backtest validation gate:** Phase 4 (live deployment) only begins after Phase 3 confirms BOTH 2024 and 2025 meet success gates
- **Trade logging:** Same journal format used in Phase 3 backtest is used in Phase 4 live trading for consistency

</code_context>

---

<specifics>

## Specific Implementation Notes

### Backtest Data & Setup

**Historical Period:** Two separate, full-year windows:
- **2024 Backtest:** January 1, 2024 (00:00) through December 31, 2024 (23:59) broker server time
- **2025 Backtest:** January 1, 2025 (00:00) through December 31, 2025 (23:59) broker server time

**MT5 Backtest Settings:**
- Mode: "Every Tick" (real tick data, not bar-open approximation)
- Data source: MT5 native download from broker
- Symbols: XAUUSD and EURUSD (both included in single backtest run, not separated)
- Starting balance: $1,000 (or actual account size; must be consistent across both years)
- Commissions/spreads: Use broker's actual spreads and commissions as of backtest period

### Success Gate Interpretation

**Win Rate ≥50%:**
- Definition: (Number of profitable trades) / (Total trades) ≥ 0.50
- Calculation: Count trades with realized P&L > 0, divide by total trade count
- Requirement: Both 2024 AND 2025 independently must achieve ≥50%

**Profit Factor ≥1.5:**
- Definition: (Sum of all profitable trade P&L) / (Sum of all losing trade P&L) ≥ 1.5
- Example: If winners total $1,500 and losers total $1,000, PF = 1,500/1,000 = 1.5 ✓
- Requirement: Both 2024 AND 2025 independently must achieve ≥1.5

**Maximum Daily Drawdown ≤2%:**
- Definition: On any single calendar day, cumulative loss from session open to close must not exceed -2% of account balance
- Validation: EA enforces -2% hard stop via daily loss flag; backtest should show zero violations
- Requirement: Both 2024 AND 2025 independently must enforce ≤2% DD

**Trade Count ≥200:**
- Definition: Total trades across both XAUUSD and EURUSD combined
- Setup type breakdown: ≥50 Setup 1 trades AND ≥50 Setup 2 trades (not just 200 total)
- Requirement: Both 2024 AND 2025 independently must execute ≥200 trades with balanced setup type distribution

### Trade-by-Trade Validation

**Setup Type Categorization:**
- Read MT5 Journal entries after backtest
- Extract `setup_type` field from each logged trade (Phase 2 logging includes this)
- Count trades by setup type; verify ≥50 of each type
- If either type has <50 trades, investigate Phase 2 entry detection logic

**Slippage Tracking:**
- Phase 2 logs intended entry price vs. actual fill price
- Track slippage per trade (>50 pips = rejected, logged separately)
- Overall slippage should average <5 pips (indication of good fills and liquidity)

### Failed Gate Protocol

If 2024 hits gates but 2025 doesn't (or vice versa):
1. Document the gap (e.g., "2024: 54% WR, 2025: 47% WR")
2. Assume Phase 2 code has regime-specific bias (over-tuned to 2024)
3. Return to Phase 2 with findings
4. Revise entry logic, exit conditions, or daily limit enforcement
5. Test revised code on same backtest data (2024 re-backtest to ensure fix doesn't break 2024)
6. Return to Phase 3 and re-backtest both 2024 and 2025

### P&L Variance Estimate

**Conservative Estimate Calculation:**
- Assume 200 trades/year
- Assume 50% win rate, 50% loss rate
- Assume Profit Factor = 1.5 (winners = 1.5x losers)
- Per-trade risk = 0.6% of $1,000 = $6
- Assume average winner = $10, average loser = $6.67 (maintains 1.5 PF)
- Expected P&L = (200 × 0.5 × $10) – (200 × 0.5 × $6.67) = $1,000 – $667 = +$333 (≈ +3.3% ROI)
- Conservative estimate range: +$250 to +$400 (allowing ±20% variance)

**Backtest Validation:**
- If actual backtest P&L is within ±20% of estimate → no overfitting, realistic results
- If actual P&L is significantly higher (e.g., $800, which is >120% of estimate) → possible curve-fitting, need to investigate

### Friday Close Validation

- EA enforces Friday 21:45 hard close (Phase 2 logic)
- Backtest should show zero open positions at 21:45 Friday or following Monday 00:00
- If any positions remain open through weekend, indicates Friday close logic failed (Phase 2 code bug)

### Data Accuracy Spot-Check

**Manual Verification Sampling:**
- After downloading 2024 tick data, randomly select 5 bars from different months
- Calculate volume profile manually (or using alternative tool/chart analysis)
- Compare calculated POC, VAH, VAL against EA output for the same bars
- If match within ±2 pips, data is accurate; proceed
- If mismatch >5 pips, investigate data source (gaps, corruption, or calculation error)

</specifics>

---

<deferred>

## Deferred Ideas

**Walk-Forward Backtesting (Rolling Windows)** — Mentioned as potential robustness validation (e.g., 12-month windows rolling monthly). Deferred to Phase 4+. Phase 3 uses two full-year windows (2024, 2025) for regime comparison. Rolling windows are overkill for MVP validation.

**Parameter Optimization** — 400-bin, 70% VA, 1.3x volume threshold, 0.6% risk, -2% hard stop, +5% profit cap all locked in Phases 1–2. Phase 3 does NOT tune parameters. If backtest fails, Phase 2 code logic is fixed, not parameters adjusted.

**Multi-Asset Expansion Backtesting** — Oil, GBPJPY, DAX, Nasdaq deferred to Phase 4+. Phase 3 validates Gold (XAUUSD) + EURUSD only.

**Advanced Statistical Analysis** — Sharpe ratio, Sortino ratio, MAE/MFE analysis, trade correlation study. Deferred to Phase 4+ performance dashboard. Phase 3 focuses on simple gates (WR, PF, DD).

**Forward Testing / Out-of-Sample Validation** — Paper trading on current live data before Phase 4 live deployment. Not in scope for Phase 3; Phase 4 live trading serves this validation role.

</deferred>

---

*Phase: 03-backtesting-validation*  
*Context gathered: 2026-05-13*  
*Status: Ready for planning*
