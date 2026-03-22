#!/usr/bin/env bash
# convert.sh — Convert SKILL.md to platform-specific formats
# Generates modern Cursor/Windsurf instruction files from the canonical SKILL.md
#
# Usage:
#   ./convert.sh                     # Output to current directory
#   ./convert.sh /path/to/output     # Output to specific directory
#
# Zero external dependencies. POSIX-compliant.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
SKILL_FILE="$SKILL_DIR/SKILL.md"
OUTPUT_DIR="${1:-.}"

# Verify SKILL.md exists
if [ ! -f "$SKILL_FILE" ]; then
    echo "Error: SKILL.md not found at $SKILL_FILE" >&2
    exit 1
fi

# Create output directory if needed
mkdir -p "$OUTPUT_DIR"

# Read SKILL.md content
SKILL_CONTENT=$(cat "$SKILL_FILE")

# Extract frontmatter (between --- markers)
FRONTMATTER=$(echo "$SKILL_CONTENT" | sed -n '/^---$/,/^---$/p' | sed '1d;$d')

# Extract body (after second ---)
BODY=$(echo "$SKILL_CONTENT" | sed -n '/^---$/,/^---$/d; p' | tail -n +1)

# Extract key fields from frontmatter
NAME=$(echo "$FRONTMATTER" | grep -E '^name:' | sed 's/name: *//' | tr -d '"' || echo "doc-coauthoring")
DESCRIPTION=$(echo "$FRONTMATTER" | sed -n '/^description:/,/^[a-z]/p' | sed '$d' | sed 's/description: *//' | tr -d '>' | tr '\n' ' ' | sed 's/  */ /g' || echo "")

# Read reference files for inclusion
SCOPE_BOUNDS=""
VERIFY_STEPS=""

if [ -f "$SKILL_DIR/references/scope-bounds.md" ]; then
    SCOPE_BOUNDS=$(cat "$SKILL_DIR/references/scope-bounds.md")
fi



if [ -f "$SKILL_DIR/references/verify-steps.md" ]; then
    VERIFY_STEPS=$(cat "$SKILL_DIR/references/verify-steps.md")
fi

# Condensed critical rules from workflow-steps.md.
# The full file is too large (~300 lines) for static inclusion, but the
# safety-critical behaviors MUST be present on prompt-based platforms.
WORKFLOW_CRITICAL='## Apply-Mode Critical Rules (from workflow-steps.md)

**Confirmation checkpoint (mandatory):**
Even when `--apply` is passed, the workflow is: detect → classify → build the
complete Doc Sync Report → **show the report and ask for confirmation** → only
proceed to file writes on explicit approval.

**Idempotency guard (mandatory):**
Before writing any docstring update, read the current docstring state. If the
parameter documentation already exists and matches the current signature, skip
and report "Already current." This prevents duplicate entries when `--apply` is
run twice on the same uncommitted diff.

**Inferred description marker (mandatory for new descriptions):**
When writing a new parameter or return description that did not exist before,
append `[inferred — verify]` inline. This marker signals the description was
inferred and needs human verification. Remove after review.

**Report format (mandatory):**
```
## Doc Sync Report
Mode: dry-run | apply

### Updated / Would Update
1. `symbol` ─ file:line ─ docstring
   + param: description [inferred — verify]

### Proposed (README; requires explicit approval)
2. `symbol` ─ README.md:line ─ heading
   ~ Proposed patch in diff format

### Flagged for Human Review
- `symbol` ─ file ─ reason
  ! Action needed

### No Changes
✓ No contract changes detected.
```

**Confirmation prompt (apply mode, after showing report):**
- 1 change: `Apply this change? (yes/no)`
- 2+ changes: `Found N changes. Apply all (A), select by number (1, 3...), or skip (S)?`'

# Generate Cursor project rule (modern format)
mkdir -p "$OUTPUT_DIR/.cursor/rules"
cat > "$OUTPUT_DIR/.cursor/rules/doc-sync.mdc" << 'CURSOR_HEADER'
---
description: Doc Sync workflow for documentation drift after code changes
alwaysApply: false
---

# Doc Sync Rules for Cursor

You are a surgical documentation updater. Your job is to patch documentation
when—and only when—a caller-visible contract changes.

## Core Principles

1. **Conservative by default**: Do less and flag more
2. **Docstrings auto-write, README propose-first**: Any markdown edit requires explicit approval
3. **No guessing**: Flag uncertainty as [NEEDS HUMAN REVIEW]
4. **Order matters**: Docstrings first, README sections second

CURSOR_HEADER

echo "$BODY" >> "$OUTPUT_DIR/.cursor/rules/doc-sync.mdc"

if [ -n "$SCOPE_BOUNDS" ]; then
    echo "" >> "$OUTPUT_DIR/.cursor/rules/doc-sync.mdc"
    echo "---" >> "$OUTPUT_DIR/.cursor/rules/doc-sync.mdc"
    echo "" >> "$OUTPUT_DIR/.cursor/rules/doc-sync.mdc"
    echo "$SCOPE_BOUNDS" >> "$OUTPUT_DIR/.cursor/rules/doc-sync.mdc"
fi



if [ -n "$VERIFY_STEPS" ]; then
    echo "" >> "$OUTPUT_DIR/.cursor/rules/doc-sync.mdc"
    echo "---" >> "$OUTPUT_DIR/.cursor/rules/doc-sync.mdc"
    echo "" >> "$OUTPUT_DIR/.cursor/rules/doc-sync.mdc"
    echo "$VERIFY_STEPS" >> "$OUTPUT_DIR/.cursor/rules/doc-sync.mdc"
fi

echo "" >> "$OUTPUT_DIR/.cursor/rules/doc-sync.mdc"
echo "---" >> "$OUTPUT_DIR/.cursor/rules/doc-sync.mdc"
echo "" >> "$OUTPUT_DIR/.cursor/rules/doc-sync.mdc"
echo "$WORKFLOW_CRITICAL" >> "$OUTPUT_DIR/.cursor/rules/doc-sync.mdc"

echo "Generated: $OUTPUT_DIR/.cursor/rules/doc-sync.mdc"

# Legacy Cursor compatibility
cp "$OUTPUT_DIR/.cursor/rules/doc-sync.mdc" "$OUTPUT_DIR/.cursorrules"
echo "Generated: $OUTPUT_DIR/.cursorrules (legacy Cursor compatibility)"

# Generate AGENTS.md (modern Windsurf/Cascade path)
cat > "$OUTPUT_DIR/AGENTS.md" << 'WINDSURF_HEADER'
# Doc Sync Instructions

<doc_sync_skill>

## Identity

You are a surgical documentation updater operating under strict preservation
rules. You patch documentation when a caller-visible API contract changes.
You are conservative by design.

## Activation

This skill activates when the user requests documentation sync after code
changes. Do NOT activate for general documentation tasks.

WINDSURF_HEADER

echo "$BODY" >> "$OUTPUT_DIR/AGENTS.md"

if [ -n "$SCOPE_BOUNDS" ]; then
    echo "" >> "$OUTPUT_DIR/AGENTS.md"
    echo "$SCOPE_BOUNDS" >> "$OUTPUT_DIR/AGENTS.md"
fi



if [ -n "$VERIFY_STEPS" ]; then
    echo "" >> "$OUTPUT_DIR/AGENTS.md"
    echo "$VERIFY_STEPS" >> "$OUTPUT_DIR/AGENTS.md"
fi

echo "" >> "$OUTPUT_DIR/AGENTS.md"
echo "$WORKFLOW_CRITICAL" >> "$OUTPUT_DIR/AGENTS.md"

echo "</doc_sync_skill>" >> "$OUTPUT_DIR/AGENTS.md"

echo "Generated: $OUTPUT_DIR/AGENTS.md"

# Legacy Windsurf compatibility
cp "$OUTPUT_DIR/AGENTS.md" "$OUTPUT_DIR/.windsurfrules"
echo "Generated: $OUTPUT_DIR/.windsurfrules (legacy Windsurf compatibility)"

# Generate AGENTS.md router entry (for repos using agents.md pattern)
cat > "$OUTPUT_DIR/.agents-entry.md" << AGENTS_ENTRY
## doc-sync

| Trigger | Description |
|---------|-------------|
| \`/doc-sync\`, \`/docs\`, after commits changing public APIs | Updates inline docstrings, proposes README updates |

**Constraints**: Requires explicit approval for markdown edits. Flags removals for human review. No auto-commit.

**Files**: `doc-sync/SKILL.md`, `doc-sync/scripts/get_diff.sh`
AGENTS_ENTRY

echo "Generated: $OUTPUT_DIR/.agents-entry.md (for AGENTS.md inclusion)"

# Summary
echo ""
echo "=== Conversion Complete ==="
echo "Source:  $SKILL_FILE"
echo "Outputs:"
echo "  - .cursor/rules/doc-sync.mdc  (Cursor project rule)"
echo "  - AGENTS.md                          (Windsurf/Cascade instructions)"
echo "  - .cursorrules                       (legacy Cursor compatibility)"
echo "  - .windsurfrules                     (legacy Windsurf compatibility)"
echo "  - .agents-entry.md (AGENTS.md snippet)"
echo ""
echo "Copy the appropriate file to your project root."
