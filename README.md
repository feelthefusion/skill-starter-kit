# New Project Skill Starter Kit

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

```bash
git clone https://github.com/feelthefusion/skill-starter-kit.git
cd skill-starter-kit
bash install/install.sh
```

Then inside Claude Code, finalize the two plugins and restart the session:

```
/plugin install superpowers@superpowers-marketplace
/plugin install supermemory@supermemory-plugins
```

The installer is **idempotent** — safe to re-run. See `/install/install.sh` for details;
the `SKILL.md` at the repo root is the recall skill that itself knows how to run all of this
(load it via "recall the starter kit / new machine setup").

## Requirements
- macOS or Linux (launchd auto-start is macOS-only; Linux runs `supermemory-server` manually)
- Node.js 18+ on PATH (Claude Code + Supermemory plugin need it)
- `gh` CLI (GitHub token) for component 7

## Directory layout
```
├── SKILL.md            # recall skill — installs/loads the whole kit
├── install/
│   └── install.sh      # idempotent bootstrap for a fresh device
└── skills/             # the portable skill files (copied to ~/.claude/skills/)
    ├── graphify/
    ├── taste-skill/
    ├── taste-code/
    ├── gsd/
    ├── lsp-plugins/
    └── github-mcp/
```