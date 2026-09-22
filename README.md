# Skill Starter Kit

One command to bootstrap a fresh Claude Code machine with the starter stack: multi-session
memory, a structured workflow, codebase knowledge graphs, anti-slop taste, an ultra-compact
response mode, per-stack language servers, official GitHub tooling, and an official
security gate.

> **Change to note:** **GSD was removed** — Superpowers already provides sub-agent-driven
> context triage, so a separate skill was redundant. The kit is 8 components.

## The components

| # | Name | Kind | What it does |
|---|------|------|--------------|
| 1 | **Graphify** | skill | Transforms a codebase into a queryable knowledge graph (stations = files, subway lines = imports). Navigate directly to relevant code instead of reloading the project. Trigger: `/graphify` |
| 2 | **Superpowers** | plugin (obra/superpowers-marketplace) | Enforces a structured multi-phase workflow (clarify → design → plan → code → verify) to stop drift and repeated file reads. Owns sub-agent orchestration for context triage. **Bundles systematic-debugging and test-driven-development skills** — don't add standalone ones. |
| 3 | **Supermemory** | plugin + LOCAL self-hosted server | Persists project context, user preferences, and state. Runs a local server on `:6767` (keeps data on your machine, works fully offline). |
| 4 | **Taste-Skill** | skills (`taste-code` + `taste-skill`) | Anti-slop harness: `taste-code` injects 10 minimalist structural rules against boilerplate, placeholder noise, redundant try/catch logs, and over-engineered architecture; `taste-skill` is the anti-slop frontend companion. |
| 5 | **LSP Plugins** | skill | Wires the language server (LSP) for your backend stack via Anthropic's **official** per-language LSP plugins (`typescript-lsp`, `pyright-lsp`, `gopls-lsp`, …) — plugin wires the connection, you install the server binary. Manual per-stack path for non-Claude-Code hosts. |
| 6 | **GitHub MCP** | skill → official server | Points at GitHub's **official** `github/github-mcp-server` (remote `https://api.githubcopilot.com/mcp/` or local) for issues, PRs, reviews, branches, actions, and security — not a hand-rolled `gh` driver. |
| 7 | **Caveman** | skills (`caveman*`) | Ultra-compressed response mode (`/caveman`, `/caveman-commit`, `/caveman-review`, `/caveman-compress`, `/caveman-help`, `/caveman-stats`). Cuts token usage by compressing communication while keeping technical accuracy; auto-drops for security/destructive/ambiguous cases. |
| 8 | **Security Gate** | skill → official plugins + gitleaks | Three layers: `security-guidance` (official — reviews each file edit in-session for injection/deserialization/DOM risks), `claude-security` (official — on-demand multi-agent deep scan, CWE-classified, SARIF output), and **gitleaks** for literal credentials in staged diffs (~170 rules) enforced by an agent-side pre-commit rule. |

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
Then inside Claude Code: `/plugin install superpowers@superpowers-marketplace`,
`/plugin install supermemory@supermemory-plugins`,
`/plugin install security-guidance@claude-plugins-official`, and
`/plugin install claude-security@claude-plugins-official`, and restart.

### Hermes
```bash
git clone https://github.com/feelthefusion/skill-starter-kit.git
cd skill-starter-kit
bash install/hermes.sh          # installs the portable skills + recall skill into ~/.hermes/skills/
```
Then open a **new Hermes session** and say **"set up the skill starter kit"**. (Hermes's
skill index loads at session start, so a new session is required.)

> On Hermes, the portable skills (Graphify, Taste, Caveman, LSP, GitHub MCP, Security Gate)
> install directly. Superpowers is a Claude Code plugin with no Hermes equivalent; Supermemory's
> local server is installable separately via its own installer; the official security plugins
> are Claude Code only (the gitleaks pre-commit layer works anywhere).

The installers are **live, not pinned** — see [Staying current](#staying-current). See
`/install/install.sh` (Claude Code) and `/install/hermes.sh` (Hermes); the `SKILL.md` at the
repo root is the recall skill that itself knows how to run all of this.

## Staying current

Nothing in the kit is version-pinned; every install pulls the latest:

| Layer | How it stays live |
|-------|-------------------|
| Kit skills (Graphify, Taste, Caveman, LSP, GitHub MCP, Security Gate) | Installers run `git pull --ff-only` on the repo first, then **refresh** installed skills in place — a re-run updates them instead of skipping |
| Plugins (Superpowers, Supermemory, security-guidance, claude-security, LSP plugins) | Registered by **GitHub repo, never a pinned ref** — Claude Code fetches the current version from origin |
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

## Requirements
- macOS or Linux (launchd auto-start is macOS-only; Linux runs `supermemory-server` manually)
- Node.js 18+ on PATH (Claude Code + Supermemory plugin need it)
- `gh` CLI (GitHub token) — auth verification for the official GitHub MCP

## Directory layout
```
├── SKILL.md            # recall skill — installs/loads the whole kit
├── install/
│   ├── bootstrap.sh    # curl-able: clone-or-pull latest, then install
│   ├── lib.sh          # shared: self-update (git pull) + refresh-in-place sync
│   ├── install.sh      # live bootstrap/update for Claude Code
│   └── hermes.sh       # live bootstrap/update for Hermes (~/.hermes/skills/)
└── skills/             # the portable skill files (copied to ~/.claude/skills/ or ~/.hermes/skills/)
```
