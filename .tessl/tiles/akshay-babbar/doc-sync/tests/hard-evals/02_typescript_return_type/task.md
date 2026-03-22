# Scenario: TypeScript return type changed; README mention must remain propose-only

A config parser library changed the return type of an exported function. The README mentions the function in a backtick code span. You must update the doc comment to match the new return type and propose (not apply) any README changes.

## Baseline (committed) state

### `src/config.ts`

```ts
export type Config = {
  host: string;
  port: number;
};

/**
 * Parse a config string.
 *
 * @param text Raw config text.
 * @returns The raw host string.
 */
export function parseConfig(text: string): string {
  const [host] = text.trim().split(":");
  return host;
}
```

### `README.md`

```markdown
# config-kit

Use `parseConfig` to parse a config string.

This README is human-authored. Do not auto-apply changes.
```

## Working tree (current) state

The function now returns a `Config` object instead of a `string`.

### `src/config.ts`

```ts
export type Config = {
  host: string;
  port: number;
};

/**
 * Parse a config string.
 *
 * @param text Raw config text.
 * @returns Parsed config (host and port).
 */
export function parseConfig(text: string): Config {
  const [host, portStr] = text.trim().split(":");
  return { host, port: Number(portStr ?? 0) };
}
```

### `README.md` (unchanged)

```markdown
# config-kit

Use `parseConfig` to parse a config string.

This README is human-authored. Do not auto-apply changes.
```

## Git setup

```bash
git init
mkdir -p src
cat > src/config.ts <<'EOF'
export type Config = {
  host: string;
  port: number;
};

/**
 * Parse a config string.
 *
 * @param text Raw config text.
 * @returns The raw host string.
 */
export function parseConfig(text: string): string {
  const [host] = text.trim().split(":");
  return host;
}
EOF
cat > README.md <<'EOF'
# config-kit

Use `parseConfig` to parse a config string.

This README is human-authored. Do not auto-apply changes.
EOF
git add -A && git commit -m "baseline"

cat > src/config.ts <<'EOF'
export type Config = {
  host: string;
  port: number;
};

/**
 * Parse a config string.
 *
 * @param text Raw config text.
 * @returns Parsed config (host and port).
 */
export function parseConfig(text: string): Config {
  const [host, portStr] = text.trim().split(":");
  return { host, port: Number(portStr ?? 0) };
}
EOF
```

## Output spec

Produce `doc-sync-report.md` with the full doc-coauthoring style report. It must include a docstring/JSDoc update for `parseConfig` and a propose-only README note.
