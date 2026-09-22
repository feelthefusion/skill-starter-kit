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

## Quick Reference (server per stack)

| Stack     | Server (package)                         | Install (per-project)          |
|-----------|------------------------------------------|--------------------------------|
| TypeScript/JS | TypeScript language server (`typescript-language-server`, or tsserver from `typescript`) | `npm i -D typescript-language-server typescript` |
| Go        | `gopls` (official)                       | `go install golang.org/x/tools/gopls@latest` |
| Python    | `pyright` (official) or `pylsp`          | `npm i -g pyright` or `pip install python-lsp-server` |
| Rust      | `rust-analyzer`                          | via `rustup component add rust-analyzer` |

## How to Run (Procedure)

1. **Identify the stack.** Ask the agent or inspect for markers: `tsconfig.json` → TS; `go.mod` →
   Go; `pyproject.toml`/`requirements.txt` → Python; `Cargo.toml` → Rust. Do not guess.
2. **Install the matching server** from the Quick Reference table.
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

## Verification
- `typecheck`-style check or "no errors" from the server for a file known to be correct.
- Definitions / references resolve to the right file for a probe symbol.
- The server process is running and attached to the current workspace.