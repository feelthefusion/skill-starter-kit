---
name: security-gate
description: "Five-layer security gate for agent-written code: Anthropic's official security-guidance + claude-security plugins, gitleaks on every staged diff, osv-scanner over the dependency tree (CVEs AND known-malicious MAL-* packages), and install hygiene (release-age cooldown, ignore-scripts, frozen lockfiles, zizmor for GitHub Actions). Use before any commit, install, or PR, and when setting up a repo."
---

# Security Gate: Official Anthropic Security Plugins

Nothing else in the kit inspects what code *contains* — Superpowers governs workflow,
taste-code governs structure, GitHub MCP transports commits. This component closes that gap
with Anthropic's two **official** security plugins, plus a secrets scanner (gitleaks) for the
literal-credential case the plugins don't target.
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

## Layer 3: literal secrets (gitleaks)

The official plugins target vulnerability *patterns*; neither greps staged diffs for literal
**credentials** (AWS keys, GitHub/API tokens, private keys). gitleaks does — ~170 rules.
This is a required layer, not a nicety: a single committed key on a public repo is scraped in
minutes.

```bash
brew install gitleaks     # the kit installer does this for you
```

**Enforcement is agent-side, by rule (see Procedure step 0) — not a global git hook.**
Optional per-repo hook for commits made outside an agent session:
```bash
printf '#!/bin/sh\ngitleaks git --staged --no-banner --redact --verbose\n' > .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```
Run that in each repo you want gated. **Never** set `git config --global core.hooksPath` to
force it everywhere: it overrides every repo's own hooks and silently breaks husky/lefthook
setups in unrelated projects.

## Layer 4: the dependency tree (osv-scanner)

Layers 1-3 all look at code *you* wrote. None of them looks at the code you *installed* — and
that is the one supply-chain vector the agent itself creates. The failure is documented:
**slopsquatting**, where the model confidently recommends a package name that never existed
and an attacker has pre-registered it on npm/PyPI. Stale model knowledge (see the
`docs-freshness` skill) is the root cause; this is the catch.

```bash
brew install osv-scanner     # the kit installer does this for you
```

Two uses, both cheap:
- **Pre-install existence check.** Before `npm install <pkg>` / `pip install <pkg>` on a package
  *the agent proposed rather than the user named*: confirm it exists, is not brand new, and the
  name matches the intended library (`npm view <pkg>` / `pip index versions <pkg>`). A
  plausible-looking name the model produced from memory is the exact thing to distrust.
- **Tree scan**, wired into the `verify` script (see the `verify-gate` skill):
  ```bash
  osv-scanner scan source -r .
  ```
  Reachability analysis suppresses CVEs your code can't actually reach, which is what keeps this
  from becoming noise the agent learns to skip.

**It catches malicious packages, not just vulnerable ones.** OSV.dev ingests the OpenSSF
`malicious-packages` database, so `MAL-*` records (typosquats, hijacked releases like the 2026
`axios` compromise) fail the scan exactly like a CVE. Verified: a lockfile pinning
`axios@1.14.1` → `MAL-2026-2307`, exit 1.

Do **not** add a full SCA platform on top. Findings the agent can't act on get suppressed, and
suppression is worse than absence because it looks like coverage.

## Layer 5: install hygiene (the window OSV cannot see)

OSV knows about a bad release only after someone files it — hours to days. Every major
package manager now closes that window natively, for free, with a **release-age cooldown**,
and the install-time script that carries the payload can simply be switched off. These are
config files, not prose; the kit's `init-project.sh` lays them down.

| Package manager | Cooldown setting (7 days) | Scripts off | Locked install |
|---|---|---|---|
| npm ≥ 11.10 | `.npmrc` → `min-release-age=7` | `ignore-scripts=true` | `npm ci` |
| pnpm ≥ 10.16 (default 1 day since v11) | `pnpm-workspace.yaml` → `minimumReleaseAge: 10080` | built-in allowlist | `pnpm install --frozen-lockfile` |
| Yarn Berry ≥ 4.10 | `.yarnrc.yml` → `npmMinimalAgeGate: 10080` | `enableScripts: false` | `yarn install --immutable` |
| Bun ≥ 1.3 | `bunfig.toml` → `[install] minimumReleaseAge = 604800` | `trustedDependencies` | `bun install --frozen-lockfile` |
| uv / pip | — (use `uv lock` + `--locked`) | n/a | `uv sync --locked` |

Agent rules that go with it:
- `verify` installs from the lockfile (`npm ci`, `uv sync --locked`) — never bare `install`.
- **Before adding a dependency the agent proposed** (not one the user named), the existence
  check from `docs-freshness` becomes a command: `npm view <pkg> time.created repository.url`
  (or `pip index versions <pkg>`) must show a repository and an age over 7 days. Otherwise stop
  and ask.
- **GitHub Actions**: `uvx zizmor --min-severity medium .github/workflows` in `verify` (or
  pre-commit). security-guidance only *flags* workflow edits — zizmor is the gate: template
  injection, unpinned `uses:`, credential persistence, excessive `permissions:`. The March 2026
  `trivy-action` `pull_request_target` compromise is the concrete case. Pin `uses:` to a SHA,
  default `permissions: contents: read`.

## What is a gate and what is advice (be honest about it)

| Layer | Deterministic gate? |
|---|---|
| gitleaks on staged diff | **yes** — exit code |
| osv-scanner in `verify` | **yes** — exit code |
| cooldown / ignore-scripts / frozen lockfile | **yes** — the package manager enforces it |
| zizmor in `verify` | **yes** — exit code |
| security-guidance pattern warnings (edit time) | partial — regex, ~25 patterns |
| security-guidance Stop-time diff review, commit reviewer | **no** — LLM prose |
| claude-security deep scan | **no** — LLM agents; strong, but advisory and unisolated: run it on **untrusted repos only inside the sandbox** (`guardrails`) |

Count only the top rows as enforcement.

## Procedure

0. **Before every `git commit`, scan staged changes:**
   ```bash
   gitleaks git --staged --no-banner --redact --verbose --exit-code 1
   ```
   `--redact` matters: without it the secret itself is echoed into the agent's context (and its
   transcript). Confirmed false positives go in a committed `.gitleaksignore` by fingerprint.
   Exit 1 = a secret is staged. **Stop.** Do not commit, do not `--no-verify`. Unstage
   the file, replace the literal with an env var reference, then re-scan. Report the finding
   uncompressed (Auto-Clarity). Only a confirmed false positive is allowed past, and only via
   an explicit `.gitleaksignore` entry — never by skipping the scan.
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
- **Skipping the secrets layer.** Vulnerability patterns ≠ leaked credentials. gitleaks is the
  only layer that catches a pasted API key.
- **`gitleaks protect` / `gitleaks detect` — REMOVED in gitleaks 8.x.** They do not error; on
  8.30 `protect --staged` prints `0 commits scanned … no leaks found` and exits 0, so a planted
  AWS key sails through and the gate silently passes everything. Commands are now `git`, `dir`,
  `stdin` — always `gitleaks git --staged` for pre-commit. Verify any hook with a planted key.
- **Canonical example keys are allowlisted.** `AKIAIOSFODNN7EXAMPLE` is ignored by the default
  config — test with a realistic-looking key or you'll "prove" a broken gate works.
- **Global `core.hooksPath`.** Breaks other repos' hook setups; gate per-repo or rely on the
  agent-side rule.
- **Caveman interaction:** security warnings already auto-drop compression (Caveman's
  Auto-Clarity rule) — never compress or truncate plugin findings.
- **Duplicate findings across layers train the agent to dismiss all of them.** One issue can
  arrive three times (security-guidance at edit time, claude-security in the deep scan, osv in
  the tree scan). De-duplicate before reporting: one finding, one line, the layer that caught
  it named once.
- **Per-edit review on every edit is a standing tax.** Most edits are not security-relevant.
  Let security-guidance fire on security-relevant surfaces — auth, crypto, deserialization,
  subprocess/shell, SQL, file paths, network, `.github/workflows/` — and don't treat its silence
  on a CSS change as a signal about anything.
- **Closing a finding with a `try/catch` violates `taste-code` rule 3.** "Wrap it and log" is
  the cheapest way to make a scanner shut up and it is not a fix. Address the root cause or
  record why the finding is a false positive; never trade a security finding for slop.

## Layer scope (what fires when)

| Layer | Trigger | Surface |
|-------|---------|---------|
| gitleaks | every `git commit` (agent-side rule) | literal credentials in the staged diff |
| security-guidance | edits to security-relevant surfaces | injection, deserialization, DOM, workflows |
| claude-security | on demand, pre-PR/release, CI | whole repo or diff, CWE-classified, SARIF |
| osv-scanner | `verify` script + before agent-proposed installs | dependency tree: CVEs + `MAL-*` malicious packages |
| cooldown / ignore-scripts / lockfile | every install, by the package manager | the days before a bad release is reported |
| zizmor | `verify` script | `.github/workflows/*` |

## Works with →
- **`guardrails`** blocks the *action* (`cat .env`, `--no-verify`, `curl | sh`); this skill
  inspects the *content* (a key in the diff, a bad dependency). Both, never either.
- **`docs-freshness`** owns "does this package exist and is it the one I meant"; layer 5 owns
  "is it old enough and does it run scripts". Run them in that order before any install.
- **`verify-gate`** carries layers 4–5 (`osv-scanner`, locked install, zizmor) so they run on
  every turn end, not when someone remembers.
- **`github-mcp`** — the same least-privilege principle at the API: read-only, lockdown mode,
  explicit toolsets, repo-scoped token.
- **`caveman`** never compresses a finding (Auto-Clarity); **`taste-code`** rule 3 forbids
  closing one with try/catch.

## Verification

- Both plugins listed in `/plugin` as installed and active.
- security-guidance: introduce `eval(` in a scratch edit → plugin flags it in-session.
- claude-security: `/claude-security` on a repo produces findings or a clean report plus
  `CLAUDE-SECURITY-RESULTS.sarif`.
- If gitleaks hook installed: staging a fake AWS key blocks the commit.
- `gitleaks git --staged` on a repo with a planted `AKIA…` key exits 1 and names the file,
  line, and rule. **Test the hook with a real-looking key — a broken command exits 0 and looks
  identical to "clean".**
- `--no-verify` removed as an option: it defeats the hook; the agent-side rule (step 0) is the
  real gate.
