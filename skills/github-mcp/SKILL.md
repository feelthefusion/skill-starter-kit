---
name: github-mcp
description: "Connect the agent to the remote repository to handle issues, PRs, and branch mechanics through a GitHub server/MCP."
---

# GitHub MCP: Repository Connection

Connects the coding agent to the remote GitHub repository so it can operate on issues, pull
requests, reviews, and branch mechanics without leaving the agent and hand-syncing state. It
keeps local and remote views honest.

**What it does NOT do:** replace reasoning about code, or auto-merge without review. It
coordinates GitHub state; your judgment still decides content and correctness.

## When to Use
- Opening / updating / closing issues and PRs from within a task.
- Branch work: create/checkout/list/delete branches, sync state between local and remote.
- Review flows: comment, request changes, approve, and reconcile review feedback.
- Any multi-repo or shared-team workflow where remote state must be current.

Don't use for:
- Actual code review judgement beyond GitHub mechanics (that's a human/other skill).
- Long-running automation the agent shouldn't own — prefer a CI/CD pipeline.

## Prerequisites
- `gh` CLI installed and authenticated (`gh auth login`) with an HTTPS or SSH token for the
  target repo(s). Scopes: `repo`, `workflow`, `read:org` as needed.
- A GitHub server/MCP integration registered with the agent (e.g. `mcpServers` config pointing
  at the GitHub connector, or the `github` server wired per toolchain).
- For MCP over stdio/SSE: the server binary/endpoint available and listed (`gh` can also be
  driven directly when MCP isn't configured).

## How to Run (Procedure)

1. **Confirm auth + repo.** `gh auth status` and confirm you target the intended remote
   (`gh repo view <owner>/<repo>`). Wrong remote = wrong changes.
2. **Sync remote state.** `git fetch --all --prune`; verify current branch and clean tree before
   creating anything. Never branch/mutate off a dirty tree.
3. **Branch mechanics.** Create a feature branch off up-to-date default (`git checkout -b`),
   keep it scoped, and keep it synced as you work.
4. **Issue / PR work.** Use the GitHub connector to fetch issue details or PR list; read the
   body/threads before acting so you respond to the real request, not a title.
5. **Open the PR** with a precise title/body and a linked issue when relevant. Target the correct
   base branch.
6. **Handle feedback** via the connector (comment, request changes, approve) and reconcile
   review comments against actual code.
7. **Merge only after** CI passes and the target/base is confirmed — then `git pull` local to
   match remote.

## Quick Reference (driving `gh` directly when MCP is unavailable)
- `gh pr create --base main --title "..." --body "..."` — open a PR
- `gh pr list --state open` / `gh pr view <n>` — inspect
- `gh issue list` / `gh issue view <n>` / `gh issue create` — issues
- `gh pr merge <n> --merge --delete-branch` — merge + cleanup
- `gh pr review <n> --comment/-a/-r "..."` — review actions

## Pitfalls
- **Dirty tree.** Branching or pushing from uncommitted state leaks local noise into remote.
  Commit or stash first.
- **Wrong base.** Conflicts and bad reviews ride on merging into the wrong base branch. Confirm.
- **Stale remote view.** Acting on cached state causes duplicate issues / abandoned PRs. Fetch
  and re-read before opening anything.
- **Over-broad permissions.** Use the least permissive token for the task (don't open wide PRs
  from a machine with admin keys).

## Verification
- `gh pr status` / `gh pr view` shows the expected branch, base, and state you intended.
- Local branch reflects remote after merge/pull (`git status` clean, `git log` in sync).
- An issue/PR you created is visible on the remote with correct metadata (assignee, labels,
  linked issue) — re-read the remote object, not just your command output.