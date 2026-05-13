"""
Calculate daily drawdown from equity curve (optional detailed metrics).
"""

import pandas as pd
import sys

def calculate_daily_drawdown(equity_curve_df, starting_balance=1000):
    """
    Calculate maximum daily drawdown (intraday peak-to-valley).

    Args:
        equity_curve_df: DataFrame with ['Date', 'Equity'] columns
        starting_balance: Account start balance ($1,000)

    Returns:
        (max_daily_dd_pct, daily_stats_df, violations_df)
    """
    equity_curve_df['Date'] = pd.to_datetime(equity_curve_df['Date']).dt.date
    daily_stats = []

    for trading_day, group in equity_curve_df.groupby('Date'):
        if len(group) == 0:
            continue
        day_open = group['Equity'].iloc[0]
        day_high = group['Equity'].max()
        day_low = group['Equity'].min()
        day_close = group['Equity'].iloc[-1]

        # Daily drawdown: peak to valley within single day
        daily_dd = (day_high - day_low) / starting_balance * 100

        daily_stats.append({
            'Date': trading_day,
            'Open': day_open,
            'High': day_high,
            'Low': day_low,
            'Close': day_close,
            'Daily_DD_%': daily_dd,
            'Gate_Pass': daily_dd <= 2.0,
        })

    daily_df = pd.DataFrame(daily_stats)
    max_daily_dd = daily_df['Daily_DD_%'].max()
    violations = daily_df[daily_df['Daily_DD_%'] > 2.0]

    return max_daily_dd, daily_df, violations

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python calculate_metrics.py <equity_curve_csv>")
        sys.exit(1)

    equity_csv = sys.argv[1]
    df = pd.read_csv(equity_csv)
    max_dd, daily_stats, violations = calculate_daily_drawdown(df)

    print(f"Max Daily Drawdown: {max_dd:.2f}%")
    print(f"Gate (≤2%): {'✓ PASS' if max_dd <= 2.0 else '✗ FAIL'}")
    if len(violations) > 0:
        print(f"\n⚠️ {len(violations)} days exceeded 2% limit:")
        print(violations)
