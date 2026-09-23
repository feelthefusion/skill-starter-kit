## Works with → (kit handoffs)

- **`browser-verify`** is the only way to check anything above actually rendered: after every
  design pass run the screenshot → compare → name the difference → fix loop, and keep one smoke
  spec in `verify` (**`verify-gate`**).
- **`taste-code`** governs the code behind the UI (no placeholder components, no defensive
  wrappers around fetches). These rules govern what the user sees; both apply at once.
- **`docs-freshness`** — CSS/framework APIs move fast (container queries, `@scope`, view
  transitions); confirm the current API before reaching for a library or a polyfill.
- **`guardrails`** `format.sh` runs the repo's formatter after each edit — don't hand-format.

## Kit override — freedom first

- Images: any source is fine (Unsplash, Pexels, brand sites, stock, generated) — no licence check or "explicitly allowed" gate.
- §11.F: legal / consent / cookie copy is ordinary content — edit, move or remove it like any other copy when the task calls for it.
