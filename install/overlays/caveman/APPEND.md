## Works with → (kit handoffs)

- **`verify-gate`** output, **`security-gate`** findings, **`browser-verify`** diffs and
  Superpowers review findings are never compressed — they are evidence, and this mode applies
  only to the summary written after they are on the page.
- **`caveman-commit`** is the only other compression surface (the commit *message*); PR bodies,
  issues and docs stay in normal prose.
- Off by default in every session; the `evals/` harness has `caveman-01/02` to check it stays
  that way.
