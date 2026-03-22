# Scope Bounds

This document defines what the doc-sync skill will NOT touch.
These boundaries are non-negotiable.

## What Is In Scope

A symbol is **in scope** if it already has a docstring or README mention,
regardless of visibility. This includes:

- Public functions and classes
- Private/internal functions (`_private`, `__dunder__`, `internal/` packages)
- Protected methods
- Module-level and class-level symbols

**The rule**: if documentation exists for it, it is in scope. If it has no
documentation, the skill reports "Missing coverage" and stops — it does not
create new documentation.

This is intentional: documentation drift does not respect visibility modifiers.
A `_parse_config_internal()` function with a stale docstring is misleading
to its callers inside the codebase, even if it is never exported.

## Files Never Modified

| File Type | Reason |
|-----------|--------|
| `CHANGELOG.md` | Requires release context and human judgment |
| `HISTORY.md` | Historical record, append-only by humans |
| `ADR-*.md`, `decisions/*.md` | Architectural decisions are human-authored |
| `tutorials/*.md` | Narrative content requiring pedagogical judgment |
| `guides/*.md` | Step-by-step content with human flow |
| `*.mdx` | Interactive docs with component logic |
| `CONTRIBUTING.md` | Community guidelines, policy decisions |
| `CODE_OF_CONDUCT.md` | Legal/policy document |
| `SECURITY.md` | Security policy, legal implications |
| `LICENSE*` | Legal document |
| `.github/*.md` | Issue/PR templates, community health files |

## Markdown Files — Propose-First

See **SKILL.md § Ownership Rule** for the canonical ownership definition.

All README and markdown documentation updates are **propose-first**. The skill
finds symbol mentions in code spans (`` `fn_name` ``) and table cells, generates
a proposed patch, and includes it in the report for human review. Any attempt
to apply a markdown edit requires explicit user approval at the time.

## Symbols Never Auto-Documented (Only Flagged)

| Symbol Type | Behavior |
|-------------|----------|
| Any symbol with no docstring | Report as "Missing coverage", do NOT create docs |
| Any symbol with no README mention | Skip README update, report |

The skill updates existing documentation. It never creates from scratch.

## Content Never Modified

### README Content (Propose-First)

All README and markdown content is human territory. The skill proposes
updates based on code span matches and only applies changes with explicit
human approval:

```markdown
# Project Name          ← NEVER AUTO-WRITE
                        
Introduction text...    ← NEVER AUTO-WRITE

## API Reference        ← NEVER AUTO-WRITE
API reference here      ← PROPOSE-FIRST (if code span match found; apply requires approval)

## Contributing         ← NEVER AUTO-WRITE
```

### Human-Authored Docstring Content

Within docstrings, only modify:
- Parameter descriptions for changed parameters
- Return type descriptions for changed returns
- Minimal symbol description lines when code adds a machine-verifiable caller-visible signal
- Falsifiable quantitative statements that became wrong after a body-only change

Never modify:
- Examples (even if outdated)
- Notes/warnings
- See-also references
- Human rationale or migration prose beyond the minimal mechanical update

### Behavioral Documentation

If a function's signature is unchanged but behavior changed:

```python
def calculate_tax(amount: float) -> float:
    """Calculate tax on amount.
    
    Note: Now uses 2024 tax brackets.  ← NEVER auto-update this
    """
```

Only auto-update mechanical claims the code now falsifies directly, such as
"validates three conditions" when the implementation now validates four.
If the change requires interpretation (performance, policy, tax brackets,
security posture, pedagogy), flag it as `[NEEDS HUMAN REVIEW]`.

## Symbols Without Prior Documentation

Any symbol without an existing docstring or README mention is out of scope for
auto-writing, including private/internal/test-only symbols. Report "Missing
coverage" or skip per the ownership rule, but do not create new documentation.

## Operations Never Performed

| Operation | Why Forbidden |
|-----------|---------------|
| Apply markdown edits without explicit approval | Human territory — propose-first |
| Delete documentation | Removal needs human review |
| Create new doc files | Scope creep, needs human decision |
| Modify code | Documentation only |
| Run external commands | Security boundary |
| Make HTTP requests | No external dependencies |
| Auto-commit changes | Human must review first |
| Parse AST | Complexity creep, pattern matching suffices |
| Generate changelogs | Requires release context |
| Update version numbers | Requires release process |

## Edge Cases

### Private Symbols with Docstrings

Private symbols (`_func`, `__func`, `internal/pkg`) are **in scope** if they
have an existing docstring. Update the docstring when their signature changes.
Do NOT promote them to public documentation or add README entries.

### Renamed Symbols

If `old_name` → `new_name`:
- Do NOT auto-update references
- Flag as `[NEEDS HUMAN REVIEW]`
- Treat rename detection as manual review; `get_diff.sh` does not infer renames mechanically
- Report: "Possible rename from `old_name` to `new_name`. Documentation references may need manual update."

### Moved Symbols

If function moved between files:
- Do NOT auto-update import examples
- Flag as `[NEEDS HUMAN REVIEW]`
- Report: "Symbol `func` moved from `old.py` to `new.py`. Import examples may need manual update."

### Deprecated Symbols

If `@deprecated` or `@obsolete` added:
- Update the inline docstring minimally to surface deprecation and the replacement if code provides one
- Do NOT rewrite examples, warnings, or migration prose
- Flag README mentions as `[NEEDS HUMAN REVIEW]`; only propose a markdown patch when the mention is an exact code-span or table-cell match

### Generic Type Changes

If `List` → `list` or `Dict` → `dict` (Python 3.9+ style):
- This is NOT a contract change
- Do NOT update documentation
- These are internal style changes with identical behavior

## Non-Standard Documentation Formats

ReStructuredText (`.rst`), AsciiDoc (`.adoc`), and wiki-style markup are out of
scope. The skill targets markdown (`.md`) and inline docstrings/JSDoc only. Repos
using Sphinx RST or AsciiDoc should not expect coverage from this skill.

## The Golden Rule

> When in doubt, flag it. A false positive (flagging something that didn't need review) is far better than a false negative (silently making a wrong change).
