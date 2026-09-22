---
name: new-project-skill-starter-kit
description: "Bootstrap a new local device with all 7 starter kit skills. Recall me as 'starter kit' / 'new machine setup' / 'install the kit' to install Graphify, Superpowers, Supermemory, Taste, GSD, LSP, and GitHub MCP."
---

# New Project Skill Starter Kit (Recall Skill)

The kit is a single command to take a fresh Claude Code machine from zero to the full
7-skill setup. This skill is the "recall" entry point: loading it tells you exactly how to
install the kit on any device — this one or a brand-new one.

## When to Use
- User says "recall the starter kit," "set up a new machine with the kit," "new project skill
  starter kit" — or wants any subset of the 7 installed on a fresh device.
- Reproducing the environment on a new computer / new profile.
- Auditing what the kit contains.

Don't use for:
- Using an individual skill day-to-day (Taste, GSD, etc. load on their own triggers).

## The 7 Components
| # | Name            | Kind      | Source                                                  |
|---|-----------------|-----------|---------------------------------------------------------|
| 1 | Graphify        | skill     | Karpathy-style codebase → knowledge graph               |
| 2 | Superpowers     | plugin    | obra/superpowers-marketplace                            |
| 3 | Supermemory     | plugin +  | supermemoryai/claude-supermemory + LOCAL server (6767)  |
| 4 | Taste-Skill     | skills    | taste-code + taste-skill (anti-slop)                    |
| 5 | GSD             | skill     | sub-agent context triage                                |
| 6 | LSP Plugins     | skill     | language server per backend stack                       |
| 7 | GitHub MCP      | skill     | gh / GitHub MCP for issues, PRs, branches              |

## How to Recall / Run

**On this device** (kit already cloned locally):
```bash
bash ~/skill-starter-kit/install/install.sh
```

**On a brand-new device** — this is the recall flow:
```bash
# 1. clone the kit (this repo)
git clone https://github.com/feelthefusion/skill-starter-kit.git && cd skill-starter-kit
# 2. install all 7
bash install/install.sh
```

## What the installer does (per component)
1. **Graphify** — copies the skill into `~/.claude/skills/`. Trigger: `/graphify`.
2. **Superpowers** — registers `obra/superpowers-marketplace` and enables it in
   `~/.claude/settings.json`. First real enable: `/plugin install superpowers@superpowers-marketplace`.
3. **Supermemory** — registers the plugin marketplace, installs the local server binary,
   sets up a launchd auto-start (macOS), and appends `SUPERMEMORY_API_URL` +
   `SUPERMEMORY_CC_API_KEY` to the shell profile so recall/save hit `localhost:6767`.
   First enable: `/plugin install supermemory@supermemory-plugins`.
4. **Taste-Skill** — copies `taste-code` (minimalist code harness, 10 rules) and
   `taste-skill` (anti-slop frontend).
5. **GSD** — copies the skill (sub-agent context triage).
6. **LSP Plugins** — copies the skill; the actual LSP installs per stack happen at
   runtime when you invoke it.
7. **GitHub MCP** — copies the skill and verifies `gh` auth (issues/PRs/branches).

## After install (fresh device)
1. Restart the Claude Code session so skills + hooks load.
2. Run in Claude Code to finalize the plugins:
   ```
   /plugin install superpowers@superpowers-marketplace
   /plugin install supermemory@supermemory-plugins
   ```
3. For Supermemory only: on a truly fresh device the server hasn't booted once yet,
   so start it (`supermemory-server`) once to generate the API key, then re-run the
   installer to wire env vars, then `/plugin`.

## Verification
- `ls ~/.claude/skills/` shows graphify, taste-skill, taste-code, gsd, lsp-plugins, github-mcp.
- `~/.claude/settings.json` has both marketplaces under `extraKnownMarketplaces` and both
  plugins under `enabledPlugins`.
- `curl -s http://localhost:6767/` returns the supermemory local web UI (component 3).
- `gh auth status` is authenticated (component 7).