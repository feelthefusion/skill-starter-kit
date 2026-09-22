---
name: skill-starter-kit
description: "Bootstrap a new local device with the skill starter kit. Recall as 'starter kit' / 'new machine setup' / 'install the kit' to install the 11 components: Graphify, Superpowers, Supermemory, Taste, LSP, GitHub MCP, Caveman, Security Gate, Verify Gate, Browser Verify, and Docs Freshness."
---

# Skill Starter Kit (Recall Skill)

The kit is a single command to take a fresh Claude Code machine from zero to the full
11-component setup. This skill is the "recall" entry point: loading it tells you exactly how
to install the kit on any device — this one or a brand-new one.

## When to Use
- User says "recall the starter kit," "set up a new machine with the kit," "new machine
  setup" — or wants any subset of the kit's components installed on a fresh device.
- Reproducing the environment on a new computer / new profile.
- Auditing what the kit contains.

Don't use for:
- Using an individual component day-to-day (Taste, LSP, etc. load on their own triggers).

## The Components
| # | Name          | Kind      | Source                                                   |
|---|---------------|-----------|----------------------------------------------------------|
| 1 | Graphify      | skill     | ON-DEMAND orientation in a large unfamiliar repo / non-code corpora. NOT the default retrieval path |
| 2 | Superpowers   | plugin    | obra/superpowers-marketplace — owns workflow + sub-agent orchestration; bundles 15 skills incl. systematic-debugging, TDD, code-review, worktrees |
| 3 | Supermemory   | plugin +  | supermemoryai/claude-supermemory + LOCAL server (6767)   |
| 4 | Taste-Skill   | skills    | taste-code + taste-skill (anti-slop; spike rule; reviewer-findings rule) |
| 5 | LSP Plugins   | skill     | official Anthropic LSP plugins — 13 languages, install PER-STACK only |
| 6 | GitHub MCP    | skill     | OFFICIAL github/github-mcp-server — read-only + per-project by default |
| 7 | Caveman       | skills    | caveman* — OPT-IN compression of final summaries only, never verification output |
| 8 | Security Gate | skill +   | security-guidance + claude-security + gitleaks (secrets) + osv-scanner (deps) |
| 9 | **Verify Gate** | skill + | one `verify` command + Stop hook + evidence discipline. The ONLY component that blocks a false "done" |
| 10 | **Browser Verify** | skill + | playwright + chrome-devtools-mcp: screenshot-compare loop, smoke E2E, console/network debugging |
| 11 | **Docs Freshness** | skill + | `--help` → installed source → llms.txt → context7 ladder; verify a package exists before installing |

> **GSD was removed** — Superpowers already provides sub-agent-driven context triage.
> **Never add** standalone systematic-debugging, TDD, code-review, or worktree skills:
> Superpowers bundles all four. See the README's "Deliberately rejected" table.

## How to Recall / Run

Installs and updates are the **same command** — the installers pull the kit from GitHub, then
refresh installed skills in place. There is nothing version-pinned in this kit.

**On this device** (kit already cloned locally):
```bash
bash ~/skill-starter-kit/install/install.sh        # Claude Code
# or for Hermes:
bash ~/skill-starter-kit/install/hermes.sh
```

**On a brand-new device** — one-liner, always latest:
```bash
curl -fsSL https://raw.githubusercontent.com/feelthefusion/skill-starter-kit/main/install/bootstrap.sh | bash
# Hermes: ...| bash -s -- hermes
```
It clones (or pulls) `~/.skill-starter-kit` and runs the installer from that fresh checkout.
Manual equivalent:
```bash
git clone https://github.com/feelthefusion/skill-starter-kit.git && cd skill-starter-kit
bash install/install.sh
```

## Liveness rules (how each layer stays current)
- **Kit skills** — `git pull --ff-only` before copying; installed copies are REFRESHED, never
  skipped. Re-running is the update path.
- **Plugins** — marketplaces registered by GitHub repo (no pinned ref), so Claude Code fetches
  the latest; `/plugin` to refresh, `/reload-plugins` to apply without restart.
- **Supermemory binary** — upstream `supermemory.ai/install` re-runs each time.
- **GitHub MCP** — official remote endpoint, updated server-side.
- Dirty repo tree → pull is skipped (never clobbers uncommitted work). Offline → soft-fails to
  the local copy. `KIT_NO_PULL=1` forces local-copy install.
- Local edits to *installed* skill copies are overwritten — edit in the repo instead.
- Installed revision is recorded in `.kit-version` beside the installed skills.

## What the installer does (per component)
1. **Graphify** — copies the skill into `~/.claude/skills/`. Trigger: `/graphify`.
2. **Superpowers** — registers `obra/superpowers-marketplace` and enables it in
   `~/.claude/settings.json`. First real enable: `/plugin install superpowers@superpowers-marketplace`.
   This owns sub-agent orchestration for context triage.
3. **Supermemory** — registers the plugin marketplace, installs the local server binary,
   sets up a launchd auto-start (macOS), and appends `SUPERMEMORY_API_URL` +
   `SUPERMEMORY_CC_API_KEY` to the shell profile so recall/save hit `localhost:6767`.
   First enable: `/plugin install supermemory@supermemory-plugins`.
4. **Taste-Skill** — copies `taste-code` (minimalist code harness, 10 rules) and
   `taste-skill` (anti-slop frontend).
5. **LSP Plugins** — copies the skill; the actual language servers install per stack when
   you invoke it (works with Claude Code's native LSP support).
6. **GitHub MCP** — registers the OFFICIAL `github/github-mcp-server` (remote
   `https://api.githubcopilot.com/mcp/` or local Docker) for issues/PRs/branches, and
   verifies `gh` auth.
7. **Caveman** — copies the `caveman*` skills (opt-in summary compression: `/caveman`,
   `/caveman-commit`, `/caveman-review`, `/caveman-compress`, `/caveman-help`, `/caveman-stats`).
   No auto-trigger: it fires only when the user asks for it by name.
8. **Security Gate** — copies the `security-gate` skill, registers the OFFICIAL
   `anthropics/claude-plugins-official` marketplace, and enables `security-guidance` (in-session
   edit review) + `claude-security` (deep scan, SARIF). Optional: `brew install gitleaks` for a
   secrets pre-commit hook. First enable:
   `/plugin install security-guidance@claude-plugins-official` and
   `/plugin install claude-security@claude-plugins-official`. Also `brew install gitleaks
   osv-scanner` for the two portable layers.
9. **Verify Gate** — copies the skill + template `verify.sh`, enables `hookify`. **Do this
   first in any new project:** copy the template, trim it to the stack's real checks, wire the
   Stop hook. Nothing else in the kit blocks a false "done".
10. **Browser Verify** — copies the skill, enables `playwright` + `chrome-devtools-mcp`.
11. **Docs Freshness** — copies the skill, registers `context7` **disabled** (enable
    per-project; a standing docs MCP is a standing context tax).

## After install (fresh device)
1. Restart the Claude Code session so skills + hooks load.
2. Run in Claude Code to finalize the plugins:
   ```
   /plugin install superpowers@superpowers-marketplace
   /plugin install supermemory@supermemory-plugins
   /plugin install security-guidance@claude-plugins-official
   /plugin install claude-security@claude-plugins-official
   /plugin install hookify@claude-plugins-official
   /plugin install playwright@claude-plugins-official
   /plugin install chrome-devtools-mcp@claude-plugins-official
   ```
   Then **per-project, not globally**: the matching `<lang>-lsp`, `context7`, GitHub MCP.
3. For Supermemory only: on a truly fresh device the server hasn't booted once yet,
   so start it (`supermemory-server`) once to generate the API key, then re-run the
   installer to wire env vars, then `/plugin`.

## Verification
- `ls ~/.claude/skills/` shows graphify, taste-skill, taste-code, caveman*, lsp-plugins,
  github-mcp, security-gate, verify-gate, browser-verify, docs-freshness.
- A repo with the kit applied has an executable `verify` (script or task) that exits 0 clean and
  names the failing check when dirty, and a Stop hook that blocks the turn on failure
  (component 9 — test it by breaking something on purpose).
- `cat ~/.claude/skills/.kit-version` shows the installed kit revision; it matches
  `git -C ~/skill-starter-kit rev-parse --short HEAD`.
- `~/.claude/settings.json` has all three marketplaces under `extraKnownMarketplaces` and the
  four plugins under `enabledPlugins`.
- `curl -s http://localhost:6767/` returns the supermemory local web UI (component 3).
- The GitHub MCP server is registered and `get_me` authenticates (component 6).
- `/plugin` lists security-guidance + claude-security as active; introducing `eval(` in a
  scratch edit gets flagged in-session (component 8).