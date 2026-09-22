---
name: security-gate
description: "Wire the OFFICIAL Anthropic security plugins (security-guidance + claude-security) so code changes are vetted for vulnerabilities and secrets before they ship — not a hand-rolled scanner."
---

# Security Gate: Official Anthropic Security Plugins

Nothing else in the kit inspects what code *contains* — Superpowers governs workflow,
taste-code governs structure, GitHub MCP transports commits. This component closes that gap
with Anthropic's two **official** security plugins, plus an optional secrets pre-commit hook.
Use the official plugins so you get maintained detection rules, patches, and SARIF output
for free — the same reasoning that put the official GitHub MCP in the kit.

**Scope:** vulnerability and secret detection on code changes and repositories. It does NOT
replace PR-time human review or a CI scanning pipeline — it reduces what reaches them.

## The Two Plugins

| Plugin | When it runs | What it covers |
|--------|--------------|----------------|
| **security-guidance** | Automatically, on each file edit in-session | Injection (`eval`, `exec`, `child_process.exec`), unsafe deserialization (`pickle`), DOM injection (`dangerouslySetInnerHTML`, `.innerHTML =`), edits under `.github/workflows/` |
| **claude-security** | On demand (`/claude-security`) | Multi-agent deep scan of repo or diff; CWE-classified findings; `CLAUDE-SECURITY-RESULTS.sarif` for GitHub code scanning; proposes patches |

## Install

In a Claude Code session, from the official Anthropic marketplace:
```
/plugin install security-guidance@claude-plugins-official
/plugin install claude-security@claude-plugins-official
```
If the marketplace is missing: `/plugin marketplace add anthropics/claude-plugins-official`,
then retry. Choose **user scope** so the plugins load in every session on the machine.

Prerequisites: `python3` ≥ 3.10 on PATH (security-guidance builds a venv under
`~/.claude/security/` on first run and needs `pip` + network; claude-security needs only
stdlib, python3 ≥ 3.9).

## Optional: literal secrets scan (gitleaks)

The official plugins target vulnerability *patterns*; for literal credentials in staged
diffs add gitleaks as a pre-commit hook:
```bash
brew install gitleaks
# per-repo hook:
printf '#!/bin/sh\ngitleaks protect --staged --verbose\n' > .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

## Procedure

1. Install both plugins (above); restart or `/reload-plugins`.
2. **security-guidance** needs nothing further — it reviews edits as Claude writes them and
   fixes findings in the same session.
3. Before a PR or release, run **`/claude-security`** — scan changes only (needs a git repo)
   or the full tree. Read findings from the panel or the SARIF file.
4. Triage by CWE class; accept proposed patches or fix manually. Re-scan until clean.
5. Commit the SARIF to CI/code-scanning if the repo uses GitHub code scanning.

## Pitfalls

- **Re-inventing it.** Don't hand-roll regex scanners or wrap semgrep in a skill when the
  official plugins exist — same rule as GitHub MCP.
- **Treating security-guidance as the deep scan.** It's an in-session linter for changes
  Claude writes; pre-existing code needs `/claude-security`.
- **Old Python.** Below 3.10, security-guidance silently degrades to single-shot review —
  check the one-time notice.
- **Skipping the secrets layer.** Vulnerability patterns ≠ leaked credentials; the gitleaks
  hook is one line and catches what the plugins don't target.
- **Caveman interaction:** security warnings already auto-drop compression (Caveman's
  Auto-Clarity rule) — never compress or truncate plugin findings.

## Verification

- Both plugins listed in `/plugin` as installed and active.
- security-guidance: introduce `eval(` in a scratch edit → plugin flags it in-session.
- claude-security: `/claude-security` on a repo produces findings or a clean report plus
  `CLAUDE-SECURITY-RESULTS.sarif`.
- If gitleaks hook installed: staging a fake AWS key blocks the commit.
