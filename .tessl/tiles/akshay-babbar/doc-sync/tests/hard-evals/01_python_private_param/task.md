# Scenario: Python documented private method gains a new parameter

A team maintains an internal billing library. A documented private method is used across the codebase and its signature changed (a new parameter was added). Your job is to sync documentation conservatively: update only previously-documented symbols whose caller-visible contract changed.

## Baseline (committed) state

### `src/billing.py`

```python
class PaymentProcessor:
    def __init__(self, default_currency: str = "USD") -> None:
        self.default_currency = default_currency

    def _normalize_amount(self, amount_cents: int) -> int:
        """Normalize amount into cents.

        Args:
            amount_cents: Amount in cents.

        Returns:
            Normalized integer cents.
        """
        if amount_cents < 0:
            raise ValueError("amount_cents must be non-negative")
        return int(amount_cents)
```

### `README.md`

```markdown
# Billing

This package provides internal billing utilities.

Do not edit documentation automatically in this repository's markdown.
```

## Working tree (current) state

The private method adds a new optional parameter `currency`.

### `src/billing.py`

```python
class PaymentProcessor:
    def __init__(self, default_currency: str = "USD") -> None:
        self.default_currency = default_currency

    def _normalize_amount(self, amount_cents: int, currency: str | None = None) -> int:
        """Normalize amount into cents.

        Args:
            amount_cents: Amount in cents.

        Returns:
            Normalized integer cents.
        """
        if amount_cents < 0:
            raise ValueError("amount_cents must be non-negative")
        if currency is None:
            currency = self.default_currency
        if currency not in {"USD", "EUR"}:
            raise ValueError("unsupported currency")
        return int(amount_cents)
```

### `README.md` (unchanged)

```markdown
# Billing

This package provides internal billing utilities.

Do not edit documentation automatically in this repository's markdown.
```

## Git setup

1. Init repo, commit baseline:

```bash
git init
mkdir -p src
cat > src/billing.py <<'EOF'
class PaymentProcessor:
    def __init__(self, default_currency: str = "USD") -> None:
        self.default_currency = default_currency

    def _normalize_amount(self, amount_cents: int) -> int:
        """Normalize amount into cents.

        Args:
            amount_cents: Amount in cents.

        Returns:
            Normalized integer cents.
        """
        if amount_cents < 0:
            raise ValueError("amount_cents must be non-negative")
        return int(amount_cents)
EOF
cat > README.md <<'EOF'
# Billing

This package provides internal billing utilities.

Do not edit documentation automatically in this repository's markdown.
EOF
git add -A && git commit -m "baseline"
```

2. Overwrite with working tree so `git diff HEAD` shows exactly the parameter addition:

```bash
cat > src/billing.py <<'EOF'
class PaymentProcessor:
    def __init__(self, default_currency: str = "USD") -> None:
        self.default_currency = default_currency

    def _normalize_amount(self, amount_cents: int, currency: str | None = None) -> int:
        """Normalize amount into cents.

        Args:
            amount_cents: Amount in cents.

        Returns:
            Normalized integer cents.
        """
        if amount_cents < 0:
            raise ValueError("amount_cents must be non-negative")
        if currency is None:
            currency = self.default_currency
        if currency not in {"USD", "EUR"}:
            raise ValueError("unsupported currency")
        return int(amount_cents)
EOF
```

## Output spec

Produce `doc-sync-report.md` containing the full skill-style report output (dry-run is acceptable). The report must show the docstring update needed for `_normalize_amount`.
