# Scenario: TypeScript internal refactor; docstring remains accurate

A TypeScript utility function was refactored internally for performance. The exported signature is identical and the existing doc comment is intentionally generic and still correct. You must be conservative: do not "improve" documentation just because code changed.

## Baseline (committed) state

### `src/normalize.ts`

```ts
/**
 * Processes the request string.
 *
 * @param input Raw request input.
 * @returns A normalized string.
 */
export function normalizeRequest(input: string): string {
  return input.trim().toLowerCase();
}
```

### `README.md`

```markdown
# normalize-kit

`normalizeRequest` is used by internal services.

README is human-authored; do not auto-apply changes.
```

## Working tree (current) state

The implementation now uses a slightly different normalization algorithm, but the contract and doc comment remain correct.

### `src/normalize.ts`

```ts
/**
 * Processes the request string.
 *
 * @param input Raw request input.
 * @returns A normalized string.
 */
export function normalizeRequest(input: string): string {
  const trimmed = input.trim();
  const collapsed = trimmed.replace(/\s+/g, " ");
  return collapsed.toLowerCase();
}
```

### `README.md` (unchanged)

```markdown
# normalize-kit

`normalizeRequest` is used by internal services.

README is human-authored; do not auto-apply changes.
```

## Git setup

Init repo, commit baseline, overwrite with working tree so `git diff HEAD` shows only the internal refactor:

```bash
git init
mkdir -p src
cat > src/normalize.ts <<'EOF'
/**
 * Processes the request string.
 *
 * @param input Raw request input.
 * @returns A normalized string.
 */
export function normalizeRequest(input: string): string {
  return input.trim().toLowerCase();
}
EOF
cat > README.md <<'EOF'
# normalize-kit

`normalizeRequest` is used by internal services.

README is human-authored; do not auto-apply changes.
EOF
git add -A && git commit -m "baseline"

cat > src/normalize.ts <<'EOF'
/**
 * Processes the request string.
 *
 * @param input Raw request input.
 * @returns A normalized string.
 */
export function normalizeRequest(input: string): string {
  const trimmed = input.trim();
  const collapsed = trimmed.replace(/\s+/g, " ");
  return collapsed.toLowerCase();
}
EOF
```

## Output spec

Produce `doc-sync-report.md` with the full doc-coauthoring style report. It must state that no documentation changes are needed for `normalizeRequest`.
