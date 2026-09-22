#!/usr/bin/env bash
# verify-gate — Claude Code Stop hook. Runs the repo's verify command when the turn ends and
# BLOCKS the stop (exit 2, output on stderr) if it fails, so the agent keeps working with the
# real failure in front of it.
#
# Why a wrapper: Claude Code blocks only on exit code 2. `./verify.sh` exits 1 on failure,
# which Claude Code treats as a non-blocking notice — a gate that never closes.
# Bounded: after MAX_BLOCKS blocked stops in one session it lets the turn end with a loud
# notice (an unbounded Stop loop is the failure mode the kit rejected ralph-loop for).
set -u
MAX_BLOCKS="${KIT_VERIFY_MAX_BLOCKS:-3}"
payload="$(cat)"
read -r sid active <<<"$(printf '%s' "$payload" | python3 -c '
import sys, json
d = json.load(sys.stdin)
print(d.get("session_id") or "nosession", "1" if d.get("stop_hook_active") else "0")' 2>/dev/null || echo "nosession 0")"

if   [ -x ./verify.sh ];                                          then v=./verify.sh
elif [ -f package.json ] && grep -q '"verify"' package.json;      then v="npm run verify"
elif [ -f Makefile ]     && grep -q '^verify:' Makefile;          then v="make verify"
else exit 0; fi                                                   # no gate defined here

# only gate turns that touched files: cheap signal = git has changes vs HEAD or untracked
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [ -z "$(git status --porcelain 2>/dev/null)" ]; then exit 0; fi
fi

out="$($v 2>&1)"; rc=$?
if [ $rc -eq 0 ]; then exit 0; fi

count_f="${TMPDIR:-/tmp}/kit-verify-blocks-$sid"
n=$(( $(cat "$count_f" 2>/dev/null || echo 0) + 1 )); printf '%s' "$n" > "$count_f"
tail_out="$(printf '%s' "$out" | tail -c 3000)"
if [ "$n" -gt "$MAX_BLOCKS" ]; then
  printf 'verify still failing after %s blocked stops (exit %s). Letting the turn end — the work is NOT done:\n%s\n' "$n" "$rc" "$tail_out" >&2
  exit 1   # non-blocking notice: visible, never traps the loop
fi
printf 'verify failed (exit %s) — block %s/%s. Fix the real cause (never suppress the check), re-run `%s`, and paste its output verbatim before finishing.\n\n%s\n' "$rc" "$n" "$MAX_BLOCKS" "$v" "$tail_out" >&2
exit 2
