#!/usr/bin/env bash
# preflight.sh — Validate eval scenarios before Tessl upload
# Run from skill repo root: bash tests/preflight.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(dirname "$SCRIPT_DIR")"
PUBLIC_EVALS_DIR="$SKILL_ROOT/evals"
HARD_EVALS_DIR="$SKILL_ROOT/tests/hard-evals"

echo "=== Tessl Eval Preflight Check ==="
echo ""

PASSED=0
FAILED=0
TOTAL=0

validate_scenario_dir() {
    local root_dir="$1"
    local label="$2"

    if [ ! -d "$root_dir" ] || [ -z "$(ls -A "$root_dir" 2>/dev/null)" ]; then
        echo "ERROR: No $label scenarios found in $root_dir"
        exit 1
    fi

    for SCENARIO_DIR in "$root_dir"/*/; do
        [ ! -d "$SCENARIO_DIR" ] && continue
        scenario=$(basename "$SCENARIO_DIR")
        ((TOTAL++))
        ERRORS=()

        [ ! -f "$SCENARIO_DIR/task.md" ] && ERRORS+=("missing task.md")
        [ ! -f "$SCENARIO_DIR/criteria.json" ] && ERRORS+=("missing criteria.json")

        if [ -d "$SCENARIO_DIR/fixture" ]; then
            FIXTURE_FILES=$(find "$SCENARIO_DIR/fixture" -type f 2>/dev/null | head -1)
            [ -z "$FIXTURE_FILES" ] && ERRORS+=("fixture/ exists but is empty")
        fi

        if [ -f "$SCENARIO_DIR/criteria.json" ]; then
            if ! python3 -c "import json; json.load(open('$SCENARIO_DIR/criteria.json'))" 2>/dev/null; then
                ERRORS+=("criteria.json is not valid JSON")
            fi
        fi

        if [ ${#ERRORS[@]} -eq 0 ]; then
            echo "PASS: [$label] $scenario"
            ((PASSED++))
        else
            echo "FAIL: [$label] $scenario"
            for err in "${ERRORS[@]}"; do
                echo "  $err"
            done
            ((FAILED++))
        fi
    done
}

validate_scenario_dir "$PUBLIC_EVALS_DIR" "eval"
validate_scenario_dir "$HARD_EVALS_DIR" "hard-eval"

echo ""
echo "=== Results ==="
echo "Passed: $PASSED/$TOTAL  Failed: $FAILED/$TOTAL"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "✓ All scenarios ready for Tessl upload"
    echo ""
    echo "Next steps:"
    echo "  1. npx tessl skill review ./"
    echo "  2. npx tessl eval run ./evals/"
    echo "  3. Spot-check tests/hard-evals/ locally before publishing"
    exit 0
else
    echo "✗ Some scenarios have issues — fix before upload"
    exit 1
fi
