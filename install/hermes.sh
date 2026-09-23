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
# Env: KIT_NO_PULL=1 (skip kit pull) · KIT_NO_UPSTREAM=1 (skip upstream fetch, use last fetched) · KIT_NO_AUTOUPDATE=1 (no session-start update check)
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

# --- portable skills (third-party ones fetched fresh from upstream)
KIT_SKILLS="graphify taste-skill taste-code caveman caveman-commit lsp-plugins github-mcp security-gate verify-gate browser-verify docs-freshness guardrails consistency"
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
    ensure_cli_tool "$tool"
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
        echo "  · not installed. Hermes already bundles the equivalent skills (systematic-debugging, TDD,"
        echo "    requesting-code-review, plan, spike, simplify-code) — that is the kit default on Hermes."
        echo "    To use Superpowers instead:  hermes plugins install obra/superpowers --enable"
        echo "    (Hermes' plugin scanner flags its test scripts; add --force if you accept that. One or the other, never both.)"
    fi
else
    echo "  · hermes CLI not on PATH — install Superpowers later: hermes plugins install obra/superpowers --enable"
fi

# --- 3: Supermemory as the Hermes memory provider (automatic when the local server is up) ---
echo "▶ Supermemory memory provider"
SM_URL="${SUPERMEMORY_API_URL:-http://localhost:6767}"
SM_KEY_FILE="$HOME/.supermemory/api-key"
HH="${HERMES_HOME:-$HOME/.hermes}"
if command -v hermes >/dev/null 2>&1 && curl -fsS -m 3 -o /dev/null "$SM_URL/" 2>/dev/null && [ -s "$SM_KEY_FILE" ]; then
    HPY="$(dirname "$(readlink -f "$(command -v hermes)")")/python"
    [ -x "$HPY" ] || HPY="$HH/hermes-agent/venv/bin/python"
    if [ -x "$HPY" ] && ! "$HPY" -c 'import supermemory' >/dev/null 2>&1; then
        "$HPY" -m pip install -q supermemory >/dev/null 2>&1 || uv pip install -q --python "$HPY" supermemory >/dev/null 2>&1 || true
    fi
    [ -f "$HH/supermemory.json" ] || printf '{\n  "base_url": "%s"\n}\n' "$SM_URL" > "$HH/supermemory.json"
    touch "$HH/.env"; chmod 600 "$HH/.env"
    grep -q '^SUPERMEMORY_API_KEY=' "$HH/.env" || printf 'SUPERMEMORY_API_KEY=%s\n' "$(cat "$SM_KEY_FILE")" >> "$HH/.env"
    if [ "$(hermes config get memory.provider 2>/dev/null)" != "supermemory" ]; then
        hermes config set memory.provider supermemory >/dev/null 2>&1 && echo "  · memory.provider = supermemory (local server $SM_URL) ✓" \
            || echo "  ⚠ could not set memory.provider — run: hermes config set memory.provider supermemory"
    else
        echo "  · memory.provider already supermemory ✓"
    fi
else
    echo "  · local Supermemory server not detected (needs $SM_URL up + $SM_KEY_FILE) — built-in memory stays active."
    echo "    Install the server with the Claude Code installer or the supermemory-local skill, then re-run."
fi

# --- 12: Guardrails hook scripts → ~/.hermes/agent-hooks, wired into config.yaml -----------
HOOKS_DIR="${HERMES_HOME:-$HOME/.hermes}/agent-hooks"
mkdir -p "$HOOKS_DIR"
for s in guard.sh format.sh verify-nudge.sh; do
    cp "$KIT_SKILLS_SRC/guardrails/templates/$s" "$HOOKS_DIR/$s" && chmod +x "$HOOKS_DIR/$s"
done
echo "▶ guardrails hook scripts → $HOOKS_DIR ✓"
if [ "${KIT_NO_HOOKS:-0}" != "1" ] && command -v hermes >/dev/null 2>&1; then
    # same contract as skills/guardrails/templates/hermes-hooks.yaml, written with `hermes config set`
    # (never hand-edit config.yaml). Existing hooks are preserved: we only add ours if absent.
    KIT_HOOKS_JSON='{"pre_tool_call":[{"matcher":"terminal","command":"~/.hermes/agent-hooks/guard.sh","timeout":5,"fail_closed":true}],"post_tool_call":[{"matcher":"write_file|patch","command":"~/.hermes/agent-hooks/format.sh","timeout":30}],"pre_verify":[{"command":"~/.hermes/agent-hooks/verify-nudge.sh","timeout":180}],"on_session_start":[{"command":"~/.local/bin/kit-update --if-stale 1 --background","timeout":10}]}'
    [ "${KIT_NO_AUTOUPDATE:-0}" = "1" ] && KIT_HOOKS_JSON="$(printf '%s' "$KIT_HOOKS_JSON" | python3 -c 'import json,sys; d=json.load(sys.stdin); d.pop("on_session_start",None); print(json.dumps(d))')"
    if [ "$(hermes config get --json hooks 2>/dev/null | python3 -c '
import json,sys
cur=json.load(sys.stdin) or {}; kit=json.loads(sys.argv[1])
print(all(any(isinstance(x,dict) and x.get("command")==e["command"] for x in (cur.get(ev) or [])) for ev,es in kit.items() for e in es))' "$KIT_HOOKS_JSON" 2>/dev/null)" = "True" ]; then
        echo "  · hermes hooks already wired ✓"
    else
        # merge: keep every existing hook, append ours per event (JSON in, JSON out)
        MERGED="$(hermes config get --json hooks 2>/dev/null | python3 -c '
import json, sys
cur = json.load(sys.stdin) or {}
if not isinstance(cur, dict): cur = {}
kit = json.loads(sys.argv[1])
for ev, entries in kit.items():
    have = cur.get(ev) or []
    for e in entries:
        if not any(x.get("command") == e["command"] for x in have if isinstance(x, dict)):
            have.append(e)
    cur[ev] = have
print(json.dumps(cur))' "$KIT_HOOKS_JSON" 2>/dev/null || echo "$KIT_HOOKS_JSON")"
        # one key per event (`hooks.<event>`): replacing the whole section needs --force and
        # would touch events the kit doesn't own
        printf '%s' "$MERGED" | python3 -c '
import json, sys
for ev, entries in json.load(sys.stdin).items(): print(ev + "\t" + json.dumps(entries))' \
        | { ok=1; while IFS=$'\t' read -r ev val; do hermes config set "hooks.$ev" "$val" >/dev/null 2>&1 || ok=0; done; [ "$ok" = 1 ]; } && echo "  · hermes hooks wired (guard, format, pre_verify, on_session_start auto-update; existing hooks kept) ✓" \
            || echo "  ⚠ hermes config set hooks failed — apply skills/guardrails/templates/hermes-hooks.yaml manually"
        hermes config set hooks_auto_accept false >/dev/null 2>&1 || true
    fi
    echo "    (first run of each hook asks for consent once — expected)"
else
    echo "  · hooks not wired (hermes CLI missing or KIT_NO_HOOKS=1) — see skills/guardrails/templates/hermes-hooks.yaml"
fi
mkdir -p "$HOME/.local/bin" && ln -sf "$KIT_ROOT/install/init-project.sh" "$HOME/.local/bin/kit-init" && echo "  · kit-init → ~/.local/bin/kit-init ✓ (run it in any repo)"
for c in kit-update kit-webhook; do ln -sf "$KIT_ROOT/install/$c.sh" "$HOME/.local/bin/$c"; done
echo "  · kit-update, kit-webhook → ~/.local/bin ✓"

echo
echo "─── done ───────────────────────────────────────────────"
echo "Installed skills: $(ls "$HERMES_SKILLS_DIR/$CATEGORY" | tr '\n' ' ')"
echo "A NEW Hermes session is required for the skills to appear (skill index loads at session start)."
echo "Then say:  'set up the skill starter kit' / 'recall the kit'."
echo "In each repo:  kit-init   (AGENTS.md, verify.sh, hooks, .npmrc — same script as init-project.sh)"
echo
echo "To update later, just re-run this installer — it pulls the kit from GitHub"
echo "and refreshes every installed skill in place."