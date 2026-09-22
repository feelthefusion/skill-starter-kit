## Works with → (kit handoffs)

- Runs **after** `gitleaks git --staged --redact` (`security-gate`) and a green `verify`
  (`verify-gate`) — compression never skips a gate. `guard.sh` (`guardrails`) blocks
  `--no-verify` regardless of wording.
- Superpowers `finishing-a-development-branch` decides *when* to commit; this decides only how
  terse the message is. PR descriptions (`github-mcp` / `gh`) stay in full prose.
