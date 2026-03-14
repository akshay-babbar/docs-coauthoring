# Workflow Steps

Detailed execution steps for the doc-coauthoring skill. Load this file
when executing the workflow. Do not load at startup.

## Invocation Modes

The skill supports two modes via `$ARGUMENTS`:

| Mode | Command | Behavior |
|------|---------|----------|
| Dry-run (default) | `/doc-coauthoring --dry-run` or `/doc-coauthoring` | Detect and report changes only. No file writes. |
| Apply | `/doc-coauthoring --apply` | Detect, report, and write docstring patches. Propose README updates. |

**Always default to dry-run when `$ARGUMENTS` is empty or `--dry-run`.**
Only write files when `--apply` is explicitly passed.

## Step 1: Detect Contract Changes

```bash
bash scripts/get_diff.sh [--dry-run|--apply] [commit-range]
# Default (no commit-range): git diff HEAD — all tracked uncommitted changes
# Explicit range:            git diff HEAD~3..HEAD — last 3 commits
# Before committing:         default captures your in-progress tracked work automatically
```

**Scope of `git diff HEAD`:**
- ✅ Tracked files with unstaged changes
- ✅ Tracked files with staged changes
- ❌ Untracked files (excluded by default — stage them first to include)

This is intentional: untracked files often include scratch work, experiments, or
generated artifacts. Once you stage a new file, it becomes tracked and visible.

Parse output:
- `[NEW]` — new documented or public symbol
- `[PARAM]` — parameter signature change
- `[RETURN]` — return type change
- `[REMOVED]` — symbol removed (requires human review)
- `✓ No caller-visible contract changes` → **do NOT stop here** — proceed to Step 2.5
  to check body-only changes in previously-documented symbols

**CRITICAL: Handle exit code 1 correctly.**
The script exits 1 when no signature changes are found. This is NOT a stop signal.
Always proceed to Step 2.5 regardless of exit code — body-only changes in documented
symbols are detected there, not in the script.

## Step 2: Classify Each Change

For each detected symbol, apply the **two-factor test** (see Step 2.5 below),
then apply the **ownership rule** to determine how changes are delivered:

| Code change | Previously documented? | Action | Write mode |
|-------------|------------------------|--------|------------|
| Added parameter | Yes — has docstring | Update docstring | **auto-write** |
| Added parameter | Yes — mentioned in README code span | Propose README update | **propose-only** |
| Added parameter | No | Report "Missing coverage" | report-only |
| Changed return type | Yes — has docstring | Update docstring | **auto-write** |
| Changed return type | Yes — mentioned in README code span | Propose README update | **propose-only** |
| Changed return type | No | Report "Missing coverage" | report-only |
| Body-only change | Yes — has docstring | Review docstring; update only if now false/incomplete | **auto-write** if stale |
| Body-only change | No | Skip entirely | skip |
| New symbol | Has docstring already | Propose README mention | **propose-only** |
| New symbol | No docstring | Report "Missing coverage" | report-only |
| Removed symbol | Any | Flag `[NEEDS HUMAN REVIEW]`, **never delete** | human-review |
| Renamed symbol | Any | Flag `[NEEDS HUMAN REVIEW]` | human-review |

### Ownership Rule (what determines write mode)

```
Docstring in source file          → auto-write always
Markdown code span match          → propose-only always
Prose mention without code span   → skip (low confidence)
No documentation found            → report-only, nothing created
```

Docstrings are symbol-local and unambiguous — safe to auto-write.
README content is human-authored territory — always propose-only, regardless
of whether it has any special markers.

**Body-change nuance**: "Review for staleness" means inspect whether the existing
docstring description contradicts the new behavior. If it does, update. If the
docstring is generic (e.g., "Connects to host") and still accurate, skip.

**The binding vote principle**: past documentation is a binding vote on importance.
A 1-line change in a documented function is in scope. A 1-line change in an
undocumented function is not. Magnitude is irrelevant; prior documentation is what counts.

**Scope rule**: A symbol is in scope if it **already has a docstring or README
mention** — regardless of visibility (public, private, internal).

## Step 2.5: Check Existing Documentation Coverage

This is the prerequisite for the two-factor test in Step 2. For every changed
file and symbol, check whether documentation already exists **before** deciding
whether to act.

### Check 1: Docstring Coverage

For each changed symbol `fn_name` in `path/to/file`:

```bash
# Grep for the function definition, then check for a docstring in the next 3 lines
grep -n "def fn_name\|function fn_name\|fn fn_name" path/to/file
# Then read the lines immediately following the definition
```

Docstring indicators by language:
- **Python**: `"""`, `'''` on the next non-blank line after `def`
- **JS/TS**: `/**` or `//` on the lines immediately before the `function`/`=>`
- **Go**: `// FuncName` comment on the line immediately above `func`
- **Rust**: `///` or `//!` immediately above `pub fn`
- **Ruby**: `##` or `# @param` immediately above `def`

Result: `HAS_DOCSTRING=true` or `HAS_DOCSTRING=false`

### Check 2: README Coverage (Code Span Match)

Search all markdown files for the symbol name inside backtick code spans:

```bash
# Step A: Find markdown files that mention the symbol IN CODE SPANS (backticks)
# This is the false-positive reduction filter — require backticks or table formatting
grep -rln '\`fn_name\`' *.md docs/ README.md 2>/dev/null || true
# Fallback: also check table cells with pipe delimiters
grep -rln '| *fn_name *|\|| *\`fn_name\` *|' *.md docs/ README.md 2>/dev/null || true

# Step B: For each match, extract surrounding heading context
grep -n '\`fn_name\`' README.md | head -5
# Then read 5 lines above the match to identify the nearest markdown heading
# This is the candidate section that would receive a proposed update
```

**Confidence levels (enforced, not advisory):**
- **High confidence:** symbol appears in backtick code span (`` `fn_name` ``)
- **Medium confidence:** symbol appears in markdown table cell
- **Low confidence:** bare symbol name in prose → **exclude from proposals**

Only high and medium confidence matches are included in `CANDIDATE_SECTIONS`.

Result: `CANDIDATE_SECTIONS=[]` or a list of `(file, heading, line)` tuples

### Coverage Decision

| HAS_DOCSTRING | CANDIDATE_SECTIONS | Previously Documented? | Write mode |
|---------------|---------------------|------------------------|------------|
| true | any | **Yes** | auto-write docstring |
| false | non-empty | **Partial** | propose-only to candidate sections |
| false | empty | **No** | report "Missing coverage" only |

### Body-Only Change Detection

For the "previously documented" path, also surface body-only changes that
`get_diff.sh` doesn't report (no signature change, but function body changed):

```bash
# Look for changed lines within functions that have existing docstrings
# For each file in the diff, check: does any changed hunk fall inside a
# function that has HAS_DOCSTRING=true?
```

If yes: read the existing docstring and compare its description to the new
behavior. If the description references the changed logic (e.g., "validates
three conditions" but now there are four), flag it for update.

If the description is generic ("Connects to host") and the body change does
not contradict it, skip — no update needed.

## Step 3: Apply Updates (only if `--apply` mode)

**Order is mandatory — docstrings first, README proposals second.**

### 3a. Update Docstrings/JSDoc

Match existing style exactly. Only change the affected parameter or return:

```python
# Before: parameter 'timeout' added
def connect(host: str, port: int) -> Connection:
    """Connect to host.

    Args:
        host: Hostname or IP.
        port: Port number.
    """

# After: add 'timeout' only
def connect(host: str, port: int, timeout: int = 30) -> Connection:
    """Connect to host.

    Args:
        host: Hostname or IP.
        port: Port number.
        timeout: Connection timeout in seconds. Defaults to 30.
    """
```

Rules:
- Match indentation of neighboring parameters exactly
- Do not reorder existing parameters
- Do not add examples, notes, or see-also references
- Do not reformat the entire docstring

### 3b. Propose README Updates

For each candidate section found in Step 2.5 Check 2, generate a proposed
patch in diff format. **Never auto-write to markdown files.**

```markdown
### Proposed
- `connect` — README.md:47 — under heading "## API Reference"
  ~ Detected code span mention. Proposed patch:
  [patch shown here in diff format]
  Review and apply manually if appropriate.
```

## Step 4: Verify (mandatory after every edit)

See `references/verify-steps.md` for the 3-point checklist:
1. Symbol exists in codebase
2. Parameters match actual signature
3. Syntax is valid

Verification is **non-optional**. If a check fails, revert the edit and flag.

## Step 5: Report Results

**Unified format contract**: whether an entry was auto-written, proposed, flagged,
or skipped, it always appears in the **same diff-style format**. This is non-negotiable
— if auto-writes and proposals look structurally different, developers stop trusting
the output within 2 uses. The only difference is the action verb.

Always output a report regardless of mode:

```
## Doc Sync Report
Mode: dry-run | apply

### Updated  (auto-write, --apply only; reads "Would Update" in --dry-run)
- `connect` ─ path/to/file.py:14 ─ docstring
  + timeout: Connection timeout in seconds. Defaults to 30.

### Proposed  (README sections; never auto-written)
- `connect` ─ README.md:47 ─ under heading "## API Reference"
  ~ Detected code span mention. Proposed patch:
  [patch shown here in diff format]

### Flagged for Human Review
- `removed_fn` ─ path/to/file.py ─ symbol not found in codebase
  ! Documentation preserved. Delete manually if intentional.
- `renamed_fn` ─ path/to/file.py ─ appears renamed
  ! Import references may be stale.

### Missing Coverage
- `new_fn` ─ path/to/file.py:42 ─ no docstring or README mention found
  ✓ Nothing created.

### Skipped
- docs/guide.md ─ bare symbol mention without code span; low confidence

### No Changes
(if nothing to report)
✓ No contract changes detected in tracked files. Documentation is current.
```

**Format rules:**
- Every entry: `` `symbol` ─ file:line ─ what changed ``
- Action verb changes (`Updated` / `Would Update` / `Proposed`), structure does not
- Patches always shown in diff format (`+` added, `-` removed, `~` contextual)
- dry-run: all `Updated` become `Would Update`; `Proposed` stays `Proposed`
