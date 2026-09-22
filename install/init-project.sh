#!/usr/bin/env bash
# =============================================================================
# Skill Starter Kit — FIRST THING in a new project.
#   bash ~/skill-starter-kit/install/init-project.sh [target-dir]
#
# Lays down, in this order of loop-closing value (then installs the stack's per-project plugins
# and runs the gate once as a baseline). Never overwrites a file you wrote —
# .claude/settings.json is MERGED (kit hooks/deny/sandbox added, yours kept) and .npmrc gets
# only the hygiene keys it is missing; everything else is created-if-absent.
#   1. AGENTS.md (+ CLAUDE.md pointer)     — project instructions the agent can't infer
#   2. verify.sh                            — verify-gate: the pass/fail completion gate
#   3. .claude/settings.json + hooks/       — guardrails (block/format) + Stop hook + deny + sandbox
#   4. .npmrc / pnpm-workspace.yaml / .yarnrc.yml / bunfig.toml — security-gate layer 5: install hygiene
#   5. .gitleaksignore                      — security-gate layer 3 convention
# Then prints the Hermes equivalents.
# =============================================================================
set -euo pipefail
SELF="${BASH_SOURCE[0]}"
while [ -L "$SELF" ]; do SELF="$(readlink "$SELF")"; done     # kit-init is a symlink to this file
KIT_ROOT="$(cd "$(dirname "$SELF")/.." && pwd)"
DEST="$(cd "${1:-.}" && pwd)"
T="$KIT_ROOT/templates/project"

put() {  # put <src> <dst-relative>
    if [ -e "$DEST/$2" ]; then echo "  · $2  exists — kept"; else
        mkdir -p "$(dirname "$DEST/$2")"; cp "$1" "$DEST/$2"; echo "  · $2  created ✓"; fi
}

# Merge kit settings into an existing .claude/settings.json: hooks are appended per event
# (skipping any hook whose command is already present), deny rules unioned, sandbox added only
# if absent. Nothing of yours is removed.
merge_settings() {  # merge_settings <kit-json> <dst-relative>
    if [ ! -e "$DEST/$2" ]; then put "$1" "$2"; return; fi
    python3 - "$1" "$DEST/$2" <<'PY'
import json, sys
kit = json.load(open(sys.argv[1])); dst_p = sys.argv[2]; cur = json.load(open(dst_p))
added = []
hooks = cur.setdefault("hooks", {})
# legacy kit shape (Stop → ./verify.sh directly) never blocked: exit 1 is advisory in Claude Code
if "Stop" in hooks:
    hooks["Stop"] = [g for g in hooks["Stop"] if not any(h.get("command") == "./verify.sh" for h in g.get("hooks", []))]
for ev, groups in kit.get("hooks", {}).items():
    have = json.dumps(hooks.get(ev, []))
    for g in groups:
        cmds = [h.get("command", "") for h in g.get("hooks", [])]
        if any(c and c in have for c in cmds): continue
        hooks.setdefault(ev, []).append(g); added.append(f"hooks.{ev}")
perm = cur.setdefault("permissions", {})
deny = perm.setdefault("deny", [])
new = [d for d in kit.get("permissions", {}).get("deny", []) if d not in deny]
if new: deny.extend(new); added.append(f"permissions.deny(+{len(new)})")
if "sandbox" in kit and "sandbox" not in cur: cur["sandbox"] = kit["sandbox"]; added.append("sandbox")
json.dump(cur, open(dst_p, "w"), indent=2); open(dst_p, "a").write("\n")
print("  · " + dst_p.split("/")[-2] + "/" + dst_p.split("/")[-1] + "  merged ✓ " + (", ".join(added) if added else "(already complete)"))
PY
}

# Append only the hygiene keys an existing .npmrc lacks (ignore-scripts is added COMMENTED when
# the file already exists: turning it on in a live project needs a build check first).
merge_npmrc() {  # merge_npmrc <kit-npmrc> <dst-relative>
    if [ ! -e "$DEST/$2" ]; then put "$1" "$2"; return; fi
    local f="$DEST/$2" added=""
    grep -q '^min-release-age=' "$f" || { printf '\n# kit: skip versions younger than a week (npm >= 11.10)\nmin-release-age=7\n' >> "$f"; added="$added min-release-age"; }
    grep -q '^save-exact=' "$f"      || { printf 'save-exact=true\n' >> "$f"; added="$added save-exact"; }
    grep -q 'ignore-scripts=' "$f"   || { printf '# kit: enable after confirming the build passes without lifecycle scripts\n# ignore-scripts=true\n' >> "$f"; added="$added ignore-scripts(commented)"; }
    echo "  · $2  exists — appended:${added:- nothing}"
}

echo "── Skill Starter Kit · init project: $DEST ──────────────"
echo "▶ 1. project instructions"
if [ -e "$DEST/CLAUDE.md" ] && [ ! -e "$DEST/AGENTS.md" ] && ! grep -q '^@AGENTS.md' "$DEST/CLAUDE.md"; then
    echo "  · CLAUDE.md  exists with real content — kept as the instructions file (no AGENTS.md created;"
    echo "    add the verify line: '\`./verify.sh\` is the completion gate — paste its output before done')"
else
    put "$T/AGENTS.md" AGENTS.md
    put "$T/CLAUDE.md" CLAUDE.md
fi
echo "▶ 2. verify gate"
# Generate verify.sh from what the repo actually has (scripts in package.json, pyproject, go.mod,
# Cargo.toml). Only steps that exist are emitted, so it is green-able on day one. Existing file kept.
gen_verify() {
    python3 - "$DEST" "$KIT_ROOT" <<'PY'
import json, os, sys, re
dest, kit = sys.argv[1], sys.argv[2]
def has(*p): return os.path.exists(os.path.join(dest, *p))
steps = []
pm = None
if has("package.json"):
    pkg = json.load(open(os.path.join(dest, "package.json"))); s = pkg.get("scripts", {})
    pm = "pnpm" if has("pnpm-lock.yaml") else "yarn" if has("yarn.lock") else "bun" if (has("bun.lock") or has("bun.lockb")) else "npm"
    run = {"npm": "npm run", "pnpm": "pnpm", "yarn": "yarn", "bun": "bun run"}[pm]
    install = {"npm": "npm ci --prefer-offline", "pnpm": "pnpm install --frozen-lockfile", "yarn": "yarn install --immutable", "bun": "bun install --frozen-lockfile"}[pm]
    steps.append(("install from lockfile", install, "security-gate layer 5 — test what will ship"))
    for name, label in (("typecheck", "typecheck"), ("check", "typecheck"), ("tsc", "typecheck")):
        if name in s: steps.append((label, f"{run} {name}", "")); break
    else:
        if has("tsconfig.json"): steps.append(("typecheck", "npx tsc --noEmit", ""))
    if "lint" in s and any(has(c) for c in ("eslint.config.js", "eslint.config.mjs", "eslint.config.ts", ".eslintrc", ".eslintrc.js", ".eslintrc.cjs", ".eslintrc.json", "biome.json", "biome.jsonc")):
        steps.append(("lint", f"{run} lint", ""))
    if "test" in s and "no test specified" not in s["test"]: steps.append(("test", f"{run} test", ""))
    if "build" in s: steps.append(("build", f"{run} build", ""))
elif has("pyproject.toml") or has("requirements.txt"):
    if has("uv.lock"): steps.append(("install from lockfile", "uv sync --locked", "security-gate layer 5"))
    py = "uv run " if has("uv.lock") else ""
    if has("pyproject.toml") and re.search(r"\[tool\.ruff", open(os.path.join(dest, "pyproject.toml")).read()): steps.append(("lint", f"{py}ruff check .", ""))
    if any(has(d) for d in ("tests", "test")) or has("pytest.ini"): steps.append(("test", f"{py}pytest -q", ""))
    if has("pyproject.toml") and "mypy" in open(os.path.join(dest, "pyproject.toml")).read(): steps.append(("typecheck", f"{py}mypy .", ""))
elif has("go.mod"):
    steps += [("vet", "go vet ./...", ""), ("test", "go test ./...", ""), ("build", "go build ./...", "")]
elif has("Cargo.toml"):
    steps += [("check", "cargo check --locked", ""), ("clippy", "cargo clippy --locked -- -D warnings", ""), ("test", "cargo test --locked", "")]
out = ["#!/usr/bin/env bash",
       "# verify — the completion gate. Exit 0 only when every check passed.",
       "# Generated by kit-init from this repo's own scripts; edit freely, keep it under ~2 minutes.",
       "# Rules: no `|| true`, no swallowed failures. A gate that can't fail isn't one.",
       "set -euo pipefail", "", "step() { printf '\\n── %s ───────────────────────────────\\n' \"$1\"; }", ""]
for label, cmd, why in steps:
    out += [f'step "{label}"' + (f"        # {why}" if why else ""), cmd, ""]
out += ['step "dependency audit"             # security-gate layer 4: CVEs + known-malicious (MAL-*) packages',
        "osv-scanner scan source -r .", "",
        "if [ -d .github/workflows ]; then",
        '  step "github actions lint"        # security-gate layer 5',
        "  uvx zizmor --min-severity medium .github/workflows", "fi", "",
        "if [ -f playwright.config.ts ] || [ -f playwright.config.js ]; then",
        '  step "browser smoke"              # browser-verify: one critical-path spec, no more',
        "  npx playwright test --reporter=line", "fi", "",
        "printf '\\n✓ verify passed — every check green\\n'"]
open(os.path.join(dest, "verify.sh"), "w").write("\n".join(out) + "\n")
print("  · verify.sh  generated ✓ steps: " + ", ".join(l for l, _, _ in steps) + ", dependency audit" + (f"  [{pm}]" if pm else ""))
PY
}
if [ -e "$DEST/verify.sh" ]; then echo "  · verify.sh  exists — kept"; else gen_verify; fi
chmod +x "$DEST/verify.sh"
echo "▶ 3. guardrails + hooks"
put "$KIT_ROOT/skills/guardrails/templates/guard.sh"  .claude/hooks/guard.sh
put "$KIT_ROOT/skills/guardrails/templates/format.sh" .claude/hooks/format.sh
put "$KIT_ROOT/skills/guardrails/templates/stop-verify.sh" .claude/hooks/stop-verify.sh
chmod +x "$DEST"/.claude/hooks/*.sh
merge_settings "$KIT_ROOT/skills/guardrails/templates/claude-settings.json" .claude/settings.json
echo "▶ 4. install hygiene"
if [ -f "$DEST/pnpm-lock.yaml" ]; then put "$T/pnpm-workspace.yaml" pnpm-workspace.yaml; fi
if [ -f "$DEST/yarn.lock" ]; then put "$T/.yarnrc.yml" .yarnrc.yml; fi
if [ -f "$DEST/bun.lock" ] || [ -f "$DEST/bun.lockb" ]; then put "$T/bunfig.toml" bunfig.toml; fi
if [ -f "$DEST/package.json" ] || [ ! -f "$DEST/pnpm-lock.yaml" ]; then merge_npmrc "$T/.npmrc" .npmrc; fi
echo "▶ 5. secrets"
put "$T/.gitleaksignore" .gitleaksignore

# --- 6. per-project plugins (Claude Code): the stack's LSP + context7 + read-only GitHub MCP ----
find_claude() {
    command -v claude 2>/dev/null && return
    local d="$HOME/Library/Application Support/Claude/claude-code"
    [ -d "$d" ] && ls -d "$d"/*/claude.app/Contents/MacOS/claude 2>/dev/null | sort -V | tail -1
}
CLAUDE_BIN="$(find_claude || true)"
if [ -n "$CLAUDE_BIN" ] && [ -x "$CLAUDE_BIN" ] && [ "${KIT_NO_PLUGINS:-0}" != "1" ]; then
    echo "▶ 6. per-project plugins"
    LSPS=""
    { [ -f "$DEST/tsconfig.json" ] || [ -f "$DEST/package.json" ]; } && LSPS="$LSPS typescript-lsp"
    { [ -f "$DEST/pyproject.toml" ] || [ -f "$DEST/requirements.txt" ]; } && LSPS="$LSPS pyright-lsp"
    [ -f "$DEST/go.mod" ]     && LSPS="$LSPS gopls-lsp"
    [ -f "$DEST/Cargo.toml" ] && LSPS="$LSPS rust-analyzer-lsp"
    for p in $LSPS context7; do
        ( cd "$DEST" && "$CLAUDE_BIN" plugin install "$p@claude-plugins-official" --scope project >/dev/null 2>&1 ) \
            && echo "  · $p  (project scope) ✓" || echo "  · $p  already present or unavailable"
    done
    if [ -d "$DEST/.git" ] && command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        ( cd "$DEST" && "$CLAUDE_BIN" mcp add --transport http --scope project github https://api.githubcopilot.com/mcp/readonly >/dev/null 2>&1 ) \
            && echo "  · github MCP (read-only, project scope) ✓ — one-time OAuth on first use" || echo "  · github MCP already configured"
    fi
fi

# --- 7. baseline: run the gate once so the repo's real state is known -------------------
if [ "${KIT_NO_BASELINE:-0}" != "1" ]; then
    echo "▶ 7. baseline ./verify.sh (this is the truth about the repo right now)"
    if ( cd "$DEST" && ./verify.sh > "$DEST/.verify-baseline.log" 2>&1 ); then
        echo "  · GREEN ✓ — the gate is live. Break something to see it block."
        rm -f "$DEST/.verify-baseline.log"
    else
        echo "  · RED — pre-existing failures; the Stop hook will block turns until fixed (or trim verify.sh)."
        echo "    log: $DEST/.verify-baseline.log   (tail shown)"
        tail -n 12 "$DEST/.verify-baseline.log" | sed 's/^/      /'
    fi
    grep -qx '.verify-baseline.log' "$DEST/.gitignore" 2>/dev/null || echo '.verify-baseline.log' >> "$DEST/.gitignore"
fi

cat <<'TXT'

Done. Everything above is wired; the only manual parts:
  • AGENTS.md — replace the <placeholders> (one minute; the agent can't infer them).
  • If baseline was RED, fix the causes (or trim verify.sh) — the gate is honest, not broken.
  • Commit: a fresh clone must inherit the gates.
Hermes: hooks are global (installed by hermes.sh); per task you can also  /goal gate add "./verify.sh"
TXT
