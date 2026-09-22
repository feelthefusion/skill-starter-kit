#!/usr/bin/env bash
# =============================================================================
# Skill Starter Kit — shared installer library
#
# Sourced by install/install.sh and install/hermes.sh. Provides the two pieces
# that keep an install LIVE: pulling the kit itself from GitHub before copying,
# and refreshing (not skipping) already-installed skills.
# =============================================================================

# Pull the kit from origin so the skills about to be copied are the latest.
# Non-fatal: offline / dirty tree / detached HEAD fall back to the local copy.
#   $1 = kit root (git work tree)
kit_self_update() {
    local root="$1" before after branch
    if [ "${KIT_NO_PULL:-0}" = "1" ]; then
        echo "▶ self-update skipped (KIT_NO_PULL=1) — using local copy"
        return 0
    fi
    if ! git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
        echo "▶ self-update skipped — not a git clone (downloaded as archive?)"
        echo "  · for live updates: git clone https://github.com/feelthefusion/skill-starter-kit.git"
        return 0
    fi

    echo "▶ self-update: pulling latest kit from origin"
    if [ -n "$(git -C "$root" status --porcelain)" ]; then
        echo "  ⚠ working tree has local changes — NOT pulling (would clobber your edits)"
        echo "    commit/stash them, or re-run after: git -C $root pull --ff-only"
        return 0
    fi

    branch="$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"
    if [ "$branch" = "HEAD" ]; then
        echo "  ⚠ detached HEAD — NOT pulling; checkout a branch for live updates"
        return 0
    fi

    before="$(git -C "$root" rev-parse --short HEAD)"
    if ! git -C "$root" pull --ff-only --quiet 2>/dev/null; then
        echo "  ⚠ pull failed (offline, or branch diverged) — installing the local copy instead"
        return 0
    fi
    after="$(git -C "$root" rev-parse --short HEAD)"
    if [ "$before" = "$after" ]; then
        echo "  · already at latest ($after) ✓"
    else
        echo "  · updated $before → $after ✓"
    fi
}

# Install or REFRESH one skill directory. Never skips: the repo is the source of
# truth, so a re-run always lands the current version.
#   $1 = source skill dir   $2 = destination skill dir
# Local edits to the INSTALLED copy are overwritten — edit skills in the repo.
sync_skill() {
    local src="$1" dst="$2" name
    name="$(basename "$src")"
    if [ ! -d "$src" ]; then
        echo "  · $name  not found in kit — skipped"
        return 0
    fi
    if [ -d "$dst" ] && diff -rq "$src" "$dst" >/dev/null 2>&1; then
        echo "  · $name  up to date"
        return 0
    fi
    local action="installed"
    [ -d "$dst" ] && action="refreshed"
    rm -rf "$dst"
    cp -R "$src" "$dst"
    echo "  · $name  $action ✓"
}

# Record which kit revision is installed, so staleness is visible later.
#   $1 = kit root   $2 = directory to write .kit-version into
write_kit_version() {
    local root="$1" dir="$2" rev
    rev="$(git -C "$root" rev-parse --short HEAD 2>/dev/null || echo "unknown (no git)")"
    mkdir -p "$dir"
    printf 'revision: %s\ninstalled: %s\nsource: %s\n' \
        "$rev" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "$(git -C "$root" remote get-url origin 2>/dev/null || echo "$root")" \
        > "$dir/.kit-version"
    echo "▶ installed kit revision $rev (recorded in $dir/.kit-version)"
}
