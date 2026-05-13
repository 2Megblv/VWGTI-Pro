#!/usr/bin/env python3
"""
Parse trading journal CSV and calculate trade-level metrics.
"""

import csv
from dataclasses import dataclass
from typing import List
from pathlib import Path


@dataclass
class Trade:
    ticket: int
    order_time: str
    order_type: str
    symbol: str
    volume: float
    entry_price: float
    exit_price: float
    profit_loss: float
    setup_type: str
    duration_bars: int
    daily_drawdown: float

    @property
    def is_winner(self) -> bool:
        return self.profit_loss > 0

    @property
    def is_loser(self) -> bool:
        return self.profit_loss < 0

    @property
    def is_breakeven(self) -> bool:
        return self.profit_loss == 0


def parse_journal(journal_path: str) -> List[Trade]:
    """Parse journal CSV file and return list of Trade objects."""
    trades = []

    with open(journal_path, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            trade = Trade(
                ticket=int(row['ticket']),
                order_time=row['order_time'],
                order_type=row['order_type'],
                symbol=row['symbol'],
                volume=float(row['volume']),
                entry_price=float(row['entry_price']),
                exit_price=float(row['exit_price']),
                profit_loss=float(row['profit_loss']),
                setup_type=row['setup_type'],
                duration_bars=int(row['duration_bars']),
                daily_drawdown=float(row['daily_drawdown'])
            )
            trades.append(trade)

    return trades


def calculate_metrics(trades: List[Trade]) -> dict:
    """Calculate comprehensive metrics from trades."""

    if not trades:
        return {
            'total_trades': 0,
            'winning_trades': 0,
            'losing_trades': 0,
            'breakeven_trades': 0,
            'win_rate': 0.0,
            'total_profit_loss': 0.0,
            'avg_profit_per_trade': 0.0,
            'profit_factor': 0.0,
            'max_drawdown': 0.0,
            'avg_daily_drawdown': 0.0,
            'setup_1_trades': 0,
            'setup_2_trades': 0,
            'setup_1_win_rate': 0.0,
            'setup_2_win_rate': 0.0,
        }

    # Count trades
    winners = [t for t in trades if t.is_winner]
    losers = [t for t in trades if t.is_loser]
    breakeven = [t for t in trades if t.is_breakeven]

    winning_trades = len(winners)
    losing_trades = len(losers)
    total_trades = len(trades)

    # Win rate
    win_rate = winning_trades / total_trades if total_trades > 0 else 0.0

    # Profit/Loss totals
    total_profit = sum(t.profit_loss for t in winners)
    total_loss = sum(abs(t.profit_loss) for t in losers)
    total_profit_loss = sum(t.profit_loss for t in trades)

    # Profit factor (gross profit / gross loss)
    profit_factor = total_profit / total_loss if total_loss > 0 else 0.0

    # Average metrics
    avg_profit_per_trade = total_profit_loss / total_trades if total_trades > 0 else 0.0

    # Drawdown metrics
    max_daily_drawdown = max(t.daily_drawdown for t in trades) if trades else 0.0
    avg_daily_drawdown = sum(t.daily_drawdown for t in trades) / total_trades if total_trades > 0 else 0.0

    # Setup type analysis
    setup_1_trades = [t for t in trades if t.setup_type == 'Setup 1']
    setup_2_trades = [t for t in trades if t.setup_type == 'Setup 2']

    setup_1_winners = len([t for t in setup_1_trades if t.is_winner])
    setup_2_winners = len([t for t in setup_2_trades if t.is_winner])

    setup_1_win_rate = setup_1_winners / len(setup_1_trades) if setup_1_trades else 0.0
    setup_2_win_rate = setup_2_winners / len(setup_2_trades) if setup_2_trades else 0.0

    return {
        'total_trades': total_trades,
        'winning_trades': winning_trades,
        'losing_trades': losing_trades,
        'breakeven_trades': len(breakeven),
        'win_rate': win_rate,
        'total_profit_loss': total_profit_loss,
        'avg_profit_per_trade': avg_profit_per_trade,
        'gross_profit': total_profit,
        'gross_loss': total_loss,
        'profit_factor': profit_factor,
        'max_daily_drawdown': max_daily_drawdown,
        'avg_daily_drawdown': avg_daily_drawdown,
        'setup_1_trades': len(setup_1_trades),
        'setup_2_trades': len(setup_2_trades),
        'setup_1_win_rate': setup_1_win_rate,
        'setup_2_win_rate': setup_2_win_rate,
    }


def main():
    """Main execution."""
    import sys

    if len(sys.argv) < 2:
        print("Usage: python parse_journal.py <journal_csv>")
        sys.exit(1)

    journal_path = sys.argv[1]

    # Parse trades
    trades = parse_journal(journal_path)
    print(f"✅ Loaded {len(trades)} trades from {journal_path}")

    # Calculate metrics
    metrics = calculate_metrics(trades)

    # Print metrics
    print("\n" + "="*60)
    print(f"TRADE SUMMARY")
    print("="*60)
    print(f"Total Trades:        {metrics['total_trades']}")
    print(f"Winning Trades:      {metrics['winning_trades']}")
    print(f"Losing Trades:       {metrics['losing_trades']}")
    print(f"Breakeven Trades:    {metrics['breakeven_trades']}")
    print(f"Win Rate:            {metrics['win_rate']:.2%}")

    print(f"\n" + "="*60)
    print(f"PROFITABILITY")
    print("="*60)
    print(f"Gross Profit:        ${metrics['gross_profit']:,.2f}")
    print(f"Gross Loss:          ${metrics['gross_loss']:,.2f}")
    print(f"Net Profit/Loss:     ${metrics['total_profit_loss']:,.2f}")
    print(f"Avg Per Trade:       ${metrics['avg_profit_per_trade']:,.2f}")
    print(f"Profit Factor:       {metrics['profit_factor']:.2f}")

    print(f"\n" + "="*60)
    print(f"DRAWDOWN METRICS")
    print("="*60)
    print(f"Max Daily Drawdown:  {metrics['max_daily_drawdown']:.2f}%")
    print(f"Avg Daily Drawdown:  {metrics['avg_daily_drawdown']:.2f}%")

    print(f"\n" + "="*60)
    print(f"SETUP TYPE ANALYSIS")
    print("="*60)
    print(f"Setup 1 Trades:      {metrics['setup_1_trades']} (Win Rate: {metrics['setup_1_win_rate']:.2%})")
    print(f"Setup 2 Trades:      {metrics['setup_2_trades']} (Win Rate: {metrics['setup_2_win_rate']:.2%})")

    # Gate validation
    print(f"\n" + "="*60)
    print(f"SUCCESS GATE VALIDATION")
    print("="*60)

    gates = {
        'Win Rate ≥ 50%': (metrics['win_rate'] >= 0.50, f"{metrics['win_rate']:.2%}"),
        'Profit Factor ≥ 1.5': (metrics['profit_factor'] >= 1.5, f"{metrics['profit_factor']:.2f}"),
        'Daily Drawdown ≤ 2%': (metrics['max_daily_drawdown'] <= 2.0, f"{metrics['max_daily_drawdown']:.2f}%"),
    }

    all_pass = True
    for gate_name, (passed, value) in gates.items():
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{gate_name:<25} {status:<12} ({value})")
        if not passed:
            all_pass = False

    print(f"\n{'OVERALL':<25} {'✅ PASS' if all_pass else '❌ FAIL':<12}")


if __name__ == '__main__':
    main()
