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

# -----------------------------------------------------------------------------
# UPSTREAM FETCH — third-party skills are pulled from THEIR source repo before
# install, so a kit install always lands the latest upstream version, not the
# copy vendored in skills/ (which is the offline fallback).
#
# Manifest: install/upstreams.tsv — one line per skill:
#   <skill-dir>  <github owner/repo>  <ref>  <path in repo (file or dir)>
# Overlays: install/overlays/<skill>/ re-applies the kit's deliberate edits on
# top of the fresh upstream copy (see apply_overlays). Fetched skills land in
# $KIT_ROOT/.cache/upstream/<skill>/ (gitignored); tracked files are never
# touched, so kit_self_update's clean-tree check keeps working.
# Env: KIT_NO_UPSTREAM=1 to skip and install the vendored copies only.
# -----------------------------------------------------------------------------
kit_fetch_upstreams() {
    local root="$1" manifest="$1/install/upstreams.tsv" cache="$1/.cache/upstream"
    if [ "${KIT_NO_UPSTREAM:-0}" = "1" ]; then
        echo "▶ upstream fetch skipped (KIT_NO_UPSTREAM=1) — using vendored copies"
        return 0
    fi
    [ -f "$manifest" ] || { echo "▶ no upstreams.tsv — using vendored copies"; return 0; }
    command -v git >/dev/null 2>&1 || { echo "▶ git missing — using vendored copies"; return 0; }

    echo "▶ fetching latest upstream versions of third-party skills"
    mkdir -p "$cache"
    local name repo ref path tmp src dst
    while IFS=$'\t' read -r name repo ref path _; do
        [ -z "$name" ] && continue
        case "$name" in \#*) continue ;; esac
        ref="${ref:-main}"
        tmp="$(mktemp -d "${TMPDIR:-/tmp}/kit-upstream.XXXXXX")"
        if ! git clone --quiet --depth 1 --branch "$ref" --filter=blob:none --no-checkout \
                "https://github.com/$repo.git" "$tmp" 2>/dev/null \
           || ! git -C "$tmp" sparse-checkout set --no-cone "$path" 2>/dev/null \
           || ! git -C "$tmp" checkout --quiet "$ref" 2>/dev/null; then
            echo "  ⚠ $name  fetch from $repo failed (offline?) — vendored copy will be used"
            rm -rf "$tmp"
            continue
        fi
        src="$tmp/$path"
        dst="$cache/$name"
        rm -rf "$dst"; mkdir -p "$dst"
        if [ -d "$src" ]; then
            cp -R "$src/." "$dst/"
        elif [ -f "$src" ]; then
            cp "$src" "$dst/SKILL.md"          # single-file upstream (e.g. graphify/skill.md)
        else
            echo "  ⚠ $name  path '$path' not found in $repo@$ref — vendored copy will be used"
            rm -rf "$tmp" "$dst"
            continue
        fi
        printf 'upstream: %s\nref: %s\npath: %s\ncommit: %s\nfetched: %s\n' \
            "$repo" "$ref" "$path" "$(git -C "$tmp" rev-parse --short HEAD)" \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$dst/.upstream"
        rm -rf "$tmp"
        apply_overlays "$root" "$name" "$dst"
        echo "  · $name  ← $repo@$(sed -n 's/^commit: //p' "$dst/.upstream") ✓"
    done < "$manifest"
}

# Re-apply the kit's deliberate edits to a freshly fetched upstream skill.
#   install/overlays/<skill>/description  — replaces the frontmatter `description:`
#   install/overlays/<skill>/PREPEND.md   — inserted right after the frontmatter
#   install/overlays/<skill>/replace/<n>.old + <n>.new
#                                          — literal text replacement in SKILL.md body (a
#                                            missing .old prints a WARN: upstream moved, kit
#                                            scope in PREPEND still wins; review the overlay)
#   install/overlays/<skill>/APPEND.md    — appended at the end of SKILL.md (kit handoffs)
#   install/overlays/<skill>/files/*      — copied over the skill dir (added/replaced)
#   $1 = kit root   $2 = skill name   $3 = skill dir to modify
apply_overlays() {
    local root="$1" name="$2" dir="$3" ov="$1/install/overlays/$2"
    [ -d "$ov" ] || return 0
    [ -d "$ov/files" ] && cp -R "$ov/files/." "$dir/"
    [ -f "$dir/SKILL.md" ] || return 0
    python3 - "$dir/SKILL.md" "$ov" <<'PY'
import sys, os, re
skill, ov = sys.argv[1], sys.argv[2]
text = open(skill, encoding="utf-8").read()
m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
if not m:
    sys.exit(0)
fm, body = m.group(1), text[m.end():]
desc_path = os.path.join(ov, "description")
if os.path.exists(desc_path):
    desc = open(desc_path, encoding="utf-8").read().strip()
    # drop the existing description (single-line or block scalar) and insert ours
    lines, out, skipping = fm.split("\n"), [], False
    for ln in lines:
        if ln.startswith("description:"):
            skipping = True
            continue
        if skipping and (ln.startswith(" ") or ln.startswith("\t")):
            continue
        skipping = False
        out.append(ln)
    out.append("description: " + '"' + desc.replace('"', '\\"').replace("\n", " ") + '"')
    fm = "\n".join(out)
rep_dir = os.path.join(ov, "replace")
if os.path.isdir(rep_dir):
    for f in sorted(os.listdir(rep_dir)):
        if not f.endswith(".old"):
            continue
        old = open(os.path.join(rep_dir, f), encoding="utf-8").read().strip("\n")
        new_p = os.path.join(rep_dir, f[:-4] + ".new")
        new = open(new_p, encoding="utf-8").read().strip("\n") if os.path.exists(new_p) else ""
        if old in body:
            body = body.replace(old, new, 1)
        else:
            print(f"    WARN overlay {os.path.basename(ov)}/replace/{f}: text not found upstream — "
                  f"upstream changed; kit scope (PREPEND) still applies, review the overlay", file=sys.stderr)
pre_path = os.path.join(ov, "PREPEND.md")
if os.path.exists(pre_path):
    body = open(pre_path, encoding="utf-8").read().rstrip() + "\n\n" + body.lstrip("\n")
app_path = os.path.join(ov, "APPEND.md")
if os.path.exists(app_path):
    body = body.rstrip() + "\n\n" + open(app_path, encoding="utf-8").read().strip() + "\n"
open(skill, "w", encoding="utf-8").write("---\n" + fm + "\n---\n\n" + body.lstrip("\n"))
PY
}

# Resolve where a skill should be copied FROM: the freshly fetched upstream copy
# when the fetch succeeded, else the vendored copy in skills/.
#   $1 = kit root   $2 = skill name   → prints the source dir
skill_src() {
    local root="$1" name="$2"
    if [ -f "$root/.cache/upstream/$name/.upstream" ]; then
        printf '%s\n' "$root/.cache/upstream/$name"
    else
        printf '%s\n' "$root/skills/$name"
    fi
}

# Install or REFRESH one skill directory. Never skips: the repo is the source of
# truth, so a re-run always lands the current version.
#   $1 = source skill dir   $2 = destination skill dir
# Local edits to the INSTALLED copy are overwritten — edit skills in the repo.
sync_skill() {
    local src="$1" dst="$2" name
    name="$(basename "$dst")"
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
