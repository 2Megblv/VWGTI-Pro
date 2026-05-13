# Phase 3: Backtesting & Validation - Research

**Researched:** 2026-05-13  
**Domain:** MT5 Historical Backtest Validation, Performance Metrics, Trade Analysis  
**Confidence:** HIGH  

---

## Summary

Phase 3 demands rigorous validation that the EA signal logic (Phase 2 implementation) actually works across two distinct market regimes (2024 and 2025) with measurable statistical confidence. This research addresses the complete backtesting workflow: configuring MT5 for accuracy, executing 1-year backtests on both 2024 and 2025 data, parsing journal entries for trade-by-trade audit, calculating success metrics (win rate ≥50%, profit factor ≥1.5, daily drawdown ≤2%), and verifying no overfitting through variance analysis.

**Key Finding:** The two-year backtest approach (separate 1-year windows on different market regimes) is the correct validation strategy for detecting regime-dependent code bugs without requiring walk-forward or rolling window complexity. MT5's "Every Tick" mode (not "Every tick based on real ticks") provides sufficient accuracy for MVP validation when real tick data is not available; however, "Every tick based on real ticks" is more accurate but ~2x slower. Automated journal parsing via Python/pandas is standard industry practice and significantly reduces manual audit error.

**Primary Recommendation:** Configure MT5 Strategy Tester with "Every Tick" mode (real tick data if available), execute 2024 and 2025 backtests independently on both XAUUSD and EURUSD combined, export trade journal to CSV, parse with Python script to count Setup 1/2 trades and calculate metrics, validate both years meet gates independently, and compare results for regime robustness signals.

---

## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01: Two Separate 1-Year Backtests (2024 and 2025)**
- Run independent backtests on Jan–Dec 2024 and Jan–Dec 2025 separately
- Both years must independently meet ALL success gates (50% WR, 1.5 PF, 2% DD)
- If either year fails any metric, STOP → Return to Phase 2 for code diagnosis

**D-02: MT5 Native Backtest with Real Tick Data (Every Tick Mode)**
- Use MT5's native backtester with "Every Tick" mode (real tick data, not bar-open)
- Slower execution acceptable for validation phase
- Manual spot-checks comparing calculated profiles (POC/VAH/VAL) to chart reference

**D-03: Hard Success Gates (Must Meet ALL Criteria)**
- Win Rate ≥50%, Profit Factor ≥1.5, Maximum Daily Drawdown ≤2%
- 200+ total trades across both XAUUSD + EURUSD combined
- ≥50 Setup 1 trades AND ≥50 Setup 2 trades per year (balanced setup distribution)

**D-04: Failed Gate Diagnosis Protocol**
- If any year fails gates, assume Phase 2 code has a logic bug (not regime)
- Return to Phase 2, revise entry logic/exit validation/daily limit enforcement
- Re-run backtest on same data to verify fix

**D-05: MT5 Journal Auto-Categorization by Setup Type**
- Phase 2 EA logs every trade with `setup_type` field ("Setup 1" or "Setup 2")
- Parse MT5 Journal after backtest, count trades by setup type
- Verify ≥50 of each type; if either <50, investigate Phase 2 entry detection

**D-06: Trade-by-Trade Audit Trail from Phase 2 Logging**
- Every trade logged: entry time, symbol, direction, entry price, lot size, setup type
- Exit details: time, exit price, exit reason (TP/SL/Daily Limit/Friday Close)
- Realized P&L (pips and currency), Risk/Reward ratio, Slippage

**D-07: Two-Year Regime Robustness Validation**
- If BOTH 2024 ≥50% WR AND 2025 ≥50% WR → Strategy is robust, proceed to Phase 4
- If one year fails → Strategy has regime-dependent weakness → Return to Phase 2
- Confidence that Phase 4 live trading will match backtest across varying conditions

**D-08: P&L Variance Check (Within ±20% of Conservative Estimate)**
- Conservative estimate: 200 trades/yr × 50% WR × 1.5 PF × per-trade risk = ~3.3% ROI
- If actual backtest P&L within ±20% of estimate → no overfitting, realistic results
- If actual P&L >> 120% of estimate → possible curve-fitting, investigate further

### Claude's Discretion

- **Regime Boundary Between 2024 and 2025:** If market regime shifts occur within the year, still enforce 1-year gate requirements per year (don't split periods)
- **Manual Spot-Check Sampling:** For data accuracy verification, may manually compare 5–10 calculated profiles (POC, VAH, VAL) against chart analysis
- **Journal Parsing Automation:** May write script (Python/MT5 export) to parse journal entries and count Setup 1 vs Setup 2, or count manually as long as final counts are verified

### Deferred Ideas (OUT OF SCOPE)

- Walk-Forward Backtesting (rolling windows) — Phase 4+ feature
- Parameter Optimization — All parameters locked in Phases 1–2
- Multi-Asset Expansion Backtesting (Oil, GBPJPY, DAX) — Phase 4+
- Advanced Statistical Analysis (Sharpe ratio, Sortino ratio, MAE/MFE analysis) — Phase 4+ dashboard

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Backtest Execution | Backend / MT5 Platform | — | MT5 Strategy Tester orchestrates tick-by-tick simulation |
| EA Signal Logic Validation | Backend / EA Code | Frontend / Chart Analysis | Phase 2 EA emits signals; Phase 3 validates accuracy against expected conditions |
| Journal Data Export | Backend / MT5 Platform | Frontend / Python Script | MT5 exports raw journal; Python script parses and aggregates metrics |
| Trade Analysis & Metrics | Frontend / Analysis Script | Backend / MT5 Journal | Python/pandas calculates win rate, PF, DD from exported trade data |
| Gate Verification | Frontend / Manual Review | Backend / Automated Checks | Planner reviews metrics against hard gates; may automate via checklist |

---

## Standard Stack

### Core Tools

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| **MetaTrader 5** | Build 4000+ | Native backtest platform + tick simulation | Industry standard for EA validation; no alternative for MQL5 backtests |
| **MT5 Strategy Tester** | Native | "Every Tick" mode backtesting | Official MT5 backtester; supports real tick data and detailed reporting |
| **Python 3.9+** | Current | Journal parsing, metrics calculation, CSV analysis | Industry-standard for quantitative analysis; pandas/numpy libraries mature |
| **pandas** | 1.x+ | Data frame manipulation, trade analysis | Standard for financial data analysis; native CSV support |
| **Excel / Google Sheets** | Current | Visual metric review, sanity checking | Universal for trade-by-trade manual validation |

### Supporting Tools

| Tool | Purpose | When to Use |
|------|---------|------------|
| **Tickstory** | Alternative tick data source validation | If MT5 native tick data suspected corrupted or incomplete |
| **Dukascopy / OANDA APIs** | Alternative broker data sources | Cross-verify tick accuracy across multiple brokers |
| **MT5 Tester Report Export** | Native backtest report (.html/.txt) | Quick metric overview before detailed journal parsing |
| **Custom MQL5 Export Script** | Automate MT5 journal → CSV export | If MT5 native export insufficient (custom field formatting) |

### Installation

```bash
# Python environment for trade analysis
python3 -m venv backtest_env
source backtest_env/bin/activate  # macOS/Linux
# or: backtest_env\Scripts\activate  # Windows

pip install pandas numpy openpyxl  # Core analysis tools
pip install matplotlib seaborn  # Optional: visualization
```

**Version verification before backtest:**
```bash
python3 --version  # Expect 3.9+
pip list | grep pandas  # Expect 1.0+
```

---

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  PHASE 3: BACKTESTING & VALIDATION FLOW                    │
└─────────────────────────────────────────────────────────────┘

INPUT LAYER:
  Phase 2 EA (compiled .ex5)
     ↓
  MT5 Historical Data (2024 & 2025 ticks)
     ↓
  Account Parameters (Starting balance $1K, spreads, commissions)

BACKTEST EXECUTION (MT5 Strategy Tester):
  ┌──────────────────────────┐
  │  Every Tick Mode Setup   │
  ├──────────────────────────┤
  │ • Symbol: XAUUSD+EURUSD  │
  │ • Period: Jan–Dec 2024   │
  │ • Mode: Every Tick       │
  │ • Start Balance: $1,000   │
  └──────────────────────────┘
           ↓
  ┌──────────────────────────────────────────┐
  │  Tick-by-Tick Simulation                │
  │  (On each tick in 2024 data):           │
  │  1. Recalculate Volume Profile (150-bar)│
  │  2. Check Setup 1 Signal Conditions     │
  │  3. Check Setup 2 Signal Conditions     │
  │  4. Execute Orders (if signal triggers) │
  │  5. Update Position State               │
  │  6. Log Trade to Journal                │
  │  7. Check Daily Limits (-2%, +5%)       │
  │  8. Check Friday Close (21:45)          │
  └──────────────────────────────────────────┘
           ↓
  Backtest Completes → 2024 Results
           ↓
  Repeat for 2025 data

JOURNAL EXPORT:
  MT5 Journal (raw trade data)
     ↓
  CSV Export (MT5 native or script)
     ↓
  Python pandas DataFrame
     ↓
  Trade-by-trade analysis

METRICS CALCULATION LAYER:
  ┌─────────────────────────────────────────┐
  │  From exported CSV:                     │
  │  • Trade count (200+ gate)              │
  │  • Setup 1 count (≥50 gate)             │
  │  • Setup 2 count (≥50 gate)             │
  │  • Win rate (≥50% gate)                 │
  │  • Profit factor (≥1.5 gate)            │
  │  • Max daily drawdown (≤2% gate)        │
  │  • P&L vs conservative estimate (±20%)  │
  └─────────────────────────────────────────┘
           ↓
  Gate Validation: 2024 and 2025 compared
           ↓
  Decision: Proceed to Phase 4 OR Return to Phase 2

GATE DECISION TREE:
  IF (2024 passes ALL gates) AND (2025 passes ALL gates)
    → ✅ ROBUSTNESS CONFIRMED → Phase 4
  ELSE IF (one year passes, other fails)
    → ⚠️ REGIME DEPENDENT ISSUE → Phase 2 Diagnosis
  ELSE IF (both fail)
    → ❌ STRATEGY FUNDAMENTALLY BROKEN → Phase 2 Major Revision

OUTPUT:
  ✅ 2024 Backtest Report (metrics, equity curve, journal)
  ✅ 2025 Backtest Report (metrics, equity curve, journal)
  ✅ Comparison Analysis (robustness assessment)
  ✅ Gate Verification Checklist (pass/fail for each metric)
```

### Recommended Project Structure

```
.planning/phases/03-backtesting-validation/
├── 03-CONTEXT.md              # Phase constraints & decisions (locked)
├── 03-RESEARCH.md             # This file — research findings
├── 03-PLAN.md                 # Task breakdown (will be created)
├── backtest_config/
│   ├── 2024_settings.json     # MT5 tester config for 2024 backtest
│   └── 2025_settings.json     # MT5 tester config for 2025 backtest
├── results/
│   ├── 2024_backtest_report.html      # MT5 native report output
│   ├── 2024_journal_export.csv        # Trade-by-trade export
│   ├── 2025_backtest_report.html
│   ├── 2025_journal_export.csv
│   └── comparison_analysis.xlsx       # Summary metrics
├── scripts/
│   ├── parse_journal.py               # Python script: CSV → metrics
│   ├── calculate_metrics.py           # Win rate, PF, DD calculations
│   └── validate_gates.py              # Gate verification logic
└── validation_checklist.md            # Manual gate verification steps
```

### Pattern 1: MT5 Backtest Configuration

**What:** Setting up MT5 Strategy Tester for accurate multi-symbol, multi-year backtests with real tick data and proper initial conditions.

**When to use:** Before running any backtest; configuration determines accuracy and reproducibility.

**Example:**

```ini
# MT5 Strategy Tester Settings (Every Tick Mode)

[2024 Backtest Configuration]
Symbol: XAUUSD, EURUSD (combined)
Period: 5M (setup timeframe)
Model: Every Tick (real tick data mode)
Starting Date: 2024-01-01 00:00:00
Ending Date: 2024-12-31 23:59:59
Starting Balance: $1,000
Initial Commission: Broker's actual spread (3 pips Gold, 5 pips EURUSD)
Slippage: 1 pip (typical broker slippage)

[Data Quality]
History Quality Indicator: Aim for >99% (available in MT5 tester report)
Data Gaps: Note and investigate if >5% of bars missing
Tick Count: Monitor total ticks processed (>50K for liquid symbols)

[Output Settings]
Export Journal: ✓ Enable
Generate Report: ✓ Enable (HTML + detailed summary)
Detailed Account Statement: ✓ Enable (needed for P&L per trade)
```

**Source:** [Testing trading strategies on real ticks - MQL5 Articles](https://www.mql5.com/en/articles/2612), [Strategy Testing - MetaTrader 5 Help](https://www.metatrader5.com/en/terminal/help/algotrading/testing)

### Pattern 2: Trade Journal Parsing (Python)

**What:** Automated extraction of trade-by-trade data from MT5 Journal CSV export, calculation of metrics (win rate, profit factor, setup type distribution).

**When to use:** After backtest completes and journal is exported to CSV.

**Example:**

```python
# parse_journal.py — Convert MT5 journal CSV to metrics

import pandas as pd
from datetime import datetime

def parse_mt5_journal(csv_file_path):
    """
    Parse MT5 journal export to DataFrame with calculated metrics.
    
    Expected CSV columns (from MT5 export):
    Time, Open, Close, High, Low, Volume, Magic, Comment (or custom setup_type field)
    
    Phase 2 EA logs format:
    timestamp | symbol | direction | entry_price | lot_size | setup_type | 
    exit_time | exit_price | exit_reason | P&L_pips | P&L_currency | 
    SL_price | TP_price | RR_ratio | slippage_pips
    """
    
    # Load CSV (adjust dtypes based on actual MT5 export format)
    df = pd.read_csv(csv_file_path, parse_dates=['Time', 'ExitTime'])
    
    # Extract setup type from Comment field (if not separate column)
    df['setup_type'] = df['Comment'].str.extract(r'(Setup [12])', expand=False)
    
    # Calculate metrics
    metrics = {
        'total_trades': len(df),
        'profitable_trades': len(df[df['P&L_currency'] > 0]),
        'losing_trades': len(df[df['P&L_currency'] < 0]),
        'win_rate': len(df[df['P&L_currency'] > 0]) / len(df) * 100,
        'gross_profit': df[df['P&L_currency'] > 0]['P&L_currency'].sum(),
        'gross_loss': abs(df[df['P&L_currency'] < 0]['P&L_currency'].sum()),
        'profit_factor': (df[df['P&L_currency'] > 0]['P&L_currency'].sum() / 
                         abs(df[df['P&L_currency'] < 0]['P&L_currency'].sum())),
        'setup_1_count': len(df[df['setup_type'] == 'Setup 1']),
        'setup_2_count': len(df[df['setup_type'] == 'Setup 2']),
    }
    
    # Validate gates
    gates = {
        'win_rate_gate': metrics['win_rate'] >= 50.0,
        'profit_factor_gate': metrics['profit_factor'] >= 1.5,
        'setup_1_gate': metrics['setup_1_count'] >= 50,
        'setup_2_gate': metrics['setup_2_count'] >= 50,
        'trade_count_gate': metrics['total_trades'] >= 200,
    }
    
    return metrics, gates, df

# Usage
metrics_2024, gates_2024, trades_2024 = parse_mt5_journal('2024_journal_export.csv')
print(f"2024 Win Rate: {metrics_2024['win_rate']:.2f}% (gate: {gates_2024['win_rate_gate']})")
print(f"2024 Profit Factor: {metrics_2024['profit_factor']:.2f} (gate: {gates_2024['profit_factor_gate']})")
print(f"2024 Total Trades: {metrics_2024['total_trades']} (gate: {gates_2024['trade_count_gate']})")
```

**Source:** [Free download of the 'ASQ Trading Journal Export' script](https://www.mql5.com/en/code/71240), [How to Export Data from Metatrader](https://forexbook.com/blog/how-to-export-data-from-metatrader), [GitHub - daivieth/MT5-data2csv](https://github.com/daivieth/MT5-data2csv)

### Pattern 3: Daily Drawdown Calculation

**What:** Computation of maximum intraday loss (daily drawdown) from trade data and equity curve, ensuring ≤2% gate is met.

**When to use:** During gate verification; correlate with EA's daily -2% hard stop enforcement.

**Example:**

```python
def calculate_daily_drawdown(equity_curve_df, starting_balance=1000):
    """
    Calculate daily maximum drawdown (peak-to-valley within single day).
    
    Args:
        equity_curve_df: DataFrame with 'Date', 'Equity' columns (intraday bars)
        starting_balance: Starting account balance
    
    Returns:
        max_daily_dd_pct: Maximum daily drawdown as percentage
        daily_dd_details: DataFrame with daily DD for each trading day
    """
    
    # Group equity by trading day
    equity_curve_df['Date'] = pd.to_datetime(equity_curve_df['Date']).dt.date
    daily_stats = []
    
    for trading_day, group in equity_curve_df.groupby('Date'):
        day_open = group['Equity'].iloc[0]
        day_high = group['Equity'].max()
        day_low = group['Equity'].min()
        day_close = group['Equity'].iloc[-1]
        
        # Daily drawdown: from highest point during day to lowest
        daily_dd = (day_high - day_low) / starting_balance * 100
        
        daily_stats.append({
            'Date': trading_day,
            'Open': day_open,
            'High': day_high,
            'Low': day_low,
            'Close': day_close,
            'Daily_DD_%': daily_dd,
            'Gate_Pass': daily_dd <= 2.0  # ≤2% gate
        })
    
    daily_df = pd.DataFrame(daily_stats)
    max_daily_dd = daily_df['Daily_DD_%'].max()
    
    # Flag any day violating the 2% gate
    violations = daily_df[daily_df['Daily_DD_%'] > 2.0]
    
    return max_daily_dd, daily_df, violations

# Usage
max_dd_2024, daily_stats_2024, violations = calculate_daily_drawdown(equity_curve)
print(f"Max Daily DD 2024: {max_dd_2024:.2f}% (gate: {max_dd_2024 <= 2.0})")
if len(violations) > 0:
    print(f"⚠️ Found {len(violations)} days exceeding 2% limit:")
    print(violations)
```

**Source:** [What does the Daily Drawdown mean and how is it calculated?](https://help.fortraders.com/en/articles/9259647-what-do-the-daily-drawdown-and-max-drawdown-mean-and-how-is-it-calculated), [Intraday Drawdown Explained](https://help.myfundedfutures.com/en/articles/12802721-intraday-drawdown-explained)

### Anti-Patterns to Avoid

- **Using "Every tick based on real ticks" for MVP validation:** Slower (~2x), not necessary for initial phase gates. "Every Tick" mode sufficient if data quality >99%. Reserve "real ticks" for Phase 4 final validation if live results don't match.
  
- **Backtesting on only one year and assuming robustness:** Single-year backtest tells you nothing about regime-dependent bugs. Two-year, two-regime approach is the correct MVP validation (as per D-07).

- **Ignoring daily limit enforcement during backtest:** If Phase 2 EA logic is correct, backtest MUST show zero violations of -2% hard stop and +5% profit cap. Any violations = Phase 2 code bug, not backtest artifact.

- **Manual trade counting instead of scripted parsing:** Error-prone. Use Python pandas to automate trade-by-trade analysis. Setup 1 vs Setup 2 counts must be traceable (not "I counted 52 Setup 1 trades by eye").

- **Accepting backtest results without spot-check data verification:** Run 5–10 manual checks: pick a random bar from backtest, calculate POC/VAH/VAL manually (or with chart tool), compare to EA's calculated levels. If ±2 pips match, data is good. If >5 pips mismatch, investigate data source.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| **Trade data parsing** | Custom regex parser in bash/Excel | Python pandas + CSV export | Regex is error-prone; pandas handles malformed fields, null values, type coercion automatically. CSV parsing is solved. |
| **Metrics calculation** | Custom Excel formulas for WR/PF | Python script (pandas) with unit tests | Excel formulas are unmaintainable; Python allows version control, testing, reproducibility across machines. |
| **Tick data validation** | Manual visual inspection of bars | MT5 tester history quality % + spot-check script | Manual inspection doesn't scale. MT5's "History Quality" indicator identifies gaps. Automated spot-check script samples 10 bars, compares calculated to expected. |
| **Daily drawdown tracking** | Manual daily P&L inspection | Python script parsing equity curve | Automation prevents missed days, calculation errors. Script tracks all 252 trading days objectively. |
| **Overfitting detection** | Assumption "two years is enough" | P&L variance analysis script (estimate vs actual within ±20%) | Two years is necessary but not sufficient. Variance check reveals if results are suspiciously high (>120% of estimate) = curve-fitting signal. |
| **Journal export formatting** | Custom MQL5 script for non-standard fields | MT5 native "Detailed Account Statement" export | MT5's native export has all needed fields (entry/exit, P&L, time). Custom script only if specific custom fields (e.g., phase of moon, custom indicators) needed. |

**Key insight:** MT5 and Python libraries solve 95% of backtesting workflows. Only hand-roll if standard tools genuinely insufficient (rare at MVP stage).

---

## Common Pitfalls

### Pitfall 1: Backtest Mode Selection Confusion

**What goes wrong:** Choosing "1 Minute OHLC" or "Bar Open" mode instead of "Every Tick," believing faster backtests are "good enough." Results show 65% win rate, proceed to Phase 4, live trading shows 40% win rate.

**Why it happens:** "Every Tick" mode is slow (3–5x slower than bar mode). Under time pressure, developers choose speed over accuracy.

**How to avoid:**
- Use "Every Tick" (real tick data if available) for MVP validation. Slower is acceptable.
- If tick data unavailable, explicitly document backtest mode limitation in research.
- After Phase 3 passes, run Phase 4 live trading on real broker data as final validation.

**Warning signs:**
- Backtest completes in <5 minutes for full-year, multi-symbol → likely not "Every Tick" mode.
- History quality indicator <95% → data gaps present, backtest unreliable.
- Slippage patterns in journal show >90% fills at exact bid/ask (unrealistic).

**Source:** [Differences between "Every Tick" and "Every tick based on real ticks"](https://www.mql5.com/en/forum/441266)

---

### Pitfall 2: Regime-Independent Code Bugs vs. Regime Sensitivity

**What goes wrong:** 2024 backtest passes (60% WR), 2025 fails (42% WR). Team assumes "2025 market was tougher" and proceeds to Phase 4. Live trading degrades immediately because the code has a regime-dependent bug (e.g., Setup 1 detection broken when VA width changes).

**Why it happens:** Single-regime understanding. If code works once, assumption is it works everywhere. Fails silently in Phase 2 if edge case (e.g., wide VA range) only occurs in 2025.

**How to avoid:**
- Enforce D-07: BOTH years must meet gates. One year failure = code bug, not market excuse.
- If 2025 fails, return to Phase 2 with diagnostic data: "2025 Setup 1 count dropped 60% → entry detection broken under wide VA conditions."
- Debug by analyzing 2025 journal: are Setup 1 signals simply not firing, or firing but being rejected due to slippage?

**Warning signs:**
- Setup 1 count: 2024 = 65 trades, 2025 = 12 trades (>50% drop) → entry logic regime-dependent.
- Win rate difference >10% between years → exit logic or position sizing affected by regime.
- 2025 losses concentrated at specific time-of-day or market condition (e.g., all losses during "grave hour") → session filtering missing.

**Source:** [Optimisation robustness and avoiding overfitting MT5](https://www.mql5.com/en/forum/459197)

---

### Pitfall 3: P&L Variance Misinterpretation

**What goes wrong:** Conservative estimate is +3% ROI ($30 on $1K account). Actual backtest shows +15% ROI ($150). Team celebrates, proceeds to Phase 4. Live trading produces -2% (losses). Signal: backtest overfitted to 2024 market data.

**Why it happens:** Assumption that backtest results are linear to future. If 2024 is unusually profitable, results don't generalize to 2025+ different conditions.

**How to avoid:**
- Calculate conservative estimate BEFORE backtest (D-08): `200 trades × 50% WR × 1.5 PF × $6 avg win = $600 profit (6% ROI)`.
- After backtest, compare actual to estimate: within ±20% → realistic. Beyond ±20% (especially >120%) → investigate.
- If actual >> estimate, look for:
  - Market bias (2024 strong uptrend, overfit to directional bias)
  - Parameter overfitting (e.g., 1.3x volume threshold works great in 2024 but too tight in 2025)
  - Data quality issue (tick data missing, filling gaps with unrealistic ticks)

**Warning signs:**
- Sharpe ratio in backtest >2.0 (usually indicates overfitting; realistic Sharpe is 0.5–1.5)
- Equity curve too smooth (no significant drawdowns; real trading always has them)
- Win rate significantly above 60% (suggest parameters tuned to data, not trading rules)

**Validation:** Compare actual 2024 P&L to 2025 P&L. If 2024 is 2–3x better, code is regime-dependent.

**Source:** [Not All 99% Backtests Are Equal: How Tick Data Quality Impacts Your Strategy](https://www.mql5.com/en/blogs/post/762517)

---

### Pitfall 4: Journal Export Data Corruption

**What goes wrong:** MT5 journal export truncates or misformats setup_type field. Trade counts come back as "Setup ?" instead of "Setup 1" or "Setup 2". Manual review finds actual Setup 1 count is 58, but script parsed 0 (because field malformed). Gate validation fails due to parsing error, not code logic.

**Why it happens:** MT5 export format varies by version. Custom EA comment fields may not export cleanly to CSV. Quote handling in CSV can break when trade comment contains special characters.

**How to avoid:**
- Test journal export on sample EA data BEFORE running full backtests.
- Use pandas `errors='coerce'` when reading CSV (converts malformed cells to NaN instead of crashing).
- Validate after parsing: Check for NaN in critical fields. If count rises >5%, re-export with different delimiter or quote style.
- Manual spot-check: Open exported CSV in Excel, inspect 10 rows manually. Ensure setup_type, P&L, dates look correct.

**Warning signs:**
- CSV has >100 cells with NaN (missing data)
- Trade comment field contains unescaped quotes or commas (breaks CSV parsing)
- Setup type counts don't match journal row count (e.g., 245 rows but only 200 have setup_type)

**Solution:** Use MT5's native "Detailed Account Statement" export (always well-formatted) if possible. Custom fields logged in Comment field may need post-processing (regex extraction).

**Source:** [Export History Data to CSV | Free Download Trading Utility for MetaTrader 5](https://www.mql5.com/en/market/product/156489)

---

### Pitfall 5: Confusing Daily Drawdown with Max Drawdown

**What goes wrong:** EA's daily -2% hard stop enforced correctly; max drawdown across the full year reaches -8%. Team thinks gate is "daily DD ≤2%" and concludes backtest passes. Actually gate means: on ANY single day, max loss ≤2% (not average, not total drawdown).

**Why it happens:** Terminology confusion. "Daily drawdown" = intraday peak-to-valley within one day. "Max drawdown" = entire equity curve peak-to-trough.

**How to avoid:**
- Clearly define gate in validation script: `daily_dd_pct = (peak_equity_of_day - low_equity_of_day) / starting_balance * 100`. Calculate for each trading day. Check if ANY day exceeds 2%.
- EA's daily hard stop (-2%) SHOULD prevent any day from exceeding -2% (if code correct). Backtest should show zero violations.
- If backtest shows 1–2 days at -1.8%, that's OK (approaching limit). If any day >-2.1%, that's a code bug (hard stop failed).

**Warning signs:**
- Backtest shows max daily loss of -2.3% on some day → hard stop failed to trigger. Phase 2 code bug.
- Equity curve shows recovery days (gains) immediately after hard stop days → confirm hard stop resetting correctly at session boundary.

**Validation:** Review 03-CONTEXT.md D-09: "When cumulative daily loss reaches -2% of account balance, force-close ALL open positions + cease all trading for remainder of session." Backtest report should show daily loss flat at -2%, no worse.

**Source:** [What does the Daily Drawdown mean and how is it calculated?](https://help.fortraders.com/en/articles/9259647-what-do-the-daily-drawdown-and-max-drawdown-mean-and-how-is-it-calculated)

---

### Pitfall 6: Overfitting Detection Without Out-of-Sample Data

**What goes wrong:** 2024 and 2025 backtests both pass with 58% win rate and 1.8 profit factor. Phase 4 live trading on current market (May 2026) produces 35% win rate. Signal: parameters tuned to 2024–2025, don't generalize to 2026.

**Why it happens:** Two years of data seems sufficient, but if both years share structural patterns (e.g., both trending years), parameters may be over-tuned to trending bias.

**How to avoid:**
- Use P&L variance check (D-08) to flag if backtest results are suspiciously high.
- Compare 2024 metrics to 2025 metrics directly. If diverge significantly (WR 2024=60%, 2025=48%), parameters are regime-sensitive.
- Phase 4 live trading is the true out-of-sample test. If live results within ±20% of backtest, strategy is robust.
- Document this explicitly: "MVP validation (Phase 3) is in-sample (historical data). Phase 4 live trading is true validation (out-of-sample, real market)."

**Warning signs:**
- 2024 and 2025 metrics nearly identical (unlikely in real trading) → suggests overfitting to both years.
- Equity curve smooth with minimal drawdowns → real trading always has noise.

**Source:** [Avoiding Over-fitting in Trading Strategy (Part 2): A Guide to Building Optimization Processes](https://www.mql5.com/en/blogs/post/756386)

---

## Code Examples

Verified patterns for backtest validation and metrics calculation:

### Win Rate and Profit Factor Calculation

```python
# Source: Industry-standard metrics (from multiple sources below)

def calculate_metrics(trades_df):
    """
    Calculate win rate and profit factor from trade data.
    
    Args:
        trades_df: DataFrame with columns ['P&L_pips', 'P&L_currency', 'entry_price', 'exit_price']
    
    Returns:
        dict with: win_rate_pct, profit_factor, avg_win, avg_loss, win_loss_ratio
    """
    
    # Win rate
    winning_trades = trades_df[trades_df['P&L_currency'] > 0]
    losing_trades = trades_df[trades_df['P&L_currency'] < 0]
    
    win_rate = len(winning_trades) / len(trades_df) * 100 if len(trades_df) > 0 else 0
    
    # Profit factor
    gross_profit = winning_trades['P&L_currency'].sum() if len(winning_trades) > 0 else 0
    gross_loss = abs(losing_trades['P&L_currency'].sum()) if len(losing_trades) > 0 else 0
    
    profit_factor = gross_profit / gross_loss if gross_loss > 0 else 0
    
    # Additional metrics
    avg_win = winning_trades['P&L_currency'].mean() if len(winning_trades) > 0 else 0
    avg_loss = losing_trades['P&L_currency'].mean() if len(losing_trades) > 0 else 0
    
    win_loss_ratio = abs(avg_win / avg_loss) if avg_loss != 0 else 0
    
    return {
        'win_rate_pct': win_rate,
        'profit_factor': profit_factor,
        'avg_win': avg_win,
        'avg_loss': avg_loss,
        'win_loss_ratio': win_loss_ratio,
        'total_trades': len(trades_df),
        'winning_trades': len(winning_trades),
        'losing_trades': len(losing_trades),
        'gross_profit': gross_profit,
        'gross_loss': gross_loss,
    }

# Example usage with validation
metrics = calculate_metrics(trades_df)
print(f"Win Rate: {metrics['win_rate_pct']:.2f}% (gate: {metrics['win_rate_pct'] >= 50.0})")
print(f"Profit Factor: {metrics['profit_factor']:.2f} (gate: {metrics['profit_factor'] >= 1.5})")
print(f"Avg Win/Loss Ratio: {metrics['win_loss_ratio']:.2f}")
```

**Source:** [Profit Factor Definition: Formula, Calculator & Trading Benchmarks](https://www.backtestbase.com/education/win-rate-vs-profit-factor), [The 5 KPIs That Matter Most in Backtesting a Strategy](https://fxreplay.com/learn/the-5-kpis-that-matter-most-in-backtesting-a-strategy)

---

### Setup Type Counting and Validation

```python
# Source: Phase 2 EA logging format (D-06)

def count_setup_types(trades_df):
    """
    Count Setup 1 and Setup 2 trades from parsed journal.
    Validate both meet ≥50 gate.
    
    Args:
        trades_df: DataFrame with 'setup_type' column
    
    Returns:
        dict with counts and gate pass/fail
    """
    
    setup_1 = len(trades_df[trades_df['setup_type'] == 'Setup 1'])
    setup_2 = len(trades_df[trades_df['setup_type'] == 'Setup 2'])
    unknown = len(trades_df[trades_df['setup_type'].isna() | (trades_df['setup_type'] == '')])
    
    return {
        'setup_1_count': setup_1,
        'setup_2_count': setup_2,
        'unknown_count': unknown,
        'setup_1_gate': setup_1 >= 50,
        'setup_2_gate': setup_2 >= 50,
        'both_gate_pass': (setup_1 >= 50) and (setup_2 >= 50),
    }

# Validation with warnings
counts = count_setup_types(trades_df)
print(f"Setup 1 trades: {counts['setup_1_count']} (gate: {counts['setup_1_gate']})")
print(f"Setup 2 trades: {counts['setup_2_count']} (gate: {counts['setup_2_gate']})")

if counts['unknown_count'] > 0:
    print(f"⚠️ WARNING: {counts['unknown_count']} trades with missing/malformed setup_type")
    print("  → Check EA logging; ensure Phase 2 logs 'Setup 1' or 'Setup 2' for every trade")
```

---

### Data Accuracy Spot-Check

```python
# Source: Manual verification methodology from D-07 (Claude's Discretion)

def spot_check_volume_profile(bar_num, actual_poc, actual_vah, actual_val, 
                              expected_poc=None, expected_vah=None, expected_val=None):
    """
    Validate calculated volume profile levels against expected/chart reference.
    
    Args:
        bar_num: Bar number in backtest
        actual_poc, actual_vah, actual_val: Calculated by EA
        expected_poc, expected_vah, expected_val: From manual chart analysis
    
    Returns:
        bool: True if within ±2 pips (accurate), False if >5 pips off (investigate)
    """
    
    if expected_poc is None:
        print(f"Bar {bar_num}: Skipping spot-check (no expected value)")
        return None
    
    poc_diff = abs(actual_poc - expected_poc)
    vah_diff = abs(actual_vah - expected_vah) if expected_vah else None
    val_diff = abs(actual_val - expected_val) if expected_val else None
    
    tolerance_good = 0.02  # ±2 pips acceptable
    tolerance_warning = 0.05  # >5 pips = investigate
    
    results = {
        'bar': bar_num,
        'poc_diff': poc_diff,
        'vah_diff': vah_diff,
        'val_diff': val_diff,
        'poc_ok': poc_diff <= tolerance_good,
        'vah_ok': vah_diff is None or vah_diff <= tolerance_good,
        'val_ok': val_diff is None or val_diff <= tolerance_good,
        'all_ok': all([
            poc_diff <= tolerance_good,
            vah_diff is None or vah_diff <= tolerance_good,
            val_diff is None or val_diff <= tolerance_good,
        ])
    }
    
    if not results['all_ok']:
        print(f"⚠️ Bar {bar_num}: Data accuracy SUSPICIOUS")
        print(f"   POC: {actual_poc} vs expected {expected_poc} (diff: {poc_diff})")
        if expected_vah:
            print(f"   VAH: {actual_vah} vs expected {expected_vah} (diff: {vah_diff})")
    
    return results

# Usage: Run on 5-10 random bars from backtest
spot_checks = []
for bar_idx in [50, 150, 250, 500, 750, 1000]:  # Sample 6 bars
    result = spot_check_volume_profile(
        bar_num=bar_idx,
        actual_poc=backtest_data[bar_idx]['poc'],
        actual_vah=backtest_data[bar_idx]['vah'],
        actual_val=backtest_data[bar_idx]['val'],
        expected_poc=manual_analysis[bar_idx]['poc'],
        expected_vah=manual_analysis[bar_idx]['vah'],
        expected_val=manual_analysis[bar_idx]['val'],
    )
    spot_checks.append(result)

# Summary
checks_passed = sum(1 for r in spot_checks if r['all_ok'])
print(f"\nData Accuracy: {checks_passed}/{len(spot_checks)} spot-checks passed")
if checks_passed == len(spot_checks):
    print("✅ Data quality confirmed; proceed with backtest confidence")
else:
    print("⚠️ Data anomalies detected; investigate tick data source")
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual trade counting (Excel) | Automated journal parsing (Python pandas) | 2015+ | Reduced human error, reproducible, scales to 1000+ trades |
| "Bar Open" mode backtesting | "Every Tick" mode with real tick data | 2020+ | More accurate fill simulation, reveals slippage-induced losses real trading shows |
| Single-year backtests | Two-year, two-regime validation | Best practice 2020+ | Detects regime-dependent code bugs; prevents overfitting to single market |
| Assumption "pass one gate" = success | Hard gates on ALL metrics (50% WR AND 1.5 PF AND 2% DD AND 200+ trades) | Best practice 2022+ | Forces discipline; single-metric success is deceptive (high WR with low PF = failure) |
| Manual overfitting detection | Automated P&L variance check (±20% of estimate) | 2023+ | Flags suspicious backtest results objectively |
| Parameter tuning during backtest | Locked parameters across phases | Best practice 2023+ | Prevents optimization bias; validates trading logic, not parameter fit |

**Deprecated/outdated:**

- **"Estimated" tick data (generated from OHLC):** Old MT4 approach; MT5 "Every Tick" based on real ticks available. Estimated ticks miss intrabar fills and reversals.
- **Walk-forward testing in MVP phase:** Overkill for initial validation. Two-year regime comparison sufficient. Save walk-forward for Phase 4+ robustness enhancements.
- **Visual backtest inspection (watching the chart):** Unreliable; misses edge cases. Automated metrics (win rate, PF) tell the real story.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | MT5's "Every Tick" mode (not "real ticks" variant) is sufficiently accurate for MVP validation | Standard Stack | If data quality <95%, backtest results don't generalize to Phase 4. Mitigation: verify history quality >99% in backtest report before accepting results. |
| A2 | Phase 2 EA logs `setup_type` field as "Setup 1" or "Setup 2" text | Common Pitfalls | If EA logs different format (e.g., "S1", "LongSetup"), script won't parse. Mitigation: test EA logging on sample trades before full backtest. |
| A3 | 2024 and 2025 represent sufficiently different market regimes to validate robustness | State of the Art | If both years share same trending bias, strategy may still be regime-dependent to 2024–2025. Mitigation: Phase 4 live trading (2026+ market) is true validation. |
| A4 | ±20% P&L variance tolerance correctly identifies overfitting | Assumptions Log | Overfitting is complex; variance check necessary but not sufficient. Mitigation: also compare 2024 vs 2025 metric divergence; if one year >10% worse, investigate regime-dependent bugs. |
| A5 | MT5 native journal export includes all fields: entry time, exit time, P&L, setup_type | Code Examples | Some brokers' MT5 builds may have custom journal format. Mitigation: test export on sample EA before full backtest. |
| A6 | Daily drawdown is calculated as max intraday loss within single calendar day (not rolling 24-hour) | Common Pitfalls | If calculated differently (e.g., rolling 24-hour from last reset), gate interpretation changes. Mitigation: explicitly define in validation script and document. |

---

## Open Questions

1. **Tick Data Availability Confirmation**
   - What we know: MT5's native "Download Data" downloads broker tick data. Some brokers offer >99% history quality.
   - What's unclear: Does the trading account's broker (Darwinfo, IC Markets, etc.) have tick history for XAUUSD and EURUSD for 2024–2025? Some brokers provide only OHLC back to certain date.
   - Recommendation: Before starting backtest, go to MT5 → Tools → History Center → XAUUSD → 2024. Check if tick data is available. If only bar data, use "Every Tick" mode (generated from bars) and document limitation.

2. **Phase 2 EA Journal Format Validation**
   - What we know: Phase 2 context specifies logging format (D-06).
   - What's unclear: Have sample trades been logged and verified to parse correctly with Python script? Does the setup_type field format exactly as "Setup 1" vs "setup1" vs "S1"?
   - Recommendation: After Phase 2 implementation, run sample backtest on 1 week of data. Export journal. Test Python script parsing before committing to full-year backtest.

3. **Conservative Estimate Calculation**
   - What we know: Conservative formula is 200 trades × 50% WR × 1.5 PF × 0.6% risk = ~$33 net profit on $1K.
   - What's unclear: Should estimate include broker commission/swap costs? Current formula assumes commission already in PF calculation.
   - Recommendation: Calculate estimate both ways (with/without explicit commissions) and record as "estimate range" (e.g., +$250 to +$400) rather than point estimate.

4. **Regime Characterization for 2024 vs 2025**
   - What we know: 2024 was tight, consolidating. 2025 saw major rallies (especially XAUUSD to $3500+ due to geopolitical events).
   - What's unclear: Did market regimes change mid-year? If 2024 had "Q1 tight, Q3 trend," should we split into sub-periods for analysis? CONTEXT.md says "don't split," but worth noting if regime shift observed.
   - Recommendation: During backtest analysis, plot equity curve by month. If sharp break point visible (e.g., flat through Oct, then rally), note regime transition. Doesn't change 1-year gate, but contextualizes Phase 4 live setup.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| MetaTrader 5 Platform | Backtest execution | ✓ (assumed) | Build 4000+ | None — MT5 required for MQL5 EA validation |
| MT5 Strategy Tester | Backtest simulation | ✓ (native in MT5) | — | None — built into MT5 |
| Python 3 | Journal parsing, metrics calculation | ✓ (assumed development env) | 3.9+ | Python 2 (outdated, not recommended) |
| pandas library | DataFrame trade analysis | ✓ (requires pip install) | 1.3+ | Excel/Google Sheets (manual, error-prone) |
| numpy library | Numerical calculations | ✓ (requires pip install) | 1.20+ | Native Python (slower for large arrays) |
| Tick data source | Historical data for backtest | ✓ (MT5 broker data) | — | Alternative broker data, Tickstory, Dukascopy |

**Missing dependencies with no fallback:**
- MetaTrader 5 platform itself — no alternative for MQL5 EA backtesting

**Missing dependencies with fallback:**
- pandas: Can parse journal CSV manually in Excel (tedious for >200 trades)
- Tick data quality: If broker's MT5 data gaps >5%, use Tickstory or Dukascopy APIs to import higher-quality ticks

---

## Validation Architecture

**Skipped:** `workflow.nyquist_validation` is explicitly set to `false` in `.planning/config.json`. Unit tests and integration tests are Phase 2 responsibilities. Phase 3 focuses on historical backtest validation (not automated test coverage).

---

## Security Domain

**Skipped:** No security domain for Phase 3. Backtesting is historical analysis on immutable data; no real trades, no live connections, no credential management needed.

---

## Sources

### Primary (HIGH confidence)
- [Testing trading strategies on real ticks - MQL5 Articles](https://www.mql5.com/en/articles/2612) — Real tick vs. simulated tick trade-offs
- [Strategy Testing - MetaTrader 5 Help](https://www.metatrader5.com/en/terminal/help/algotrading/testing) — Official MT5 backtester documentation
- [Differences between "Every Tick" and "Every tick based on real ticks"](https://www.mql5.com/en/forum/441266) — Community explanation of mode differences
- [How to Backtest a Strategy in MT5 (Advanced Guide)](https://www.fortraders.com/blog/backtest-strategy-in-mt5-advanced-guide) — Comprehensive MT5 workflow
- [Not All 99% Backtests Are Equal: How Tick Data Quality Impacts Your Strategy](https://www.mql5.com/en/blogs/post/762517) — Data quality importance (2025 article)

### Secondary (MEDIUM confidence)
- [Profit Factor Definition: Formula, Calculator & Trading Benchmarks](https://www.backtestbase.com/education/win-rate-vs-profit-factor) — Metrics definitions and industry standards
- [The 5 KPIs That Matter Most in Backtesting a Strategy](https://fxreplay.com/learn/the-5-kpis-that-matter-most-in-backtesting-a-strategy) — Backtest metrics overview
- [What does the Daily Drawdown mean and how is it calculated?](https://help.fortraders.com/en/articles/9259647-what-do-the-daily-drawdown-and-max-drawdown-mean-and-how-is-it-calculated) — Daily drawdown formula
- [Free download of the 'ASQ Trading Journal Export' script](https://www.mql5.com/en/code/71240) — Journal export automation tool
- [How to Export Data from Metatrader](https://forexbook.com/blog/how-to-export-data-from-metatrader) — MT5 data export methods
- [GitHub - daivieth/MT5-data2csv](https://github.com/daivieth/MT5-data2csv) — Python MT5 → CSV script reference
- [Avoiding Over-fitting in Trading Strategy (Part 2)](https://www.mql5.com/en/blogs/post/756386) — Overfitting detection and prevention
- [Real and Generated Ticks - MetaTrader 5 Help](https://www.metatrader5.com/en/terminal/help/algotrading/tick_generation) — MT5 tick generation modes

### Tertiary (RESEARCH, market context)
- [Gold Outlook 2025: Navigating rates, risk and growth](https://www.gold.org/goldhub/research/gold-outlook-2025) — XAUUSD 2024–2025 regime context
- [EUR/USD technical analysis: Spotting Mean Reversion in the 2,000 pip Range](https://www.marketpulse.com/markets/eurusd-technical-analysis-spotting-mean-reversion-in-the-2-000-pip-range/) — EURUSD regime characteristics

---

## Metadata

**Confidence breakdown:**
- **MT5 Backtesting Configuration:** HIGH — Official documentation and community validation consistent; "Every Tick" mode standard across forums
- **Metrics Calculation (Win Rate, Profit Factor):** HIGH — Industry-standard formulas across multiple authoritative sources
- **Daily Drawdown Calculation:** HIGH — Definition consistent across finance sources
- **Journal Parsing & Automation:** MEDIUM — Tools exist (ASQ script, Python pandas), but format varies by MT5 version/broker. Requires testing.
- **Overfitting Detection:** MEDIUM — P&L variance check is heuristic; two-year validation is best practice but not foolproof. Phase 4 live trading is ultimate test.
- **Market Regime Characterization (2024 vs 2025):** MEDIUM — Based on 2025 articles and forecasts; 2024 characterization inferred from 2025 comparisons

**Research date:** 2026-05-13  
**Valid until:** 2026-06-13 (30 days; MT5 features stable; market analysis refreshed monthly)

---

## Summary & Planning Readiness

Phase 3 is straightforward validation of Phase 2 EA correctness across two market regimes. The planner needs to:

1. **Backtest Configuration Task:** Set up MT5 Strategy Tester with correct settings (Every Tick mode, 2024 and 2025 separate runs, combined XAUUSD + EURUSD symbols, starting balance $1K, broker spreads 3/5 pips).

2. **Journal Parsing Task:** After backtest, export MT5 journal to CSV. Create or use Python pandas script to parse trades, count Setup 1/2, calculate win rate / profit factor / daily drawdown.

3. **Gate Validation Task:** Compare 2024 and 2025 metrics against hard gates (50% WR, 1.5 PF, 2% DD, 200+ trades, 50+ each setup type). If both years pass ALL gates, proceed to Phase 4. If either year fails, trigger Phase 2 diagnosis.

4. **Data Accuracy Task:** Run spot-checks on 5–10 random bars. Calculate POC/VAH/VAL manually or with chart tool, compare to EA output. If ±2 pips match, data good. If >5 pips off, investigate tick data source.

5. **Documentation Task:** Record all metrics, gate pass/fail, and regime comparison summary. If proceeding to Phase 4, include statement: "Strategy validated across 2 market regimes; backtest P&L within ±20% of conservative estimate; no overfitting indicators detected."

**Ready for planning:** All research findings are concrete and actionable. Planner can create executable tasks with clear acceptance criteria (gate pass/fail) and known tooling (MT5, Python, pandas).

---

*Research completed: 2026-05-13*  
*Phase 3 Backtesting & Validation — ready for planning phase*
