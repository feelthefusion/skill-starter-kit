#!/usr/bin/env bash
# =============================================================================
# kit-update — detect and apply updates to the kit, its upstream skills, and
# every repo you armed with kit-init. Event-driven, never scheduled:
#
#   • session start   Claude Code SessionStart hook / Hermes on_session_start
#                     run `kit-update --if-stale 1 --background` (returns instantly,
#                     checks at most once an hour however many sessions you open)
#   • push webhook    GitHub → Hermes webhook route → `kit-update --force --background`
#                     (install/kit-webhook.sh; instant, for repos you own)
#   • by hand         kit-update            (check + apply now)
#                     kit-update --check    (report only; exit 10 = updates available)
#
# What it updates:
#   1. the kit checkout (git pull --ff-only)
#   2. third-party skills (Graphify, Caveman, Taste) — compared by upstream commit
#   3. installed skills for every host already set up (Claude Code and/or Hermes)
#   4. kit-managed files in armed repos (.claude/hooks/*.sh) — only files still
#      identical to a version the kit shipped; files you edited or deleted are left alone.
#      verify.sh / AGENTS.md / settings.json are yours and never touched.
# =============================================================================
set -uo pipefail

SELF="${BASH_SOURCE[0]}"
while [ -L "$SELF" ]; do
    d="$(cd "$(dirname "$SELF")" && pwd)"; SELF="$(readlink "$SELF")"
    case "$SELF" in /*) ;; *) SELF="$d/$SELF" ;; esac
done
KIT_ROOT="$(cd "$(dirname "$SELF")/.." && pwd)"
STATE="${KIT_STATE_DIR:-$HOME/.config/skill-starter-kit}"
PROJECTS="$STATE/projects"
LOG="$STATE/update.log"
mkdir -p "$STATE"

MODE=apply FORCE=0 BG=0 STALE_H=""
while [ $# -gt 0 ]; do
    case "$1" in
        --check) MODE=check ;;
        --force) FORCE=1 ;;
        --background) BG=1 ;;
        --if-stale) STALE_H="${2:-1}"; shift ;;
        -h|--help) sed -n '2,24p' "$SELF"; exit 0 ;;
        *) echo "unknown flag: $1"; exit 1 ;;
    esac
    shift
done

# throttle: event-driven checks at most once per STALE_H hours (cheap: one stat)
if [ -n "$STALE_H" ] && [ "$FORCE" = 0 ] && [ -f "$STATE/last-check" ]; then
    now=$(date +%s); last=$(cat "$STATE/last-check" 2>/dev/null || echo 0)
    [ $(( now - last )) -lt $(( STALE_H * 3600 )) ] && exit 0
fi

# background: return to the caller (a session-start hook) immediately
if [ "$BG" = 1 ]; then
    args=(); [ "$MODE" = check ] && args+=(--check); [ "$FORCE" = 1 ] && args+=(--force)
    # own session so the host (hook runner / webhook gateway) can't take it down with its group
    if command -v setsid >/dev/null 2>&1; then
        setsid nohup bash "$SELF" ${args[@]+"${args[@]}"} >>"$LOG" 2>&1 </dev/null &
    else
        nohup python3 -c 'import os,sys; os.setsid(); os.execvp("bash", ["bash"]+sys.argv[1:])' \
            "$SELF" ${args[@]+"${args[@]}"} >>"$LOG" 2>&1 </dev/null &
    fi
    exit 0
fi

# one run at a time (session hooks + webhook can fire together)
LOCK="$STATE/update.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
    if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +30 2>/dev/null)" ]; then rm -rf "$LOCK"; mkdir "$LOCK"
    else echo "kit-update: another run in progress"; exit 0; fi
fi
trap 'rm -rf "$LOCK"' EXIT
date +%s > "$STATE/last-check"
echo "── kit-update $(date -u +%FT%TZ) ──"


# ---- 1. what changed? -------------------------------------------------------
CHANGES=()
if git -C "$KIT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    branch="$(git -C "$KIT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
    local_sha="$(git -C "$KIT_ROOT" rev-parse HEAD 2>/dev/null)"
    remote_sha="$(git -C "$KIT_ROOT" ls-remote origin "refs/heads/$branch" 2>/dev/null | cut -f1)"
    if [ -n "$remote_sha" ] && [ "$remote_sha" != "$local_sha" ] \
       && ! git -C "$KIT_ROOT" merge-base --is-ancestor "$remote_sha" HEAD 2>/dev/null; then
        CHANGES+=("kit ${local_sha:0:7} → ${remote_sha:0:7}")
    fi
fi
while IFS=$'\t' read -r name repo ref path _; do
    [ -z "$name" ] && continue; case "$name" in \#*) continue ;; esac
    have="$(sed -n 's/^commit: //p' "$KIT_ROOT/.cache/upstream/$name/.upstream" 2>/dev/null)"
    want="$(git ls-remote "https://github.com/$repo.git" "refs/heads/${ref:-main}" 2>/dev/null | cut -c1-7)"
    [ -z "$want" ] && continue                                  # offline / unreachable
    [ "$have" != "$want" ] && CHANGES+=("$name ${have:-none} → $want ($repo)")
done < "$KIT_ROOT/install/upstreams.tsv"

HOOKS_SRC="$KIT_ROOT/skills/guardrails/templates"
MANAGED="guard.sh format.sh stop-verify.sh"
# A repo file is "kit-owned" when it is byte-identical to ANY version the kit ever shipped
# (git blob history) — so edits you made are detected without a manifest, and kept.
kit_owned() {  # kit_owned <file-in-repo> <template-name>
    local blob; blob="$(git hash-object "$1" 2>/dev/null)" || return 1
    git -C "$KIT_ROOT" log --format=%H -- "skills/guardrails/templates/$2" 2>/dev/null \
      | while read -r c; do git -C "$KIT_ROOT" rev-parse "$c:skills/guardrails/templates/$2" 2>/dev/null; done \
      | grep -qx "$blob"
}
needs_update() {  # needs_update <repo> <name>: kit-owned, present, and not current
    local cur="$1/.claude/hooks/$2"
    [ -f "$cur" ] || return 1
    cmp -s "$cur" "$HOOKS_SRC/$2" && return 1
    kit_owned "$cur" "$2"
}
STALE_REPOS=()
if [ -f "$PROJECTS" ]; then
    while IFS= read -r repo; do
        [ -d "$repo/.claude" ] || continue
        for f in $MANAGED; do needs_update "$repo" "$f" && { STALE_REPOS+=("$repo"); break; }; done
    done < "$PROJECTS"
fi

if [ ${#CHANGES[@]} -eq 0 ] && [ ${#STALE_REPOS[@]} -eq 0 ] && [ "$FORCE" = 0 ]; then
    echo "✓ everything current"; exit 0
fi
for c in ${CHANGES[@]+"${CHANGES[@]}"}; do echo "  ↑ $c"; done
for r in ${STALE_REPOS[@]+"${STALE_REPOS[@]}"}; do echo "  ↑ hooks in $r"; done
[ "$MODE" = check ] && exit 10

# ---- 2. apply ---------------------------------------------------------------
if [ ${#CHANGES[@]} -gt 0 ] || [ "$FORCE" = 1 ]; then
    git -C "$KIT_ROOT" pull --ff-only --quiet 2>/dev/null \
        || echo "  ⚠ kit checkout has local changes/diverged — not pulled (skills still refreshed)"
    if [ -f "$HOME/.claude/skills/.kit-version" ]; then
        KIT_NO_PULL=1 bash "$KIT_ROOT/install/install.sh" >/dev/null 2>&1 \
            && echo "  · Claude Code skills refreshed ✓" || echo "  ⚠ install.sh failed — run it by hand to see why"
    fi
    if [ -d "${HERMES_HOME:-$HOME/.hermes}/skills/autonomous-ai-agents/verify-gate" ]; then
        KIT_NO_PULL=1 bash "$KIT_ROOT/install/hermes.sh" >/dev/null 2>&1 \
            && echo "  · Hermes skills refreshed ✓" || echo "  ⚠ hermes.sh failed — run it by hand to see why"
    fi
fi

# ---- 3. armed repos: refresh kit-owned hook files (yours / deleted ones untouched) ----
[ -f "$PROJECTS" ] && while IFS= read -r repo; do
    [ -d "$repo/.claude" ] || continue
    touched=0
    for f in $MANAGED; do
        cur="$repo/.claude/hooks/$f"
        [ -f "$cur" ] || continue                        # you removed it: respected
        cmp -s "$cur" "$HOOKS_SRC/$f" && continue         # already current
        if kit_owned "$cur" "$f"; then
            cp "$HOOKS_SRC/$f" "$cur" && chmod +x "$cur" && echo "  · $repo: $f updated ✓" && touched=1
        else
            echo "  · $repo: $f edited by you — kept"
        fi
    done
    # stamp every armed repo: it is now in sync with this kit revision (hooks updated or confirmed current)
    [ -d "$repo/.claude" ] && printf 'kit: %s\nupdated: %s\n' "$(git -C "$KIT_ROOT" rev-parse --short HEAD 2>/dev/null)" "$(date -u +%FT%TZ)" > "$repo/.claude/kit-version"
done < "$PROJECTS"
echo "✓ done"
