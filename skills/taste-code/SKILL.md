---
name: taste-code
description: "Anti-slop code generation harness. Apply minimalist structural rules so output avoids boilerplate, placeholder noise, redundant error handling, and over-engineered architectures."
---

# Taste-Code: Minimalist Code Generation Harness

Standard LLMs gravitate to large, generic, over-engineered code that bloats past token limits
and buries the real logic. This skill injects rigorous structural discipline into code
generation: emit the smallest correct thing, nothing decorative, no placeholder scaffolding.
Think of it as taste filters applied to every code block you produce.

**Scope:** any code generation or refactor. It pairs with the frontend Taste skill
(`design-taste-frontend`) for UI concerns; this one is about code structure itself.

## The 10 Structural Rules

1. **Smallest correct unit.** Write only what the task requires. If a helper is used once, inline
   it. If a function is trivial, keep it a function only when it names intent.
2. **No placeholder scaffolding.** No `// TODO: fill me`, `return null` stubs passed off as done,
   `console.log("here")`, or fake data. Ship working paths, or say what is unimplemented.
3. **No redundant error handling.** Don't wrap everything in try/catch + log noise. Handle
   errors where they compound; otherwise let them propagate. No `catch (e) { console.error(e) }`
   dressed up as robustness.
4. **No over-engineered architecture.** No factory-of-factories, interface-for-everything,
   abstraction layers for a single call site, or config systems with one option. Build for the
   code that exists, not a speculative future.
5. **Prefer plain standard library** over pulling a dependency for something stdlib does in a
   line. Dependency cost is real; add a package only when it earns its weight.
6. **Explicit over clever.** No one-liners that hide intent, no magic numbers, no clever
   pyramids. Readability beats brevity as soon as the "clever" obscures meaning.
7. **Naming says what it is.** Functions/classes/variables named by behavior, not
   implementation. `processPayment` not `handleTrx2`. No `data`, `helper`, `temp`.
8. **No dead code or speculative params.** No unused imports, unused variables, unused args,
   or feature switches for things that don't exist yet. If it's not used now, it doesn't ship.
9. **No generic comment fluff.** Only comments that explain WHY (non-obvious constraint,
   tradeoff, invariant). Delete "this prints the value", "// initialize", boilerplate headers.
10. **Right-sized formatting.** Match the surrounding file's conventions. No reformatting
    hunks you didn't change, no blowing up style just to look organized.

## Spikes: validate outside the repo

When an idea is risky or unproven (unfamiliar API, uncertain algorithm, "will this even
work?"), spike it first: write the throwaway experiment in a scratch directory OUTSIDE the
repo (e.g. `$TMPDIR/spike-<name>`), prove or kill the idea, then delete it. Only the
*lesson* comes back into the repo, as the smallest correct implementation (rule 1).
Never commit spike code, never "clean up a spike into production" — rewrite from what you
learned. This is rule 4 applied to process: no speculative code in the tree.

## Mechanize what can be mechanized

Prose rules are advisory: they get dropped as context fills, and they cost tokens in every
session whether or not they fire. Several of the 10 are **mechanically checkable** — rule 8
(unused imports/variables/args), rule 10 (formatting), and part of rule 2 (placeholder
scaffolding) — so enforce those in a PostToolUse formatter/linter hook instead of here.
Deterministic, zero standing context, no reliance on the model remembering.

What stays as text is only what needs judgement: rules 1, 4, 6, 7 (smallest correct unit, no
over-engineering, explicit over clever, naming says what it is). A hook cannot decide whether
an abstraction is speculative.

## Reviewer findings do not license slop

A reviewer asked to find gaps will manufacture them, and the cheapest way to close a
manufactured finding is exactly the slop these rules exist to prevent: an extra abstraction
layer, a defensive branch for an impossible state, a test for a state the type system already
excludes, or `try/catch` + log to silence a security scanner (rule 3).

**You have standing permission to reject a review finding that would violate these rules.** Say
which rule it violates and why the finding does not apply. A reviewer's authority covers
correctness and stated-requirement gaps — not style, and not speculative hardening. If a
finding is real, fix the root cause; do not wrap it.

## When to Use
- Every code generation request, unless the user explicitly asks for maximal scaffolding.
- Code review passes: check output against these rules before presenting it.
- Refactors: strip dead/placeholder/speculative code as part of the change.

Don't use for:
- User explicitly requesting verbose/educational code, or scaffolding they asked for by name.

## Procedure
1. Read the request. Restate (internally) the smallest change that satisfies it.
2. Generate against the 10 rules — deliberately resist the boilerplate default.
3. **Self-check**: walk the output for rule violations (unused imports, try/catch noise,
   placeholder returns, speculative abstraction, naming). Fix before presenting.
4. Present the minimal change; note unimplemented paths explicitly rather than stubbing them.

## Pitfalls
- **Fitting 10 rules is not padding.** Enforcement means *less* code, not the same code with a
  "minimalist" label.
- **Don't remove necessary error handling.** Rule 3 bans *redundant* logging-wrapping, not
  error handling where failure is a real control-flow path (I/O, network, parse).
- **Conventions win.** Rule 10 exists because breaking the file's existing style is itself
  noise; match what's there even when you'd format differently.
- **Descriptions shaped like praise** ("minimalist!") add nothing — follow the rules literally.

## Verification
- The change is the smallest that satisfies the request (no unused imports/vars/params).
- No placeholder/`TODO` stubs, no fabricated working paths, no try/catch-log noise.
- Comments are WHY-only; naming is behavior-based; deps are justified.
- You can explain every line — nothing survives "what does this do and why."