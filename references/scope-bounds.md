# Scope Bounds

This document defines what the doc-coauthoring skill will NOT touch.
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

## Markdown Files — Propose-Only

All README and markdown documentation updates are **propose-only**. The skill
never auto-writes to markdown files. It finds symbol mentions in code spans
(`` `fn_name` ``) and table cells, generates a proposed patch, and includes it
in the report for human review.

## Symbols Never Auto-Documented (Only Flagged)

| Symbol Type | Behavior |
|-------------|----------|
| Any symbol with no docstring | Report as "Missing coverage", do NOT create docs |
| Any symbol with no README mention | Skip README update, report |

The skill updates existing documentation. It never creates from scratch.

## Content Never Modified

### README Content (All Propose-Only)

All README and markdown content is human territory. The skill proposes
updates based on code span matches but never auto-writes:

```markdown
# Project Name          ← NEVER AUTO-WRITE
                        
Introduction text...    ← NEVER AUTO-WRITE

## API Reference        ← NEVER AUTO-WRITE
API reference here      ← PROPOSE-ONLY (if code span match found)

## Contributing         ← NEVER AUTO-WRITE
```

### Human-Authored Docstring Content

Within docstrings, only modify:
- Parameter descriptions for changed parameters
- Return type descriptions for changed returns
- Symbol descriptions for new symbols

Never modify:
- Examples (even if outdated)
- Notes/warnings
- See-also references
- Deprecation notices (flag for review instead)

### Behavioral Documentation

If a function's signature is unchanged but behavior changed:

```python
def calculate_tax(amount: float) -> float:
    """Calculate tax on amount.
    
    Note: Now uses 2024 tax brackets.  ← NEVER auto-update this
    """
```

Flag as `[NEEDS HUMAN REVIEW]` — behavioral changes require human judgment.

## Symbols Never Documented

| Symbol Type | Reason |
|-------------|--------|
| `_private_func` | Private by convention |
| `__dunder__` | Magic methods, well-documented elsewhere |
| `_ClassName` | Internal class |
| Functions in `test_*.py` | Test code, not API |
| Functions in `*_test.go` | Test code, not API |
| `internal/` directory | Go internal packages |
| `_internal/` directory | Python internal packages |

## Operations Never Performed

| Operation | Why Forbidden |
|-----------|---------------|
| Auto-write to markdown files | Human territory — propose-only |
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
- Report: "Symbol renamed from `old_name` to `new_name`. Documentation references may need manual update."

### Moved Symbols

If function moved between files:
- Do NOT auto-update import examples
- Flag as `[NEEDS HUMAN REVIEW]`
- Report: "Symbol `func` moved from `old.py` to `new.py`. Import examples may need manual update."

### Deprecated Symbols

If `@deprecated` or `@obsolete` added:
- Do NOT modify existing docs
- Flag as `[NEEDS HUMAN REVIEW]`
- Report: "Symbol `func` marked deprecated. Documentation may need deprecation notice."

### Generic Type Changes

If `List` → `list` or `Dict` → `dict` (Python 3.9+ style):
- This is NOT a contract change
- Do NOT update documentation
- These are internal style changes with identical behavior

## The Golden Rule

> When in doubt, flag it. A false positive (flagging something that didn't need review) is far better than a false negative (silently making a wrong change).
