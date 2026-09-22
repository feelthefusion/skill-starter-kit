## Works with → (kit handoffs)

- **`lsp-plugins`** + grep are the default retrieval path; use this only for first-hour
  orientation in a large unfamiliar repo or a non-code corpus, and say when the graph was built.
- **Superpowers `brainstorming` / `writing-plans`** — the graph's job is to make the plan's
  file list right; once the plan exists, go back to LSP.
- **`docs-freshness`** (`--wiki` / DeepWiki) answers architectural questions about a
  *dependency*; this answers them about *your* repo.
- **`guardrails`** — the graph build is read-only; if a `graphify` step wants to write outside
  `graphify-out/`, that is a bug, not a step to approve.
