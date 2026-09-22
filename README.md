# Skill Starter Kit

One command to bootstrap a fresh Claude Code machine with all 7 starter skills:
multi-session memory, a structured workflow, codebase knowledge graphs, anti-slop taste,
context-triage sub-agents, per-stack language servers, and GitHub tooling.

## The 7 components

| # | Name | Kind | What it does |
|---|------|------|--------------|
| 1 | **Graphify** | skill | Transforms a codebase into a queryable knowledge graph (stations = files, subway lines = imports). Navigate directly to relevant code instead of reloading the project. Trigger: `/graphify` |
| 2 | **Superpowers** | plugin (obra/superpowers-marketplace) | Enforces a structured multi-phase workflow (clarify → design → plan → code → verify) to stop drift and repeated file reads. |
| 3 | **Supermemory** | plugin + LOCAL self-hosted server | Persists project context, user preferences, and state. Runs a local server on `:6767` (keeps data on your machine, works fully offline). |
| 4 | **Taste-Skill** | skills (`taste-code` + `taste-skill`) | Anti-slop harness: `taste-code` injects 10 minimalist structural rules against boilerplate, placeholder noise, redundant try/catch logs, and over-engineered architecture; `taste-skill` is the anti-slop frontend companion. |
| 5 | **GSD (Get Shit Done)** | skill | Sub-agent context triage: offloads isolated, hyper-specific side tasks to fresh lightweight sub-agents, harvests the result, and discards them to protect the main context window. |
| 6 | **LSP Plugins** | skill | Installs the official language server (LSP) for your backend stack (TS, Go, Python, Rust) so the agent gets real static types, imports, and diagnostics. |
| 7 | **GitHub MCP** | skill | Connects the agent to the remote repo for issues, PRs, and branch mechanics. |

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

> On Hermes, the portable skills (Graphify, Taste, GSD, LSP, GitHub MCP) install directly.
> Superpowers is a Claude Code plugin with no Hermes equivalent; Supermemory's local server
> is installable separately via its own installer.

The installers are **idempotent** — safe to re-run. See `/install/install.sh` (Claude Code)
and `/install/hermes.sh` (Hermes); the `SKILL.md` at the repo root is the recall skill that
itself knows how to run all of this.

## Requirements
- macOS or Linux (launchd auto-start is macOS-only; Linux runs `supermemory-server` manually)
- Node.js 18+ on PATH (Claude Code + Supermemory plugin need it)
- `gh` CLI (GitHub token) for component 7

## Directory layout
```
├── SKILL.md            # recall skill — installs/loads the whole kit
├── install/
│   ├── install.sh      # idempotent bootstrap for Claude Code (fresh device)
│   └── hermes.sh       # idempotent bootstrap for Hermes (~/.hermes/skills/)
└── skills/             # the portable skill files (copied to ~/.claude/skills/ or ~/.hermes/skills/)
```
