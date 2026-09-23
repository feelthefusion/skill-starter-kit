---
name: cloud-clis
description: "Operate GitHub, Railway, Cloudflare, AWS, Google Cloud and Google Workspace from the terminal: which CLI does what (gh, railway, wrangler/cloudflared, aws, gcloud, gws, gam), how to check you're signed in, deploy, read logs, manage env vars/secrets, DNS, storage and databases — CLI first, MCP opt-in. Use for any deploy, hosting, domain, DNS, bucket, database, env var, log, PR/issue/release or CI task on these platforms."
---

# Cloud CLIs: GitHub · Railway · Cloudflare · AWS · Google Cloud · Google Workspace

The kit installs all seven CLIs and the vendors' own skills (`use-railway`, `cloudflare`,
`wrangler`, `workers-best-practices`, `deploy-on-aws`, `gcloud`, and on Claude Code the core
`gws-*` skills — Hermes' bundled `google-workspace` skill already drives `gws`). This skill is the router: which tool,
signed in as whom, and the few rules that keep deploys boring.

## Which CLI for what

| Platform | CLI | Signed in? | Typical jobs | Vendor skill |
|---|---|---|---|---|
| GitHub | `gh` | `gh auth status` | PRs, issues, releases, Actions runs/logs (`gh run view --log-failed`), `gh api` for anything else | — (`github-mcp` for the read-only MCP) |
| Railway | `railway` | `railway whoami` | link project/service, deploy (`railway up`), logs, env vars, domains, Postgres | `use-railway` |
| Cloudflare | `wrangler` (+ `cloudflared`) | `wrangler whoami` | Workers/Pages deploy, D1, R2, KV, Queues, secrets, DNS via API; `cloudflared` for tunnels | `cloudflare` (product choice), `wrangler`, `workers-best-practices` |
| AWS | `aws` | `aws sts get-caller-identity` | S3, SES, IAM, Lambda, RDS, CloudFront, CloudWatch logs; architecture + IaC | `deploy-on-aws` |
| Google Cloud | `gcloud` (+ `gsutil`, `bq`) | `gcloud auth list` · `gcloud config list` | Cloud Run, Cloud SQL, GCS, BigQuery, IAM, logs (`gcloud logging read`), APIs & credentials | `gcloud` |
| Google Workspace (user data) | `gws` | `gws auth status` | Gmail, Drive, Calendar, Sheets, Docs, Slides, Chat, Tasks; JSON in/out; `gws schema <method>` for any API | `gws-shared` + `gws-gmail` · `-drive` · `-calendar` · `-sheets` · `-docs` · `-slides` · `-admin-reports` |
| Google Workspace (admin) | `gam` (GAM7) | `gam oauth info` | users, groups, OUs, aliases, licenses, shared drives, bulk CSV (`gam csv users.csv gam update user ~email …`), audits | — (`gam help`, GAM wiki) |

Not signed in → run the login yourself (`gh auth login`, `railway login`, `wrangler login`,
`aws configure sso`, `gcloud auth login`, `gws auth login` (first time: `gws auth setup`), `gam oauth create`) — each opens the browser; the user clicks approve once.

## Rules

1. **CLI first.** Prefer the CLI over an MCP server: no standing context cost, same on both
   hosts. Ask for JSON and filter it (`gh … --json`, `railway … --json`, `aws … --output json
   --query`, `wrangler whoami --json`, `gcloud … --format=json`) instead of pasting whole tables.
2. **Check the target before you change it.** Print the account/project/environment first
   (`railway status`, `wrangler whoami`, `aws sts get-caller-identity`, `gcloud config get project`, `gh repo view`) — the
   classic mistake is deploying to the wrong project or account.
3. **Secrets stay out of the transcript.** Read variable *names*, not values
   (`railway variables --json | jq -r 'keys[]'`, `wrangler secret list`, `aws ssm describe-parameters`).
   `railway variables` / `--kv` print raw values — never run them bare.
   Set secrets from a file or stdin, never inline in a command. Never print tokens
   (`gws auth export`, `gcloud auth print-access-token` are blocked).
4. **Deploy after `./verify.sh` is green**, then prove the deploy: health endpoint / `curl -I`,
   deploy logs, and the browser (`browser-verify`) on the live URL.
5. **GAM changes real users.** Preview bulk jobs first (`gam print users query "…"` / a CSV of
   targets), run on one account, then the batch.
6. **Irreversible cloud deletes are blocked by `guard.sh`** (buckets, databases, stacks,
   instances, Railway projects/services/environments/volumes, Workers, D1/R2/KV, GCP projects/SQL/
   buckets, Workspace users/groups/shared drives, permanent Drive/Gmail deletes, repos). If one is genuinely intended, the user runs it by hand.

## MCP servers (opt-in)

The vendors also ship MCP servers. Enable one only when the CLI can't do the job:
- Railway: `claude mcp add --transport http railway https://mcp.railway.com`
- Cloudflare: `claude mcp add --transport http cloudflare https://mcp.cloudflare.com/mcp`
- Google Cloud: `npx -y @google-cloud/gcloud-mcp` (googleapis/gcloud-mcp)
- AWS: `/plugin marketplace add awslabs/agent-plugins` → `/plugin install deploy-on-aws@agent-plugins-for-aws` (IaC, pricing, knowledge MCPs)

Hermes: `hermes mcp add <name> --url <url>`.

## Works with →
- **`verify-gate`** — green `./verify.sh` before any deploy; **`browser-verify`** checks the live URL after.
- **`guardrails`** — `guard.sh` blocks irreversible cloud deletes and credential-dir reads.
- **`security-gate`** — gitleaks before a push; zizmor for Actions workflows you create with `gh`.
- **`github-mcp`** — the read-only GitHub MCP when `gh` isn't enough.
- **`docs-freshness`** — `<cli> --help` and the vendor skill beat memory; CLIs change fast.

## Verification
- `gh --version && railway --version && wrangler --version && aws --version && gcloud --version && gws --version && gam version` all print.
- The seven "signed in?" commands name the right account.
- `guard.sh` blocks `aws s3 rb s3://x --force`, `railway delete`, `wrangler d1 delete x` and `gh repo delete`.
