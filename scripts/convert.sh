#!/usr/bin/env bash
# convert.sh — Convert SKILL.md to platform-specific formats
# Generates .cursorrules and .windsurfrules from the canonical SKILL.md
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

# Generate .cursorrules (Cursor format)
# Cursor uses a flat markdown file with all instructions
cat > "$OUTPUT_DIR/.cursorrules" << 'CURSOR_HEADER'
# Doc-Coauthoring Rules for Cursor

You are a surgical documentation updater. Your job is to patch documentation
when—and only when—a caller-visible contract changes.

## Core Principles

1. **Conservative by default**: Do less and flag more
2. **Docstrings auto-write, README propose-only**: Never auto-write markdown files
3. **No guessing**: Flag uncertainty as [NEEDS HUMAN REVIEW]
4. **Order matters**: Docstrings first, README sections second

CURSOR_HEADER

echo "$BODY" >> "$OUTPUT_DIR/.cursorrules"

if [ -n "$SCOPE_BOUNDS" ]; then
    echo "" >> "$OUTPUT_DIR/.cursorrules"
    echo "---" >> "$OUTPUT_DIR/.cursorrules"
    echo "" >> "$OUTPUT_DIR/.cursorrules"
    echo "$SCOPE_BOUNDS" >> "$OUTPUT_DIR/.cursorrules"
fi



if [ -n "$VERIFY_STEPS" ]; then
    echo "" >> "$OUTPUT_DIR/.cursorrules"
    echo "---" >> "$OUTPUT_DIR/.cursorrules"
    echo "" >> "$OUTPUT_DIR/.cursorrules"
    echo "$VERIFY_STEPS" >> "$OUTPUT_DIR/.cursorrules"
fi

echo "Generated: $OUTPUT_DIR/.cursorrules"

# Generate .windsurfrules (Windsurf format)
# Windsurf uses similar format but with different header conventions
cat > "$OUTPUT_DIR/.windsurfrules" << 'WINDSURF_HEADER'
# Doc-Coauthoring Skill

<doc_coauthoring_skill>

## Identity

You are a surgical documentation updater operating under strict preservation
rules. You patch documentation when a caller-visible API contract changes.
You are conservative by design.

## Activation

This skill activates when the user requests documentation sync after code
changes. Do NOT activate for general documentation tasks.

WINDSURF_HEADER

echo "$BODY" >> "$OUTPUT_DIR/.windsurfrules"

if [ -n "$SCOPE_BOUNDS" ]; then
    echo "" >> "$OUTPUT_DIR/.windsurfrules"
    echo "$SCOPE_BOUNDS" >> "$OUTPUT_DIR/.windsurfrules"
fi



if [ -n "$VERIFY_STEPS" ]; then
    echo "" >> "$OUTPUT_DIR/.windsurfrules"
    echo "$VERIFY_STEPS" >> "$OUTPUT_DIR/.windsurfrules"
fi

echo "</doc_coauthoring_skill>" >> "$OUTPUT_DIR/.windsurfrules"

echo "Generated: $OUTPUT_DIR/.windsurfrules"

# Generate AGENTS.md router entry (for repos using agents.md pattern)
cat > "$OUTPUT_DIR/.agents-entry.md" << AGENTS_ENTRY
## doc-coauthoring

| Trigger | Description |
|---------|-------------|
| \`/doc-sync\`, \`/docs\`, after commits changing public APIs | Updates inline docstrings, proposes README updates |

**Constraints**: Never auto-writes markdown files. Flags removals for human review. No auto-commit.

**Files**: \`doc-coauthoring/SKILL.md\`, \`doc-coauthoring/scripts/get_diff.sh\`
AGENTS_ENTRY

echo "Generated: $OUTPUT_DIR/.agents-entry.md (for AGENTS.md inclusion)"

# Summary
echo ""
echo "=== Conversion Complete ==="
echo "Source:  $SKILL_FILE"
echo "Outputs:"
echo "  - .cursorrules    (Cursor AI)"
echo "  - .windsurfrules  (Windsurf/Codeium)"
echo "  - .agents-entry.md (AGENTS.md snippet)"
echo ""
echo "Copy the appropriate file to your project root."
