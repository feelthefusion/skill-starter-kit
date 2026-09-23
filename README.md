# Skill Starter Kit

One command to bootstrap a fresh Claude Code **or Hermes** machine with the starter stack, and
one command to arm a new repo: a deterministic completion gate, action guardrails, browser-based
verification, fresh library docs, install hygiene, multi-session memory, a structured workflow,
anti-slop taste, per-stack language servers, official GitHub tooling, and a five-layer security
gate — wired so each component hands off to the next.

> **v3 (deep-research pass).** The kit is **14 components + a project template**. Added because
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
| 13 | **Consistency** | skill (kit-owned) | Features that appear on several surfaces — coupons, prices, totals, tax, shipping thresholds, stock, points, subscriptions — stay right everywhere: **map every surface** (drawer, cart, checkout, confirmation, account, emails/SMS, admin, API) → **one server calculation** → **one Playwright spec** asserting every surface agrees, plus edge cases (invalid/expired/minimum/removed/reload). Runs in `verify`. | spec in `verify` |
| 14 | **Cloud CLIs** | skill (kit-owned) + CLIs + vendor skills | Installs **`gh`**, **`railway`**, **`wrangler`** + **`cloudflared`**, **`aws`**, **`gcloud`**, **`gws`** (Google Workspace), **`gam`** (GAM7, Workspace admin) (brew/npm/uv, or official release binaries on Linux) and live-fetches the vendors' own skills: Railway `use-railway`, Cloudflare `cloudflare` · `wrangler` · `workers-best-practices`, AWS `deploy-on-aws`, Google `gcloud`, Google Workspace core `gws-*` (Claude Code; Hermes' bundled `google-workspace` covers it). `cloud-clis` routes jobs to the right CLI, checks the signed-in account before changes, keeps secret values out of the transcript, and deploys only after `verify`. CLI first; vendor MCP servers are opt-in. `guard.sh` blocks irreversible cloud deletes. | guard |

## How they work together

The root [`SKILL.md`](SKILL.md) is the workflow map. Short version of a feature, end to end:

1. **Orient** with LSP + grep (5); Graphify (1) only for a large unfamiliar repo.
2. **Shape** with Superpowers brainstorm → plan (2); `taste-code` rule 4 on the plan (4); recall from Supermemory (3).
3. **Before any dependency**: stdlib first (4) → does it exist / is it the one I meant (11) → is it old enough, scripts off, locked (8). The package manager enforces the last one even if the agent forgets.
4. **Build**: TDD (2) · current API (11) · taste shapes it (4) · `format.sh` after every edit (12) · LSP diagnostics (5) · `guard.sh` blocks the irreversible (12).
5. **See it**: design-taste (4) → browser compare loop (10); multi-surface features get a surface map + agreement spec (13); bugs via systematic-debugging (2) with DevTools evidence (10).
6. **Prove it**: `verify` at turn end (9); fix causes, never suppress (4); output verbatim, Caveman hands off (7).
7. **Review**: fresh-context code review (2); reject findings that violate taste (4); `/claude-security` before a PR (8).
8. **Deploy**: right account first, `railway up` / `wrangler deploy` / `aws`, then prove it live (14).
9. **Ship**: gitleaks → commit (`caveman-commit` opt-in) → PR via `gh` / GitHub MCP (6) → merge when CI agrees with `verify`.
10. **Remember**: Supermemory (3), `AGENTS.md` (0), or a skill.

Every kit-owned skill ends with a **Works with →** section stating exactly these handoffs, so
the component you're in tells you which one is next.

## Quick start

**Fresh device — always latest:**
```bash
curl -fsSL https://raw.githubusercontent.com/feelthefusion/skill-starter-kit/main/install/bootstrap.sh | bash              # Claude Code
curl -fsSL https://raw.githubusercontent.com/feelthefusion/skill-starter-kit/main/install/bootstrap.sh | bash -s -- hermes # Hermes
```
Or `git clone https://github.com/feelthefusion/skill-starter-kit.git && bash skill-starter-kit/install/install.sh` (`hermes.sh` for Hermes).

**Claude Code:** the installer finds `claude` (on PATH, or bundled inside the Claude desktop
app) and installs/updates all six plugins itself, writes a 10-line always-on stanza to
`~/.claude/CLAUDE.md`, and puts `kit-init` on your PATH. Restart Claude Code once (or
`/reload-plugins`). If no `claude` binary is found, the installer prints the `/plugin install`
lines to paste (see *Manual triggers* below).

**Hermes:** skills are installed and the guardrails hooks are wired into `config.yaml` with
`hermes config set` (skipped if you already have custom hooks — see *Manual triggers*). Open a
new session; the skill index loads at start. Superpowers is **not** installed on Hermes by
default: Hermes bundles the equivalent skills, and its plugin scanner flags Superpowers' test
scripts (use `--force` if you want it anyway — one or the other, never both).

### First thing in a new repo
```bash
kit-init            # = bash <kit>/install/init-project.sh   (installed on PATH by the installer)
```
Writes `AGENTS.md` (+ `CLAUDE.md` pointer), `verify.sh`, `.claude/settings.json` (Stop hook +
guardrails hooks + deny-list + sandbox), `.claude/hooks/{guard,format}.sh`, and the install-hygiene
config for your package manager (`.npmrc` / `pnpm-workspace.yaml` / `.yarnrc.yml` / `bunfig.toml`).
Never overwrites your files: an existing `.claude/settings.json` is **merged** (your hooks kept,
kit hooks/deny/sandbox added), an existing `.npmrc` gets only the missing hygiene keys
(`ignore-scripts` is added *commented* — enable after one clean build without scripts), and a real
`CLAUDE.md` is kept as the instructions file. Then: edit `AGENTS.md`, trim `verify.sh`, **break
something and confirm the gate blocks the turn**, add your stack's irreversible commands to
`guard.sh`, commit.

## One line to install, one command per repo — everything else is automatic

```bash
curl -fsSL https://raw.githubusercontent.com/feelthefusion/skill-starter-kit/main/install/bootstrap.sh | bash                 # Claude Code
curl -fsSL https://raw.githubusercontent.com/feelthefusion/skill-starter-kit/main/install/bootstrap.sh | bash -s -- hermes    # Hermes
```
```bash
kit-init      # in any repo: AGENTS.md, generated verify.sh, hooks, deny-list, sandbox, hygiene, LSP + context7 + GitHub MCP, baseline run
```

**What the one-liner does for you (Claude Code):** clones/pulls the kit · fetches Graphify, Caveman,
Taste from their upstream repos · installs all 14 skills · finds `claude` (PATH or the desktop app's
bundle) and installs/updates the six plugins (Superpowers, Supermemory, security-guidance,
claude-security, playwright, chrome-devtools-mcp) · installs and auto-starts the local Supermemory
server · installs gitleaks, osv-scanner, uv · writes a 10-line always-on stanza to
`~/.claude/CLAUDE.md` · puts `kit-init` on your PATH. Restart Claude Code once.

**What it does for you (Hermes):** the same skills · wires guardrails hooks into `config.yaml`
(merging with any hooks you already have) · sets Supermemory as the memory provider when the local
server is running · puts `kit-init` on your PATH. Superpowers is not installed on Hermes by default
(Hermes bundles the equivalents; its scanner flags Superpowers' test scripts).

**What `kit-init` does in a repo:** detects the stack (npm/pnpm/yarn/bun, Python, Go, Rust) and
**generates `verify.sh` from the scripts that actually exist** · merges hooks/deny/sandbox into
`.claude/settings.json` (yours kept) · adds hygiene keys to `.npmrc` (`ignore-scripts` commented in
existing repos) · keeps a real `CLAUDE.md` if you have one · installs the stack's LSP, `context7`
and read-only GitHub MCP at project scope · **runs `verify.sh` once** and tells you GREEN or RED.

**Then just prompt.** Skills are model-invoked; the stanza and the `skill-starter-kit` recall
skill make the loop the default; hooks are deterministic. You never name a skill.

### The complete manual list
```text
# edit once per repo (the agent cannot infer these)
$EDITOR AGENTS.md            # replace the <placeholders>; ≤12 lines

# on demand, per task — deliberately not automatic
/graphify                    # knowledge graph: only for a large unfamiliar repo or non-code corpus
/claude-security             # deep semantic security review, before a PR
caveman mode                 # compress the final summary only; "stop caveman" to turn off
/goal gate add "./verify.sh" # Hermes: per-task gate (the pre_verify hook already covers the default)
```
```bash
# sign in once per machine (each opens the browser; skip the platforms you don't use)
gh auth login
railway login
wrangler login
aws configure sso
gcloud auth login
gws auth setup && gws auth login
gam oauth create
```
```bash
# only if the installer told you it could not do it itself
hermes plugins install obra/superpowers --enable --force     # Superpowers on Hermes instead of the bundled skills
claude plugin install <lang>-lsp@claude-plugins-official --scope project   # a stack kit-init did not detect
```

## Staying current — automatic, event-driven, no schedule

Nothing is pinned and nothing is copied: the kit ships only its own files, and every third-party
skill is fetched fresh from its author's repo at install/update time.

**Updates apply themselves.** Three triggers, all events — no cron, no polling loop:

| Trigger | What fires | Covers |
|---|---|---|
| **You start a session** | Claude Code `SessionStart` / Hermes `on_session_start` → `kit-update --if-stale 1 --background` (returns instantly; checks at most once an hour) | kit, Graphify, Caveman, Taste, armed repos |
| **GitHub push** (optional, instant) | GitHub webhook → Hermes webhook route → `kit-update` (route returns `[SILENT]`: no agent run, zero LLM cost) | repos you administer — the kit or your fork |
| **You ask** | `kit-update` (apply now) · `kit-update --check` (report; exit 10 = updates) | everything |

`kit-update` compares remote HEADs (`git ls-remote`, ~1 s) with what's installed, and only when
something moved: pulls the kit → re-fetches upstream skills → refreshes installed skills for every
host you set up → updates hook scripts in every repo you ran `kit-init` in. Repo files you edited or
deleted are detected (compared against every version the kit ever shipped) and left alone;
`verify.sh`, `AGENTS.md` and `settings.json` are always yours. Log: `~/.config/skill-starter-kit/update.log`.

Turn on push updates (needs Hermes and `gh`; no tunnel account needed):
```bash
hermes gateway install                 # gateway as a login service (receives the webhook)
kit-webhook enable --tunnel            # route + silent script + cloudflared tunnel service + GitHub webhook
kit-webhook status                     # public URL, listener, last update runs
```
The tunnel service starts at login and re-points the GitHub webhook whenever its URL changes.
Have your own stable host (Tailscale Funnel, a reverse proxy)? Use `kit-webhook enable --url https://<host>` instead.
Deliveries are HMAC-signed; the route runs `kit-update` and returns `[SILENT]` — no agent turn, no LLM cost.
Undo: `kit-webhook disable`.

GitHub only sends webhooks for repos you administer, so upstream skills you don't own are picked
up by the session-start check instead.

| Layer | How it stays live |
|-------|-------------------|
| Kit-owned skills | `git pull --ff-only`, installed copies refreshed in place |
| Third-party skills (Graphify, Caveman, Taste) | Fetched from upstream (`install/upstreams.tsv`), kit scoping re-applied from `install/overlays/`, commit recorded in `.upstream` |
| Plugins (Superpowers, Supermemory, Anthropic, LSP) | Installed/updated by the installer; Claude Code refreshes marketplaces itself |
| CLIs (gitleaks, osv-scanner, uv) | brew, or official GitHub release binaries on Linux |

`KIT_NO_AUTOUPDATE=1` skips the session-start hook · `KIT_NO_UPSTREAM=1` reuses the last fetched
copies · offline → soft-fails to what's already installed.

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
- Node.js 22+ (`wrangler` requires it; everything else runs on 18+)
- Installed automatically (brew, or official release binaries / npm / uv on Linux): `gitleaks`, `osv-scanner`, `uv` (for `uvx zizmor`), `gh`, `railway`, `wrangler`, `cloudflared`, `aws`, `gcloud`, `gws`, `gam`
- Claude Code sandbox: macOS Seatbelt built in; Linux needs `bubblewrap` + `socat`

## Directory layout
```
├── SKILL.md                 # recall skill + workflow map (single source; installers copy it)
├── install/
│   ├── bootstrap.sh         # curl-able: clone-or-pull latest, then install
│   ├── lib.sh               # self-update, UPSTREAM FETCH + overlays, refresh-in-place sync
│   ├── upstreams.tsv        # skill → upstream repo/ref/path
│   ├── overlays/<skill>/    # kit scoping re-applied over fresh upstream (description, PREPEND, replace/)
│   ├── kit-update.sh        # detect + apply updates (kit, upstream skills, armed repos)
│   ├── kit-webhook.sh       # GitHub push → Hermes webhook → kit-update
│   ├── install.sh           # Claude Code
│   ├── hermes.sh            # Hermes
│   └── init-project.sh      # per repo: AGENTS.md, verify.sh, hooks, settings, .npmrc
├── skills/                  # the kit's own skills (third-party ones are fetched, never copied)
│   └── guardrails/templates # guard.sh, format.sh, verify-nudge.sh, claude-settings.json, hermes-hooks.yaml
├── templates/project/       # AGENTS.md, CLAUDE.md, .npmrc, pnpm-workspace.yaml, .yarnrc.yml, bunfig.toml
└── evals/                   # task cases + runner: how you prove a component earns its keep
```

## License

Public domain ([Unlicense](LICENSE)). Use, copy, modify, sell, relicense — anything, no conditions.
