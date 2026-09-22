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
  "verify": "npm ci --ignore-scripts && npm run typecheck && npm run lint && npm test && npm run build && osv-scanner scan source -r ."
}
```

```makefile
# Makefile
verify:
	uv sync --locked && ruff check . && mypy . && pytest -q && osv-scanner scan source -r .
```

A copy-paste starting point for repos with no task runner:
`templates/verify.sh` (chmod +x, commit it at the repo root).

Rules for the script:
- **Exit 0 means every check passed.** No `|| true`, no swallowed failures, no `set +e`.
- **Include what the stack actually has.** A repo with no types has no typecheck step; do not
  invent one. Missing step > fake step.
- **Keep it under ~2 minutes.** A gate slow enough to skip gets skipped. Push the slow suite to
  CI and keep `verify` at the fast, high-signal subset.
- **Install from the lockfile first** (`npm ci`, `uv sync --locked`, `pnpm install
  --frozen-lockfile`) so the gate tests what will ship — `security-gate` layer 5.
- **`osv-scanner scan source -r .`** is the dependency-tree layer from `security-gate`
  (CVEs and known-malicious `MAL-*` packages).
- **`uvx zizmor .github/workflows`** if the repo has Actions — `security-gate` layer 5.
- **One Playwright smoke spec** if the repo renders a UI — `browser-verify`.

## Step 2: Wire the Stop hook

Write it directly in `.claude/settings.json` — through the kit's wrapper, not the bare command:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [{ "type": "command", "command": ".claude/hooks/stop-verify.sh", "timeout": 600 }]
      }
    ]
  }
}
```

**Why the wrapper:** Claude Code blocks a stop only on **exit code 2** (with stderr returned to
the agent). `verify` exits 1 on failure, which Claude Code treats as a *non-blocking* notice — a
gate that never closes. `stop-verify.sh` (in `guardrails/templates/`) runs `verify`, maps
failure → exit 2 with the real output, skips clean trees (nothing edited → nothing to gate), and
is **bounded**: after 3 blocked stops in a session it lets the turn end with a loud notice, so it
can never trap the loop (the reason the kit rejected `ralph-loop`).

The kit's `guardrails` template (`claude-settings.json`) already contains this Stop hook next to
the PreToolUse/PostToolUse hooks — `init-project.sh` installs all of them together.

### Hermes: two native equivalents, both deterministic

Hermes ships a built-in *verify-on-stop* nudge when code was edited without fresh verification
evidence, and two ways to make **your** `verify` the gate:

1. **`pre_verify` shell hook** — fires once per turn when the agent edited code, right before
   it finishes; it accepts the Claude Code Stop shape (`{"decision":"block","reason":…}`) and
   is bounded by `agent.max_verify_nudges` (default 3) so it can never trap the loop. The kit's
   `guardrails/templates/verify-nudge.sh` runs `./verify.sh` / `npm run verify` / `make verify`
   and, on failure, returns the real output as the reason. Wire it via
   `guardrails/templates/hermes-hooks.yaml` (apply with `hermes config set`).
2. **`/goal gate add "./verify.sh"`** — a per-task quality gate: a shell command that must exit
   0 before the goal judge may declare the goal done. Pair with `/goal draft <objective>` so the
   completion contract names the verification surface.

Escalation ladder, weakest to strongest (use the strongest the host supports):
1. In-prompt instruction to run the check — advisory, gets dropped.
2. Hermes `/goal` judge alone — LLM-judged, re-checked every turn.
3. **Stop hook (Claude Code) / `pre_verify` hook or `/goal gate` (Hermes)** — deterministic
   block. Default for this kit.
4. Verification subagent — fresh context sees only the diff and the criteria (Superpowers'
   `requesting-code-review`, or Hermes `delegate_task`).

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

## Works with →
- **`guardrails`** — same `settings.json`; `guard.sh` blocks `--no-verify` so nothing routes
  around this gate.
- **Superpowers `verification-before-completion`** is the *advisory* twin of this gate
  ("evidence before claims"). Keep both: the skill shapes the habit, the hook enforces it. On
  Hermes the bundled skills play the same role.
- **`security-gate`** supplies the dependency/Actions steps; **`browser-verify`** supplies the
  smoke spec; **`lsp-plugins`** catches per-file type errors *before* the gate runs so fewer
  turns bounce.
- **`caveman`** must never touch the output this gate produces.
- **`taste-code`** — when the gate fails, fix the cause; a suppression that turns it green is
  slop the gate now certifies.

## Verification

- `npm run verify` (or `./verify.sh`) exits 0 on a clean tree and names the failing check on a
  dirty one.
- Deliberately introduce a type error → the Stop hook blocks the turn and the agent reports the
  real compiler output.
- Deliberately break a test → same, and the pasted output matches what the suite actually
  printed.
- `git log` shows `verify` committed at the repo root, so a fresh clone inherits the gate.
