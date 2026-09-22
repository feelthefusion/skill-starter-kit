---
name: guardrails
description: "Deterministic action gates for coding agents: block destructive commands before they run (rm -rf, force-push, reset --hard, DB drops, secret reads), auto-format after every edit, and set a permission floor (deny-list + OS sandbox). One hook script serves Claude Code and Hermes. Use when setting up a new project or machine, before enabling autonomous/auto-approve modes, or when an agent has run something irreversible."
---

# Guardrails: Gate the Action, Not the Prose

The kit gates *completion* (`verify-gate`) and *code content* (`security-gate`). Nothing gated
**actions** — the command about to run. An agent that passes every test can still
`git push --force`, `rm -rf` the wrong directory, or `curl` your `.env` to a pastebin. The fix
is not a rule in a markdown file (dropped as context fills); it is a hook the harness runs
before the tool executes, and an OS sandbox under it.

**Scope:** what the agent is *allowed to do*. Not what its code contains (`security-gate`), not
whether the work is done (`verify-gate`). Zero always-on context: hooks and settings, no prose.

## Three layers

| Layer | Claude Code | Hermes | Closes |
|-------|-------------|--------|--------|
| **1. Destructive-command block** | `PreToolUse` hook on `Bash`; exit 2 = block | `hooks.pre_tool_call`, matcher `terminal`, `fail_closed: true`; same JSON + exit-2 contract | irreversible actions |
| **2. Format on edit** | `PostToolUse` on `Edit\|Write` | `hooks.post_tool_call`, matcher `write_file\|patch` | `taste-code` rules 8 & 10 (unused imports, formatting) — **mechanized**, no longer prose |
| **3. Permission floor** | `permissions.deny` + `sandbox.enabled` | built-in dangerous-command approval; Docker/egress isolation for autonomous runs | exfiltration leg of the "lethal trifecta" |

Layer 3 is the enforcement; layers 1–2 are the belt. Deny rules have a documented history of
silent misses (`grep -r`/`cp -r` reading a denied path), so **never rely on deny rules alone**
— enable the sandbox and set `failIfUnavailable: true` so a missing sandbox is a hard stop,
not a warning.

## Install (per project — the templates are in this skill)

```bash
# from the kit checkout; init-project.sh does all of this for you
mkdir -p .claude/hooks
cp <kit>/skills/guardrails/templates/guard.sh  .claude/hooks/guard.sh
cp <kit>/skills/guardrails/templates/format.sh .claude/hooks/format.sh
chmod +x .claude/hooks/*.sh
```

**Claude Code** — merge `templates/claude-settings.json` into `.claude/settings.json` (commit it;
`settings.local.json` is for personal overrides). It wires `guard.sh` (PreToolUse), `format.sh`
(PostToolUse), the `verify` Stop hook from `verify-gate`, the deny-list, and the sandbox.

**Hermes** — `templates/hermes-hooks.yaml` shows the `hooks:` block. Apply with
`hermes config set` (never hand-edit `config.yaml`), or copy the scripts to
`~/.hermes/agent-hooks/`. Hermes prompts for consent on first use of each `(event, command)`
pair; that is expected.

## The block list (`guard.sh`)

Blocks, with the reason returned to the agent so it can choose a safe alternative:

- `rm -rf` on `/`, `~`, `.`, `*`, or a path outside the repo · `git push --force*` / `-f` to a
  protected branch · `git reset --hard` · `git clean -fd*` · `git checkout -- .` / `git restore .`
  (unstaged work loss) · `git branch -D` · `DROP TABLE|DATABASE`, `TRUNCATE` ·
  `chmod -R 777` · `curl|wget … | sh` · `sudo` · reads of `.env*`, `~/.ssh`, `~/.aws`,
  `~/.config/gh` (cat/less/head/grep/cp) · `npm publish`, `--no-verify` (defeats
  `security-gate`'s gitleaks step)

It is a plain bash script with one `case` block. **Add your stack's irreversibles** (prod
deploy commands, migration `down`, `terraform destroy`). Keep it under 100 lines — a
guardrail nobody reads is a guardrail nobody trusts.

Escape hatch: the *human* runs the command in their own shell. The agent never gets a bypass
flag; if it needs one, the block was correct.

## Format on edit (`format.sh`)

Detects the formatter by lockfile/config present — `biome` → `prettier` → `ruff` → `gofmt` →
`rustfmt` — and runs it on the one file just written. This is `taste-code` rule 10 ("match the
surrounding file's conventions") made deterministic, and with `ruff --fix` / `biome check
--write`, rule 8 (unused imports) too. The agent's in-context copy of the file is not
re-read automatically; the next read picks up the formatted version.

## Permission floor

Claude Code (`templates/claude-settings.json`):
```json
"permissions": { "deny": [
  "Read(./.env)", "Read(./.env.*)", "Read(~/.ssh/**)", "Read(~/.aws/**)", "Read(~/.config/gh/**)",
  "Bash(curl *)", "Bash(wget *)", "Bash(git push --force*)", "Bash(rm -rf *)",
  "Bash(npm publish*)", "Bash(sudo *)"
]},
"sandbox": { "enabled": true, "failIfUnavailable": true }
```
`--dangerously-skip-permissions` / `hooks_auto_accept` only inside a container or VM that holds
no real credentials. Effective sandboxing needs **both** filesystem and network isolation.

Hermes: dangerous-command approval is on by default — keep it. For unattended runs use the
Docker backend with network egress isolation (Hermes docs: *Network Egress Isolation*).

## Works with →
- **`verify-gate`** — the Stop hook lives in the same `settings.json`; `guard.sh` blocks
  `--no-verify` so the gate cannot be skipped.
- **`security-gate`** — guardrails stop the *action* (reading a secret, skipping gitleaks);
  security-gate inspects the *content* (a secret in the diff). Both, not either.
- **`taste-code`** — `format.sh` is rules 8 and 10 in mechanical form; the prose rules that
  remain are the judgement ones.
- **`github-mcp`** — same principle at the API layer: read-only + lockdown + explicit toolsets.

## Verification
- `echo '{"tool_name":"Bash","tool_input":{"command":"git push --force origin main"}}' | .claude/hooks/guard.sh; echo $?` → prints a reason on stderr, exits 2.
- Same with `"command":"git status"` → exits 0, empty stdout.
- Ask the agent to `rm -rf node_modules ../other-repo` — it is blocked and reports the reason.
- Write a badly formatted file through the agent → it is formatted on disk after the edit.
- `/sandbox` in Claude Code shows enabled; a `curl` to an unapproved host prompts or fails.
