# doc-sync

A universal agentic skill that updates inline docstrings and proposes README
updates when a **documented symbol's** contract changes. Conservative by design:
patches what changed, proposes what might need updating, flags what's uncertain.

Works on any repo out of the box. No setup required.

Scope: any symbol that already has a docstring or README mention —
public, private, or internal. Documentation drift does not respect visibility.

## What It Does

- ✅ Detects caller-visible contract changes via git diff (tracked files: staged + unstaged)
- ✅ Untracked files excluded by default — stage new files to include them
- ✅ Dry-run mode by default — reports what would change without writing files
- ✅ Apply mode (`--apply`) writes docstring patches after you review the dry-run
- ✅ **Auto-writes** inline docstrings (symbol-local, unambiguous)
- ✅ README/markdown updates are **propose-first** and require explicit approval before any markdown edit is applied
- ✅ Discovers README candidate sections via code span matching (`` `fn_name` ``)
- ✅ Unified diff-style report: same format for auto-writes, proposals, flags, and skips
- ✅ Flags removed/renamed symbols as `[NEEDS HUMAN REVIEW]`, never auto-deletes
- ✅ Reports missing documentation coverage
- ✅ Preserves all human-authored content — runs forked, isolated from conversation

See **SKILL.md § Ownership Rule** for the full canonical definition.

In short: docstrings are auto-written, README changes are proposed-first and
require explicit approval, prose-only mentions are skipped.

## What It Does NOT Do

- ❌ No AST parsing — uses pattern matching
- ❌ No markdown edits without explicit approval
- ❌ No changelog generation — requires release context
- ❌ No tutorial updates — requires pedagogical judgment
- ❌ No auto-commit — human must review first
- ❌ No external API calls — zero network dependencies
- ❌ No pip/npm dependencies — pure shell + markdown

## Known Limitations

### Trust-on-Prompt Write Boundary

The skill uses `allowed-tools: Edit` which permits file edits anywhere in the
workspace. The ownership rules (docstrings = auto-write, README = propose-first)
are enforced by **prompt instructions**, not by a hard filesystem permission
boundary.

This is acceptable because:
- Dry-run is the default — no writes without explicit `--apply`
- Markdown edits require explicit approval
- The skill runs in a forked context, isolated from conversation

Claude Code and OpenCode can enforce the markdown boundary mechanically through
their native hook / permission systems. Windsurf and Cursor remain prompt-based.

### Body-Only Change Detection is Model-Dependent

The "body-only change in a documented function" case (Step 2.5) requires the
model to compare the existing docstring description to the new code behavior
and judge whether they conflict.

V3 adds a mechanical pre-filter (checking for quantitative claims like "validates
three conditions" that are now false), but the semantic fallback is still model-dependent.
Expected behavior by model:
- **Claude Opus/Sonnet**: reliable, will catch most semantic drift
- **Claude Haiku**: may skip some body-change updates
- **Other models**: untested, results may vary

If body-only detection matters for your workflow, use Sonnet or higher.

### Platform Enforcement Differences

| Platform | Markdown Protection | Mechanism |
|----------|--------------------|-----------|
| Claude Code | **Mechanical** | `PreToolUse` hook in `SKILL.md` calls `scripts/block_markdown_writes.sh` for `.md` ask / `.mdx` deny |
| OpenCode | **Mechanical** | `permission.edit` rules in `opencode.json` set `.md` to `ask` and `.mdx` to `deny` |
| Windsurf | **Prompt-based + UI** | Generated `AGENTS.md` / skill instructions plus Windsurf's accept/reject UI |
| Cursor | **Prompt-based + UI** | `.cursor/rules/doc-coauthoring.mdc` instructions plus Cursor's diff UI (`.cursorrules` is legacy) |

In Windsurf and Cursor, markdown protection relies on the AI following prompt
instructions. The platform's accept/reject UI provides a file-level checkpoint,
but does not substitute for Claude Code's mechanical hook enforcement. The skill's
V3 apply-mode confirmation checkpoint (show report → ask for explicit yes → then write)
provides an additional safety layer across all platforms.

### Bash Tool Scope

The skill declares `allowed-tools: Bash(bash "${CLAUDE_SKILL_DIR}/scripts":*)` to
restrict shell access to its own scripts. However, Claude Code's `allowed-tools`
enforcement is [currently unreliable](https://github.com/anthropics/claude-code/issues/14956)
— the scoping declaration is best-effort. The skill's prompt instructions confine
Bash usage to `get_diff.sh`, but on Claude Code the tool permission may still
prompt for approval depending on version.

### Generated Rule Context Overhead

The `convert.sh` script emits static instruction files for prompt-based platforms.
Those files can add context overhead on every conversation where they are loaded,
unlike Claude/OpenCode where the native skill loader can stay lazy. If context
budget is a concern, keep the generated rule scoped to the repo and invoke the
skill manually when needed.

## Installation & Invocation

### Tessl.io (Primary Distribution)

```bash
# From skill root
npx tessl publish
npx tessl skill review ./
tessl eval run .
```

Tessl install / claim flows depend on your workspace permissions and current
registry state. Verify the exact distribution command against current Tessl docs
before publishing public instructions.

### Claude Code (Local Path)

```bash
mkdir -p ~/.claude/skills
cp -r doc-sync ~/.claude/skills/

# Invoke
/doc-sync --dry-run     # preview (default)
/doc-sync --apply       # write with confirmation
/doc-sync --apply HEAD~3..HEAD  # specify commit range
```

For truly automatic invocation after every commit, add this to `.git/hooks/post-commit`:
```bash
#!/bin/bash
echo "Running doc-coauthoring dry-run..."
claude -p "/doc-coauthoring --dry-run"
```
Make it executable: `chmod +x .git/hooks/post-commit`

### OpenCode (Local Path)

```bash
mkdir -p ~/.config/opencode/skills
cp -r doc-sync ~/.config/opencode/skills/

# Invoke same as Claude Code
/doc-sync --dry-run
/doc-sync --apply
```

For markdown protection in OpenCode, add to `opencode.json` in project root:
```json
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "edit": {
      "*": "allow",
      "**/*.md": "ask",
      "**/*.mdx": "deny"
    }
  }
}
```

### Cursor

```bash
cd doc-sync
./scripts/convert.sh /path/to/your/project
# Creates .cursor/rules/doc-sync.mdc
# Also emits .cursorrules for legacy Cursor compatibility
```

Prefer `.cursor/rules/doc-coauthoring.mdc`. `.cursorrules` is legacy.

### Windsurf / Codeium

```bash
cd doc-sync
./scripts/convert.sh /path/to/your/project
# Creates AGENTS.md for repo-scoped Cascade instructions
# Also emits .windsurfrules for legacy compatibility
```

Prefer the generated `AGENTS.md`. If your repo already has an `AGENTS.md`, merge
the generated instructions or use `.agents-entry.md` as a snippet.

## Usage

### After Making Code Changes

```bash
# 1. (Optional) Run the diff script directly to see what changed
bash doc-sync/scripts/get_diff.sh
# Default: all tracked uncommitted changes (staged + unstaged vs HEAD)
# Or specify a range: HEAD~3..HEAD

# 2. Preview what the skill would update (no file writes)
/doc-sync --dry-run

# 3. Review the report, then apply
/doc-sync --apply
```

### Example: Before and After

**Code change:**
```diff
- def fetch_user(user_id: int) -> User:
+ def fetch_user(user_id: int, include_profile: bool = False) -> User:
```

**Docstring update (auto-written):**
```diff
  def fetch_user(user_id: int, include_profile: bool = False) -> User:
      """Fetch a user by ID.
      
      Args:
          user_id: The user's unique identifier.
+         include_profile: Whether to include profile data. Defaults to False.
          
      Returns:
          User object.
      """
```

**README update (proposed; apply requires explicit approval):**
```
### Proposed
- `fetch_user` — README.md:47 — under heading "## API Reference"
  ~ Detected code span mention. Proposed patch:
  | `fetch_user(user_id, include_profile=False)` | user_id: int, include_profile: bool | User |
  Review and apply manually if appropriate.
```

### Example: Removed Symbol

```bash
# Skill output:
## Flagged for Human Review
- `deprecated_function` — symbol removed from codebase
  Documentation preserved. Please review and remove manually if appropriate.
```

The skill never deletes documentation. Removal requires human confirmation.

## Testing the Skill (Evals)

### Running Preflight Checks

```bash
# Verify eval structure is valid before running
bash tests/preflight.sh
```

This confirms all eval scenarios have the required `task.md` and `criteria.json` files. Must pass before running evals.
It validates both `evals/` and `tests/hard-evals/`.

### Running Individual Evals Manually

Each eval in `evals/` and `tests/hard-evals/` has a `task.md` with a setup script embedded. To test a specific scenario:

```bash
# 1. Create a clean temp directory
mkdir -p /tmp/eval-test && cd /tmp/eval-test

# 2. Extract and run the setup script from the eval's task.md
#    (copy the bash block under "FILE: inputs/setup.sh" and run it)
bash setup.sh

# 3. Install the skill locally
cp -r /path/to/doc-sync .

# 4. Invoke the skill as the eval specifies
/doc-sync --dry-run   # or --apply depending on the eval

# 5. Check your output against criteria.json
#    Each criterion has a description and max_score.
#    Grade pass/fail for each criterion manually or via Tessl's eval runner.
```

### Running All Evals via Tessl

```bash
tessl eval run .
```

Use the hard-evals as a local quality gate in addition to the public Tessl evals.

### What Good Looks Like

The public evals plus hard-evals cover these critical behaviors:

| Eval | What it Proves |
|------|---------------|
| `dry-run-default-no-file-writes` | Skill never writes without --apply |
| `body-only-drift-proceed-past-exit-code-1` | Skill doesn't stop at script exit 1 |
| `protected-files-never-modify-changelog` | CHANGELOG and ADRs never touched |
| `new-documented-symbol-propose-readme` | New symbols generate README proposals |
| `moved-symbol-flag-for-human-review` | Moves are never auto-handled |
| `minimal-docstring-edit-preserve-examples` | Existing content preserved |
| `ruby-docstring-style-match` | Style matching works across languages |
| `readme-table-cell-match-medium-confidence` | Table cell detection works |
| `generic-type-alias-change-not-a-contract` | Style-only changes ignored |
| `java-javadoc-update-param` | Java/Kotlin coverage works |

## Test Cases

The skill is designed to pass these scenarios:

| Scenario | Expected Behavior |
|----------|-------------------|
| Added parameter | Updates docstring, proposes README update |
| Pure internal refactor | Reports "no contract changes", does nothing |
| Private method signature changed | Detects and updates docstring (in scope by documented-symbol rule) |
| Removed symbol (any visibility) | Flags `[NEEDS HUMAN REVIEW]`, preserves docs |
| No existing documentation | Reports "missing coverage", does not create |
| User runs without `--apply` | Dry-run only — no files written, report shown |

## File Structure

```
doc-sync/
├── SKILL.md                   # Lean router (~200 tokens)
├── PRESERVATION.md            # Public social contract
├── README.md                  # This file
├── tile.json                  # Tessl tile configuration
├── tessl.json                 # Tessl vendored-source configuration
├── evals/                     # Tessl evaluation scenarios
├── scripts/
│   ├── block_markdown_writes.sh  # Claude Code markdown approval hook
│   ├── get_diff.sh            # Git diff → changed documented symbols
│   └── convert.sh             # SKILL.md → Cursor/Windsurf formats
├── references/
│   ├── workflow-steps.md      # Detailed execution steps (lazy-loaded)
│   ├── scope-bounds.md        # What the skill will NOT touch
│   └── verify-steps.md        # 3-point verification checklist
└── tests/
    ├── preflight.sh           # Validate evals/ and hard-evals structure
    ├── hard-evals/            # Stronger publication-review scenarios
    └── EVIDENCE.md            # Empirical notes and evaluation evidence
```

**Architecture note**: `SKILL.md` is a lean router (~200 tokens). Heavy content
lives in `references/` and is lazy-loaded by the agent only when needed. This
preserves context window space for other installed skills (progressive disclosure).

## Philosophy

> Documentation co-authorship is a negotiated boundary: machines maintain
> what they can verify (signatures, types, parameter lists), humans maintain
> what requires judgment (explanations, examples, warnings). Docstrings are
> symbol-local and unambiguous — safe to auto-write. README prose is human
> territory — always proposed, never auto-applied. Cross the line, and trust
> is broken. Respect it, and documentation stays accurate without losing its voice.

## Contributing

1. This skill follows the [Agent Skills open standard](https://agentskills.io)
2. All changes must preserve the conservative philosophy
3. New features that expand scope will be rejected
4. Bug fixes that improve accuracy are welcome

## License

Apache 2.0
