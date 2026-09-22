# Skill Starter Kit

One command to bootstrap a fresh Claude Code **or Hermes** machine with the starter stack, and
one command to arm a new repo: a deterministic completion gate, action guardrails, browser-based
verification, fresh library docs, install hygiene, multi-session memory, a structured workflow,
anti-slop taste, per-stack language servers, official GitHub tooling, and a five-layer security
gate — wired so each component hands off to the next.

> **v3 (deep-research pass).** The kit is **12 components + a project template**. Added because
> they close loops deterministically: **Guardrails** (nothing gated *actions* — `rm -rf`, force
> push, reading `.env`, `curl | sh`; now a PreToolUse hook + deny-list + OS sandbox, and the
> PostToolUse formatter that `taste-code` always promised), **install hygiene** inside the
> security gate (release-age cooldowns, `ignore-scripts`, frozen lockfiles, `zizmor` — the days
> before a malicious release is reported are the one window scanners can't see), and an
> **`AGENTS.md` template** (presence moves rule-following 0 → 68%; length does nothing, so it's
> 12 lines). Trimmed: Caveman to two skills. Fixed: the Hermes story — Superpowers, hooks,
> `/goal gate`, MCP and Supermemory all have native Hermes paths now. **Third-party skills are
> fetched from their upstream repos at install time**, with the kit's scoping re-applied as
> overlays, so a fresh install is never behind upstream. Every kit-owned skill now ends with a
> **Works with →** section naming its handoffs; the root `SKILL.md` carries the full workflow map.

## The components

| # | Name | Kind | What it does | Gate? |
|---|------|------|--------------|-------|
| 0 | **`AGENTS.md`** template | file (per repo) | ≤12 hand-written bullets the agent cannot infer: the `verify` command, stack/package manager, forbidden operations, where plans live. `CLAUDE.md` is a one-line pointer to it. Never auto-generated (auto-generated context files measurably *hurt*). | — |
| 1 | **Graphify** | skill ← `Graphify-Labs/graphify` | **On-demand** orientation in a large unfamiliar repo, cross-repo maps, non-code corpora → knowledge graph. `/graphify`. Not the default retrieval path — LSP + grep are. | — |
| 2 | **Superpowers** | plugin — **Claude Code and Hermes** | brainstorm → plan → execute → review → finish. Bundles TDD, systematic-debugging, code-review, git-worktrees, verification-before-completion — never add standalone versions. Hermes: `hermes plugins install obra/superpowers --enable`, *or* use Hermes' bundled equivalents; never both. | — |
| 3 | **Supermemory** | plugin + LOCAL server (`:6767`) | Cross-session memory of decisions and preferences. On Hermes it is a native memory provider (`memory.provider: supermemory`). | — |
| 4 | **Taste** | skills (`taste-code` + `design-taste-frontend` ← `Leonxlnx/taste-skill`) | Anti-slop: judgement rules against boilerplate, placeholder noise, defensive try/catch and over-architecture; spike rule; permission to reject reviewer findings. Rules 8/10 are **mechanized** by Guardrails' `format.sh`. | — |
| 5 | **LSP plugins** | skill → official plugins | Compiler-accurate types/refs/diagnostics. **12 Anthropic plugins + Shopify's `liquid-lsp`.** Per stack only. | per file |
| 6 | **GitHub MCP** | skill → official server | `github/github-mcp-server`, **read-only + lockdown mode + explicit toolsets**, repo-scoped token, per project. `gh` CLI is the cheap default. | — |
| 7 | **Caveman** | skills (`caveman`, `caveman-commit` ← `JuliusBrussee/caveman`) | **Opt-in only** compression of the *final summary*. Never reasoning, never tool output, never verification output. | — |
| 8 | **Security Gate** | skill → official plugins + CLIs | Five layers: `security-guidance` · `claude-security` · **gitleaks** (`--redact`) · **osv-scanner** (CVEs **and** known-malicious `MAL-*` packages) · **install hygiene** (`min-release-age`, `ignore-scripts`, `npm ci`/`--locked`, **zizmor** for Actions). Honest table of which layers are gates and which are prose. | layers 3–5 |
| 9 | **Verify Gate** ⭐ | skill + hook | One `verify` command (locked install → typecheck → lint → test → build → osv → zizmor → smoke spec) wired to the **Stop hook** (Claude Code) or **`pre_verify` hook / `/goal gate`** (Hermes). Evidence discipline: paste real output. | **yes** |
| 10 | **Browser Verify** | skill → `playwright` + `chrome-devtools-mcp` | See what was built: render → screenshot → diff against the design → fix → re-shoot. Smoke spec in `verify`; console/network instead of guessing. | smoke spec |
| 11 | **Docs Freshness** | skill → `context7` (optional) | `--help` → installed source → `llms.txt` → Context7 → DeepWiki. Never install a package name produced from memory without checking it exists. | — |
| 12 | **Guardrails** ⭐ | skill + hooks + settings | `guard.sh` (PreToolUse: blocks recursive deletes outside the repo, force-push/reset, `--no-verify`, secret reads, `curl \| sh`, publishing, prod DB drops), `format.sh` (PostToolUse: biome/prettier/ruff/gofmt/rustfmt), `permissions.deny`, OS **sandbox** with `failIfUnavailable`. **Same scripts on both hosts.** | **yes** |

## How they work together

The root [`SKILL.md`](SKILL.md) is the workflow map. Short version of a feature, end to end:

1. **Orient** with LSP + grep (5); Graphify (1) only for a large unfamiliar repo.
2. **Shape** with Superpowers brainstorm → plan (2); `taste-code` rule 4 on the plan (4); recall from Supermemory (3).
3. **Before any dependency**: stdlib first (4) → does it exist / is it the one I meant (11) → is it old enough, scripts off, locked (8). The package manager enforces the last one even if the agent forgets.
4. **Build**: TDD (2) · current API (11) · taste shapes it (4) · `format.sh` after every edit (12) · LSP diagnostics (5) · `guard.sh` blocks the irreversible (12).
5. **See it**: design-taste (4) → browser compare loop (10); bugs via systematic-debugging (2) with DevTools evidence (10).
6. **Prove it**: `verify` at turn end (9); fix causes, never suppress (4); output verbatim, Caveman hands off (7).
7. **Review**: fresh-context code review (2); reject findings that violate taste (4); `/claude-security` before a PR (8).
8. **Ship**: gitleaks → commit (`caveman-commit` opt-in) → PR via `gh` / GitHub MCP (6) → merge when CI agrees with `verify`.
9. **Remember**: Supermemory (3), `AGENTS.md` (0), or a skill.

Every kit-owned skill ends with a **Works with →** section stating exactly these handoffs, so
the component you're in tells you which one is next.

## Quick start

**Fresh device — always latest:**
```bash
curl -fsSL https://raw.githubusercontent.com/feelthefusion/skill-starter-kit/main/install/bootstrap.sh | bash              # Claude Code
curl -fsSL https://raw.githubusercontent.com/feelthefusion/skill-starter-kit/main/install/bootstrap.sh | bash -s -- hermes # Hermes
```
Or `git clone https://github.com/feelthefusion/skill-starter-kit.git && bash skill-starter-kit/install/install.sh` (`hermes.sh` for Hermes).

**Claude Code, then inside the session:**
```
/plugin install superpowers@superpowers-marketplace
/plugin install supermemory@supermemory-plugins
/plugin install security-guidance@claude-plugins-official
/plugin install claude-security@claude-plugins-official
/plugin install playwright@claude-plugins-official
/plugin install chrome-devtools-mcp@claude-plugins-official
```
Restart. Then **per project, never global**: the matching `<lang>-lsp`, `context7`, GitHub MCP.
Optional: `claude-md-management` (`/revise-claude-md` folds session learnings into `AGENTS.md`)
and `session-report` (measures the startup-context claim below).

**Hermes:** open a new session (skill index loads at start), then optionally
`hermes plugins install obra/superpowers --enable` and
`hermes config set memory.provider supermemory`. Guardrails scripts land in
`~/.hermes/agent-hooks/`; wire them with `skills/guardrails/templates/hermes-hooks.yaml`.

### First thing in a new repo
```bash
bash ~/skill-starter-kit/install/init-project.sh
```
Writes `AGENTS.md` (+ `CLAUDE.md` pointer), `verify.sh`, `.claude/settings.json` (Stop hook +
guardrails hooks + deny-list + sandbox), `.claude/hooks/{guard,format}.sh`, and the install-hygiene
config for your package manager (`.npmrc` / `pnpm-workspace.yaml` / `.yarnrc.yml` / `bunfig.toml`).
Never overwrites existing files. Then: edit `AGENTS.md`, trim `verify.sh`, **break something and
confirm the gate blocks the turn**, add your stack's irreversible commands to `guard.sh`, commit.

## Staying current

Nothing is version-pinned; every install pulls the latest **at every layer**:

| Layer | How it stays live |
|-------|-------------------|
| Kit-owned skills (taste-code, LSP, GitHub MCP, Security Gate, Verify Gate, Browser Verify, Docs Freshness, Guardrails, recall) | `git pull --ff-only` on the kit, then installed copies are **refreshed in place** |
| **Third-party skills** (Graphify, Caveman, Taste) | **Fetched from their upstream repo on every install** (`install/upstreams.tsv`), kit scoping re-applied from `install/overlays/`, upstream commit recorded in `.upstream`. Offline → falls back to the vendored copy in `skills/`. `install/refresh-vendored.sh` updates the vendored copies for committing. |
| Plugins (Superpowers, Supermemory, Anthropic plugins, LSP) | Registered by GitHub repo, never a pinned ref; `/plugin` refreshes |
| Supermemory server | Upstream install script re-runs each time |
| GitHub MCP | Official remote endpoint, updated server-side |
| CLIs (gitleaks, osv-scanner, uv/zizmor) | `brew install` if missing; `brew upgrade` is yours |

Re-run the installer to update any machine. `KIT_NO_PULL=1` skips the kit pull;
`KIT_NO_UPSTREAM=1` installs vendored copies only. Dirty tree → pull skipped; offline → soft-fail
to local copies. Edits to *installed* copies are overwritten — edit in the repo (kit-owned) or in
`install/overlays/` (third-party).

## Deliberately rejected

All good tools; each duplicates a chosen component, fails the context budget, or doesn't close an
*agent* loop.

| Candidate | Why not |
|-----------|---------|
| **Serena MCP** | Duplicates LSP plugins *and* Graphify, plus a third memory layer; heaviest schema cost surveyed. |
| **spec-kit**, **OpenSpec**, **BMAD** | Duplicate Superpowers' workflow. Swap *to*, never stack. |
| **tdd-guard**, official **`feature-dev`**, **`code-review`**, **`pr-review-toolkit`**, **`code-simplifier`**, **`commit-commands`**, **`skill-creator`**, **`plugin-dev`** | Duplicate what Superpowers bundles (TDD, review, plan→execute, skill authoring). |
| **`ralph-loop`** | A second Stop-hook loop that fights the Verify Gate's. Hermes `/goal` is the sanctioned loop. |
| official **`frontend-design`**, **`webapp-testing`** | Duplicate `design-taste-frontend` / Browser Verify. |
| **`explanatory-`/`learning-output-style`**, **`discernment-nudge`** | Per-turn injected prose; violate the <15% rule. |
| **repomix**, **code2prompt** | Whole-repo packing: more context to do less than LSP. |
| **claude-mem**, **mempalace**, **`remember`**, **mattpocock-skills** | Second memory layer / duplicate TDD + review. |
| **Ref** | Overlaps Context7; wins only on private docs, needs a key. |
| **Semgrep**, **SonarQube plugin** | Partial overlap with the security gate; SonarQube needs a server + always-on MCP. Fine as CI. |
| **TruffleHog**, **detect-secrets** | Slower/network-verified; unmaintained. gitleaks is enough. |
| **Socket** (as default), **Trivy**, **Grype**, **pip-audit**, `uv audit` | SaaS account; container-focused overlap; OSV-redundant; preview. |
| **SBOM / SLSA / sigstore** | Producer-side value only; revisit if the kit publishes packages. |
| Mutation testing, Lighthouse CI, ADR tooling, devcontainers, Renovate | Good CI additions; none closes an *agent* loop. |
| Community "guardrail" frameworks | 0–2 stars, no third-party review. The kit's Guardrails is native hooks + settings only. |
| **zen-mcp**, **semgrep/mcp**, **trivy-mcp**, **cc-statusline** | Stale or archived. |

## Context budget

The dominant failure mode is context exhaustion, not missing capability.

- `/context` on a fresh session; target **startup context under ~15%**. `session-report`
  (optional, official) measures it.
- Guardrails, hooks, deny rules and the sandbox cost **zero** standing context — that is why they
  are preferred over prose.
- Per project, never global: `<lang>-lsp`, `context7`, GitHub MCP.
- `/clear` between unrelated tasks.

## Requirements
- macOS or Linux (launchd auto-start is macOS-only)
- Node.js 18+, `gh` CLI (authenticated)
- `gitleaks`, `osv-scanner`, `uv` (for `uvx zizmor`) — installers `brew install` them if missing
- Claude Code sandbox: macOS Seatbelt built in; Linux needs `bubblewrap` + `socat`

## Directory layout
```
├── SKILL.md                 # recall skill + workflow map (single source; installers copy it)
├── install/
│   ├── bootstrap.sh         # curl-able: clone-or-pull latest, then install
│   ├── lib.sh               # self-update, UPSTREAM FETCH + overlays, refresh-in-place sync
│   ├── upstreams.tsv        # skill → upstream repo/ref/path
│   ├── overlays/<skill>/    # kit scoping re-applied over fresh upstream (description, PREPEND, replace/)
│   ├── refresh-vendored.sh  # maintainer: pull upstream into skills/ for committing
│   ├── install.sh           # Claude Code
│   ├── hermes.sh            # Hermes
│   └── init-project.sh      # per repo: AGENTS.md, verify.sh, hooks, settings, .npmrc
├── skills/                  # portable skills (kit-owned + vendored fallbacks)
│   └── guardrails/templates # guard.sh, format.sh, verify-nudge.sh, claude-settings.json, hermes-hooks.yaml
├── templates/project/       # AGENTS.md, CLAUDE.md, .npmrc, pnpm-workspace.yaml, .yarnrc.yml, bunfig.toml
└── evals/                   # task cases + runner: how you prove a component earns its keep
```
