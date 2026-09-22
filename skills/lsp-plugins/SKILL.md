---
name: lsp-plugins
description: "Install the official language server (LSP) for the backend stack so the agent gets real static types, imports, and diagnostics instead of guessing from file reads."
---

# LSP Plugins: Language Server for the Backend Stack

Language servers give the agent precise, current answers about types, imports, symbols, and
diagnostics — instead of re-reading entire files and inferring. This skill installs the right
server for the stack in use, so the agent can ask structural questions with correct answers.

**What it does NOT do:** change how you edit code. It adds a fast, accurate structural query
path (types, references, definitions, errors) alongside normal file editing.

## When to Use
- Starting work on a codebase in an unfamiliar / typestrict stack.
- Any time the agent is unsure about types, imports, or whether code will typecheck — an LSP
  query is cheaper and more reliable than eyeballing the whole file.
- Setting up a new machine / new project (part of the Project Starter Kit run).

Don't use for:
- Interpretation of semantics or business logic — that is not a structural concern.
- In-place replacement of the build/test pipeline.

## Prerequisites
- The backend stack is identified (see table). Project uses a package manager with the server
  available (npm/pnpm/yarn, go, pip/uv, cargo).
- The editor/agent is wired to run the LSP server over the standard JSON-RPC/LSP protocol.

## Preferred Path: Official Anthropic LSP Plugins (Claude Code)

Anthropic ships first-party per-language LSP plugins in the official marketplace — use these
before hand-wiring servers. In a Claude Code session:
```
/plugin install typescript-lsp@claude-plugins-official   # TypeScript/JS
/plugin install pyright-lsp@claude-plugins-official      # Python
/plugin install gopls-lsp@claude-plugins-official        # Go
/plugin install rust-analyzer-lsp@claude-plugins-official # Rust
/plugin install clangd-lsp@claude-plugins-official       # C/C++
```
If the marketplace is missing: `/plugin marketplace add anthropics/claude-plugins-official`.
Also available: `csharp-lsp`, `jdtls-lsp`, `kotlin-lsp`, `liquid-lsp`, `lua-lsp`, `php-lsp`,
`ruby-lsp`, `swift-lsp` — **13 LSP plugins in total: 12 Anthropic first-party plus
`liquid-lsp`, which is Shopify-owned** (verified against the live `marketplace.json`).
**The plugin wires the connection but does NOT install the server binary** — install the
binary from the table below first (the plugin's LSP tool then gives automatic post-edit
diagnostics plus navigation: definitions, references, hover types, call hierarchies).
Cloud sessions don't start plugin language servers. Hosts without the marketplace (e.g.
Hermes) use the manual path alone.

**Install per-stack only, never the whole set.** Every installed plugin's tools and metadata
occupy context in projects that never use that language — a Python-only repo should not be
paying for `gopls-lsp` and `typescript-lsp`. Detect the stack (step 1), install the one or two
that match, and skip the rest. This is the kit component with the best ratio of accuracy gained
to context spent; scoping it is what keeps that true.

## Server Binaries (install per stack — required for the plugins too)

| Stack     | Server (package)                         | Install (per-project)          |
|-----------|------------------------------------------|--------------------------------|
| TypeScript/JS | TypeScript language server (`typescript-language-server`, or tsserver from `typescript`) | `npm i -D typescript-language-server typescript` |
| Go        | `gopls` (official)                       | `go install golang.org/x/tools/gopls@latest` |
| Python    | `pyright` (official) or `pylsp`          | `npm i -g pyright` or `pip install python-lsp-server` |
| Rust      | `rust-analyzer`                          | via `rustup component add rust-analyzer` |

## How to Run (Procedure)

1. **Identify the stack.** Ask the agent or inspect for markers: `tsconfig.json` → TS; `go.mod` →
   Go; `pyproject.toml`/`requirements.txt` → Python; `Cargo.toml` → Rust. Do not guess.
2. **Install the server binary** from the table, then **install the matching official
   plugin** (Claude Code) — or run the binary alone on other hosts.
3. **Restart** the editor/agent so the server attaches to the workspace.
4. **Verify** the server is live (see Verification) before relying on it.
5. **Use it** for structural queries: symbols, definitions, references, type of expression,
   file diagnostics — the primary reason it was installed.

## Pitfalls
- **Wrong server for the stack.** Installing pyright into a TS project wastes the step. Identify
  the stack first, every time.
- **Server started before project load.** It answers stale/wrong until the workspace is reopened.
- **Version skew.** A server older than the toolchain can emit phantom diagnostics. Keep the
  server matching the installed toolchain version.
- **Monorepos / multiple languages.** Install per-language servers touched in the task; don't
  collapse to one.

## Works with →
- **`verify-gate`** — LSP diagnostics catch the type error in the file you just edited; the gate
  catches the regression three modules away. Fix LSP errors *before* ending the turn so the
  gate bounces less.
- **`graphify`** — this is the default retrieval path; Graphify is for orientation only.
- **`guardrails`** `format.sh` runs after each edit; LSP re-reads the formatted file.
- **`docs-freshness`** — LSP knows a signature *exists*; it cannot know the call is semantically
  right for the installed version. Different question, different tool.

## Verification
- `typecheck`-style check or "no errors" from the server for a file known to be correct.
- Definitions / references resolve to the right file for a probe symbol.
- The server process is running and attached to the current workspace.