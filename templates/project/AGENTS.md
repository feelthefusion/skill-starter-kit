# AGENTS.md

<!-- Hand-written, ≤12 bullets, only what an agent cannot infer from the tree.
     Evidence: presence of this file moved rule-following 0% → 68% (arXiv 2605.10039);
     length, position and splitting changed nothing; auto-generated long files were
     net-negative on SWE-bench (ETH Zurich). Keep it short, keep it true. -->

- **Verify:** `./verify.sh` — typecheck, lint, test, build, dep audit. Run it before saying "done"; paste its output.
- **Stack:** <language + framework>, package manager `<npm|pnpm|uv|cargo>`. Install with the lockfile (`npm ci` / `uv sync --locked`), never bare `install`.
- **Run locally:** `<command>` · **Tests:** `<command>` (one file: `<command> path`).
- **Never:** force-push, `reset --hard`, edit generated files under `<dir>`, touch `.env*`, add a dependency without checking it exists and is >7 days old.
- **Layout:** `<src/>` app · `<tests/>` tests · `<docs/plans/>` plans and decisions.
- **Conventions the tree doesn't show:** <e.g. "errors propagate to the handler layer; no try/catch in services">.
