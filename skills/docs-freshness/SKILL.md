---
name: docs-freshness
description: "Stop writing code against APIs that no longer exist. Fetch version-specific library documentation before using an unfamiliar or fast-moving dependency, prefer `--help` and allowlisted doc URLs over guessing from memory, and never install a package name the model produced from memory without checking it exists. Use when writing code against a third-party library, when an API call fails unexpectedly, or when about to add a dependency."
---

# Docs Freshness: the Model's Memory Is Older Than Your Lockfile

Every other component in the kit reasons about *your* material — Supermemory your history,
Graphify your code, LSP your types, the review layers your diff. None of them knows what
shipped in a third-party library last month. The model's weights are stale relative to your
`package.json`, and the failure modes are specific:

- **Removed or renamed APIs** — code that was correct two versions ago.
- **Semantically wrong but valid usage** — compiles, typechecks, behaves wrong. LSP cannot catch
  this; it only knows the signature exists.
- **Invented packages** — the model recommends a plausible name that never existed, and an
  attacker has pre-registered it (**slopsquatting**). This is the one where stale knowledge has
  a supply-chain payload.

**Scope:** external library knowledge. Not your codebase (LSP + grep), not general web research.

## The Ladder — cheapest first

Reach for the lowest rung that answers the question. Each rung up costs more context.

1. **`--help` / `man` / `<cmd> help`.** The most context-efficient source that exists, always
   matches the installed version, and works for any CLI the model has never seen:
   `Use 'foo --help' to learn the foo tool`.
2. **The installed source.** `node_modules/<pkg>`, the venv's package dir, `go doc`. This is
   *definitionally* the version you are running.
3. **An allowlisted doc URL.** Paste or fetch the specific page. Allowlist the domains you hit
   often (`/permissions`) so it stops prompting.
4. **`llms.txt`.** Many projects now publish an agent-oriented digest at `/llms.txt` — try it
   before scraping a docs site.
5. **Context7 MCP** — version-specific docs and examples on demand:
   `/plugin install context7@claude-plugins-official`. Enable **per-project**, for projects with
   fast-moving or unfamiliar dependencies. It is in Anthropic's official marketplace, but a
   standing MCP server is a standing context tax — tool definitions are paid every session
   whether or not you use them.
6. **DeepWiki** (`https://mcp.deepwiki.com/mcp`, free, no auth) for *architectural* questions
   about a public repo — "how does library X actually implement Y" — where Context7 answers
   API-reference questions. Public indexed repos only.

## Before Adding Any Dependency

Two questions, in order:

1. **Does `taste-code` rule 5 allow it?** Prefer the standard library over a package for
   something stdlib does in a line. Most "I need a library for this" is wrong.
2. **Does the package exist, and is it the one you meant?** If *the agent proposed the name*
   rather than the user naming it, verify before installing:

```bash
npm view <pkg>                  # real? how recently published? what repo?
pip index versions <pkg>
```

Red flags: no repository link, published days ago, download counts near zero, a name one
character off a popular package. On any of those — stop and confirm with the user. The
deterministic form of this check (`npm view <pkg> time.created repository.url`, age > 7 days,
plus the package manager's own release-age cooldown) is `security-gate` layer 5; run
`osv-scanner scan source -r .` (layer 4) after the install lands.

## Procedure

1. About to use an unfamiliar or fast-moving API? Get the current signature **before** writing
   the call, not after the error.
2. Use the lowest rung on the ladder that answers it.
3. Anchor to the **installed version** — read it from the lockfile, not from assumption.
4. Write the code. Cite the source in a comment **only** when the behavior is non-obvious
   (`taste-code` rule 9 — no comment fluff).
5. An API call fails unexpectedly → suspect stale knowledge before suspecting your own logic.
   Re-check the current signature first; it is a cheaper hypothesis than a debugging session.

## Pitfalls

- **Confident wrong recall.** The model does not signal uncertainty about an API it "remembers".
  Version-sensitive code deserves a check even when nothing feels uncertain.
- **Reading docs for the wrong version.** Latest-on-the-website ≠ what your lockfile pins.
  Anchor to the installed version, every time.
- **Enabling every docs MCP.** One is enough. Context7 covers public library docs; adding a
  second overlapping server buys nothing and costs context in every session.
- **Fetching a whole docs site.** Pull the specific page or the `llms.txt`, not the sitemap.
- **Trusting a search-result snippet over the installed source.** Rung 2 beats rung 3 whenever
  it can answer.

## Works with →
- **`security-gate`** — this skill asks "is it real and the one I meant"; layer 5 asks "is it
  old enough and does it run scripts". Same moment, in that order, before every install.
- **`taste-code`** rule 5 comes first: most "I need a library" is wrong.
- **`lsp-plugins`** verifies the signature compiles; this skill verifies it is the *current*
  API. Both are needed for fast-moving dependencies.
- **`graphify`** (`--wiki`/DeepWiki) answers *architectural* questions about a dependency;
  Context7 answers reference questions.

## Verification

- `foo --help` output appears in the transcript before code using `foo` is written.
- For a pinned dependency, the version consulted matches the lockfile.
- A deliberately fabricated package name fails the `npm view` check instead of being installed.
- Context7 (if enabled) returns docs for the pinned version, not just the latest.
