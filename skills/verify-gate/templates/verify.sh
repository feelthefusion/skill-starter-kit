#!/usr/bin/env bash
# verify — the completion gate. Exit 0 only when every check passed.
#
# Copy to your repo root (init-project.sh does), chmod +x, delete the steps your stack
# doesn't have, and wire it to the Stop hook (guardrails/templates/claude-settings.json
# already does) or Hermes `pre_verify` / `/goal gate add ./verify.sh`.
#
# Rules: no `|| true`, no swallowed failures. A gate that can't fail isn't one.
# Keep it under ~2 minutes; push the slow suite to CI.
set -euo pipefail

step() { printf '\n── %s ───────────────────────────────\n' "$1"; }

step "install from lockfile"        # security-gate layer 5 — test what will ship
npm ci --ignore-scripts             # or: uv sync --locked / pnpm install --frozen-lockfile / cargo fetch --locked

step "typecheck"
npm run typecheck                   # or: mypy . / tsc --noEmit / go vet ./... / cargo check

step "lint"
npm run lint                        # or: ruff check . / golangci-lint run / cargo clippy -- -D warnings

step "test"
npm test                            # or: pytest -q / go test ./... / cargo test

step "build"
npm run build                       # or: go build ./... / cargo build --release

step "dependency audit"             # security-gate layer 4: CVEs + known-malicious (MAL-*) packages
osv-scanner scan source -r .

if [ -d .github/workflows ]; then
  step "github actions lint"        # security-gate layer 5
  uvx zizmor --min-severity medium .github/workflows
fi

if [ -f playwright.config.ts ] || [ -f playwright.config.js ]; then
  step "browser smoke"              # browser-verify: one critical-path spec, no more
  npx playwright test --reporter=line
fi

printf '\n✓ verify passed — every check green\n'
