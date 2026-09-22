#!/usr/bin/env bash
# =============================================================================
# Skill Starter Kit — remote bootstrap (always latest)
#
#   curl -fsSL https://raw.githubusercontent.com/feelthefusion/skill-starter-kit/main/install/bootstrap.sh | bash
#   ...| bash -s -- hermes     # install for Hermes instead of Claude Code
#
# Clones the kit to ~/.skill-starter-kit (or pulls if already there), then runs
# the installer from that fresh checkout. Safe to re-run: this is the update path.
# =============================================================================
set -euo pipefail

TARGET="${1:-claude}"
KIT_DIR="${KIT_DIR:-$HOME/.skill-starter-kit}"
REPO="https://github.com/feelthefusion/skill-starter-kit.git"

command -v git >/dev/null 2>&1 || { echo "✗ git required"; exit 1; }

if [ -d "$KIT_DIR/.git" ]; then
    echo "▶ updating kit checkout at $KIT_DIR"
    git -C "$KIT_DIR" pull --ff-only
else
    echo "▶ cloning kit into $KIT_DIR"
    git clone --depth 1 "$REPO" "$KIT_DIR"
fi

case "$TARGET" in
    hermes) exec bash "$KIT_DIR/install/hermes.sh" ;;
    claude) exec bash "$KIT_DIR/install/install.sh" ;;
    *) echo "✗ unknown target '$TARGET' (use: claude | hermes)"; exit 1 ;;
esac
