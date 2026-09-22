#!/usr/bin/env bash
# =============================================================================
# Skill Starter Kit — HERMES installer
#
# Installs the kit's portable skills as HERMES skills (instead of Claude Code).
# Usage:  bash install/hermes.sh
#
# Components installed into ~/.hermes/skills/:
#   1. Graphify (on-demand orientation)  2. (Superpowers = Claude Code plugin only, skipped)
#   3. Supermemory (local server still installable — see note)  4. Taste
#   5. LSP Plugins       skill (copied) — installs LSP per stack at runtime
#   6. GitHub MCP        skill (copied) — official github/github-mcp-server via gh
#   7. Caveman           skills (caveman*) — OPT-IN summary compression, not auto-triggered
#   8. Security Gate     skill (copied) — Anthropic's security plugins are Claude Code only;
#      the gitleaks + osv-scanner layers work anywhere
#   9. Verify Gate       skill (copied) — the pass/fail completion gate (portable)
#  10. Browser Verify    skill (copied) — Playwright/DevTools MCP as plain MCP servers
#  11. Docs Freshness    skill (copied) — --help/llms.txt ladder; context7 optional
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
for skill in graphify taste-skill taste-code caveman caveman-commit caveman-compress caveman-help caveman-review caveman-stats lsp-plugins github-mcp security-gate verify-gate browser-verify docs-freshness; do
    sync_skill "$KIT_SKILLS_SRC/$skill" "$HERMES_SKILLS_DIR/$CATEGORY/$skill"
done

# --- recall skill: always rewritten so it tracks the current kit
RECALL_DST="$HERMES_SKILLS_DIR/$CATEGORY/skill-starter-kit"
mkdir -p "$RECALL_DST"
cat > "$RECALL_DST/SKILL.md" <<'MD'
---
name: skill-starter-kit
description: "Set up a fresh device with the 11-component Claude Code / Hermes starter kit."
---

# Skill Starter Kit (recall)

Recalled when the user asks to set up a new device, reproduce their environment,
"install the kit/skills", or rebuild the starter kit.

## Source
- GitHub: https://github.com/feelthefusion/skill-starter-kit (public)
- Installer: `install/install.sh` (Claude Code) · `install/hermes.sh` (Hermes)

## The 11 components
1. Graphify — on-demand orientation for a large unfamiliar repo (`/graphify`). NOT the default
   retrieval path; LSP + grep are.
2. Superpowers — Claude Code plugin (obra/superpowers-marketplace) — *Claude Code only*;
   bundles systematic-debugging + TDD + code-review + worktrees. Never add standalone versions.
3. Supermemory — plugin + LOCAL self-hosted server on :6767
4. Taste-Skill — `taste-code` (judgement rules + spike rule; mechanizable rules belong in a
   hook) + `taste-skill` (anti-slop frontend)
5. LSP Plugins — official Anthropic LSP plugins, 13 languages. Install per-stack only.
6. GitHub MCP — official github/github-mcp-server. Read-only by default; `gh` CLI is cheaper.
7. Caveman — OPT-IN compression of final summaries only. Never the reasoning path, never
   verification output.
8. Security Gate — security-guidance + claude-security (Claude Code) + gitleaks (secrets) +
   osv-scanner (dependency tree / slopsquatting)
9. **Verify Gate** — one `verify` command + Stop hook + evidence discipline. The only component
   that blocks a false "done". Set this up FIRST in a new project.
10. **Browser Verify** — Playwright + Chrome DevTools MCP: screenshot-compare loop, smoke E2E,
    console/network debugging. Closes the frontend loop.
11. **Docs Freshness** — `--help`/installed-source/llms.txt/Context7 ladder + verify a package
    exists before installing a name the model produced from memory.

On Hermes, the portable skills (1, 4, 5, 6, 7, 8, 9, 10, 11) install directly here.
Component 2 is a Claude Code plugin; 3's local server installs separately; the Anthropic
plugins in 8/10/11 are Claude Code only — the CLI layers (gitleaks, osv-scanner, npx
@playwright/mcp, npx chrome-devtools-mcp) work anywhere.

## Rejected on purpose (do not re-add)
Serena (duplicates LSP + Graphify), spec-kit / OpenSpec / BMAD (duplicate Superpowers'
workflow), tdd-guard (duplicates bundled TDD), repomix / code2prompt (worse than LSP per
token), a second memory layer (conflicts with Supermemory), a second docs MCP (Context7 is
enough).

## Staying current
Both installers `git pull` the repo before copying and REFRESH already-installed skills in
place. To update this machine, re-run the installer:
```bash
bash ~/skill-starter-kit/install/hermes.sh     # or install/install.sh for Claude Code
```
Installed revision is recorded in `.kit-version` next to the installed skills.
MD
echo "  · skill-starter-kit (recall)  written ✓"
write_kit_version "$KIT_ROOT" "$HERMES_SKILLS_DIR/$CATEGORY"

# --- 8/9: portable CLI layers (work on any host, no plugins needed) ----------
echo "▶ portable security + verify CLI layers"
for tool in gitleaks osv-scanner; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "  · $tool present ✓"
    elif command -v brew >/dev/null 2>&1; then
        brew install "$tool" >/dev/null 2>&1 \
            && echo "  · $tool installed ✓" \
            || echo "  ⚠ brew install $tool failed — install manually"
    else
        echo "  ⚠ $tool missing and no brew — install manually"
    fi
done

# --- 7: GitHub MCP — check gh auth -------------------------------------------
echo "▶ GitHub MCP — checking gh auth"
if command -v gh >/dev/null 2>&1; then
    gh auth status >/dev/null 2>&1 && echo "  · gh authenticated ✓" || echo "  · gh present but NOT authenticated — run: gh auth login"
else
    echo "  ⚠ gh CLI not installed — install via brew to get GitHub MCP PR/issue tools"
fi

echo
echo "─── done ───────────────────────────────────────────────"
echo "Installed skills: $(ls "$HERMES_SKILLS_DIR/$CATEGORY" | tr '\n' ' ')"
echo "A NEW Hermes session is required for the skills to appear (skill index loads at session start)."
echo "Then say:  'set up the skill starter kit' / 'recall the kit'."
echo
echo "To update later, just re-run this installer — it pulls the kit from GitHub"
echo "and refreshes every installed skill in place."