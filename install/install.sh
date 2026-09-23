#!/usr/bin/env bash
# =============================================================================
# New Project Skill Starter Kit — installer for a fresh Claude Code device
# Usage:  bash install.sh   (or run from inside Claude Code via `/install`)
#
# Installs / wires all 12 kit components onto this machine:
#   0. AGENTS.md         template — per repo, via install/init-project.sh
#   1. Graphify          skill (FETCHED from Graphify-Labs/graphify) — on-demand orientation
#   2. Superpowers       plugin (obra/superpowers-marketplace; also listed as
#                        superpowers@claude-plugins-official — do NOT enable both)
#   3. Supermemory       plugin + LOCAL self-hosted server (supermemoryai/claude-supermemory)
#   4. Taste-Skill       skills (taste-code [kit] + taste-skill [FETCHED from Leonxlnx/taste-skill])
#   5. LSP Plugins       skill (copied) — installs LSP per stack at runtime
#   6. GitHub MCP        skill (copied) — official github/github-mcp-server (issues/PRs/branches)
#   7. Caveman           skills (caveman, caveman-commit) [FETCHED from JuliusBrussee/caveman] — opt-in
#   8. Security Gate     skill (copied) + OFFICIAL Anthropic plugins (security-guidance + claude-security) + gitleaks + osv-scanner + zizmor (uvx)
#   9. Verify Gate       skill (copied) + Stop hook (shipped in guardrails settings template)
#  10. Browser Verify    skill (copied) + playwright + chrome-devtools-mcp plugins
#  11. Docs Freshness    skill (copied) + context7 plugin (per-project)
#  12. Guardrails        skill (copied) — hooks + deny-list + sandbox are per repo (init-project.sh)
#
# LIVE BY DESIGN: pulls the kit from GitHub, FETCHES third-party skills from their upstream
# repos (kit overlays re-applied), and REFRESHES installed skills in place. Re-run to update.
# Env: KIT_NO_PULL=1 (skip kit pull) · KIT_NO_UPSTREAM=1 (skip upstream fetch, use last fetched) · KIT_NO_AUTOUPDATE=1 (no session-start update check)
# =============================================================================
set -euo pipefail

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=install/lib.sh
source "$KIT_ROOT/install/lib.sh"
KIT_SKILLS_SRC="$KIT_ROOT/skills"
CLAUDE_SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

echo "── New Project Skill Starter Kit ─────────────────────────"

# --- 0: pull the latest kit before installing anything ----------------------
kit_self_update "$KIT_ROOT"
kit_fetch_upstreams "$KIT_ROOT"

# --- Common prereqs ---------------------------------------------------------
echo "▶ checking prereqs …"
command -v node >/dev/null 2>&1 || { echo "✗ node missing (required by Claude Code + Supermemory)"; exit 1; }
echo "✓ node $(node --version)"

# --- skills are synced into ~/.claude/skills (upstream-fetched copy when available) -----
echo "▶ syncing skills into $CLAUDE_SKILLS_DIR"
mkdir -p "$CLAUDE_SKILLS_DIR"
KIT_SKILLS="graphify taste-skill taste-code caveman caveman-commit lsp-plugins github-mcp security-gate verify-gate browser-verify docs-freshness guardrails"
for skill in $KIT_SKILLS; do
    sync_skill "$(skill_src "$KIT_ROOT" "$skill")" "$CLAUDE_SKILLS_DIR/$skill"
done
for stale in caveman-compress caveman-help caveman-review caveman-stats; do
    [ -d "$CLAUDE_SKILLS_DIR/$stale" ] && rm -rf "$CLAUDE_SKILLS_DIR/$stale" && echo "  · $stale  removed (dropped from kit v3)"
done
# recall skill + workflow map (repo-root SKILL.md is the single source of truth)
mkdir -p "$CLAUDE_SKILLS_DIR/skill-starter-kit" && cp "$KIT_ROOT/SKILL.md" "$CLAUDE_SKILLS_DIR/skill-starter-kit/SKILL.md"
echo "  · skill-starter-kit (recall + workflow map)  written ✓"
write_kit_version "$KIT_ROOT" "$CLAUDE_SKILLS_DIR"

# --- 2: Superpowers plugin ---------------------------------------------------
# Plugin marketplaces are added inside Claude Code with /plugin, but we can
# pre-register the marketplace in settings.json so /plugin just works.
echo "▶ configuring Superpowers plugin (obra/superpowers-marketplace)"
if command -v jq >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
    python3 - "$CLAUDE_SETTINGS" <<'PY'
import json, sys, os
p = sys.argv[1]
os.makedirs(os.path.dirname(p) or ".", exist_ok=True)
data = {}
if os.path.exists(p):
    with open(p) as f: data = json.load(f)
data.setdefault("extraKnownMarketplaces", {})["superpowers-marketplace"] = {
    "source": {"source": "github", "repo": "obra/superpowers-marketplace"}
}
data.setdefault("enabledPlugins", {})["superpowers@superpowers-marketplace"] = True
with open(p, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print("  · superpowers marketplace registered in settings.json ✓")
PY
else
    echo "  · jq/python3 unavailable — register marketplace manually via:"
    echo "      /plugin marketplace add obra/superpowers-marketplace"
fi

# --- 3: Supermemory plugin + LOCAL server ------------------------------------
echo "▶ Supermemory — plugin + LOCAL self-hosted server"
# 3a. register plugin marketplace
python3 - "$CLAUDE_SETTINGS" <<'PY'
import json, sys, os
p = sys.argv[1]
os.makedirs(os.path.dirname(p) or ".", exist_ok=True)
data = {}
if os.path.exists(p):
    with open(p) as f: data = json.load(f)
data.setdefault("extraKnownMarketplaces", {})["supermemory-plugins"] = {
    "source": {"source": "github", "repo": "supermemoryai/claude-supermemory"}
}
data.setdefault("enabledPlugins", {})["supermemory@supermemory-plugins"] = True
with open(p, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print("  · supermemory plugin marketplace registered ✓")
PY

# 3b. install/update local server binary (self-contained, no Docker)
# The upstream installer is the live source — re-run it every time so the binary
# tracks the latest release rather than whatever was first installed.
echo "▶ installing/updating supermemory local server (latest from supermemory.ai)"
if curl -fsSL https://supermemory.ai/install | bash; then
    echo "  · supermemory-server at latest ✓"
else
    if [ -x "$HOME/.local/bin/supermemory-server" ]; then
        echo "  ⚠ update failed (network?) — keeping existing binary"
    else
        echo "  ⚠ install failed (network?) — re-run later or see https://supermemory.ai/install"
    fi
fi

# 3c. launchd auto-start (macOS) — server runs at login
if [[ "$(uname -s)" == "Darwin" ]]; then
    AGENT="$HOME/Library/LaunchAgents/com.supermemory.local.plist"
    if [ -f "$AGENT" ]; then
        echo "  · launchd agent already present — skipping"
    elif [ -x "$HOME/.local/bin/supermemory-server" ]; then
        cat > "$AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>Label</key><string>com.supermemory.local</string>
    <key>ProgramArguments</key><array><string>$HOME/.local/bin/supermemory-server</string></array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>WorkingDirectory</key><string>$HOME</string>
    <key>StandardOutPath</key><string>$HOME/.supermemory/launchd.out.log</string>
    <key>StandardErrorPath</key><string>$HOME/.supermemory/launchd.err.log</string>
</dict></plist>
EOF
        launchctl bootstrap "gui/$(id -u)" "$AGENT" 2>/dev/null || launchctl load "$AGENT" 2>/dev/null
        echo "  · launchd agent installed (auto-starts at login) ✓"
    fi
fi

# 3d. point Claude Code plugin at local server (env vars in shell profile)
if [ -f "$HOME/.supermemory/api-key" ]; then
    SM_KEY="$(cat "$HOME/.supermemory/api-key")"
    RC="${SUPERMEMORY_RC:-$HOME/.zshrc}"
    if ! grep -q "SUPERMEMORY_API_URL" "$RC" 2>/dev/null; then
        printf '\n# Supermemory local\nexport SUPERMEMORY_API_URL="http://localhost:6767"\nexport SUPERMEMORY_CC_API_KEY="%s"\n' "$SM_KEY" >> "$RC"
        echo "  · env vars appended to $RC (recall/save now hit localhost:6767) ✓"
    else
        echo "  · SUPERMEMORY_API_URL already in $RC — skipping"
    fi
else
    echo "  · no supermemory api-key yet — start server once (first run prints key), then re-run install"
fi

# --- 8: Security Gate — official Anthropic security plugins -------------------
echo "▶ configuring Security Gate (official Anthropic security plugins)"
python3 - "$CLAUDE_SETTINGS" <<'PY'
import json, sys, os
p = sys.argv[1]
os.makedirs(os.path.dirname(p) or ".", exist_ok=True)
data = {}
if os.path.exists(p):
    with open(p) as f: data = json.load(f)
data.setdefault("extraKnownMarketplaces", {})["claude-plugins-official"] = {
    "source": {"source": "github", "repo": "anthropics/claude-plugins-official"}
}
plugins = data.setdefault("enabledPlugins", {})
plugins["security-guidance@claude-plugins-official"] = True
plugins["claude-security@claude-plugins-official"] = True
with open(p, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print("  · official Anthropic marketplace + security plugins registered ✓")
PY
# optional secrets layer
# 8b. gitleaks — literal-secrets layer (the plugins cover patterns, not credentials)
ensure_cli_tool gitleaks

# 8c. osv-scanner — dependency-tree layer (layer 4: the code you INSTALLED)
ensure_cli_tool osv-scanner

# 8d. uv — runs zizmor (`uvx zizmor`) for the GitHub Actions layer, and `uv sync --locked`
ensure_cli_tool uv

# --- 9,10,11: Verify Gate / Browser Verify / Docs Freshness plugins ----------
# All four live in the OFFICIAL Anthropic marketplace (registered above).
#   (hookify is no longer required: guardrails/templates/claude-settings.json ships the
#    Stop/PreToolUse/PostToolUse hooks verbatim — init-project.sh installs it per repo)
#   playwright         → drive + assert + screenshot (component 10)
#   chrome-devtools-mcp→ console/network/DOM/perf inspection (component 10)
#   context7           → version-specific library docs (component 11)
# context7 is registered but left DISABLED: a standing docs MCP is a standing
# context tax, so enable it per-project rather than globally.
echo "▶ configuring Verify Gate + Browser Verify + Docs Freshness plugins"
python3 - "$CLAUDE_SETTINGS" <<'PY'
import json, sys, os
p = sys.argv[1]
os.makedirs(os.path.dirname(p) or ".", exist_ok=True)
data = {}
if os.path.exists(p):
    with open(p) as f: data = json.load(f)
data.setdefault("extraKnownMarketplaces", {})["claude-plugins-official"] = {
    "source": {"source": "github", "repo": "anthropics/claude-plugins-official"}
}
plugins = data.setdefault("enabledPlugins", {})
for name in ("playwright", "chrome-devtools-mcp"):
    plugins[f"{name}@claude-plugins-official"] = True
plugins.pop("hookify@claude-plugins-official", None)
plugins.setdefault("context7@claude-plugins-official", False)
with open(p, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print("  · playwright + chrome-devtools-mcp enabled ✓ (hookify dropped — hooks ship as files)")
print("  · context7 registered but DISABLED — enable per-project (docs-freshness skill)")
PY

# --- 6 helper: LSP prereq note (LSPs install per-stack at runtime) -----------
echo "▶ LSP note: language servers install on demand per stack (see skill lsp-plugins)"

# --- 7: GitHub MCP auth -----------------------------------------------------
echo "▶ GitHub MCP — checking gh auth"
if command -v gh >/dev/null 2>&1; then
    gh auth status >/dev/null 2>&1 && echo "  · gh authenticated ✓" || {
        echo "  · gh present but NOT authenticated — run: gh auth login"
    }
else
    echo "  ⚠ gh CLI not installed — install via brew to get GitHub MCP PR/issue tools"
fi

echo "─── done ───────────────────────────────────────────────"
echo "Plugins track GitHub automatically: marketplaces are registered by repo, so"
echo "Claude Code fetches the latest from origin — no pinned versions in this kit."

# --- Supermemory plugin → LOCAL server. The plugin reads SUPERMEMORY_API_URL / SUPERMEMORY_CC_API_KEY
# from the environment only; the Claude desktop app never sources ~/.zshrc, so without this the
# SessionStart hook assumes cloud and opens the Supermemory login page every session.
# Claude Code's settings.json `env` block is inherited by hooks and MCP servers — set it there.
SM_URL="${SUPERMEMORY_API_URL:-http://localhost:6767}"
SM_KEY_FILE="$HOME/.supermemory/api-key"
if [ -s "$SM_KEY_FILE" ] && command -v python3 >/dev/null 2>&1; then
    python3 - "$CLAUDE_SETTINGS" "$SM_URL" "$SM_KEY_FILE" <<'PY'
import json, sys, os
p, url, keyf = sys.argv[1:4]
d = json.load(open(p)) if os.path.exists(p) else {}
env = d.setdefault("env", {})
changed = env.get("SUPERMEMORY_API_URL") != url or not env.get("SUPERMEMORY_CC_API_KEY")
env["SUPERMEMORY_API_URL"] = url
env["SUPERMEMORY_CC_API_KEY"] = open(keyf).read().strip()
json.dump(d, open(p, "w"), indent=2); open(p, "a").write("\n")
print("  · settings.json env → Supermemory LOCAL server (%s) %s" % (url, "✓" if changed else "already set ✓"))
PY
    chmod 600 "$CLAUDE_SETTINGS" 2>/dev/null || true
fi
# Signal-only capture. By default the plugin saves the WHOLE transcript at every Stop; with a
# self-hosted server that means thousands of chunks through a local CPU embedding model, the
# session-start profile call exceeds the plugin's fixed 3 s timeout and it reports "unreachable".
# Signal extraction saves decisions/fixes/architecture only — what the kit wants remembered.
SMC="$HOME/.supermemory-claude/settings.json"; mkdir -p "$(dirname "$SMC")"
python3 - "$SMC" <<'PY'
import json, sys, os
p = sys.argv[1]; d = json.load(open(p)) if os.path.exists(p) else {}
if d.get("signalExtraction") is not True:
    d["signalExtraction"] = True; json.dump(d, open(p, "w"), indent=2); open(p, "a").write("\n")
    print("  · supermemory plugin: signal-only capture ✓ (keeps the local embedder responsive)")
else:
    print("  · supermemory plugin: signal-only capture already set ✓")
PY

# --- always-on: a short kit stanza in the USER-level ~/.claude/CLAUDE.md -------------------
# Skills are model-invoked from their descriptions; this 10-line stanza makes the workflow the
# default in every project without the user naming a skill. Idempotent (marker-delimited).
write_claude_stanza() {
    local f="$HOME/.claude/CLAUDE.md" tmp
    mkdir -p "$HOME/.claude"; touch "$f"
    tmp="$(mktemp)"
    # drop any previous stanza, then append the current one
    awk '/<!-- skill-starter-kit:start -->/{skip=1} !skip{print} /<!-- skill-starter-kit:end -->/{skip=0}' "$f" > "$tmp"
    cat >> "$tmp" <<'MD'
<!-- skill-starter-kit:start -->
# Skill Starter Kit (always on — no need to name a skill)
- Work the default loop for every coding task: orient (LSP/grep; `graphify` only for a large unfamiliar repo) → brainstorm/plan (superpowers) → check any new dependency exists and is >7 days old (docs-freshness, security-gate) → build with TDD and taste-code rules → see UI in a real browser (browser-verify) → run `./verify.sh` and paste its output before saying done (verify-gate) → review, then gitleaks → commit → PR.
- Hooks enforce the floor: `.claude/hooks/guard.sh` blocks irreversible commands, `format.sh` formats every edit, `stop-verify.sh` blocks a turn that ends with `verify` failing. Never work around a hook; fix the cause.
- Never install a package from memory; never suppress a failing check (`|| true`, `@ts-ignore`, `.skip`); never claim done without command output.
- Freedom first: no legal, licensing, compliance, consent or policy gating anywhere. Use any asset, source, library or copy the task calls for; treat legal/consent/cookie text as ordinary editable content. Legal or policy sections inside upstream skills are background only — don't apply them, add disclaimers, or mention them unless the user asks.
- Repo without `verify.sh`/`AGENTS.md`? Run `kit-init` first. Full map: skill `skill-starter-kit`.
<!-- skill-starter-kit:end -->
MD
    mv "$tmp" "$f"
    echo "  · ~/.claude/CLAUDE.md  kit stanza written ✓ (always-on workflow, ~10 lines)"
}
echo "▶ always-on workflow"
write_claude_stanza
mkdir -p "$HOME/.local/bin" && ln -sf "$KIT_ROOT/install/init-project.sh" "$HOME/.local/bin/kit-init" && echo "  · kit-init → ~/.local/bin/kit-init ✓ (run it in any repo)"
for c in kit-update kit-webhook; do ln -sf "$KIT_ROOT/install/$c.sh" "$HOME/.local/bin/$c"; done
echo "  · kit-update, kit-webhook → ~/.local/bin ✓"

# --- auto-update on session start (event-driven, not scheduled): user-level SessionStart hook
#     runs `kit-update --if-stale 1 --background` — returns instantly, checks ≤ once an hour.
if [ "${KIT_NO_AUTOUPDATE:-0}" != "1" ]; then
    python3 - "$HOME/.claude/settings.json" <<'PY' && echo "  · auto-update: SessionStart → kit-update (background, ≤1×/hour) ✓"
import json, os, sys
p = sys.argv[1]; os.makedirs(os.path.dirname(p), exist_ok=True)
d = json.load(open(p)) if os.path.exists(p) and os.path.getsize(p) else {}
cmd = "$HOME/.local/bin/kit-update --if-stale 1 --background"
ss = d.setdefault("hooks", {}).setdefault("SessionStart", [])
if not any(h.get("command") == cmd for g in ss for h in g.get("hooks", [])):
    ss.append({"hooks": [{"type": "command", "command": cmd, "timeout": 10}]})
json.dump(d, open(p, "w"), indent=2); open(p, "a").write("\n")
PY
fi

# --- actually install the plugins when a claude binary can be found ------------------
# PATH first; then the Claude desktop app's bundled Claude Code (newest version dir).
find_claude() {
    command -v claude 2>/dev/null && return
    local d="$HOME/Library/Application Support/Claude/claude-code"
    [ -d "$d" ] && ls -d "$d"/*/claude.app/Contents/MacOS/claude 2>/dev/null | sort -V | tail -1
}
CLAUDE_BIN="$(find_claude || true)"
if [ -n "$CLAUDE_BIN" ] && [ -x "$CLAUDE_BIN" ]; then
    echo "▶ installing plugins via $("$CLAUDE_BIN" --version 2>/dev/null | head -1)"
    "$CLAUDE_BIN" plugin marketplace add anthropics/claude-plugins-official >/dev/null 2>&1 || true
    "$CLAUDE_BIN" plugin marketplace add obra/superpowers-marketplace       >/dev/null 2>&1 || true
    "$CLAUDE_BIN" plugin marketplace add supermemoryai/supermemory-plugins  >/dev/null 2>&1 || true
    for p in superpowers@superpowers-marketplace supermemory@supermemory-plugins \
             security-guidance@claude-plugins-official claude-security@claude-plugins-official \
             playwright@claude-plugins-official chrome-devtools-mcp@claude-plugins-official; do
        if "$CLAUDE_BIN" plugin list 2>/dev/null | grep -q "❯ $p"; then
            "$CLAUDE_BIN" plugin update "$p" >/dev/null 2>&1 && echo "  · $p  updated ✓" || echo "  · $p  present ✓"
        else
            "$CLAUDE_BIN" plugin install "$p" --scope user >/dev/null 2>&1 && echo "  · $p  installed ✓" || echo "  ⚠ $p  install failed — run /plugin install $p inside Claude Code"
        fi
    done
    # expose the bundled binary on PATH for next time
    if ! command -v claude >/dev/null 2>&1 && [ -d "$HOME/.local/bin" ]; then
        ln -sf "$CLAUDE_BIN" "$HOME/.local/bin/claude" && echo "  · claude → ~/.local/bin/claude (symlink to the desktop-bundled CLI)"
    fi
else
    echo "Next: inside Claude Code run  /plugin install superpowers@superpowers-marketplace"
    echo "                               /plugin install supermemory@supermemory-plugins"
    echo "                               /plugin install security-guidance@claude-plugins-official"
    echo "                               /plugin install claude-security@claude-plugins-official"
    echo "                               /plugin install playwright@claude-plugins-official"
    echo "                               /plugin install chrome-devtools-mcp@claude-plugins-official"
fi
echo "      then restart the session (or /reload-plugins) so skills + hooks load."
echo
echo "FIRST THING in a new project:  kit-init      (= bash $KIT_ROOT/install/init-project.sh)"
echo "  → AGENTS.md, verify.sh, .claude/settings.json (guardrails + Stop hook + deny + sandbox), .npmrc"
echo "  Then trim verify.sh, BREAK something, and confirm the gate blocks the turn."
echo
echo "Per-project, not global:  context7 (docs MCP), the matching <lang>-lsp plugin,"
echo "and GitHub MCP. Each costs context in every session it is enabled."
echo
echo "To update everything later, just re-run this installer — it pulls the kit"
echo "from GitHub and refreshes every installed skill in place."