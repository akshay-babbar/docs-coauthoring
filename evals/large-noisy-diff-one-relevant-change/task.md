# Scenario: Large noisy diff; only one relevant doc change

A developer made a large refactor touching many files and hundreds of lines. Only one change is documentation-relevant: a documented Python function `parse_config` gained a new optional parameter `strict: bool = False`. The remaining changes are internal refactors, test updates, and configuration changes with no docstrings.

Your job is to find the one in-scope change without false positives.

## Setup

Extract the following file and set up the git repository:

=============== FILE: inputs/setup.sh ===============
#!/usr/bin/env bash
set -euo pipefail

git init
git config user.email "dev@example.com"
git config user.name "Dev"

mkdir -p src tests config

cat > src/config_parser.py << 'PYEOF'
from __future__ import annotations


def parse_config(path: str) -> dict:
    """Parse a config file into a dict.

    Args:
        path: Path to a KEY=VALUE config file.

    Returns:
        Parsed key-value pairs.
    """
    out: dict[str, str] = {}
    with open(path, "r", encoding="utf-8") as f:
        for line in f.read().splitlines():
            if not line.strip() or line.strip().startswith("#"):
                continue
            if "=" not in line:
                continue
            k, _, v = line.partition("=")
            out[k.strip()] = v.strip()
    return out
PYEOF

# Create lots of noise files (undocumented) to simulate a large refactor.
for i in $(seq 1 11); do
  cat > "src/noise_${i}.py" <<'PYEOF'
from __future__ import annotations


def internal_transform(x: int) -> int:
    # Internal helper: intentionally undocumented.
    total = 0
    for n in range(25):
        total += (x + n) % 7
    # Pretend this file is large.
    blob = """
    line01
    line02
    line03
    line04
    line05
    line06
    line07
    line08
    line09
    line10
    line11
    line12
    line13
    line14
    line15
    line16
    line17
    line18
    line19
    line20
    line21
    line22
    line23
    line24
    line25
    """
    _ = blob
    return total
PYEOF

done

cat > tests/test_noise.py << 'PYEOF'
def test_smoke():
    assert True
PYEOF

cat > config/app.toml << 'EOF'
# Placeholder config file
mode = "dev"
EOF

git add -A && git commit -m "baseline noisy repo"

# Working tree change: ONLY parse_config is a doc-relevant change.
cat > src/config_parser.py << 'PYEOF'
from __future__ import annotations


def parse_config(path: str, strict: bool = False) -> dict:
    """Parse a config file into a dict.

    Args:
        path: Path to a KEY=VALUE config file.

    Returns:
        Parsed key-value pairs.
    """
    out: dict[str, str] = {}
    with open(path, "r", encoding="utf-8") as f:
        for line in f.read().splitlines():
            if not line.strip() or line.strip().startswith("#"):
                continue
            if "=" not in line:
                if strict:
                    raise ValueError("invalid line")
                continue
            k, _, v = line.partition("=")
            out[k.strip()] = v.strip()
    return out
PYEOF

# Additional noise changes (no docstrings anywhere).
for i in $(seq 1 4); do
  sed -i '' 's/range(25)/range(30)/' "src/noise_${i}.py" || true
  printf '\n# refactor note %s\n' "$i" >> "src/noise_${i}.py"
done

printf '\n# touched by refactor\n' >> config/app.toml

## Output Specification

Run the doc-sync skill and produce `doc-sync-report.md` with the full report output.
