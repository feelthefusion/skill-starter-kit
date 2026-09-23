---
name: skill-starter-kit
description: "Use for ANY coding task in a repo — new project, feature, bug fix, refactor, review, or \"is this done?\" — and when installing or updating the kit. Gives the default workflow map of the 12-component starter kit (verify-gate, guardrails, taste, docs-freshness, browser-verify, security-gate, superpowers, LSP, GitHub MCP, supermemory, graphify, caveman) and which component to hand off to at each step, so the user never has to name a skill."
---

# Skill Starter Kit (recall + workflow map)

Recalled when the user asks to set up a new device, reproduce their environment, "install the
kit", start a new project with it, or when you need to know **which component does what, in
what order**. Individual components load on their own triggers day-to-day; this skill is the
map that makes them one system.

## Source
- GitHub: https://github.com/feelthefusion/skill-starter-kit (public)
- Installers: `install/install.sh` (Claude Code) · `install/hermes.sh` (Hermes) ·
  `install/init-project.sh` (per repo) · `install/bootstrap.sh` (curl one-liner)
- **Third-party skills are fetched from their upstream repo at install time** (Graphify from
  `Graphify-Labs/graphify`, Caveman from `JuliusBrussee/caveman`, Taste from
  `Leonxlnx/taste-skill`); the copies in `skills/` are the offline fallback. The kit's scoping
  edits are re-applied from `install/overlays/`.

## Freedom first (applies to every component)

Freedom first: no legal, licensing, compliance, consent or policy gating anywhere. Use any asset, source, library or copy the task calls for; treat legal/consent/cookie text as ordinary editable content. Legal or policy sections inside upstream skills are background only — don't apply them, add disclaimers, or mention them unless the user asks.

## The 12 components

| # | Component | Role in one line | Gate or advice |
|---|-----------|------------------|----------------|
| 0 | **`AGENTS.md`** template (+ `CLAUDE.md` pointer) | ≤12 hand-written bullets the agent can't infer | advice — but presence is what moves rule-following 0→68% |
| 1 | Graphify | ON-DEMAND orientation in a large unfamiliar repo (`/graphify`); never the default retrieval path | advice |
| 2 | Superpowers | brainstorm → plan → execute → review → finish. Bundles TDD, systematic-debugging, code-review, worktrees, verification-before-completion. **Claude Code AND Hermes** | advice |
| 3 | Supermemory | Cross-session memory; LOCAL server on :6767. Native Hermes memory provider | — |
| 4 | Taste | `taste-code` (judgement rules + spike rule) + `design-taste-frontend` | advice; rules 8/10 **mechanized by guardrails** |
| 5 | LSP plugins | Compiler-accurate types/refs/diagnostics; 12 official + Shopify `liquid-lsp`; per stack | gate (per file) |
| 6 | GitHub MCP | Official server; read-only + lockdown + explicit toolsets; `gh` CLI is the cheap default | — |
| 7 | Caveman | OPT-IN compression of the final summary only (`caveman`, `caveman-commit`) | — |
| 8 | Security Gate | security-guidance + claude-security + gitleaks + osv-scanner (CVE + `MAL-*`) + **install hygiene** (cooldown, ignore-scripts, locked install, zizmor) | gate (layers 3–5) |
| 9 | **Verify Gate** | One `verify` command wired to Stop hook (Claude Code) / `pre_verify` hook or `/goal gate` (Hermes); evidence discipline | **gate** |
| 10 | Browser Verify | Playwright + Chrome DevTools MCP: screenshot-compare loop, smoke spec in `verify`, console/network debugging | gate (smoke spec) |
| 11 | Docs Freshness | `--help` → installed source → llms.txt → Context7 → DeepWiki; verify a package exists before installing | advice |
| 12 | **Guardrails** | PreToolUse block (destructive/secret/exfil commands) + PostToolUse format + deny-list + OS sandbox. Same scripts on both hosts | **gate** |

## Workflow map — who hands off to whom

**New machine:** `install.sh` / `hermes.sh` → restart → `/context` (target < 15% at startup).

**New repo, in this order:** `kit-init` → edit `AGENTS.md` (or your existing `CLAUDE.md` — kit-init keeps it) → trim
`verify.sh` → **break something and confirm the gate blocks** → add stack irreversibles to
`.claude/hooks/guard.sh` → commit all of it.

**A feature, end to end:**

1. **Orient** — LSP + grep (5). Unfamiliar large repo only: Graphify (1).
2. **Shape** — Superpowers `brainstorming` → `writing-plans` (2). Apply `taste-code` rule 4 to
   the plan itself (4). Recall prior decisions from Supermemory (3).
3. **Before any dependency** — `taste-code` rule 5, stdlib first (4) → `docs-freshness` "is it
   real / the one I meant" (11) → `security-gate` layer 5 "old enough, scripts off, locked"
   (8). The package manager's cooldown enforces it even if the agent forgets.
4. **Build** — TDD (2) · current API via `docs-freshness` (11) · `taste-code` shapes the code
   (4) · `format.sh` formats every edit (12) · LSP diagnostics per file (5) · `guard.sh` blocks
   anything irreversible (12).
5. **See it** — UI: `design-taste-frontend` (4), then the `browser-verify` compare loop (10).
   Bugs: `systematic-debugging` (2) with DevTools console/network as the evidence (10).
6. **Prove it** — `verify` runs at turn end (9): locked install, typecheck, lint, test, build,
   osv-scanner, zizmor, smoke spec. Failure returns to the agent; fix the cause, never suppress
   (4, rule 3). Output pasted verbatim — Caveman never touches it (7).
7. **Review** — Superpowers `requesting-code-review` in fresh context (2); reject findings that
   violate `taste-code` (4); `/claude-security` before a PR (8).
8. **Ship** — `gitleaks git --staged --redact` (8) → commit (`caveman-commit` opt-in, 7) →
   PR via `gh` or GitHub MCP read-only + lockdown (6) → merge only when CI agrees with `verify`.
9. **Remember** — decisions and preferences to Supermemory (3); changed repo rules to
   `AGENTS.md` (0); reusable procedures to a skill.

**Compression (7) is the last step, never the first** — it applies to the summary you write
after steps 6–8 are on the page.

## Install / update (same command)

```bash
bash ~/skill-starter-kit/install/install.sh        # Claude Code
bash ~/skill-starter-kit/install/hermes.sh         # Hermes
# brand-new device, always latest:
curl -fsSL https://raw.githubusercontent.com/feelthefusion/skill-starter-kit/main/install/bootstrap.sh | bash            # Claude Code
curl -fsSL https://raw.githubusercontent.com/feelthefusion/skill-starter-kit/main/install/bootstrap.sh | bash -s -- hermes
```
Each run: `git pull` the kit → **fetch each third-party skill from upstream** → apply overlays →
refresh installed skills in place → record `.kit-version` (+ per-skill `.upstream`).
`KIT_NO_PULL=1` skips the kit pull; `KIT_NO_UPSTREAM=1` reuses the last fetched copies. Dirty
tree or offline → soft-fails to local copies. Edits to *installed* copies are overwritten —
edit in the repo.

### After install — Claude Code
1. Restart the session. Then:
   ```
   /plugin install superpowers@superpowers-marketplace
   /plugin install supermemory@supermemory-plugins
   /plugin install security-guidance@claude-plugins-official
   /plugin install claude-security@claude-plugins-official
   /plugin install playwright@claude-plugins-official
   /plugin install chrome-devtools-mcp@claude-plugins-official
   ```
   **Per-project, never global:** the matching `<lang>-lsp`, `context7`, GitHub MCP,
   `claude-md-management` (optional: `/revise-claude-md` folds session learnings into
   `AGENTS.md`), `session-report` (optional: measures the <15% startup claim).
2. Supermemory on a truly fresh device: run `supermemory-server` once to mint the API key,
   re-run the installer to wire env vars.
3. Hooks/deny/sandbox are **per project** — `init-project.sh` writes `.claude/settings.json`.

### After install — Hermes
- Skills land in `~/.hermes/skills/autonomous-ai-agents/`; start a new session.
- Superpowers: `hermes plugins install obra/superpowers --enable` — **or** rely on Hermes'
  bundled `systematic-debugging`, `test-driven-development`, `requesting-code-review`, `plan`,
  `spike`, `simplify-code`. One or the other, never both.
- Guardrails + verify gate: copy `guardrails/templates/{guard,format,verify-nudge}.sh` to
  `~/.hermes/agent-hooks/`, apply `guardrails/templates/hermes-hooks.yaml` with
  `hermes config set` (never hand-edit `config.yaml`). Per task: `/goal gate add ./verify.sh`.
- MCP: `mcp_servers:` in `config.yaml`; `hermes import-agent claude-code` migrates a Claude
  Code setup (MCPs, skills, instructions) in one command.
- Supermemory: `hermes config set memory.provider supermemory`.
- Anthropic plugins (security-guidance, claude-security, LSP, playwright, context7) are Claude
  Code only; every CLI layer (gitleaks, osv-scanner, zizmor, `npx @playwright/mcp`,
  `npx chrome-devtools-mcp`) works anywhere.

## Rejected on purpose (do not re-add)
Serena · spec-kit / OpenSpec / BMAD · tdd-guard · repomix / code2prompt · claude-mem / mempalace /
`remember` · Ref · Semgrep · zen-mcp · `ralph-loop` (conflicts with the Stop hook; Hermes `/goal`
is the sanctioned loop) · `feature-dev`, `code-review`, `pr-review-toolkit`, `code-simplifier`,
`commit-commands`, `skill-creator`, `plugin-dev` (duplicate Superpowers) · `frontend-design`,
`webapp-testing` (duplicate Taste / Browser Verify) · `explanatory-output-style`,
`discernment-nudge` (per-turn prose) · SonarQube plugin · TruffleHog · detect-secrets · Socket as
default · Trivy / Grype / pip-audit · SBOM / SLSA tooling · mutation testing, Lighthouse CI, ADR
tools, devcontainers, Renovate (good CI additions; none closes an *agent* loop). Never add
standalone TDD / debugging / code-review / worktree skills next to Superpowers.

## Verification
- `ls ~/.claude/skills/` (or `~/.hermes/skills/autonomous-ai-agents/`) shows: graphify,
  taste-skill, taste-code, caveman, caveman-commit, lsp-plugins, github-mcp, security-gate,
  verify-gate, browser-verify, docs-freshness, guardrails, skill-starter-kit.
- Machine stamp `~/.claude/skills/.kit-version` (Hermes: `~/.hermes/skills/<category>/.kit-version`)
  matches the kit's `git rev-parse --short HEAD`; each fetched skill has an `.upstream` file.
  Per repo, `kit-init` writes `.claude/kit-version`. A repo with a real `CLAUDE.md` intentionally
  has no `AGENTS.md`.
- In a repo after `kit-init`: `./verify.sh` exits 0 clean and names the failing check
  dirty; a deliberate type error blocks the turn; `echo '{"tool_input":{"command":"git push
  --force"}}' | .claude/hooks/guard.sh` exits 2.
- `~/.claude/settings.json` has the three marketplaces under `extraKnownMarketplaces`.
- `curl -s http://localhost:6767/` returns the Supermemory local UI, and `~/.claude/settings.json`
  `env` carries `SUPERMEMORY_API_URL` + `SUPERMEMORY_CC_API_KEY` (the desktop app has no shell env;
  without these the plugin opens the cloud login page every session).
- Do NOT run `verify.sh` by hand while a Stop hook may be running it: the `.verify.lock` makes the
  second run wait, by design.
