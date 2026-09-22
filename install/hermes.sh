#!/usr/bin/env bash
# =============================================================================
# Skill Starter Kit — HERMES installer
#
# Installs the kit's portable skills as HERMES skills (instead of Claude Code).
# Usage:  bash install/hermes.sh
#
# Components installed into ~/.hermes/skills/:
#   1. Graphify  2. (Superpowers = Claude Code plugin only, skipped on Hermes)
#   3. Supermemory (local server still installable — see note)  4. Taste
#   5. LSP Plugins       skill (copied) — installs LSP per stack at runtime
#   6. GitHub MCP        skill (copied) — official github/github-mcp-server via gh
#   7. Caveman           skills (caveman*) — response-compression layer
#   8. Security Gate     skill (copied) — official Anthropic security plugins are Claude Code only;
#      the skill documents the gitleaks pre-commit layer usable anywhere
#
# LIVE BY DESIGN: pulls the kit from GitHub before installing, and REFRESHES
# already-installed skills instead of skipping them. Re-run it any time to update.
# Env: KIT_NO_PULL=1 to install the local copy without pulling.
# =============================================================================
set -euo pipefail

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=install/lib.sh
source "$KIT_ROOT/install/lib.sh"
KIT_SKILLS_SRC="$KIT_ROOT/skills"
HERMES_SKILLS_DIR="${HERMES_SKILLS_DIR:-$HOME/.hermes/skills}"
CATEGORY="${HERMES_CATEGORY:-autonomous-ai-agents}"

echo "── Skill Starter Kit · HERMES install ───────────────────"
echo "  kit skills src : $KIT_SKILLS_SRC"
echo "  install target : $HERMES_SKILLS_DIR/$CATEGORY"
echo

# --- 0: pull the latest kit before installing anything ----------------------
kit_self_update "$KIT_ROOT"
echo

mkdir -p "$HERMES_SKILLS_DIR/$CATEGORY"

# --- portable skills (Superpowers is a Claude Code plugin -> no Hermes equivalent)
for skill in graphify taste-skill taste-code caveman caveman-commit caveman-compress caveman-help caveman-review caveman-stats lsp-plugins github-mcp security-gate; do
    sync_skill "$KIT_SKILLS_SRC/$skill" "$HERMES_SKILLS_DIR/$CATEGORY/$skill"
done

# --- recall skill: always rewritten so it tracks the current kit
RECALL_DST="$HERMES_SKILLS_DIR/$CATEGORY/skill-starter-kit"
mkdir -p "$RECALL_DST"
cat > "$RECALL_DST/SKILL.md" <<'MD'
---
name: skill-starter-kit
description: "Set up a fresh device with the 8-skill Claude Code kit."
---

# Skill Starter Kit (recall)

Recalled when the user asks to set up a new device, reproduce their environment,
"install the kit/skills", or rebuild the 8-skill starter kit.

## Source
- GitHub: https://github.com/feelthefusion/skill-starter-kit (public)
- Installer: `install/install.sh` (Claude Code) · `install/hermes.sh` (Hermes)

## The 8 components
1. Graphify — codebase → knowledge graph (`/graphify`)
2. Superpowers — Claude Code plugin (obra/superpowers-marketplace) — *Claude Code only*; bundles systematic-debugging + TDD skills
3. Supermemory — plugin + LOCAL self-hosted server on :6767
4. Taste-Skill — `taste-code` (10-rule minimalist harness + spike rule) + `taste-skill` (anti-slop frontend)
5. LSP Plugins — official Anthropic LSP plugins (Claude Code) or per-stack server binaries
6. GitHub MCP — official github/github-mcp-server (issues/PRs/branches)
7. Caveman — ultra-compressed response mode (`/caveman`, `/caveman-commit`, `/caveman-review`, `/caveman-compress`, `/caveman-help`, `/caveman-stats`)
8. Security Gate — official Anthropic plugins (security-guidance + claude-security) + optional gitleaks pre-commit

On Hermes, the portable skills (1,4,5,6,7,8) install directly here. Component 2
(Superpowers) is a Claude Code plugin; 3's local server can be installed separately;
8's plugins are Claude Code only (the gitleaks layer works anywhere).

## Staying current
The kit is live: both installers `git pull` the repo before copying and REFRESH
already-installed skills in place. To update this machine, re-run the installer:
```bash
bash ~/skill-starter-kit/install/hermes.sh     # or install/install.sh for Claude Code
```
Installed revision is recorded in `.kit-version` next to the installed skills.
MD
echo "  · skill-starter-kit (recall)  written ✓"
write_kit_version "$KIT_ROOT" "$HERMES_SKILLS_DIR/$CATEGORY"

# --- 7: GitHub MCP — check gh auth -------------------------------------------
echo "▶ GitHub MCP — checking gh auth"
if command -v gh >/dev/null 2>&1; then
    gh auth status >/dev/null 2>&1 && echo "  · gh authenticated ✓" || echo "  · gh present but NOT authenticated — run: gh auth login"
else
    echo "  ⚠ gh CLI not installed — install via brew to get GitHub MCP PR/issue tools"
fi

echo
echo "─── done ───────────────────────────────────────────────"
echo "Installed skills: $(ls "$HERMES_SKILLS_DIR/$CATEGORY" | grep -E 'graphify|taste-skill|taste-code|caveman|lsp-plugins|github-mcp|security-gate|skill-starter-kit' | tr '\n' ' ')"
echo "A NEW Hermes session is required for the skills to appear (skill index loads at session start)."
echo "Then say:  'set up the skill starter kit' / 'recall the kit'."
echo
echo "To update later, just re-run this installer — it pulls the kit from GitHub"
echo "and refreshes every installed skill in place."