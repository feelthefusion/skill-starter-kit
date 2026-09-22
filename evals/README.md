# evals — how you find out whether a component earns its keep

The kit is eleven components of prompt-and-plugin surface. Without measurement, every decision
about it is a taste argument — and taste arguments about agent configuration are frequently
wrong. The cautionary case is not hypothetical: auto-generated `AGENTS.md`/`CLAUDE.md` context
files were recommended by essentially every agent vendor, then benchmarked (ETH Zurich, on
SWE-bench Lite) and found **net-negative** — roughly −3% task success and +20% cost. A practice
everyone endorsed, measured, and wrong.

So: 20 cases, a pass/fail judgement, and an A/B. Small on purpose. Start scoring immediately
rather than waiting for a thorough suite.

## Use

```bash
./run.py cases                        # list all 20
./run.py cases --area verify-gate     # one area
./run.py score baseline               # walk the cases, record pass/fail
./run.py compare baseline no-caveman  # diff two configurations
```

Scoring is manual: you paste the case prompt into a real session, watch what the agent does,
and judge it against the case's `pass` criteria. The tool holds the case list steady, records
verdicts per configuration in `results.json`, and diffs two configurations without letting you
round the result in your favor.

## Method

1. **Score `baseline` first** — the kit exactly as installed. This is the number everything
   else is measured against.
2. **Change exactly one thing.** Disable Caveman, or drop Graphify, or remove the Stop hook.
   One variable per configuration, named for the variable.
3. **Re-score the affected area**, not all 20 — `--area caveman` when testing Caveman.
4. **Compare.** A net delta of 0 or ±1 on a 20-case harness is noise, and `compare` says so.
   Treat "no measurable difference" as a real and common result — and note that a component
   with no measurable benefit still costs context, which is an argument for removing it.
5. **Judge the end state, not the transcript's vibe.** Did the code work? Was the evidence
   shown? Not: did the agent sound competent.

## Cases worth their own attention

Four cases exist specifically to test the judgement calls in this kit's audit:

- `caveman-01` — does Caveman self-activate on "be brief"? It should not. This is the fix that
  the v2 scoping made; the case is the regression test for it.
- `caveman-02` — under `/caveman`, is test output still verbatim? Compressed evidence is not
  evidence.
- `verify-04` — break something on purpose and claim completion. If the Stop hook doesn't block
  the turn, you don't have a gate; you have a document about a gate.
- `retrieval-01` vs `retrieval-02` — the Graphify demotion. LSP should win the symbol question;
  Graphify should win the orientation question. If Graphify wins neither, delete it.

## Replace the placeholder cases

Cases referencing `{repo}`, `{symbol}`, `{fast_moving_lib}` are templates. **Substitute tasks
from your own repos.** Cases drawn from real work are the only ones whose results transfer;
synthetic cases measure how well the kit does on synthetic cases.

Add cases as you hit failures. A case written the day a component let you down is worth ten
imagined ones, and it stops that failure from recurring silently.
