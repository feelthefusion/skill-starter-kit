## Scope — read this before activating

**Opt-in only, and summaries only.** Earlier versions of this skill claimed every response,
inferred activation from "be brief", and persisted indefinitely. That was wrong, and the
evidence says so: system-level brevity instructions measurably reduce factual accuracy across
frontier models, and the mechanism is specific — under a brevity constraint a model lacks the
room to acknowledge a false premise or push back on a wrong assumption. Contradicting the user
is a large fraction of a coding agent's value ("the API doesn't work that way", "the bug isn't
where the ticket says"), so compression must never touch the reasoning path.

**Never compress:**
- Reasoning, plans, design discussion, or tradeoff analysis.
- Verification output — test/build/lint/typecheck results are pasted **verbatim**, never
  paraphrased or summarized. Evidence is the point; an assertion that tests passed is worthless.
- Tool-result interpretation, error strings, stack traces, diffs.
- Multi-turn debugging of a live problem.
- Security findings, destructive-action confirmations, ambiguity that needs a question.

Compress only the final human-facing summary, after the work and its evidence are on the page.

**Do not trust the ~75% figure without measuring it.** Output prose is the smallest line item in
a coding session — file reads, tool definitions and command output dominate context. Run the
kit's eval harness (`evals/`) with and without this mode before believing it earns its keep.

**Where the upstream text below contradicts this scope (e.g. "every response", "tool calls: fire direct"), this scope wins.** The kit's install overlay rewrites those passages; if one slips through after an upstream change, treat it as void.
