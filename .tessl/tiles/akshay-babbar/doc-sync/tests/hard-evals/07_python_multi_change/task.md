# Scenario: Python multi-change diff; must not conflate actions

A single commit-range contains three different kinds of changes across one Python module: a documented function gets a new parameter, an undocumented internal helper is refactored, and a documented exported function is deleted. You must apply the two-factor rule per symbol.

## Baseline (committed) state

### `src/orders.py`

```python
from __future__ import annotations


def process_order(order_id: str) -> dict:
    """Process an order by ID.

    Args:
        order_id: The order identifier.

    Returns:
        A summary dict.
    """
    _internal_flush({"order_id": order_id})
    return {"id": order_id, "status": "processed"}


def _internal_flush(cache: dict) -> None:
    cache.clear()


def deprecated_export(x: int) -> int:
    """Legacy exported helper.

    Args:
        x: Input value.

    Returns:
        Doubled value.
    """
    return x * 2
```

### `README.md`

```markdown
# orders

Use `process_order` to process incoming orders.

The function `deprecated_export` is kept for legacy integrations.

Do not auto-apply markdown changes.
```

## Working tree (current) state

Changes in one diff:
- `process_order` adds a new parameter `dry_run` (documented → in scope)
- `_internal_flush` body refactor (no docstring and no code-span mention → out of scope)
- `deprecated_export` removed (documented → flag)

### `src/orders.py`

```python
from __future__ import annotations


def process_order(order_id: str, dry_run: bool = False) -> dict:
    """Process an order by ID.

    Args:
        order_id: The order identifier.

    Returns:
        A summary dict.
    """
    if not dry_run:
        _internal_flush({"order_id": order_id})
    return {"id": order_id, "status": "processed"}


def _internal_flush(cache: dict) -> None:
    # new flush strategy: preserve keys, reset values
    for k in list(cache.keys()):
        cache[k] = None
```

### `README.md` (unchanged)

```markdown
# orders

Use `process_order` to process incoming orders.

The function `deprecated_export` is kept for legacy integrations.

Do not auto-apply markdown changes.
```

## Git setup

```bash
git init
mkdir -p src
cat > src/orders.py <<'EOF'
from __future__ import annotations


def process_order(order_id: str) -> dict:
    """Process an order by ID.

    Args:
        order_id: The order identifier.

    Returns:
        A summary dict.
    """
    _internal_flush({"order_id": order_id})
    return {"id": order_id, "status": "processed"}


def _internal_flush(cache: dict) -> None:
    cache.clear()


def deprecated_export(x: int) -> int:
    """Legacy exported helper.

    Args:
        x: Input value.

    Returns:
        Doubled value.
    """
    return x * 2
EOF
cat > README.md <<'EOF'
# orders

Use `process_order` to process incoming orders.

The function `deprecated_export` is kept for legacy integrations.

Do not auto-apply markdown changes.
EOF
git add -A && git commit -m "baseline"

cat > src/orders.py <<'EOF'
from __future__ import annotations


def process_order(order_id: str, dry_run: bool = False) -> dict:
    """Process an order by ID.

    Args:
        order_id: The order identifier.

    Returns:
        A summary dict.
    """
    if not dry_run:
        _internal_flush({"order_id": order_id})
    return {"id": order_id, "status": "processed"}


def _internal_flush(cache: dict) -> None:
    # new flush strategy: preserve keys, reset values
    for k in list(cache.keys()):
        cache[k] = None
EOF
```

## Output spec

Produce `doc-sync-report.md` with the full doc-coauthoring style report. It must (1) update the `process_order` docstring to document `dry_run`, (2) skip `_internal_flush`, and (3) flag `deprecated_export` as removed.
