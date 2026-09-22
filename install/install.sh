#!/usr/bin/env bash
# =============================================================================
# New Project Skill Starter Kit — installer for a fresh Claude Code device
# Usage:  bash install.sh   (or run from inside Claude Code via `/install`)
#
# Installs / wires all 7 kit components onto this machine:
#   1. Graphify          skill (copied)
#   2. Superpowers       plugin (obra/superpowers-marketplace)
#   3. Supermemory       plugin + LOCAL self-hosted server (supermemoryai/claude-supermemory)
#   4. Taste-Skill       skills (taste-code + taste-skill)  [copied]
#   5. LSP Plugins       skill (copied) — installs LSP per stack at runtime
#   6. GitHub MCP        skill (copied) — official github/github-mcp-server (issues/PRs/branches)
#   +  Caveman           skills (caveman*) — response-compression layer
#
# Idempotent: safe to re-run; will not clobber existing files.
# =============================================================================
set -euo pipefail

KIT_SKILLS_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/skills"
CLAUDE_SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

echo "── New Project Skill Starter Kit ─────────────────────────"

# --- Common prereqs ---------------------------------------------------------
echo "▶ checking prereqs …"
command -v node >/dev/null 2>&1 || { echo "✗ node missing (required by Claude Code + Supermemory)"; exit 1; }
echo "✓ node $(node --version)"

# --- 1,4,5,6,7: skills are copied into ~/.claude/skills --------------------
echo "▶ installing skills into $CLAUDE_SKILLS_DIR"
mkdir -p "$CLAUDE_SKILLS_DIR"
for skill in graphify taste-skill taste-code caveman caveman-commit caveman-compress caveman-help caveman-review caveman-stats lsp-plugins github-mcp; do
    if [ -d "$CLAUDE_SKILLS_DIR/$skill" ]; then
        echo "  · $skill already present — skipping"
    elif [ -d "$KIT_SKILLS_SRC/$skill" ]; then
        cp -R "$KIT_SKILLS_SRC/$skill" "$CLAUDE_SKILLS_DIR/"
        echo "  · $skill installed ✓"
    else
        echo "  · $skill not found in kit (source missing) — skipped"
    fi
done

# --- 2: Superpowers plugin ---------------------------------------------------
# Plugin marketplaces are added inside Claude Code with /plugin, but we can
# pre-register the marketplace in settings.json so /plugin just works.
echo "▶ configuring Superpowers plugin (obra/superpowers-marketplace)"
if command -v jq >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
    python3 - "$CLAUDE_SETTINGS" <<'PY'
import json, sys, os
p = sys.argv[1]
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

# 3b. install local server binary (self-contained, no Docker)
echo "▶ installing supermemory local server"
if [ -x "$HOME/.local/bin/supermemory-server" ]; then
    echo "  · supermemory-server already present — skipping"
else
    echo "  · downloading installer …"
    curl -fsSL https://supermemory.ai/install | bash || {
        echo "  ⚠ installer failed (network?) — re-run later or install from https://supermemory.ai/install"
    }
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
echo "Next: inside Claude Code run  /plugin install superpowers@superpowers-marketplace"
echo "                               /plugin install supermemory@supermemory-plugins"
echo "      then restart the session so skills + hooks load."