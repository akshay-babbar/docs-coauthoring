# Scenario: Docstring and README contradict; return type changes

A Python function `calculate_fee` has conflicting documentation: its docstring describes one return type/units while the README describes another. The function's return type annotation changed from `-> int` to `-> Decimal`.

You must:
- Update the docstring to match the new return type.
- Propose (not auto-write) the README update.
- Surface the contradiction in the report — do not silently pick one source of truth.

## Setup

Extract the following file and set up the git repository:

=============== FILE: inputs/setup.sh ===============
#!/usr/bin/env bash
set -euo pipefail

git init
git config user.email "dev@example.com"
git config user.name "Dev"

mkdir -p src

cat > src/fees.py << 'PYEOF'
from __future__ import annotations


def calculate_fee(amount_cents: int, rate_percent: int = 5) -> int:
    """Calculate a fee for a transaction.

    Args:
        amount_cents: Amount in cents.
        rate_percent: Fee rate as an integer percent.

    Returns:
        Fee in dollars as a float.
    """
    return (amount_cents * rate_percent) // 100
PYEOF

cat > README.md << 'MDEOF'
# Fees

`calculate_fee` returns an integer fee in cents.

Do not auto-apply markdown edits.
MDEOF

git add -A && git commit -m "baseline"

cat > src/fees.py << 'PYEOF'
from __future__ import annotations

from decimal import Decimal


def calculate_fee(amount_cents: int, rate_percent: int = 5) -> Decimal:
    """Calculate a fee for a transaction.

    Args:
        amount_cents: Amount in cents.
        rate_percent: Fee rate as an integer percent.

    Returns:
        Fee in dollars as a float.
    """
    return (Decimal(amount_cents) * Decimal(rate_percent)) / Decimal(100)
PYEOF

## Output Specification

Run the doc-sync skill and produce `doc-sync-report.md` with the full report output.
