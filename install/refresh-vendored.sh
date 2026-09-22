#!/usr/bin/env bash
# =============================================================================
# Skill Starter Kit — MAINTAINER script: refresh the vendored (offline-fallback)
# copies in skills/ from their upstreams, with kit overlays applied.
#
# End users never need this: the installers fetch upstream at install time.
# Run it before a kit release so a clone that is offline still gets a recent
# copy.  Usage:  bash install/refresh-vendored.sh   then review `git diff`.
# =============================================================================
set -euo pipefail
KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=install/lib.sh
source "$KIT_ROOT/install/lib.sh"

KIT_NO_UPSTREAM=0 kit_fetch_upstreams "$KIT_ROOT"

while IFS=$'\t' read -r name _ _ _ _; do
    [ -z "$name" ] && continue
    case "$name" in \#*) continue ;; esac
    src="$KIT_ROOT/.cache/upstream/$name"
    if [ -f "$src/.upstream" ]; then
        rm -rf "$KIT_ROOT/skills/$name"
        cp -R "$src" "$KIT_ROOT/skills/$name"
        echo "  · skills/$name  vendored copy refreshed ($(sed -n 's/^commit: //p' "$src/.upstream"))"
    else
        echo "  ⚠ skills/$name  not refreshed (fetch failed)"
    fi
done < "$KIT_ROOT/install/upstreams.tsv"
echo "Review with: git -C $KIT_ROOT diff --stat skills/"
