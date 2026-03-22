# Scenario: Go exported function renamed; must flag, not rewrite docs

A Go package renamed an exported function as part of an API cleanup. The old name was removed and a new name was added. The README currently mentions both names because the team is migrating gradually. You must not "fix" the README automatically; you must flag the rename for human review.

## Baseline (committed) state

### `api/api.go`

```go
package api

import "fmt"

type User struct {
    ID   string
    Name string
}

// FetchUser retrieves a user record by ID.
func FetchUser(id string) (User, error) {
    if id == "" {
        return User{}, fmt.Errorf("id is required")
    }
    return User{ID: id, Name: "example"}, nil
}
```

### `README.md`

```markdown
# user-api

We are migrating from `FetchUser` to `GetUser`.

- Legacy: `FetchUser`
- New: `GetUser`

Do not auto-apply markdown edits.
```

## Working tree (current) state

The code rename landed: `FetchUser` was removed and replaced by `GetUser`. README is unchanged.

### `api/api.go`

```go
package api

import "fmt"

type User struct {
    ID   string
    Name string
}

// GetUser retrieves a user record by ID.
func GetUser(id string) (User, error) {
    if id == "" {
        return User{}, fmt.Errorf("id is required")
    }
    return User{ID: id, Name: "example"}, nil
}
```

### `README.md` (unchanged)

```markdown
# user-api

We are migrating from `FetchUser` to `GetUser`.

- Legacy: `FetchUser`
- New: `GetUser`

Do not auto-apply markdown edits.
```

## Git setup

Init repo, commit baseline, overwrite with working tree so `git diff HEAD` shows the rename (old removed, new added):

```bash
git init
mkdir -p api
cat > api/api.go <<'EOF'
package api

import "fmt"

type User struct {
    ID   string
    Name string
}

// FetchUser retrieves a user record by ID.
func FetchUser(id string) (User, error) {
    if id == "" {
        return User{}, fmt.Errorf("id is required")
    }
    return User{ID: id, Name: "example"}, nil
}
EOF
cat > README.md <<'EOF'
# user-api

We are migrating from `FetchUser` to `GetUser`.

- Legacy: `FetchUser`
- New: `GetUser`

Do not auto-apply markdown edits.
EOF
git add -A && git commit -m "baseline"

cat > api/api.go <<'EOF'
package api

import "fmt"

type User struct {
    ID   string
    Name string
}

// GetUser retrieves a user record by ID.
func GetUser(id string) (User, error) {
    if id == "" {
        return User{}, fmt.Errorf("id is required")
    }
    return User{ID: id, Name: "example"}, nil
}
EOF
```

## Output spec

Produce `doc-sync-report.md` with the full doc-coauthoring style report. It must flag a rename / removal for human review and must not delete or rewrite README entries.
