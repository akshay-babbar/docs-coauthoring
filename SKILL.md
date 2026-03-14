---
name: doc-coauthoring
description: >
  Updates inline docstrings and README sections when a documented symbol's
  contract changes (parameters, return type, new or removed symbol). Invoke
  after commits that change function signatures. Auto-writes docstrings only.
  README updates are always propose-only — never auto-written. Preserves all
  human-authored content. Never modifies tutorials, changelogs, or ADRs.
  Use /doc-coauthoring --dry-run to preview, /doc-coauthoring --apply to
  write patches. Auto-invocable by Claude for dry-run detection; only writes
  files when --apply is explicitly passed.
license: Apache-2.0
metadata:
  version: "3.0.0"
  author: doc-coauthoring
allowed-tools: Read Edit Grep Bash
argument-hint: "[--dry-run | --apply] [commit-range]"
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

Load `references/workflow-steps.md` for full execution detail.

1. Run `scripts/get_diff.sh $ARGUMENTS` to detect changes (default: all uncommitted)
2. Check existing doc coverage for every changed symbol (Step 2.5 in workflow-steps.md)
3. Check for README candidate sections via symbol-name grep (Step 2.5 Check 2)
4. Classify with two-factor + ownership test (Step 2 in workflow-steps.md)
5. If `--apply`: auto-write docstrings; propose README updates (never auto-write markdown)
6. Verify every edit with `references/verify-steps.md`
7. Report in unified format: Updated / Proposed / Flagged / Missing Coverage / Skipped

## Scope — The Two-Factor Rule

A symbol is in scope when **both** conditions are true:
1. It already has a docstring or README mention (previously documented)
2. Its code changed

**The binding vote principle**: past documentation is a vote on importance.
A trivial 1-line body change in a documented function is in scope.
A trivial 1-line change in an undocumented function is not.
Visibility (public/private/internal) is irrelevant — only prior documentation is.

## Ownership Rule

```
Docstring in source file       → auto-write always
Markdown code span match       → propose-only always
Prose mention without code span → skip (low confidence)
No coverage found              → report-only
```

Docstrings are symbol-local and unambiguous — safe to auto-write.
README content is human-authored territory — always propose-only.

See `references/scope-bounds.md` and `references/workflow-steps.md` Step 2.5.

## When Uncertain

Flag as `[NEEDS HUMAN REVIEW]`, explain, stop. Never guess.
