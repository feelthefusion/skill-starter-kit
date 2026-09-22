# Skill Starter Kit

One command to bootstrap a fresh Claude Code machine with the starter stack: a deterministic
completion gate, browser-based verification, fresh library docs, multi-session memory, a
structured workflow, anti-slop taste, per-stack language servers, official GitHub tooling, and
a four-layer security gate.

> **v2 (audit pass).** The kit is **11 components**. Three were added because they close real
> loops — `verify-gate` (nothing else produced a pass/fail that blocks a false "done"),
> `browser-verify` (the frontend skill had no way to *see* its output), and `docs-freshness`
> (nothing knew what shipped in a library last month). Two were scoped down because the
> evidence went against them: **Caveman no longer auto-triggers** (brevity instructions
> measurably reduce factual accuracy, and the mechanism — no room to push back on a false
> premise — is exactly what a coding agent needs) and **Graphify is no longer the default
> retrieval path** (LSP + grep are compiler-accurate and never stale). GSD was removed earlier;
> Superpowers already owns sub-agent orchestration.

## The components

| # | Name | Kind | What it does |
|---|------|------|--------------|
| 1 | **Graphify** | skill | **On-demand** orientation in a large unfamiliar repo, cross-repo maps, and non-code corpora (docs/papers/images/video) → knowledge graph. Trigger: `/graphify`. Not the default retrieval path — LSP + grep are, because a stale graph is worse than none. |
| 2 | **Superpowers** | plugin (obra/superpowers-marketplace) | Enforces a structured multi-phase workflow (brainstorm → plan → execute → review → finish) to stop drift and repeated file reads. Owns sub-agent orchestration. **Bundles 15 skills including systematic-debugging, test-driven-development, requesting/receiving-code-review, git-worktrees and verification-before-completion** — never add standalone versions of these. Also listed as `superpowers@claude-plugins-official`; enable one source, not both. |
| 3 | **Supermemory** | plugin + LOCAL self-hosted server | Persists project context, user preferences, and state. Runs a local server on `:6767` (keeps data on your machine, works fully offline). |
| 4 | **Taste-Skill** | skills (`taste-code` + `taste-skill`) | Anti-slop harness: `taste-code` injects 10 minimalist structural rules against boilerplate, placeholder noise, redundant try/catch logs, and over-engineered architecture; `taste-skill` is the anti-slop frontend companion. |
| 5 | **LSP Plugins** | skill | Compiler-accurate types, definitions, references and post-edit diagnostics via Anthropic's **official** per-language LSP plugins — **13 languages**. Plugin wires the connection, you install the server binary. **Install per-stack only**; a Python repo shouldn't pay context for `gopls`. |
| 6 | **GitHub MCP** | skill → official server | GitHub's **official** `github/github-mcp-server` for issues, PRs, reviews, branches, actions. **Read-only by default, per-project, token scoped to one repo** — it reads attacker-controllable issue text into an agent with write access, which is a demonstrated exfiltration path. `gh` CLI is the cheaper default. |
| 7 | **Caveman** | skills (`caveman*`) | **Opt-in only** (`/caveman`) compression of *final human-facing summaries*. Never the reasoning path, never tool-result interpretation, never verification output — test/build/lint output is pasted verbatim. Does not persist across sessions. |
| 8 | **Security Gate** | skill → official plugins + CLIs | Four layers: `security-guidance` (official — security-relevant edits), `claude-security` (official — on-demand CWE-classified deep scan, SARIF), **gitleaks** (literal credentials in staged diffs), and **osv-scanner** (the dependency tree — the one supply-chain vector the agent itself creates via hallucinated package names). Findings are de-duplicated across layers. |
| 9 | **Verify Gate** ⭐ | skill + `hookify` | One `verify` command (typecheck + lint + test + build + dep audit) wired to a **Stop hook**, so a turn cannot end while it fails, plus evidence discipline: paste the command and its real output, never "tests pass". **The only component that blocks a false "done" — set it up first in a new project.** |
| 10 | **Browser Verify** | skill → `playwright` + `chrome-devtools-mcp` | Lets the agent *see* what it built: render → screenshot → diff against the design → name the differences → fix → re-screenshot. Plus a smoke E2E spec in the `verify` gate, and console/network/DOM debugging instead of guessing. |
| 11 | **Docs Freshness** | skill → `context7` (optional) | The model's weights are older than your lockfile. A cheapest-first ladder — `--help` → installed source → allowlisted doc URL → `llms.txt` → Context7 → DeepWiki — plus: never install a package name the model produced from memory without checking it exists. |

## Quick start (fresh device)

**Always-latest one-liner** (clones or updates `~/.skill-starter-kit`, then installs):
```bash
curl -fsSL https://raw.githubusercontent.com/feelthefusion/skill-starter-kit/main/install/bootstrap.sh | bash
# Hermes instead of Claude Code:
curl -fsSL https://raw.githubusercontent.com/feelthefusion/skill-starter-kit/main/install/bootstrap.sh | bash -s -- hermes
```

### Claude Code
```bash
git clone https://github.com/feelthefusion/skill-starter-kit.git
cd skill-starter-kit
bash install/install.sh
```
Then inside Claude Code:
```
/plugin install superpowers@superpowers-marketplace
/plugin install supermemory@supermemory-plugins
/plugin install security-guidance@claude-plugins-official
/plugin install claude-security@claude-plugins-official
/plugin install hookify@claude-plugins-official
/plugin install playwright@claude-plugins-official
/plugin install chrome-devtools-mcp@claude-plugins-official
```
…and restart. Then **per-project, not globally**: the matching `<lang>-lsp` plugin,
`context7` (docs), and GitHub MCP — each costs context in every session it's enabled.

### First thing in a new project
```bash
cp ~/skill-starter-kit/skills/verify-gate/templates/verify.sh ./verify.sh && chmod +x verify.sh
```
Trim it to the checks your stack actually has, then wire the Stop hook (see the `verify-gate`
skill). Until that exists, nothing in the kit can stop the agent from claiming success.

### Hermes
```bash
git clone https://github.com/feelthefusion/skill-starter-kit.git
cd skill-starter-kit
bash install/hermes.sh          # installs the portable skills + recall skill into ~/.hermes/skills/
```
Then open a **new Hermes session** and say **"set up the skill starter kit"**. (Hermes's
skill index loads at session start, so a new session is required.)

> On Hermes, the portable skills (Graphify, Taste, Caveman, LSP, GitHub MCP, Security Gate,
> Verify Gate, Browser Verify, Docs Freshness) install directly. Superpowers is a Claude Code
> plugin with no Hermes equivalent; Supermemory's local server installs separately. The
> Anthropic plugins are Claude Code only — but every CLI layer works anywhere: `gitleaks`,
> `osv-scanner`, `npx @playwright/mcp@latest`, `npx chrome-devtools-mcp@latest`.

The installers are **live, not pinned** — see [Staying current](#staying-current). See
`/install/install.sh` (Claude Code) and `/install/hermes.sh` (Hermes); the `SKILL.md` at the
repo root is the recall skill that itself knows how to run all of this.

## Staying current

Nothing in the kit is version-pinned; every install pulls the latest:

| Layer | How it stays live |
|-------|-------------------|
| Kit skills (Graphify, Taste, Caveman, LSP, GitHub MCP, Security Gate, Verify Gate, Browser Verify, Docs Freshness) | Installers run `git pull --ff-only` on the repo first, then **refresh** installed skills in place — a re-run updates them instead of skipping |
| Plugins (Superpowers, Supermemory, security-guidance, claude-security, hookify, playwright, chrome-devtools-mcp, context7, LSP plugins) | Registered by **GitHub repo, never a pinned ref** — Claude Code fetches the current version from origin |
| Supermemory server binary | Installer re-runs the upstream `supermemory.ai/install` script each time, so the binary tracks the latest release |
| GitHub MCP | Points at the official remote endpoint (`api.githubcopilot.com/mcp/`), auto-updated server-side |

**To update any machine, just re-run the installer** (or the bootstrap one-liner):
```bash
bash ~/skill-starter-kit/install/install.sh    # Claude Code
bash ~/skill-starter-kit/install/hermes.sh     # Hermes
```
The installed revision is written to `.kit-version` beside the installed skills, so you can
always see what's deployed. Inside Claude Code, `/plugin` refreshes plugins and
`/reload-plugins` applies changes without a restart.

Notes:
- **Local edits to *installed* skill copies are overwritten** on refresh — edit skills in the
  repo (that's the source of truth), then re-run.
- If the repo working tree is dirty, the installer **skips the pull** rather than clobber your
  uncommitted work, and installs the local copy.
- Offline, or a diverged branch: the pull fails soft and the local copy installs.
- `KIT_NO_PULL=1` installs the local copy without pulling.

## Deliberately rejected

Recorded so they don't get re-litigated. All are good tools; all either duplicate a chosen
component or fail the context budget.

| Candidate | Why not |
|-----------|---------|
| **Serena MCP** | Duplicates the official LSP plugins *and* Graphify, plus a third memory layer. Heaviest tool-schema cost surveyed. |
| **GitHub spec-kit**, **OpenSpec**, **BMAD** | Duplicate Superpowers' multi-phase workflow wholesale. Two process frameworks is strictly worse than one — swap *to*, never stack. |
| **tdd-guard** | Duplicates Superpowers' bundled `test-driven-development`. |
| **repomix**, **code2prompt** | Whole-repo context packing: more context to do less than LSP. |
| **claude-mem**, **mempalace** | Second memory layer → conflicting recall with Supermemory. |
| **Ref** | Overlaps Context7; only wins on *private* docs, and needs an API key. |
| **Semgrep** | Partially overlaps the security gate. OSV filled a real hole; this mostly doesn't. Add it as a CI gate if you want org-specific rules. |
| **zen-mcp**, **semgrep/mcp**, **trivy-mcp**, **cc-statusline** | Stale or archived. |
| Community "guardrail" frameworks | Every candidate had 0–2 stars and no third-party review. Use native `settings.json` deny rules + one small `PreToolUse` hook. |

## Context budget

The kit's dominant failure mode is context exhaustion, not missing capability — performance
degrades as the window fills, and tool definitions alone can cost tens of thousands of tokens
before the agent reads your first request. So:

- Run `/context` on a fresh session with the kit installed and know the number.
- Target **startup context under ~15%** of the window.
- Any new component must justify its share. Three things are **per-project, never global**:
  the `<lang>-lsp` plugin, `context7`, and GitHub MCP.
- `/clear` between unrelated tasks. The kitchen-sink session is a real failure mode.

## Requirements
- macOS or Linux (launchd auto-start is macOS-only; Linux runs `supermemory-server` manually)
- Node.js 18+ on PATH (Claude Code + Supermemory plugin need it)
- `gh` CLI (GitHub token) — auth verification for the official GitHub MCP
- `gitleaks` + `osv-scanner` (installers `brew install` both) — Security Gate layers 3 and 4

## Directory layout
```
├── SKILL.md            # recall skill — installs/loads the whole kit
├── install/
│   ├── bootstrap.sh    # curl-able: clone-or-pull latest, then install
│   ├── lib.sh          # shared: self-update (git pull) + refresh-in-place sync
│   ├── install.sh      # live bootstrap/update for Claude Code
│   └── hermes.sh       # live bootstrap/update for Hermes (~/.hermes/skills/)
├── skills/             # the portable skill files (copied to ~/.claude/skills/ or ~/.hermes/skills/)
└── evals/              # ~20 task cases + runner: how you prove a component earns its keep
```
