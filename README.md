# Skill Starter Kit

One command to bootstrap a fresh Claude Code machine with the starter stack: multi-session
memory, a structured workflow, codebase knowledge graphs, anti-slop taste, per-stack
language servers, and official GitHub tooling.

> **Change to note:** **GSD was removed** — Superpowers already provides sub-agent-driven
> context triage, so a separate skill was redundant. The kit is 6 components.

## The components

| # | Name | Kind | What it does |
|---|------|------|--------------|
| 1 | **Graphify** | skill | Transforms a codebase into a queryable knowledge graph (stations = files, subway lines = imports). Navigate directly to relevant code instead of reloading the project. Trigger: `/graphify` |
| 2 | **Superpowers** | plugin (obra/superpowers-marketplace) | Enforces a structured multi-phase workflow (clarify → design → plan → code → verify) to stop drift and repeated file reads. Owns sub-agent orchestration for context triage. |
| 3 | **Supermemory** | plugin + LOCAL self-hosted server | Persists project context, user preferences, and state. Runs a local server on `:6767` (keeps data on your machine, works fully offline). |
| 4 | **Taste-Skill** | skills (`taste-code` + `taste-skill`) | Anti-slop harness: `taste-code` injects 10 minimalist structural rules against boilerplate, placeholder noise, redundant try/catch logs, and over-engineered architecture; `taste-skill` is the anti-slop frontend companion. |
| 5 | **LSP Plugins** | skill | Wires the language server (LSP) for your backend stack (TS, Go, Python, Rust) into Claude Code's native LSP support for real static types, imports, and diagnostics. |
| 6 | **GitHub MCP** | skill → official server | Points at GitHub's **official** `github/github-mcp-server` (remote `https://api.githubcopilot.com/mcp/` or local) for issues, PRs, reviews, branches, actions, and security — not a hand-rolled `gh` driver. |

## Quick start (fresh device)

### Claude Code
```bash
git clone https://github.com/feelthefusion/skill-starter-kit.git
cd skill-starter-kit
bash install/install.sh
```
Then inside Claude Code: `/plugin install superpowers@superpowers-marketplace` and
`/plugin install supermemory@supermemory-plugins`, and restart.

### Hermes
```bash
git clone https://github.com/feelthefusion/skill-starter-kit.git
cd skill-starter-kit
bash install/hermes.sh          # installs the portable skills + recall skill into ~/.hermes/skills/
```
Then open a **new Hermes session** and say **"set up the skill starter kit"**. (Hermes's
skill index loads at session start, so a new session is required.)

> On Hermes, the portable skills (Graphify, Taste, LSP, GitHub MCP) install directly.
> Superpowers is a Claude Code plugin with no Hermes equivalent; Supermemory's local server
> is installable separately via its own installer.

The installers are **idempotent** — safe to re-run. See `/install/install.sh` (Claude Code)
and `/install/hermes.sh` (Hermes); the `SKILL.md` at the repo root is the recall skill that
itself knows how to run all of this.

## Requirements
- macOS or Linux (launchd auto-start is macOS-only; Linux runs `supermemory-server` manually)
- Node.js 18+ on PATH (Claude Code + Supermemory plugin need it)
- `gh` CLI (GitHub token) — auth verification for the official GitHub MCP

## Directory layout
```
├── SKILL.md            # recall skill — installs/loads the whole kit
├── install/
│   ├── install.sh      # idempotent bootstrap for Claude Code (fresh device)
│   └── hermes.sh       # idempotent bootstrap for Hermes (~/.hermes/skills/)
└── skills/             # the portable skill files (copied to ~/.claude/skills/ or ~/.hermes/skills/)
```
