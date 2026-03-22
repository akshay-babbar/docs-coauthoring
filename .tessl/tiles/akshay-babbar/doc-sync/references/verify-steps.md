# Verification Steps

After every documentation edit, perform this 3-point mechanical verification.
These checks are non-negotiable before reporting success.

## The Three Checks

### 1. Symbol Exists

**Question**: Does the symbol I just documented actually exist in the codebase?

**How to verify**:
```bash
# For functions
grep -r "def function_name" --include="*.py"
grep -r "function function_name" --include="*.js"
grep -r "func FunctionName" --include="*.go"

# For classes
grep -r "class ClassName" --include="*.py"
grep -r "class ClassName" --include="*.ts"
```

**Failure mode**: Documenting a symbol that was renamed or removed.

**If check fails**: 
- Remove the documentation you just added
- Flag as `[NEEDS HUMAN REVIEW]`: "Symbol `X` not found in codebase"

### 2. Parameters Match Signature

**Question**: Do the parameters in my documentation exactly match the actual function signature?

**How to verify**:
1. Read the actual function definition
2. Compare parameter names character-by-character
3. Compare parameter types if typed
4. Compare default values if present

**Example verification**:

Actual code:
```python
def process(data: dict, *, validate: bool = True, timeout: int = 30) -> Result:
```

Documentation must show:
- `data` (dict) — required positional
- `validate` (bool, default: True) — keyword-only
- `timeout` (int, default: 30) — keyword-only
- Returns: `Result`

**Failure modes**:
- Parameter name typo (`valdate` instead of `validate`)
- Missing parameter
- Extra parameter that doesn't exist
- Wrong default value
- Wrong type annotation

**If check fails**:
- Correct the documentation to match the signature exactly
- Do NOT modify the code

### 3. Syntax Valid

**Question**: Is the documentation syntactically valid for its format?

**Markdown table syntax**:
```markdown
| Header | Header |
|--------|--------|    ← Must have separator row
| Cell   | Cell   |    ← Pipes must align (approximately)
```

**Docstring syntax (Python)**:
```python
def func():
    """Short description.
    
    Args:
        param: Description.    ← Proper indentation
        
    Returns:
        Description.           ← Proper section
    """
```

**JSDoc syntax**:
```javascript
/**
 * Short description.
 * @param {string} name - Description.  ← Proper format
 * @returns {number} Description.       ← Proper format
 */
```

**Common syntax errors**:
- Missing table separator row
- Mismatched backticks
- Unclosed code blocks
- Wrong indentation in docstrings
- Missing closing delimiters

**If check fails**:
- Fix the syntax error
- Do NOT skip validation

## Verification Checklist Template

Use this template after each edit:

```
## Verification: [symbol_name]

### 1. Symbol Exists
- [ ] Searched codebase for symbol
- [ ] Symbol found at: [file:line]

### 2. Parameters Match
- [ ] Compared each parameter name
- [ ] Compared each parameter type
- [ ] Compared default values
- [ ] Count matches: [N] params in code, [N] params in docs

### 3. Syntax Valid
- [ ] Docstring/JSDoc properly formatted
- [ ] Markdown tables have separator rows
- [ ] Code blocks properly closed
- [ ] No unclosed formatting

Result: [PASS / FAIL - reason]
```

## Batch Verification

When updating multiple symbols, verify each one individually.
Do not batch-verify — each symbol needs independent confirmation.

**Correct**:
```
Verified: parse() ✓
Verified: validate() ✓
Verified: transform() ✓
```

**Incorrect**:
```
Verified: all 3 functions ✓  ← Too vague, may hide errors
```

## What To Do When Verification Fails

| Failure | Action |
|---------|--------|
| Symbol not found | Revert change, flag for review |
| Params don't match | Correct documentation |
| Syntax invalid | Fix syntax |
| Multiple failures | Revert all, report issues |

## The Meta-Rule

> If you cannot mechanically verify a change, you should not have made it.

Every documentation update must be verifiable by:
1. A text search (symbol exists)
2. A character comparison (params match)
3. A syntax check (format valid)

If your change cannot be verified by these mechanical means, it likely involves judgment — flag it for human review instead.
