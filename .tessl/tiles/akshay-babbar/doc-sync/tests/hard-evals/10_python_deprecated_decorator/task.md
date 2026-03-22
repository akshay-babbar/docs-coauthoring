# Scenario: Python deprecated decorator added; must surface deprecation and flag README

A Python library added a `@deprecated` decorator to a previously documented function without changing its signature. This is a caller-visible contract change (the function is now deprecated) even though the signature is identical. The README references the function in a code span.

Your job is conservative doc coauthoring: update only previously documented symbols whose caller-visible contract changed, never auto-write markdown, and flag uncertainty.

## Baseline (committed) state

### `src/api.py`

```python
from __future__ import annotations


def fetch_user(user_id: int) -> dict:
    """Fetch a user record.

    Args:
        user_id: The user's integer ID.

    Returns:
        A user dict.
    """
    return {"id": user_id}
```

### `README.md`

```markdown
# user-service

Call `fetch_user` to load user data.

Do not auto-apply markdown edits.
```

## Working tree (current) state

A `@deprecated` decorator was added. Signature and behavior otherwise unchanged.

### `src/api.py`

```python
from __future__ import annotations


def deprecated(reason: str):
    def _wrap(fn):
        fn.__deprecated_reason__ = reason
        return fn
    return _wrap


@deprecated("Use get_user(user_id) instead")
def fetch_user(user_id: int) -> dict:
    """Fetch a user record.

    Args:
        user_id: The user's integer ID.

    Returns:
        A user dict.
    """
    return {"id": user_id}
```

### `README.md` (unchanged)

```markdown
# user-service

Call `fetch_user` to load user data.

Do not auto-apply markdown edits.
```

## Git setup

Init repo, commit baseline, overwrite with working tree so `git diff HEAD` catches the decorator addition and nothing else:

```bash
git init
mkdir -p src
cat > src/api.py <<'EOF'
from __future__ import annotations


def fetch_user(user_id: int) -> dict:
    """Fetch a user record.

    Args:
        user_id: The user's integer ID.

    Returns:
        A user dict.
    """
    return {"id": user_id}
EOF
cat > README.md <<'EOF'
# user-service

Call `fetch_user` to load user data.

Do not auto-apply markdown edits.
EOF
git add -A && git commit -m "baseline"

cat > src/api.py <<'EOF'
from __future__ import annotations


def deprecated(reason: str):
    def _wrap(fn):
        fn.__deprecated_reason__ = reason
        return fn
    return _wrap


@deprecated("Use get_user(user_id) instead")
def fetch_user(user_id: int) -> dict:
    """Fetch a user record.

    Args:
        user_id: The user's integer ID.

    Returns:
        A user dict.
    """
    return {"id": user_id}
EOF
```

## Output spec

Produce `doc-sync-report.md` containing the full doc-coauthoring style report output. It must:

- Update the `fetch_user` docstring to explicitly note the deprecation (minimal change).
- Flag the README mention of `fetch_user` for human review (do not auto-edit markdown).
