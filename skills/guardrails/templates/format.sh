#!/usr/bin/env bash
# guardrails/format.sh — PostToolUse (Claude Code) / post_tool_call (Hermes) formatter.
# Formats ONLY the file just written, with whatever formatter the repo already uses.
# taste-code rules 8 (unused imports) and 10 (match surrounding formatting), mechanized.
set -u
payload="$(cat)"
f="$(printf '%s' "$payload" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    print(""); sys.exit()
ti = d.get("tool_input") or {}
print(ti.get("file_path") or ti.get("path") or "")
' 2>/dev/null)"
[ -n "$f" ] && [ -f "$f" ] || { printf '{}\n'; exit 0; }

have() { command -v "$1" >/dev/null 2>&1; }
case "$f" in
  *.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs|*.json|*.css|*.md|*.yaml|*.yml)
      if [ -f biome.json ] || [ -f biome.jsonc ]; then
          have biome && biome check --write "$f" >/dev/null 2>&1 || npx --no biome check --write "$f" >/dev/null 2>&1
      elif [ -f node_modules/.bin/prettier ] || have prettier; then
          npx --no prettier --write --log-level silent "$f" >/dev/null 2>&1
      fi;;
  *.py)
      if have ruff; then ruff check --fix -q "$f" >/dev/null 2>&1; ruff format -q "$f" >/dev/null 2>&1
      elif have black; then black -q "$f" >/dev/null 2>&1; fi;;
  *.go)   have gofmt && gofmt -w "$f" >/dev/null 2>&1;;
  *.rs)   have rustfmt && rustfmt --edition 2021 "$f" >/dev/null 2>&1;;
  *.sh)   have shfmt && shfmt -w "$f" >/dev/null 2>&1;;
esac
printf '{}\n'
exit 0
