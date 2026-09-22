#!/usr/bin/env bash
# guardrails/guard.sh — PreToolUse (Claude Code) / pre_tool_call (Hermes) action gate.
# Reads the hook JSON on stdin, exits 2 with a reason on stderr to BLOCK, 0 to allow.
# Both hosts honour exit 2; the stderr text is returned to the agent as the block reason.
# Keep this short. Add your stack's irreversibles to the case block below.
set -u
payload="$(cat)"
cmd="$(printf '%s' "$payload" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    print(""); sys.exit()
ti = d.get("tool_input") or {}
print(ti.get("command") or ti.get("cmd") or "")
' 2>/dev/null)"
[ -z "$cmd" ] && exit 0

block() { printf 'guardrails: blocked — %s\nCommand: %s\nIf this is genuinely needed, the human runs it in their own shell.\n' "$1" "$cmd" >&2; exit 2; }

# normalise whitespace for matching
c="$(printf '%s' "$cmd" | tr -s '[:space:]' ' ')"

# --- recursive rm: inspect every target, in every segment of the pipeline -----------
rm_reason="$(printf '%s' "$cmd" | python3 -c '
import sys, shlex, re, os
cmd = sys.stdin.read()
try:
    toks = shlex.split(cmd, posix=True)
except ValueError:
    toks = cmd.split()
segs, cur = [], []
for t in toks:
    if t in ("|", "||", "&&", ";", "&"): segs.append(cur); cur = []
    else: cur.append(t)
segs.append(cur)
for s in segs:
    if not s: continue
    i = 0
    while i < len(s) and s[i] in ("sudo", "env", "xargs", "nice", "time", "command"): i += 1
    if i >= len(s) or os.path.basename(s[i]) != "rm": continue
    flags = [a for a in s[i+1:] if a.startswith("-")]
    targets = [a for a in s[i+1:] if not a.startswith("-")]
    recursive = any(("r" in f.lower() or "recursive" in f) for f in flags)
    if not recursive: continue
    if not targets: print("recursive rm with no explicit target"); break
    for t in targets:
        # scratch dirs are fine (taste-code spikes live in $TMPDIR/spike-<name> and are deleted)
        if re.match(r"^(\$\{?TMPDIR\}?|/tmp|/private/tmp|/var/folders)/.+", t): continue
        if t in ("/", "~", ".", "*", "..", "./", "../") or t.startswith(("/", "~", "..", "$HOME", "${HOME")) \
           or t.startswith("$") or t in ("*/", ".*") or t.endswith("/*") and t.count("/") <= 1:
            print(f"recursive delete of {t!r} — root/home/parent/absolute/glob/variable target")
            sys.exit(0)
' 2>/dev/null)"
[ -n "$rm_reason" ] && block "$rm_reason"

case "$c" in
  # --- filesystem ---------------------------------------------------------
  *"chmod -R 777"*)      block "world-writable recursive chmod";;
  # --- git: history / work loss --------------------------------------------
  *"git push"*"--force"*|*"git push"*" -f "*|*"git push -f"*)
      block "force-push rewrites shared history (use --force-with-lease on your own branch, by hand)";;
  *"git reset --hard"*)  block "hard reset discards uncommitted work";;
  *"git clean -fd"*|*"git clean -xdf"*|*"git clean -fdx"*)
      block "git clean deletes untracked files";;
  *"git checkout -- ."*|*"git restore ."*|*"git restore --staged --worktree ."*)
      block "discards all unstaged changes";;
  *"git branch -D"*)     block "force-deleting a branch";;
  *"--no-verify"*)       block "skipping hooks defeats security-gate (gitleaks) and verify-gate";;
  # --- data ------------------------------------------------------------------
  *"DROP TABLE"*|*"DROP DATABASE"*|*"drop table"*|*"drop database"*|*"TRUNCATE "*|*"truncate table"*)
      block "destructive SQL";;
  # --- secrets: read or exfiltrate -------------------------------------------
  *"cat .env"*|*"cat ./.env"*|*"less .env"*|*"head .env"*|*"grep "*".env"*|*"cp .env"*|*"cat "*"/.env"*)
      block "reading a secrets file into the agent context";;
  *"~/.ssh"*|*"\$HOME/.ssh"*|*"~/.aws"*|*"~/.config/gh"*)
      block "touching credential directories";;
  *"curl "*"| sh"*|*"curl "*"| bash"*|*"wget "*"| sh"*|*"wget "*"| bash"*)
      block "piping a remote script into a shell";;
  # --- publish / privilege -----------------------------------------------------
  *"npm publish"*|*"pnpm publish"*|*"yarn publish"*|*"twine upload"*|*"cargo publish"*)
      block "publishing a package";;
  *"sudo "*)             block "privilege escalation";;
  # --- your stack's irreversibles (edit) ------------------------------------------
  # *"terraform destroy"*)     block "destroys infrastructure";;
  # *"prisma migrate reset"*)  block "resets the database";;
esac
exit 0
