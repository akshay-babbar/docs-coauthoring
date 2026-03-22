# Scenario: Python body-only change (binding vote) makes docstring stale

A data validation function’s signature did not change, but its behavior did. The function is documented, and the docstring contains a falsifiable statement that is now wrong. You must detect this body-only semantic drift and update the docstring conservatively.

## Baseline (committed) state

### `src/validate.py`

```python
def validate_input(data: dict) -> bool:
    """Validate input data against schema.

    Checks three conditions:
    1. Data is not empty
    2. Required keys exist
    3. Values are non-null

    Args:
        data: Dictionary to validate.

    Returns:
        True if all three conditions pass.
    """
    if not data:
        return False
    required = ["name", "email"]
    if not all(k in data for k in required):
        return False
    if any(v is None for v in data.values()):
        return False
    return True
```

### `README.md`

```markdown
# validation

The `validate_input` helper validates user input.

Do not auto-write markdown in this repo.
```

## Working tree (current) state

The function now checks an additional condition (email must contain `@`). Signature is identical.

### `src/validate.py`

```python
def validate_input(data: dict) -> bool:
    """Validate input data against schema.

    Checks three conditions:
    1. Data is not empty
    2. Required keys exist
    3. Values are non-null

    Args:
        data: Dictionary to validate.

    Returns:
        True if all three conditions pass.
    """
    if not data:
        return False
    required = ["name", "email"]
    if not all(k in data for k in required):
        return False
    if any(v is None for v in data.values()):
        return False
    if "@" not in data.get("email", ""):
        return False
    return True
```

### `README.md` (unchanged)

```markdown
# validation

The `validate_input` helper validates user input.

Do not auto-write markdown in this repo.
```

## Git setup

```bash
git init
mkdir -p src
cat > src/validate.py <<'EOF'
def validate_input(data: dict) -> bool:
    """Validate input data against schema.

    Checks three conditions:
    1. Data is not empty
    2. Required keys exist
    3. Values are non-null

    Args:
        data: Dictionary to validate.

    Returns:
        True if all three conditions pass.
    """
    if not data:
        return False
    required = ["name", "email"]
    if not all(k in data for k in required):
        return False
    if any(v is None for v in data.values()):
        return False
    return True
EOF
cat > README.md <<'EOF'
# validation

The `validate_input` helper validates user input.

Do not auto-write markdown in this repo.
EOF
git add -A && git commit -m "baseline"

cat > src/validate.py <<'EOF'
def validate_input(data: dict) -> bool:
    """Validate input data against schema.

    Checks three conditions:
    1. Data is not empty
    2. Required keys exist
    3. Values are non-null

    Args:
        data: Dictionary to validate.

    Returns:
        True if all three conditions pass.
    """
    if not data:
        return False
    required = ["name", "email"]
    if not all(k in data for k in required):
        return False
    if any(v is None for v in data.values()):
        return False
    if "@" not in data.get("email", ""):
        return False
    return True
EOF
```

## Output spec

Produce `doc-sync-report.md` with the full doc-coauthoring style report. It must call out the body-only change and update the docstring statement from three conditions to four.
