#!/usr/bin/env bash
# =============================================================================
# Skill Starter Kit — HERMES installer
#
# Installs the kit's portable skills as HERMES skills. Usage:  bash install/hermes.sh
#
# Components installed into ~/.hermes/skills/<category>/:
#   0. AGENTS.md template  (per repo — install/init-project.sh)
#   1. Graphify            fetched from Graphify-Labs/graphify (on-demand orientation)
#   2. Superpowers         NATIVE Hermes plugin: `hermes plugins install obra/superpowers --enable`
#   3. Supermemory         native Hermes memory provider (`memory.provider: supermemory`)
#   4. Taste               taste-code (kit) + taste-skill (fetched from Leonxlnx/taste-skill)
#   5. LSP Plugins         skill — manual LSP path on Hermes
#   6. GitHub MCP          skill — official server via mcp_servers: / gh CLI
#   7. Caveman             caveman + caveman-commit (fetched from JuliusBrussee/caveman) — OPT-IN
#   8. Security Gate       skill + gitleaks + osv-scanner (+ zizmor via uvx) — CLI layers work anywhere
#   9. Verify Gate         skill — pre_verify hook / `/goal gate add` on Hermes
#  10. Browser Verify      skill — Playwright/DevTools MCP as mcp_servers: entries
#  11. Docs Freshness      skill — --help/llms.txt ladder; context7 optional
#  12. Guardrails          skill + hook scripts (pre_tool_call block, post_tool_call format)
#
# LIVE BY DESIGN: pulls the kit from GitHub, FETCHES third-party skills from their upstream
# repos, re-applies kit overlays, and REFRESHES installed skills in place. Re-run to update.
# Env: KIT_NO_PULL=1 (skip kit pull) · KIT_NO_UPSTREAM=1 (skip upstream fetch, use vendored)
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
kit_fetch_upstreams "$KIT_ROOT"
echo

mkdir -p "$HERMES_SKILLS_DIR/$CATEGORY"

# --- portable skills (upstream-fetched copy when available, vendored otherwise)
KIT_SKILLS="graphify taste-skill taste-code caveman caveman-commit lsp-plugins github-mcp security-gate verify-gate browser-verify docs-freshness guardrails"
for skill in $KIT_SKILLS; do
    sync_skill "$(skill_src "$KIT_ROOT" "$skill")" "$HERMES_SKILLS_DIR/$CATEGORY/$skill"
done
# skills removed from the kit are removed from the install too
for stale in caveman-compress caveman-help caveman-review caveman-stats; do
    [ -d "$HERMES_SKILLS_DIR/$CATEGORY/$stale" ] && rm -rf "$HERMES_SKILLS_DIR/$CATEGORY/$stale" && echo "  · $stale  removed (dropped from kit v3)"
done

# --- recall skill: the repo-root SKILL.md is the single source of truth ------------
RECALL_DST="$HERMES_SKILLS_DIR/$CATEGORY/skill-starter-kit"
mkdir -p "$RECALL_DST"
cp "$KIT_ROOT/SKILL.md" "$RECALL_DST/SKILL.md"
echo "  · skill-starter-kit (recall + workflow map)  written ✓"
write_kit_version "$KIT_ROOT" "$HERMES_SKILLS_DIR/$CATEGORY"

# --- 8/9/12: portable CLI layers (work on any host, no plugins needed) -------
echo "▶ portable security + verify CLI layers"
for tool in gitleaks osv-scanner uv; do
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
# --- 2: Superpowers — native Hermes plugin (optional; or use Hermes' bundled skills) ------
echo "▶ Superpowers on Hermes"
if command -v hermes >/dev/null 2>&1; then
    if hermes plugins list 2>/dev/null | grep -qi superpowers; then
        echo "  · superpowers plugin already installed ✓"
    else
        echo "  · to install:  hermes plugins install obra/superpowers --enable"
        echo "    (or rely on Hermes' bundled systematic-debugging / TDD / requesting-code-review / plan"
        echo "     / spike / simplify-code — one or the other, never both)"
    fi
else
    echo "  · hermes CLI not on PATH — install Superpowers later: hermes plugins install obra/superpowers --enable"
fi

# --- 12: Guardrails hook scripts → ~/.hermes/agent-hooks (config applied by you) ---------
HOOKS_DIR="${HERMES_HOME:-$HOME/.hermes}/agent-hooks"
mkdir -p "$HOOKS_DIR"
for s in guard.sh format.sh verify-nudge.sh; do
    cp "$KIT_SKILLS_SRC/guardrails/templates/$s" "$HOOKS_DIR/$s" && chmod +x "$HOOKS_DIR/$s"
done
echo "▶ guardrails hook scripts → $HOOKS_DIR ✓"
echo "  · wire them with the hooks: block in skills/guardrails/templates/hermes-hooks.yaml"
echo "    (apply via \`hermes config set\`; consent prompt on first use is expected)"

echo
echo "─── done ───────────────────────────────────────────────"
echo "Installed skills: $(ls "$HERMES_SKILLS_DIR/$CATEGORY" | tr '\n' ' ')"
echo "A NEW Hermes session is required for the skills to appear (skill index loads at session start)."
echo "Then say:  'set up the skill starter kit' / 'recall the kit'."
echo "In each repo:  bash $KIT_ROOT/install/init-project.sh   (AGENTS.md, verify.sh, hooks, .npmrc)"
echo
echo "To update later, just re-run this installer — it pulls the kit from GitHub"
echo "and refreshes every installed skill in place."