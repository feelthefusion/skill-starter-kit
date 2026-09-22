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

# One verify at a time per tree: several sessions (or a Stop hook + a manual run) racing the same
# node_modules / test database is how "tsc vanished" and flaky suites happen. mkdir is atomic; a
# lock older than 20 min belongs to a dead run.
LOCK=".verify.lock"; waited=0
until mkdir "$LOCK" 2>/dev/null; do
  [ -n "$(find "$LOCK" -maxdepth 0 -mmin +20 2>/dev/null)" ] && { rm -rf "$LOCK"; continue; }
  [ "$waited" -ge 1200 ] && { echo "verify: another run has held $LOCK for 20 minutes" >&2; exit 1; }
  [ "$waited" -eq 0 ] && echo "verify: another run is in progress, waiting for it"
  sleep 5; waited=$((waited + 5))
done
trap 'rm -rf "$LOCK"' EXIT

step "dependencies match the lockfile"   # security-gate layer 5 — test what will ship
# A CLEAN install only when the lockfile changed (or in CI): `npm ci` deletes node_modules first,
# so running it on every Stop hook races dev servers and mid-task commands.
if [ -n "${CI:-}" ] || [ ! -d node_modules ] || [ package-lock.json -nt node_modules/.package-lock.json ]; then
  npm ci --ignore-scripts           # or: pnpm install --frozen-lockfile / uv sync --locked / cargo fetch --locked
else
  echo "node_modules up to date with package-lock.json (CI=1 forces a clean install)"
fi

step "typecheck"
npm run typecheck                   # or: mypy . / tsc --noEmit / go vet ./... / cargo check

step "lint"
npm run lint                        # or: ruff check . / golangci-lint run / cargo clippy -- -D warnings

step "test"
npm test                            # or: pytest -q / go test ./... / cargo test

step "build"
npm run build                       # or: go build ./... / cargo build --release

step "dependency audit"             # security-gate layer 4: CVEs + known-malicious (MAL-*) packages
if ! command -v osv-scanner >/dev/null 2>&1; then
  echo "⚠ dependency audit skipped: osv-scanner not installed (kit installer adds it; brew/GitHub releases)."
elif curl -sS -m 4 -o /dev/null https://api.osv.dev/ 2>/dev/null || [ -n "${CI:-}" ]; then
  osv-scanner scan source -r .
else                                # a sandboxed hook has no network: skip VISIBLY, never `|| true`
  echo "⚠ dependency audit skipped: no network here (sandboxed hook). Runs in CI and when verify has network."
fi

if [ -d .github/workflows ] && command -v uvx >/dev/null 2>&1; then
  step "github actions lint"        # security-gate layer 5
  uvx zizmor --min-severity medium .github/workflows
elif [ -d .github/workflows ]; then
  echo "⚠ actions lint skipped: uvx not installed (kit installer adds uv)."
fi

if [ -f playwright.config.ts ] || [ -f playwright.config.js ]; then
  step "browser smoke"              # browser-verify: one critical-path spec, no more
  npx playwright test --reporter=line
fi

printf '\n✓ verify passed — every check green\n'
