#!/usr/bin/env bash
# verify — the completion gate. Exit 0 only when every check passed.
#
# Copy to your repo root, chmod +x, delete the steps your stack doesn't have,
# and wire it to a Stop hook (see the verify-gate skill).
#
# Rules: no `|| true`, no swallowed failures. A gate that can't fail isn't one.
set -euo pipefail

step() { printf '\n── %s ───────────────────────────────\n' "$1"; }

step "typecheck"
npm run typecheck          # or: mypy . / tsc --noEmit / go vet ./... / cargo check

step "lint"
npm run lint               # or: ruff check . / golangci-lint run / cargo clippy -- -D warnings

step "test"
npm test                   # or: pytest -q / go test ./... / cargo test

step "build"
npm run build              # or: go build ./... / cargo build --release

step "dependency audit"
osv-scanner scan source -r .   # security-gate layer 4: known CVEs + slopsquatting

printf '\n✓ verify passed — every check green\n'
