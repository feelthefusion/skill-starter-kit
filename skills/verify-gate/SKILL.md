---
name: verify-gate
description: "Close the loop on 'done'. Define one `verify` command (test + typecheck + lint + build + dep audit) that returns pass/fail, wire it to a Stop hook so a turn cannot end while it fails, and require real command output as evidence instead of a claim of success. Use when setting up a new project, before claiming any work complete, or when the agent has said 'done' without showing output."
---

# Verify Gate: a Pass/Fail the Agent Cannot Talk Its Way Past

An agent stops when the work *looks* done. Without a check it can run, "looks done" is the only
signal available — and then you are the verification loop: every mistake waits for you to
notice it.

Everything else in this kit is advisory. `taste-code` is prose the model may drop as context
fills. TDD and systematic-debugging are procedures. LSP gives per-file diagnostics, not a
repo-level verdict. **Nothing produced a pass/fail that blocks a false "done" — this does.**

**Scope:** the completion gate for a repo. It does not replace tests, review, or CI; it is the
thing that makes all three load-bearing by refusing to let the turn end when they fail.

## The Contract

1. **One command.** Every repo exposes `verify` — one entry point, machine-readable exit code.
2. **A Stop hook runs it.** The turn cannot end while it fails. Deterministic, not advisory.
3. **Evidence, not assertion.** Never "tests pass". Paste the command and its real output.
   Compression of this output is forbidden (see `caveman`'s never-compress list).

## Step 1: Define `verify`

One command, in the project's own idiom. Fast checks first so failures surface early.

```bash
# package.json
"scripts": {
  "verify": "npm run typecheck && npm run lint && npm test && npm run build && osv-scanner scan source -r ."
}
```

```makefile
# Makefile
verify:
	ruff check . && mypy . && pytest -q && osv-scanner scan source -r .
```

A copy-paste starting point for repos with no task runner:
`templates/verify.sh` (chmod +x, commit it at the repo root).

Rules for the script:
- **Exit 0 means every check passed.** No `|| true`, no swallowed failures, no `set +e`.
- **Include what the stack actually has.** A repo with no types has no typecheck step; do not
  invent one. Missing step > fake step.
- **Keep it under ~2 minutes.** A gate slow enough to skip gets skipped. Push the slow suite to
  CI and keep `verify` at the fast, high-signal subset.
- **`osv-scanner scan source -r .`** is the dependency-tree layer from `security-gate`.

## Step 2: Wire the Stop hook

`hookify@claude-plugins-official` generates this from a sentence, or write it directly in
`.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [{ "type": "command", "command": "npm run verify" }]
      }
    ]
  }
}
```

A non-zero exit blocks the turn from ending and the failure output returns to the agent, which
then fixes it and retries — the loop closes without you in it.

Escalation ladder, weakest to strongest (use the strongest the host supports):
1. In-prompt instruction to run the check — advisory, gets dropped.
2. `/goal` condition — re-checked after every turn.
3. **Stop hook** — deterministic block. Default for this kit.
4. Verification subagent — fresh context sees only the diff and the criteria.

## Step 3: Evidence discipline

Before the words "done", "fixed", "working", or "passing" appear in a response:

- Run `verify`. Paste the command and its actual output.
- If a check was skipped, say which and why. "I didn't run the build" is an acceptable report;
  silence about it is not.
- Reviewing evidence is faster than re-running the verification yourself — that is the whole
  point of pasting it.
- **Never** paraphrase, summarize, or compress test/build/lint output. Verbatim or not at all.

## Step 4 (optional): the fresh-context reviewer

For anything non-trivial, hand the diff to a subagent that did **not** write it, with only the
diff and the criteria — no reasoning history. Constrain its scope in the prompt:

> Review this diff against PLAN.md. Check that every stated requirement is implemented and
> correct. **Style and speculative hardening are out of scope.** Report gaps, not preferences.

That constraint is load-bearing: an unconstrained reviewer manufactures findings, and the
cheapest way to close a manufactured finding is the slop `taste-code` exists to prevent.

## Pitfalls

- **A gate that never fails is not a gate.** Break something on purpose and confirm the hook
  blocks the turn. An untested gate is indistinguishable from no gate.
- **`|| true` anywhere in the chain.** Silently converts the gate into decoration.
- **Gating on a flaky test.** The agent learns the gate is noise and starts routing around it.
  Fix or quarantine the flake; do not soften the gate.
- **Suppressing the error instead of fixing the cause.** Address the root cause — a suppression
  that makes `verify` green is a lie the gate now tells for you.
- **Letting the gate creep.** Every added minute increases the odds someone disables it.
- **Confusing LSP diagnostics with this.** LSP catches type errors in the edited file. It does
  not catch a broken suite, a failing build, or a regression three modules away.

## Verification

- `npm run verify` (or `./verify.sh`) exits 0 on a clean tree and names the failing check on a
  dirty one.
- Deliberately introduce a type error → the Stop hook blocks the turn and the agent reports the
  real compiler output.
- Deliberately break a test → same, and the pasted output matches what the suite actually
  printed.
- `git log` shows `verify` committed at the repo root, so a fresh clone inherits the gate.
