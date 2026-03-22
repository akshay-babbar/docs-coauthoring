# Workflow Steps

Detailed execution steps for the doc-sync skill. Load this file
when executing the workflow. Do not load at startup.

## Invocation Modes

The skill supports two modes via `$ARGUMENTS`:

| Mode | Command | Behavior |
|------|---------|----------|
| Dry-run (default) | `/doc-sync --dry-run` or `/doc-sync` | Detect and report changes only. No file writes. |
| Apply | `/doc-sync --apply` | Detect, report, and write docstring patches. Propose README updates. |

**Always default to dry-run when `$ARGUMENTS` is empty or `--dry-run`.**
Only write files when `--apply` is explicitly passed.

**Apply-mode confirmation checkpoint (mandatory):**
Even when `--apply` is passed, the workflow is: detect → classify → build the complete Doc Sync Report → **show the report and ask for confirmation** → only proceed to file writes on explicit approval. This ensures the user understands the intent before seeing diffs, regardless of platform.

**Confirmation prompt format (terminal agents — Claude Code, OpenCode):**
- Let `change_count` be the total number of entries in the Doc Sync Report under `Would Update` / `Updated` and `Proposed` combined.
- If `change_count == 1`: use exactly `Apply this change? (yes/no)`.
- If `change_count >= 2`: use `Found N changes. Apply all (A), select by number (1, 3, 5...), or skip (S)?` where `N == change_count`. **Do not** use the single-change yes/no prompt when more than one change is present.
- Every entry under `Would Update` / `Updated` and `Proposed` must be numbered in the report so the user can reference them by number.
- If the user selects by number, only apply those entries. All others are reported as Skipped.
- In Windsurf/Cursor, the platform's accept/reject UI handles per-change selection at the diff level, so no numbered prompt is needed.

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
| Added parameter | Yes — mentioned in README code span | Propose README update | **propose-first** |
| Added parameter | No | Report "Missing coverage" | report-only |
| Changed return type | Yes — has docstring | Update docstring | **auto-write** |
| Changed return type | Yes — mentioned in README code span | Propose README update | **propose-first** |
| Changed return type | No | Report "Missing coverage" | report-only |
| Body-only change | Yes — has docstring | Review docstring; update only if now false/incomplete | **auto-write** if stale |
| Body-only change | No | Skip entirely | skip |
| New symbol | Has docstring already | Propose README mention | **propose-first** |
| New symbol | No docstring | Report "Missing coverage" | report-only |
| Removed symbol | Any | Flag `[NEEDS HUMAN REVIEW]`, **never delete** | human-review |
| Renamed symbol | Any | Flag `[NEEDS HUMAN REVIEW]` | human-review |

### Ownership Rule

See **SKILL.md § Ownership Rule** for the canonical definition. In summary:
- Docstring in source file → auto-write
- Markdown code span match → propose-first
- Prose mention without code span → skip
- No documentation found → report-only

**Body-change staleness check** (mechanical pre-filter, then semantic fallback):

1. **Mechanical check (always run first):** Does the docstring contain a specific number or quantitative claim (e.g., "validates three conditions", "returns three fields", "retries up to 5 times") that is now falsified by the new code? If yes → update.
2. **Semantic fallback (only if mechanical check is inconclusive):** Does the docstring description contradict the new behavior? If it does, update. If the docstring is generic (e.g., "Connects to host") and still accurate, skip.
3. **When in doubt:** Skip. A false negative here (not catching a stale docstring) is recoverable; a false positive (rewriting an accurate docstring incorrectly) is worse.

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

**Persistence requirement:** Before proceeding to Step 3, include `CANDIDATE_SECTIONS` in the Doc Sync Report structure (under a `### Proposed` heading with placeholders). This ensures candidate sections survive context window pressure between Step 2.5 and Step 3b. Do not rely on the agent remembering them across steps.

### Coverage Decision

| HAS_DOCSTRING | CANDIDATE_SECTIONS | Previously Documented? | Write mode |
|---------------|---------------------|------------------------|------------|
| true | any | **Yes** | auto-write docstring |
| false | non-empty | **Partial** | propose-first to candidate sections |
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

## Step 3: Apply Updates (only after confirmation in `--apply` mode)

**Prerequisite:** The Doc Sync Report has been shown and the user has confirmed "yes" to apply.

**Order is mandatory — docstrings first, README proposals second.**

**For large batches (>5 symbols):** Before starting writes, record the list of
pending changes in the report output. If the session is interrupted, the next
run can reference the report to avoid re-detecting from scratch.

### 3a. Update Docstrings/JSDoc

**Idempotency guard (mandatory):** Before writing any docstring update, read the
current docstring state. If the parameter documentation already exists and matches
the current signature, skip and report "Already current." This prevents duplicate
entries when `--apply` is run twice on the same uncommitted diff.

**Inferred description marker (mandatory for new descriptions):**
When the skill writes a **new** parameter or return description that did not
exist before, the description must be inferred from the parameter name, type,
and default value. Because this inference may be wrong, append the marker
`[inferred — verify]` inline to every auto-inferred description.

Example:
```python
    Args:
        host: Hostname or IP.                                     # existing — no marker
        port: Port number.                                        # existing — no marker
        timeout: Connection timeout in seconds. Defaults to 30. [inferred — verify]
```

Rules for the marker:
- **Add** `[inferred — verify]` to any description the skill writes from scratch
- **Do NOT add** it to descriptions that already existed and were merely preserved
  or extended with a known-safe change (e.g., only the default value changed)
- The marker appears both in the written docstring AND in the report
- In the report, add a note: "Review `[inferred — verify]` entries — these were
  inferred from parameter names and may need correction."
- Once a human verifies or rewrites the description, remove the marker in that
  same review pass or in the next doc-cleanup edit; verified production docs
  should not keep the marker indefinitely.

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
        timeout: Connection timeout in seconds. Defaults to 30. [inferred — verify]
    """
```

Rules:
- Match indentation of neighboring parameters exactly
- Do not reorder existing parameters
- Do not add examples, notes, or see-also references
- Do not reformat the entire docstring

### 3b. Propose README Updates

For each candidate section found in Step 2.5 Check 2, generate a proposed
patch in diff format. Only apply markdown edits with explicit user approval.

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

Always output a report regardless of mode.

**Numbering rule**: In `--apply` mode, number every entry under Updated/Would Update
and Proposed sequentially (1, 2, 3...) so the user can reference them in the
confirmation prompt. In `--dry-run` mode, numbering is optional.

```
## Doc Sync Report
Mode: dry-run | apply

### Updated  (auto-write, --apply only; reads "Would Update" in --dry-run)
1. `connect` ─ path/to/file.py:14 ─ docstring
   + timeout: Connection timeout in seconds. Defaults to 30. [inferred — verify]

### Proposed  (README sections; apply requires explicit approval)
2. `connect` ─ README.md:47 ─ under heading "## API Reference"
   ~ Detected code span mention. Proposed patch:
   [patch shown here in diff format]

> **Note:** Review `[inferred — verify]` entries — these were inferred from
> parameter names and may need correction.

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

**Confirmation prompt (apply mode only, after showing the report):**
- 1 change: `Apply this change? (yes/no)`
- 2+ changes: `Found N changes. Apply all (A), select by number (1, 3, 5...), or skip (S)?`
- If user selects by number, apply only those entries. Report all others as Skipped.

**Format rules:**
- Every entry: `` `symbol` ─ file:line ─ what changed ``
- Action verb changes (`Updated` / `Would Update` / `Proposed`), structure does not
- Patches always shown in diff format (`+` added, `-` removed, `~` contextual)
- dry-run: all `Updated` become `Would Update`; `Proposed` stays `Proposed`
- Entries with `[inferred — verify]` markers must preserve the marker in the report
