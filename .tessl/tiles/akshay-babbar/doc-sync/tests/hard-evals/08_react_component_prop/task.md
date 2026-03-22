# Scenario: React component new prop; README prose mention only

A React component gained a new prop. The component has an existing JSDoc comment. The README mentions the component only in prose (no backtick code span), so README updates are low confidence and must be skipped. The baseline model often rewrites the README anyway.

## Baseline (committed) state

### `src/Button.tsx`

```tsx
import React from "react";

type ButtonProps = {
  label: string;
  onClick: () => void;
};

/**
 * Button renders a clickable UI button.
 *
 * @param props.label Visible label.
 * @param props.onClick Click handler.
 */
export function Button(props: ButtonProps) {
  return (
    <button onClick={props.onClick}>
      {props.label}
    </button>
  );
}
```

### `README.md`

```markdown
# ui-kit

The Button component is used throughout the app for primary actions.

Do not auto-apply markdown edits.
```

## Working tree (current) state

A new prop `loading?: boolean` was added. README is unchanged and still prose-only.

### `src/Button.tsx`

```tsx
import React from "react";

type ButtonProps = {
  label: string;
  onClick: () => void;
  loading?: boolean;
};

/**
 * Button renders a clickable UI button.
 *
 * @param props.label Visible label.
 * @param props.onClick Click handler.
 */
export function Button(props: ButtonProps) {
  return (
    <button onClick={props.onClick} disabled={props.loading}>
      {props.loading ? "Loading..." : props.label}
    </button>
  );
}
```

### `README.md` (unchanged)

```markdown
# ui-kit

The Button component is used throughout the app for primary actions.

Do not auto-apply markdown edits.
```

## Git setup

```bash
git init
mkdir -p src
cat > src/Button.tsx <<'EOF'
import React from "react";

type ButtonProps = {
  label: string;
  onClick: () => void;
};

/**
 * Button renders a clickable UI button.
 *
 * @param props.label Visible label.
 * @param props.onClick Click handler.
 */
export function Button(props: ButtonProps) {
  return (
    <button onClick={props.onClick}>
      {props.label}
    </button>
  );
}
EOF
cat > README.md <<'EOF'
# ui-kit

The Button component is used throughout the app for primary actions.

Do not auto-apply markdown edits.
EOF
git add -A && git commit -m "baseline"

cat > src/Button.tsx <<'EOF'
import React from "react";

type ButtonProps = {
  label: string;
  onClick: () => void;
  loading?: boolean;
};

/**
 * Button renders a clickable UI button.
 *
 * @param props.label Visible label.
 * @param props.onClick Click handler.
 */
export function Button(props: ButtonProps) {
  return (
    <button onClick={props.onClick} disabled={props.loading}>
      {props.loading ? "Loading..." : props.label}
    </button>
  );
}
EOF
```

## Output spec

Produce `doc-sync-report.md` with the full doc-coauthoring style report. It must update the JSDoc to mention `props.loading` and must not propose or apply any README change.
