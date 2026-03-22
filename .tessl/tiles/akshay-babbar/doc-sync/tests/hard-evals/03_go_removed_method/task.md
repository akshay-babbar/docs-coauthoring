# Scenario: Go exported method removed; must flag only

A Go SDK removed an exported method from an exported type. The README still mentions the method in a code span. You must not delete documentation automatically; you must flag the removal as requiring human review.

## Baseline (committed) state

### `client/client.go`

```go
package client

import (
    "context"
)

type Client struct {
    Endpoint string
}

// Send transmits payload bytes to the configured endpoint.
func (c *Client) Send(ctx context.Context, payload []byte) error {
    _ = ctx
    _ = payload
    return nil
}
```

### `README.md`

```markdown
# go-client

The `Client.Send` method sends a payload to the server.

This README is human territory. Do not auto-apply edits.
```

## Working tree (current) state

The method `Send` was removed entirely.

### `client/client.go`

```go
package client

type Client struct {
    Endpoint string
}
```

### `README.md` (unchanged)

```markdown
# go-client

The `Client.Send` method sends a payload to the server.

This README is human territory. Do not auto-apply edits.
```

## Git setup

Init repo, commit baseline, then overwrite with working tree so `git diff HEAD` catches the removal:

```bash
git init
mkdir -p client
cat > client/client.go <<'EOF'
package client

import (
    "context"
)

type Client struct {
    Endpoint string
}

// Send transmits payload bytes to the configured endpoint.
func (c *Client) Send(ctx context.Context, payload []byte) error {
    _ = ctx
    _ = payload
    return nil
}
EOF
cat > README.md <<'EOF'
# go-client

The `Client.Send` method sends a payload to the server.

This README is human territory. Do not auto-apply edits.
EOF
git add -A && git commit -m "baseline"

cat > client/client.go <<'EOF'
package client

type Client struct {
    Endpoint string
}
EOF
```

## Output spec

Produce `doc-sync-report.md` containing the full doc-coauthoring style report. It must flag `Send` as removed and `[NEEDS HUMAN REVIEW]`, and it must not delete README content.
