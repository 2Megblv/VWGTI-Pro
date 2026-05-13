"""
Parse MT5 journal CSV export to calculate backtest metrics.
Expected CSV columns from MT5 export:
Time, Symbol, Direction, EntryPrice, LotSize, SetupType, ExitTime, ExitPrice,
ExitReason, P&L_Pips, P&L_Currency, SL_Price, TP_Price, RR_Ratio, Slippage_Pips
"""

import pandas as pd
import sys
from datetime import datetime

def parse_mt5_journal(csv_file_path):
    """
    Load MT5 journal CSV, validate structure, return DataFrame.
    """
    try:
        df = pd.read_csv(csv_file_path, parse_dates=['Time', 'ExitTime'], errors='coerce')
        print(f"✓ Loaded {len(df)} trades from {csv_file_path}")

        # Validate required columns
        required_cols = ['Symbol', 'Direction', 'EntryPrice', 'LotSize', 'SetupType',
                        'ExitPrice', 'P&L_Currency', 'SL_Price', 'TP_Price']
        missing = [col for col in required_cols if col not in df.columns]
        if missing:
            raise ValueError(f"Missing columns in CSV: {missing}")

        # Check for malformed setup_type
        invalid_setup = df[~df['SetupType'].isin(['Setup 1', 'Setup 2'])].shape[0]
        if invalid_setup > 0:
            print(f"⚠️  WARNING: {invalid_setup} trades with malformed SetupType (expected 'Setup 1' or 'Setup 2')")
            print(f"   Sample invalid values: {df[~df['SetupType'].isin(['Setup 1', 'Setup 2'])]['SetupType'].unique()[:5]}")

        return df
    except Exception as e:
        print(f"❌ ERROR loading journal: {e}")
        sys.exit(1)

def calculate_metrics(trades_df):
    """
    Calculate win rate, profit factor, setup type distribution from trades.
    """
    total_trades = len(trades_df)
    if total_trades == 0:
        print("❌ ERROR: No trades in journal")
        return None

    # Win rate
    winning_trades = trades_df[trades_df['P&L_Currency'] > 0]
    losing_trades = trades_df[trades_df['P&L_Currency'] < 0]
    break_even = trades_df[trades_df['P&L_Currency'] == 0]

    win_rate = (len(winning_trades) / total_trades * 100) if total_trades > 0 else 0

    # Profit factor
    gross_profit = winning_trades['P&L_Currency'].sum() if len(winning_trades) > 0 else 0
    gross_loss = abs(losing_trades['P&L_Currency'].sum()) if len(losing_trades) > 0 else 1  # Avoid division by zero
    profit_factor = gross_profit / gross_loss if gross_loss > 0 else 0

    # Setup type distribution
    setup_1_count = len(trades_df[trades_df['SetupType'] == 'Setup 1'])
    setup_2_count = len(trades_df[trades_df['SetupType'] == 'Setup 2'])

    metrics = {
        'total_trades': total_trades,
        'profitable_trades': len(winning_trades),
        'losing_trades': len(losing_trades),
        'break_even_trades': len(break_even),
        'win_rate_pct': win_rate,
        'gross_profit': gross_profit,
        'gross_loss': gross_loss,
        'profit_factor': profit_factor,
        'setup_1_count': setup_1_count,
        'setup_2_count': setup_2_count,
        'avg_win': winning_trades['P&L_Currency'].mean() if len(winning_trades) > 0 else 0,
        'avg_loss': losing_trades['P&L_Currency'].mean() if len(losing_trades) > 0 else 0,
    }

    return metrics

def validate_gates(metrics):
    """
    Check if metrics meet Phase 3 success gates.
    """
    if metrics is None:
        return None

    gates = {
        'win_rate_gate': metrics['win_rate_pct'] >= 50.0,
        'profit_factor_gate': metrics['profit_factor'] >= 1.5,
        'trade_count_gate': metrics['total_trades'] >= 200,
        'setup_1_gate': metrics['setup_1_count'] >= 50,
        'setup_2_gate': metrics['setup_2_count'] >= 50,
    }

    return gates

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python parse_journal.py <journal_csv_file>")
        sys.exit(1)

    csv_file = sys.argv[1]
    df = parse_mt5_journal(csv_file)
    metrics = calculate_metrics(df)
    gates = validate_gates(metrics)

    # Print results
    print("\n=== METRICS ===")
    print(f"Total Trades: {metrics['total_trades']}")
    print(f"Win Rate: {metrics['win_rate_pct']:.2f}%")
    print(f"Profit Factor: {metrics['profit_factor']:.2f}")
    print(f"Setup 1 Trades: {metrics['setup_1_count']}")
    print(f"Setup 2 Trades: {metrics['setup_2_count']}")

    print("\n=== GATE VALIDATION ===")
    for gate_name, passed in gates.items():
        status = "✓ PASS" if passed else "✗ FAIL"
        print(f"{gate_name}: {status}")
