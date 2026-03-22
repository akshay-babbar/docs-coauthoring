# Scenario: Rust new pub fn added with zero prior documentation

A Rust crate added a new public function. There was no prior documentation for it (no doc comment, no README mention). The skill must not invent documentation; it must report missing coverage only.

## Baseline (committed) state

### `src/lib.rs`

```rust
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}
```

### `README.md`

```markdown
# mathy

A tiny crate.
```

## Working tree (current) state

A new public function is added without documentation.

### `src/lib.rs`

```rust
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}

pub fn multiply(a: i32, b: i32) -> i32 {
    a * b
}
```

### `README.md` (unchanged)

```markdown
# mathy

A tiny crate.
```

## Git setup

```bash
git init
mkdir -p src
cat > src/lib.rs <<'EOF'
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}
EOF
cat > README.md <<'EOF'
# mathy

A tiny crate.
EOF
git add -A && git commit -m "baseline"

cat > src/lib.rs <<'EOF'
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}

pub fn multiply(a: i32, b: i32) -> i32 {
    a * b
}
EOF
```

## Output spec

Produce `doc-sync-report.md` with the full doc-coauthoring style report. It must list `multiply` under Missing Coverage and must not create any new doc comments.
