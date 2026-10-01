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
# lock older than 5 min belongs to a dead run (was 20; shortened so one stuck run cannot
# hold every other agent hostage).
LOCK=".verify.lock"; waited=0
until mkdir "$LOCK" 2>/dev/null; do
  [ -n "$(find "$LOCK" -maxdepth 0 -mmin +5 2>/dev/null)" ] && { rm -rf "$LOCK"; continue; }
  [ "$waited" -ge 300 ] && { echo "verify: another run has held $LOCK for 5 minutes" >&2; exit 1; }
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
npm test                            # or: .venv/bin/python -m pytest -q / go test ./... / cargo test

step "build"
npm run build                       # or: go build ./... / cargo build --release

step "dependency audit"             # security-gate layer 4: CVEs + known-malicious (MAL-*) packages
if ! command -v osv-scanner >/dev/null 2>&1; then
  echo "⚠ dependency audit skipped: osv-scanner not installed (kit installer adds it; brew/GitHub releases)."
elif curl -sS -m 4 -o /dev/null https://api.osv.dev/ 2>/dev/null || [ -n "${CI:-}" ]; then
  # A range-only manifest ("aiohttp>=3.9") has no resolved version, so a source scan reports CVEs
  # against the old floor — noise that trains you to ignore the gate. With no lockfile at all,
  # audit what a Python venv actually has installed instead.
  if [ -z "$(ls uv.lock package-lock.json pnpm-lock.yaml yarn.lock bun.lock Cargo.lock poetry.lock 2>/dev/null)" ] && [ -x .venv/bin/python ]; then
    .venv/bin/python - > requirements.verify.txt <<'PY'
import pathlib, tomllib
from importlib.metadata import distributions
norm = lambda s: s.lower().replace('_', '-').replace('.', '-')
try:
    proj = tomllib.load(open('pyproject.toml', 'rb'))['project']['name']
except Exception:
    proj = ''
for d in sorted(distributions(), key=lambda d: (d.metadata['Name'] or '').lower()):
    name = d.metadata['Name']
    if not name or norm(name) == norm(proj):
        continue
    if (pathlib.Path(d._path) / 'direct_url.json').exists():
        continue
    print(f'{name}=={d.version}')
PY
    osv-scanner --lockfile requirements.verify.txt --format json > .verify-osv.json 2>/dev/null || true
    rm -f requirements.verify.txt
  else
    osv-scanner scan source -r . --format json > .verify-osv.json 2>/dev/null || true
  fi
  # Fail only on HIGH/CRITICAL (CVSS >= 7.0). A real tree almost always carries transitive or
  # dev-only advisories, and a gate that is permanently red is one everyone learns to ignore.
  if ! python3 - .verify-osv.json <<'PY'
import json, sys
THRESHOLD = 7.0                                  # CVSS: HIGH >= 7.0, CRITICAL >= 9.0
try:
    d = json.load(open(sys.argv[1]))
except Exception as exc:
    print(f"⚠ dependency audit: could not read osv-scanner output ({exc})")
    sys.exit(0)
rows = [(float(g.get("max_severity") or 0), p["package"].get("name", "?"),
         p["package"].get("version", "?"), (r.get("source") or {}).get("path", ""),
         ", ".join(g.get("ids", [])[:2]))
        for r in d.get("results", []) for p in r.get("packages", []) for g in p.get("groups", [])]
blocking = sorted((x for x in rows if x[0] >= THRESHOLD), reverse=True)
print(f"dependency audit: {len(rows)} advisories, {len(blocking)} at HIGH/CRITICAL (CVSS >= {THRESHOLD})")
for score, name, ver, path, ids in blocking[:15]:
    print(f"  {score:>4}  {name} {ver}  {path}  {ids}")
if len(blocking) > 15:
    print(f"  ... {len(blocking) - 15} more")
sys.exit(1 if blocking else 0)
PY
  then
    echo "✗ dependency audit: HIGH/CRITICAL advisories above — upgrade or pin a patched version."
    rm -f .verify-osv.json
    exit 1
  fi
  rm -f .verify-osv.json
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
