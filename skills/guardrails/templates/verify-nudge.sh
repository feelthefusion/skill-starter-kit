#!/usr/bin/env bash
# verify-gate on Hermes — pre_verify shell hook. Runs the repo's verify command when the
# agent edited code this turn; on failure tells the agent to keep going with the real output.
# One-shot per turn (gates on .extra.attempt) so it can never trap the loop.
set -u
payload="$(cat)"
read -r attempt cwd <<<"$(printf '%s' "$payload" | python3 -c '
import sys, json
d = json.load(sys.stdin); e = d.get("extra") or {}
print(int(e.get("attempt") or 0), d.get("cwd") or ".")' 2>/dev/null || echo "0 .")"
[ "$attempt" != "0" ] && { printf '{}\n'; exit 0; }
cd "$cwd" 2>/dev/null || { printf '{}\n'; exit 0; }
if   [ -x ./verify.sh ];                 then v=./verify.sh
elif [ -f package.json ] && grep -q '"verify"' package.json; then v="npm run verify"
elif [ -f Makefile ] && grep -q '^verify:' Makefile;         then v="make verify"
else printf '{}\n'; exit 0; fi
out="$($v 2>&1 | tail -c 4000)"; rc=$?
if [ $rc -ne 0 ]; then
  python3 -c 'import json,sys; print(json.dumps({"action":"continue","message":"verify failed (exit %d). Fix the real cause, re-run `%s`, and paste its output verbatim before finishing.\n\n%s" % (int(sys.argv[1]), sys.argv[2], sys.argv[3])}))' "$rc" "$v" "$out"
else
  printf '{}\n'
fi
exit 0
