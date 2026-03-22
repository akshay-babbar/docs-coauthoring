#!/usr/bin/env bash
# get_diff.sh — Extract caller-visible contract changes from git diff
# Part of doc-sync skill. Detects parameter, return type, and symbol changes.
# Zero external dependencies. POSIX-compliant where possible.
#
# Usage:
#   ./get_diff.sh                    # All uncommitted changes (working tree + staged vs HEAD)
#   ./get_diff.sh HEAD~5..HEAD       # Compare specific commit range
#   ./get_diff.sh main..feature      # Compare branches
#   ./get_diff.sh --apply            # --apply/--dry-run flags are stripped; passed by agent
#
# Output: List of changed public symbols with change type
# Exit codes: 0 = changes found, 1 = no changes, 2 = error

set -euo pipefail

# Parse arguments: strip --apply/--dry-run flags (agent mode flags, not for this script)
# Anything else is treated as the commit range.
# Default: HEAD compares working tree + staging area to last commit (all uncommitted changes).
COMMIT_RANGE=""
for arg in "$@"; do
    case "$arg" in
        --apply|--dry-run) ;; # consumed by the agent, ignored here
        *) COMMIT_RANGE="$arg" ;;
    esac
done
COMMIT_RANGE="${COMMIT_RANGE:-HEAD}"

# Colors for terminal output (disabled if not a tty)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

# Verify we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not a git repository" >&2
    exit 2
fi

# Verify commit range is valid
# For a plain ref like HEAD or HEAD~1, check directly.
# For a range like HEAD~1..HEAD, check the left side.
verify_ref() {
    git rev-parse --verify "$1" > /dev/null 2>&1
}

if [[ "$COMMIT_RANGE" == *"..."* ]]; then
    LEFT_REF="${COMMIT_RANGE%%...*}"
    RIGHT_REF="${COMMIT_RANGE##*...}"
    if ! verify_ref "$LEFT_REF" || ! verify_ref "$RIGHT_REF"; then
        echo "Error: Invalid commit or range: $COMMIT_RANGE" >&2
        exit 2
    fi
elif [[ "$COMMIT_RANGE" == *".."* ]]; then
    LEFT_REF="${COMMIT_RANGE%%..*}"
    RIGHT_REF="${COMMIT_RANGE##*..}"
    if ! verify_ref "$LEFT_REF" || ! verify_ref "$RIGHT_REF"; then
        echo "Error: Invalid commit or range: $COMMIT_RANGE" >&2
        exit 2
    fi
else
    if ! verify_ref "$COMMIT_RANGE"; then
        echo "Error: Invalid commit or range: $COMMIT_RANGE" >&2
        exit 2
    fi
fi

echo "=== Contract Change Detection ==="
if [ "$COMMIT_RANGE" = "HEAD" ]; then
    echo "Range: working tree + staged changes vs HEAD (all uncommitted)"
else
    echo "Range: $COMMIT_RANGE"
fi
echo ""

CHANGES_FOUND=0

# Get the diff with function context
DIFF_OUTPUT=$(git diff "$COMMIT_RANGE" --unified=3 -p)

if [ -z "$DIFF_OUTPUT" ]; then
    echo "No changes in commit range."
    exit 1
fi

# Track findings
declare -a ADDED_PARAMS=()
declare -a CHANGED_RETURNS=()
declare -a NEW_FUNCTIONS=()
declare -a REMOVED_SYMBOLS=()
declare -a INTERNAL_ONLY=()

# Process each changed file
while IFS= read -r file; do
    [ -z "$file" ] && continue
    
    EXT="${file##*.}"
    
    # Skip non-code files
    case "$EXT" in
        md|txt|json|yaml|yml|lock|sum|mod) continue ;;
    esac
    
    FILE_DIFF=$(git diff "$COMMIT_RANGE" -- "$file" 2>/dev/null || true)
    [ -z "$FILE_DIFF" ] && continue
    
    # Detect language and set patterns
    case "$EXT" in
        py)
            # Python: match both module-level (col 0) AND indented class methods.
            # Any function/class with an existing docstring is in scope regardless
            # of visibility — private methods with docstrings drift too.
            FUNC_PATTERN='^[-+][ \t]*def [_a-zA-Z][_a-zA-Z0-9]*\('
            CLASS_PATTERN='^[-+][ \t]*class [_a-zA-Z][_a-zA-Z0-9]*'
            PRIVATE_PATTERN='^[-+][ \t]*(def|class) _'
            RETURN_PATTERN='-> [a-zA-Z]'
            ;;
        js|ts|jsx|tsx)
            # JS/TS: require explicit 'export' to avoid false-positives on
            # internal functions. Covers functions, classes, and arrow exports.
            FUNC_PATTERN='^[-+]export (default )?(async )?function [a-zA-Z]|^[-+]export (const|let) [a-zA-Z][a-zA-Z0-9_]* *='
            CLASS_PATTERN='^[-+]export (default )?class [a-zA-Z]'
            PRIVATE_PATTERN='^[-+](private |#|  #)'
            RETURN_PATTERN='): [a-zA-Z]'
            ;;
        go)
            # Go: Uppercase first letter = exported (applies to receiver methods too)
            FUNC_PATTERN='^[-+]func [^(].*[A-Z][a-zA-Z0-9]*\(|^[-+]func \([a-zA-Z].*\) [A-Z][a-zA-Z0-9]*\('
            CLASS_PATTERN='^[-+]type [A-Z][a-zA-Z0-9]* struct'
            PRIVATE_PATTERN='^[-+]func [a-z]|^[-+]func \([a-zA-Z].*\) [a-z]'
            RETURN_PATTERN=') [a-zA-Z*\[(]'
            ;;
        rb)
            # Ruby: match both indented (class methods) and module-level defs
            FUNC_PATTERN='^[-+][ \t]*def [a-zA-Z][a-zA-Z0-9_]*'
            CLASS_PATTERN='^[-+]class [A-Z]|^[-+]module [A-Z]'
            PRIVATE_PATTERN='^[-+][ \t]*def _|^[-+][ \t]*private'
            RETURN_PATTERN='#.*@return|# @return'
            ;;
        java|kt)
            # Java/Kotlin: public/protected keyword
            FUNC_PATTERN='^[-+].*(public|protected) .* [a-zA-Z]+\('
            CLASS_PATTERN='^[-+].*(public|protected) class'
            PRIVATE_PATTERN='^[-+].*private '
            RETURN_PATTERN='(public|protected) [a-zA-Z<>\[\]]+ [a-zA-Z]+\('
            ;;
        rs)
            # Rust: pub fn at any indentation (covers impl blocks too)
            FUNC_PATTERN='^[-+][ \t]*pub (async )?fn [a-zA-Z]'
            CLASS_PATTERN='^[-+][ \t]*pub struct [A-Z]|^[-+][ \t]*pub enum [A-Z]'
            PRIVATE_PATTERN='^[-+][ \t]*fn [a-z]|^[-+][ \t]*fn _'
            RETURN_PATTERN='-> [a-zA-Z]'
            ;;
        *)
            # Default: look for common patterns
            FUNC_PATTERN='^[-+][ \t]*(export |pub |public )?(async )?(function|def|fn|func) [a-zA-Z]'
            CLASS_PATTERN='^[-+][ \t]*(export |pub |public )?class [A-Z]'
            PRIVATE_PATTERN='^[-+][ \t]*.*(private|_[a-z])'
            RETURN_PATTERN='(->|:) [a-zA-Z]'
            ;;
    esac
    
    # Extract added lines (new/changed)
    # Use [+] and [-] for BSD grep compatibility (avoid \+ in extended regex)
    ADDED_LINES=$(echo "$FILE_DIFF" | grep -E '^[+]' | grep -v '^[+][+][+]' || true)
    REMOVED_LINES=$(echo "$FILE_DIFF" | grep -E '^[-]' | grep -v '^[-][-][-]' || true)
    
    # Check for new public functions/methods
    NEW_FUNCS=$(echo "$ADDED_LINES" | grep -E -- "$FUNC_PATTERN" | grep -vE -- "$PRIVATE_PATTERN" || true)
    if [ -n "$NEW_FUNCS" ]; then
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            # Extract function name
            FNAME=$(echo "$line" | sed -E 's/^[+-].*(def|function|func|fn|async function) ([a-zA-Z_][a-zA-Z0-9_]*).*/\2/; s/^[+-].*export (const|let) ([a-zA-Z_][a-zA-Z0-9_]*) *=.*/\2/')
            NEW_FUNCTIONS+=("$file: $FNAME")
            CHANGES_FOUND=1
        done <<< "$NEW_FUNCS"
    fi
    
    # Check for new classes
    NEW_CLASSES=$(echo "$ADDED_LINES" | grep -E -- "$CLASS_PATTERN" | grep -vE -- "$PRIVATE_PATTERN" || true)
    if [ -n "$NEW_CLASSES" ]; then
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            CNAME=$(echo "$line" | sed -E 's/^[+-].*(class|struct|type) ([A-Z][a-zA-Z0-9_]*).*/\2/')
            NEW_FUNCTIONS+=("$file: $CNAME (class)")
            CHANGES_FOUND=1
        done <<< "$NEW_CLASSES"
    fi
    
    # Check for removed public functions (need human review)
    REMOVED_FUNCS=$(echo "$REMOVED_LINES" | grep -E -- "$FUNC_PATTERN" | grep -vE -- "$PRIVATE_PATTERN" || true)
    if [ -n "$REMOVED_FUNCS" ]; then
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            FNAME=$(echo "$line" | sed -E 's/^[-].*(def|function|func|fn|async function) ([a-zA-Z_][a-zA-Z0-9_]*).*/\2/; s/^[-].*export (const|let) ([a-zA-Z_][a-zA-Z0-9_]*) *=.*/\2/')
            # Check if it's truly removed or just moved/renamed
            # Use -F for fixed string match and word boundary check
            if ! echo "$ADDED_LINES" | grep -qF "$FNAME"; then
                REMOVED_SYMBOLS+=("$file: $FNAME")
                CHANGES_FOUND=1
            fi
        done <<< "$REMOVED_FUNCS"
    fi
    
    # Detect parameter changes (added/removed params in function signatures)
    # IMPORTANT: First match FUNC_PATTERN (definitions only), THEN check for params.
    # This prevents false positives on function calls like foo(bar, baz).
    PARAM_CHANGES=$(echo "$FILE_DIFF" | grep -E -- "$FUNC_PATTERN" | grep -E '\([^)]*,' || true)
    if [ -n "$PARAM_CHANGES" ]; then
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            FNAME=$(echo "$line" | sed -E 's/^[+-].*\b(def|function|func|fn) ([a-zA-Z_][a-zA-Z0-9_]*).*/\2/')
            # Only add if not already in NEW_FUNCTIONS
            if [[ ! " ${NEW_FUNCTIONS[*]+${NEW_FUNCTIONS[*]}} " =~ " $file: $FNAME " ]]; then
                ADDED_PARAMS+=("$file: $FNAME")
                CHANGES_FOUND=1
            fi
        done <<< "$PARAM_CHANGES"
    fi
    
    # Detect return type changes
    RETURN_CHANGES=$(echo "$FILE_DIFF" | grep -E '^\+' | grep -E -- "$RETURN_PATTERN" || true)
    OLD_RETURNS=$(echo "$FILE_DIFF" | grep -E '^\-' | grep -E -- "$RETURN_PATTERN" || true)
    if [ -n "$RETURN_CHANGES" ] && [ -n "$OLD_RETURNS" ]; then
        # There's a change in return type annotation
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            FNAME=$(echo "$line" | sed -E 's/^[+-].*\b(def|function|func|fn) ([a-zA-Z_][a-zA-Z0-9_]*).*/\2/')
            if [[ ! " ${CHANGED_RETURNS[*]+${CHANGED_RETURNS[*]}} " =~ " $file: $FNAME " ]]; then
                CHANGED_RETURNS+=("$file: $FNAME")
                CHANGES_FOUND=1
            fi
        done <<< "$RETURN_CHANGES"
    fi
    
    # Check for internal-only changes (private functions, implementation details)
    INTERNAL_CHANGES=$(echo "$FILE_DIFF" | grep -E '^\+' | grep -E -- "$PRIVATE_PATTERN" || true)
    if [ -n "$INTERNAL_CHANGES" ] && [ $CHANGES_FOUND -eq 0 ]; then
        INTERNAL_ONLY+=("$file: internal changes only")
    fi
    
    # --- Second pass: private/internal functions with docstring indicators ---
    # The binding vote principle: visibility is irrelevant; if documented, it's in scope.
    # The patterns above only catch exported symbols for JS/TS and Go.
    # This pass catches private/internal functions that have docstring comments nearby.
    case "$EXT" in
        js|ts|jsx|tsx)
            # Look for non-exported function definitions near JSDoc (/** ... */) in the diff
            # Match: any function/const/let without 'export' that is added or changed
            PRIV_FUNCS=$(echo "$ADDED_LINES" | grep -E '^[+][ \t]*(async )?(function [a-zA-Z]|const [a-zA-Z][a-zA-Z0-9_]* *= *(async )?\()' | grep -vE '^[+]export ' || true)
            if [ -n "$PRIV_FUNCS" ]; then
                # Per-function proximity check: only flag if /** appears within
                # 5 lines before this function in the diff context. Avoids
                # false positives from unrelated JSDoc elsewhere in the file.
                while IFS= read -r line; do
                    [ -z "$line" ] && continue
                    FNAME=$(echo "$line" | sed -E 's/^[+][ \t]*(async )?function ([a-zA-Z_][a-zA-Z0-9_]*).*/\2/; s/^[+][ \t]*(const|let) ([a-zA-Z_][a-zA-Z0-9_]*) *=.*/\2/')
                    NEARBY_JSDOC=$(echo "$FILE_DIFF" | grep -B5 -F "$line" | grep -c '/\*\*' || true)
                    if [ "$NEARBY_JSDOC" -gt 0 ]; then
                        if [[ ! " ${NEW_FUNCTIONS[*]+${NEW_FUNCTIONS[*]}} " =~ " $file: $FNAME " ]] && \
                           [[ ! " ${ADDED_PARAMS[*]+${ADDED_PARAMS[*]}} " =~ " $file: $FNAME " ]]; then
                            ADDED_PARAMS+=("$file: $FNAME (documented-private)")
                            CHANGES_FOUND=1
                        fi
                    fi
                done <<< "$PRIV_FUNCS"
            fi
            ;;
        go)
            # Look for unexported (lowercase) functions near godoc comments in the diff
            PRIV_GO_FUNCS=$(echo "$ADDED_LINES" | grep -E '^[+]func [a-z][a-zA-Z0-9]*\(|^[+]func \([a-zA-Z].*\) [a-z][a-zA-Z0-9]*\(' || true)
            if [ -n "$PRIV_GO_FUNCS" ]; then
                # Per-function proximity check: only flag if a godoc comment
                # (// lowercase) appears within 3 lines before this function.
                while IFS= read -r line; do
                    [ -z "$line" ] && continue
                    FNAME=$(echo "$line" | sed -E 's/^[+]func ([a-z][a-zA-Z0-9]*).*/\1/; s/^[+]func \(.*\) ([a-z][a-zA-Z0-9]*).*/\1/')
                    NEARBY_GODOC=$(echo "$FILE_DIFF" | grep -B3 -F "$line" | grep -cE '^[ \t]*// [a-z]' || true)
                    if [ "$NEARBY_GODOC" -gt 0 ]; then
                        if [[ ! " ${NEW_FUNCTIONS[*]+${NEW_FUNCTIONS[*]}} " =~ " $file: $FNAME " ]] && \
                           [[ ! " ${ADDED_PARAMS[*]+${ADDED_PARAMS[*]}} " =~ " $file: $FNAME " ]]; then
                            ADDED_PARAMS+=("$file: $FNAME (documented-private)")
                            CHANGES_FOUND=1
                        fi
                    fi
                done <<< "$PRIV_GO_FUNCS"
            fi
            ;;
    esac
    
done < <(git diff "$COMMIT_RANGE" --name-only)

# Output results
echo "=== Analysis Results ==="
echo ""

if [ $CHANGES_FOUND -eq 0 ]; then
    echo -e "${GREEN}✓ No caller-visible contract changes detected.${NC}"
    echo "  Only internal refactors or out-of-scope changes found."
    if [ ${#INTERNAL_ONLY[@]} -gt 0 ]; then
        echo ""
        echo "  Internal changes in:"
        for item in "${INTERNAL_ONLY[@]}"; do
            echo "    - $item"
        done
    fi
    exit 1
fi

if [ ${#NEW_FUNCTIONS[@]} -gt 0 ]; then
    echo -e "${GREEN}[NEW] Public functions/classes:${NC}"
    for item in "${NEW_FUNCTIONS[@]}"; do
        echo "  + $item"
    done
    echo ""
fi

if [ ${#ADDED_PARAMS[@]} -gt 0 ]; then
    echo -e "${BLUE}[PARAM] Parameter changes:${NC}"
    for item in "${ADDED_PARAMS[@]}"; do
        echo "  ~ $item"
    done
    echo ""
fi

if [ ${#CHANGED_RETURNS[@]} -gt 0 ]; then
    echo -e "${BLUE}[RETURN] Return type changes:${NC}"
    for item in "${CHANGED_RETURNS[@]}"; do
        echo "  ~ $item"
    done
    echo ""
fi

if [ ${#REMOVED_SYMBOLS[@]} -gt 0 ]; then
    echo -e "${YELLOW}[REMOVED] Symbols removed (NEEDS HUMAN REVIEW):${NC}"
    for item in "${REMOVED_SYMBOLS[@]}"; do
        echo "  - $item"
    done
    echo ""
fi

if [ ${#NEW_FUNCTIONS[@]} -gt 0 ] && [ ${#REMOVED_SYMBOLS[@]} -gt 0 ]; then
    echo -e "${YELLOW}[NOTE] Rename detection is manual:${NC}"
    echo "  get_diff.sh does not infer renames mechanically. Review added + removed"
    echo "  symbol pairs manually and flag possible renames or moves for human review."
    echo ""
fi

echo "=== Summary ==="
echo "New symbols:      ${#NEW_FUNCTIONS[@]}"
echo "Param changes:    ${#ADDED_PARAMS[@]}"
echo "Return changes:   ${#CHANGED_RETURNS[@]}"
echo "Removed symbols:  ${#REMOVED_SYMBOLS[@]} (require review)"
echo ""
echo "Run doc-sync to update documentation for these changes."

exit 0
