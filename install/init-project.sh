#!/usr/bin/env bash
# =============================================================================
# Skill Starter Kit — FIRST THING in a new project.
#   bash ~/skill-starter-kit/install/init-project.sh [target-dir]
#
# Lays down, in this order of loop-closing value (never overwrites existing files):
#   1. AGENTS.md (+ CLAUDE.md pointer)     — project instructions the agent can't infer
#   2. verify.sh                            — verify-gate: the pass/fail completion gate
#   3. .claude/settings.json + hooks/       — guardrails (block/format) + Stop hook + deny + sandbox
#   4. .npmrc / pnpm-workspace.yaml / .yarnrc.yml / bunfig.toml — security-gate layer 5: install hygiene
#   5. .gitleaksignore                      — security-gate layer 3 convention
# Then prints the Hermes equivalents.
# =============================================================================
set -euo pipefail
KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$(cd "${1:-.}" && pwd)"
T="$KIT_ROOT/templates/project"

put() {  # put <src> <dst-relative>
    if [ -e "$DEST/$2" ]; then echo "  · $2  exists — kept"; else
        mkdir -p "$(dirname "$DEST/$2")"; cp "$1" "$DEST/$2"; echo "  · $2  created ✓"; fi
}

echo "── Skill Starter Kit · init project: $DEST ──────────────"
echo "▶ 1. project instructions"
put "$T/AGENTS.md" AGENTS.md
put "$T/CLAUDE.md" CLAUDE.md
echo "▶ 2. verify gate"
put "$KIT_ROOT/skills/verify-gate/templates/verify.sh" verify.sh; chmod +x "$DEST/verify.sh"
echo "▶ 3. guardrails + hooks"
put "$KIT_ROOT/skills/guardrails/templates/guard.sh"  .claude/hooks/guard.sh
put "$KIT_ROOT/skills/guardrails/templates/format.sh" .claude/hooks/format.sh
chmod +x "$DEST"/.claude/hooks/*.sh
put "$KIT_ROOT/skills/guardrails/templates/claude-settings.json" .claude/settings.json
echo "▶ 4. install hygiene"
if [ -f "$DEST/pnpm-lock.yaml" ]; then put "$T/pnpm-workspace.yaml" pnpm-workspace.yaml; fi
if [ -f "$DEST/yarn.lock" ]; then put "$T/.yarnrc.yml" .yarnrc.yml; fi
if [ -f "$DEST/bun.lock" ] || [ -f "$DEST/bun.lockb" ]; then put "$T/bunfig.toml" bunfig.toml; fi
if [ -f "$DEST/package.json" ] || [ ! -f "$DEST/pnpm-lock.yaml" ]; then put "$T/.npmrc" .npmrc; fi
echo "▶ 5. secrets"
put "$T/.gitleaksignore" .gitleaksignore

cat <<'TXT'

Next:
  • Edit AGENTS.md — fill the <placeholders>, delete bullets that don't apply, stay ≤12 lines.
  • Edit verify.sh — delete steps your stack doesn't have. Then BREAK something and confirm
    the Stop hook blocks the turn (an untested gate is no gate).
  • Add your stack's irreversibles to .claude/hooks/guard.sh (terraform destroy, migrate reset…).
  • Commit all of it: a fresh clone must inherit the gates.

Hermes users (same scripts, native hooks):
  mkdir -p ~/.hermes/agent-hooks && cp .claude/hooks/*.sh ~/.hermes/agent-hooks/
  cp <kit>/skills/guardrails/templates/verify-nudge.sh ~/.hermes/agent-hooks/
  # then apply skills/guardrails/templates/hermes-hooks.yaml via `hermes config set`
  # per-task alternative: /goal gate add "./verify.sh"
TXT
