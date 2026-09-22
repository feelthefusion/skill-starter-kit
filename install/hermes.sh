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
#
# Idempotent: re-run safe.
# =============================================================================
set -euo pipefail

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KIT_SKILLS_SRC="$KIT_ROOT/skills"
HERMES_SKILLS_DIR="${HERMES_SKILLS_DIR:-$HOME/.hermes/skills}"
CATEGORY="${HERMES_CATEGORY:-autonomous-ai-agents}"

echo "── Skill Starter Kit · HERMES install ───────────────────"
echo "  kit skills src : $KIT_SKILLS_SRC"
echo "  install target : $HERMES_SKILLS_DIR/$CATEGORY"
echo

mkdir -p "$HERMES_SKILLS_DIR/$CATEGORY"

# --- portable skills: graphify, taste-skill, taste-code, lsp-plugins, github-mcp
#     (Superpowers is a Claude Code plugin marketplace -> no Hermes equivalent here.)
for skill in graphify taste-skill taste-code lsp-plugins github-mcp; do
    if [ -d "$HERMES_SKILLS_DIR/$CATEGORY/$skill" ]; then
        echo "  · $skill  already installed — skipping"
    elif [ -d "$KIT_SKILLS_SRC/$skill" ]; then
        cp -R "$KIT_SKILLS_SRC/$skill" "$HERMES_SKILLS_DIR/$CATEGORY/"
        echo "  · $skill  installed ✓"
    else
        echo "  · $skill  not found in kit — skipped"
    fi
done

# --- recall skill: install the kit's own SKILL.md as 'skill-starter-kit'
RECALL_DST="$HERMES_SKILLS_DIR/$CATEGORY/skill-starter-kit"
if [ -d "$RECALL_DST" ]; then
    echo "  · skill-starter-kit (recall)  already installed — skipping"
else
    mkdir -p "$RECALL_DST"
    # Write a Hermes-flavoured recall skill (short description for the index)
    cat > "$RECALL_DST/SKILL.md" <<'MD'
---
name: skill-starter-kit
description: "Set up a fresh device with the 7-skill Claude Code kit."
---

# Skill Starter Kit (recall)

Recalled when the user asks to set up a new device, reproduce their environment,
"install the kit/skills", or rebuild the 7-skill starter kit.

## Source
- GitHub: https://github.com/feelthefusion/skill-starter-kit (public)
- Installer: `install/install.sh` (Claude Code) · `install/hermes.sh` (Hermes)

## The 7 components
1. Graphify — codebase → knowledge graph (`/graphify`)
2. Superpowers — Claude Code plugin (obra/superpowers-marketplace) — *Claude Code only*
3. Supermemory — plugin + LOCAL self-hosted server on :6767
4. Taste-Skill — `taste-code` (10-rule minimalist harness) + `taste-skill` (anti-slop frontend)
5. LSP Plugins — per-stack language server
6. GitHub MCP — official github/github-mcp-server (issues/PRs/branches)

On Hermes, the portable skills (1,4,5,6) install directly here. Components 2
(Superpowers) is a Claude Code plugin; 3's local server can be installed separately.
MD
    echo "  · skill-starter-kit (recall)  installed ✓"
fi

# --- 7: GitHub MCP — check gh auth -------------------------------------------
echo "▶ GitHub MCP — checking gh auth"
if command -v gh >/dev/null 2>&1; then
    gh auth status >/dev/null 2>&1 && echo "  · gh authenticated ✓" || echo "  · gh present but NOT authenticated — run: gh auth login"
else
    echo "  ⚠ gh CLI not installed — install via brew to get GitHub MCP PR/issue tools"
fi

echo
echo "─── done ───────────────────────────────────────────────"
echo "Installed skills: $(ls "$HERMES_SKILLS_DIR/$CATEGORY" | grep -E 'graphify|taste-skill|taste-code|lsp-plugins|github-mcp|skill-starter-kit' | tr '\n' ' ')"
echo "A NEW Hermes session is required for the skills to appear (skill index loads at session start)."
echo "Then say:  'set up the skill starter kit' / 'recall the kit'."