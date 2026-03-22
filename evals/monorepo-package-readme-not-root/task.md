# Scenario: Monorepo package README (not root) contains the mention

A monorepo has a package README at `packages/auth/README.md` (not the root README). A documented function `verify_token` in `packages/auth/auth.py` gained a new parameter. The root `README.md` does not mention this function. Only the package README mentions it in a code span.

The skill must find the package-level README mention and propose there (never auto-write markdown).

## Setup

Extract the following file and set up the git repository:

=============== FILE: inputs/setup.sh ===============
#!/usr/bin/env bash
set -euo pipefail

git init
git config user.email "dev@example.com"
git config user.name "Dev"

mkdir -p packages/auth

cat > packages/auth/auth.py << 'PYEOF'
from __future__ import annotations


def verify_token(token: str) -> bool:
    """Verify an authentication token.

    Args:
        token: The raw token string.

    Returns:
        True if the token is valid.
    """
    return bool(token)
PYEOF

cat > packages/auth/README.md << 'MDEOF'
# auth package

Use `verify_token(token)` to validate tokens.

Do not auto-apply markdown edits.
MDEOF

cat > README.md << 'MDEOF'
# monorepo

Root documentation.
MDEOF

git add -A && git commit -m "baseline"

cat > packages/auth/auth.py << 'PYEOF'
from __future__ import annotations


def verify_token(token: str, expiry_seconds: int = 3600) -> bool:
    """Verify an authentication token.

    Args:
        token: The raw token string.

    Returns:
        True if the token is valid.
    """
    _ = expiry_seconds
    return bool(token)
PYEOF

## Output Specification

Run the doc-sync skill and produce `doc-sync-report.md` with the full report output.
