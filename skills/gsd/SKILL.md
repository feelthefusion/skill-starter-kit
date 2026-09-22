---
name: gsd
description: "Offload isolated sub-tasks to fresh sub-agents to protect the main context window. Use when conversation history grows long, or for any hyper-specific side task."
---

# GSD (Get Shit Done): Sub-Agent Context Triage

Large, multi-file refactors degrade in quality as the conversation history grows. GSD keeps
the primary context window clean by spinning up fresh, lightweight sub-agents for isolated
side tasks, harvesting their output, and discarding them.

**What it does NOT do:** split the *core* feature work — only well-isolated, self-contained
sub-tasks whose results can be applied back without deep coupling to the main thread.

## When to Use
- Conversation history for the primary task is long and edits are getting slower / more repetitive.
- A side task is fully specified in one short prompt and needs no decisions mid-run.
- Straightforward, isolated logic: a pure function, a utility, a migration snippet, a test,
  a config adaptation, a small file rewrite.
- Costly / token-hungry subtask that doesn't need the main context to succeed.

Don't use for:
- Work that requires judgment edits across many connected files — keep that inline.
- Any task where the sub-agent would need to ask questions or hold your project's broader intent.

## Prerequisites
- Ability to dispatch a sub-agent with an isolated context (agent/delegate tooling) and get a
  transcript or final summary back. The sub-agent learns only what you pass it.

## How to Run (Procedure)

1. **Decide if it's eligible.** One prompt fully defines it; no mid-run decisions; result plugs
   in directly. If it needs context you can't copy in one step, it's not eligible — do it inline.
2. **Write a self-contained brief.** Include: file paths, exact current code if relevant, what to
   change, constraints/conventions, the exact output shape (diff, file content, snippet), and
   the stated output language / style.
3. **Dispatch.** Spawn exactly one sub-agent per isolated task. State the output format up front
   and that it must not ask questions — decide everything in the brief.
4. **Harvest.** When it returns, extract the solution from its output.
5. **Apply back.** Write/patch it into the primary tree yourself. Sight-check it (see Verification).
6. **Burn.** Close/end the sub-agent. Fresh context cost nothing if none is retained.

## Pitfalls
- **Context you forgot to pass.** If the sub-agent's output references something you assumed it
  Knew, the fault is the brief, not the agent. Re-dispatch with the missing context rather than
  half-applying wrong output.
- **Missing convention adherence.** Sub-agents don't know your project's style. Either put
  conventions in the brief or verify them yourself after applying (a review pass on the diff).
- **Runaway scope.** An isolated task that balloons back into the main feature is a sign it was
  never isolated; reabsorb it and stop delegating.
- **Verification is yours, not the agent's.** A returned "solution" that isn't checked is the
  same as not running GSD at all.

## Verification
- After applying the harvested output, the diff compiles / the test passes before you push on.
- The final diff is attributable and minimal — no unrelated changes smuggled from the sub-agent.
- The sub-agent is gone (no retained context) and the main thread continues without its history.