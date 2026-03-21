---
name: doc-coauthoring
description: >
  Keeps docstrings and README sections accurate after code changes. Use this
  whenever a function signature changed, a parameter was added or removed, a
  return type changed, or a symbol was renamed or deleted — and the documentation
  needs to match. Also trigger when users say "update the docs", "sync docs after
  my refactor", "my API changed", "fix the docstring", "check if my docs are still
  accurate", or anything indicating docs may be out of date after a code change.
  Always shows a full proposal report first and asks for confirmation before
  writing anything. README edits always require explicit approval — never
  auto-applied.
compatibility: Designed for Claude Code CLI, OpenCode, Windsurf, and Cursor. Some enforcement features (hooks, allowed-tools) are Claude Code specific.
license: Apache-2.0
metadata:
  version: "3.0.0"
  author: doc-coauthoring
allowed-tools: Read Edit Grep Bash(bash "${CLAUDE_SKILL_DIR}/scripts":*)
argument-hint: "[--dry-run | --apply] [commit-range]"
hooks:
  PreToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "bash \"${CLAUDE_SKILL_DIR}/scripts/block_markdown_writes.sh\""
---

# Doc-Coauthoring

Surgical documentation updater. Patches docs when a documented symbol's
caller-visible contract changes. Conservative by design: flag more, change less.

## Invocation

- `/doc-coauthoring` or `/doc-coauthoring --dry-run` — detect and report, **no file writes**
- `/doc-coauthoring --apply` — detect, report, and write patches
- `/doc-coauthoring --apply HEAD~3..HEAD` — specify commit range

Arguments are available as `$ARGUMENTS`. Default to dry-run when empty.

## Workflow

**Load timing:** After Step 1 completes and returns results, load `references/workflow-steps.md` before proceeding to Step 2. Do not load at startup — only when actively executing the workflow.

1. Run `scripts/get_diff.sh $ARGUMENTS` to detect changes (default: all uncommitted)
2. Check existing doc coverage for every changed symbol (Step 2.5 in workflow-steps.md)
3. Check for README candidate sections via symbol-name grep (Step 2.5 Check 2)
4. Classify with two-factor + ownership test (Step 2 in workflow-steps.md)
 
    Example (decorator-only contract change):
    Before: a documented `fetch_user(id)` has no deprecation signal; signature unchanged.
    After: add `@deprecated("Use get_user")` to the same function.
    Expected: update the `fetch_user` docstring to surface deprecation; if README mentions it, flag `[NEEDS HUMAN REVIEW]` and propose-first (only apply markdown edits with explicit user approval).
5. If `--apply`: auto-write docstrings; propose README updates (only apply markdown edits with explicit user approval)
6. Verify every edit with `references/verify-steps.md`
7. Report in unified format: Updated / Proposed / Flagged / Missing Coverage / Skipped

## Scope — The Two-Factor Rule

A symbol is in scope when **both** conditions are true:
1. It already has a docstring or README mention (previously documented)
2. Its code changed

This skill handles Python, TypeScript, JavaScript, Go, Rust, Ruby, Java, and Kotlin. Docstring formats vary by language — match the existing style exactly.

**Write boundary**: In non-markdown source files, the only permitted edit is to docstring/JSDoc comment content. Function bodies, imports, logic, and all other code are never modified.

**The binding vote principle**: past documentation is a vote on importance.
A trivial 1-line body change in a documented function is in scope.
A trivial 1-line change in an undocumented function is not.
Visibility (public/private/internal) is irrelevant — only prior documentation is.

Example (binding vote, body-only semantic drift):
Before: docstring says "validates three conditions"; signature unchanged.
After: body changes to validate four conditions.
Expected: update only the stale docstring sentence to "four conditions"; do not touch unrelated docs.

## Ownership Rule (canonical — other files reference this)

```
Docstring in source file       → auto-write always
Markdown code span match       → propose-first; only apply with explicit user approval
Prose mention without code span → skip (low confidence)
No coverage found              → report-only
```

Docstrings are symbol-local and unambiguous — safe to auto-write.
README content is human-authored territory — always require explicit user approval before applying edits.

See `references/scope-bounds.md` and `references/workflow-steps.md` Step 2.5.

## When Uncertain

Flag as `[NEEDS HUMAN REVIEW]`, explain, stop. Never guess.
