#!/usr/bin/env bash
# =============================================================================
# Skill Starter Kit — FIRST THING in a new project.
#   bash ~/skill-starter-kit/install/init-project.sh [target-dir]
#
# Lays down, in this order of loop-closing value. Never overwrites a file you wrote —
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
KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
put "$KIT_ROOT/skills/verify-gate/templates/verify.sh" verify.sh; chmod +x "$DEST/verify.sh"
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
