#!/usr/bin/env bash
# =============================================================================
# kit-webhook — push-based updates: GitHub push → Hermes webhook → kit-update.
# No polling and no schedule: nothing runs until GitHub delivers a push event.
#
#   kit-webhook enable --tunnel [--repo owner/name ...]   # zero-account public URL, auto-kept in sync
#   kit-webhook enable [--url https://your-public-host] [--repo owner/name ...]
#   kit-webhook status
#   kit-webhook disable
#
# How it works
#   1. A Hermes webhook route `kit-update` accepts GitHub `push` events (HMAC-checked).
#   2. Its route script (~/.hermes/scripts/kit-update-webhook.sh) starts
#      `kit-update --force --background` and returns [SILENT] — no agent run, zero LLM cost.
#   3. kit-update pulls the kit, re-fetches upstream skills, refreshes installed skills
#      and the hook files in every repo you armed with kit-init.
#
# Needs: Hermes gateway running (`hermes gateway run`, or its service) and the gateway's
# port (8644) reachable from GitHub — e.g. `tailscale funnel 8644` or a cloudflared named
# tunnel. Pass that public base URL with --url and the GitHub webhook is created for you
# (gh CLI, admin on the repo). GitHub can only send webhooks for repos you administer —
# for third-party upstreams (Graphify, Caveman, Taste) the session-start check covers it.
# =============================================================================
set -euo pipefail
SELF="${BASH_SOURCE[0]}"
while [ -L "$SELF" ]; do d="$(cd "$(dirname "$SELF")" && pwd)"; SELF="$(readlink "$SELF")"
    case "$SELF" in /*) ;; *) SELF="$d/$SELF" ;; esac; done
KIT_ROOT="$(cd "$(dirname "$SELF")/.." && pwd)"
HH="${HERMES_HOME:-$HOME/.hermes}"
STATE="${KIT_STATE_DIR:-$HOME/.config/skill-starter-kit}"
ROUTE=kit-update
PORT="${WEBHOOK_PORT:-8644}"
mkdir -p "$STATE"

cmd="${1:-status}"; shift || true
URL="" REPOS=() TUNNEL=0
SECRET_FILE="$STATE/webhook-secret"
while [ $# -gt 0 ]; do
    case "$1" in
        --url) URL="${2%/}"; shift ;;
        --repo) REPOS+=("$2"); shift ;;
        --tunnel) TUNNEL=1 ;;
        *) echo "unknown flag: $1"; exit 1 ;;
    esac; shift
done
if [ ${#REPOS[@]} -eq 0 ]; then
    origin="$(git -C "$KIT_ROOT" remote get-url origin 2>/dev/null || true)"
    REPOS=("$(printf '%s' "$origin" | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')")
fi

command -v hermes >/dev/null 2>&1 || { echo "✗ hermes CLI not found — webhooks run through the Hermes gateway"; exit 1; }

# create or re-point the GitHub webhook(s) at $1 (public base URL)
github_hooks() {
    local hook_url="$1/webhooks/$ROUTE" repo id
    for repo in "${REPOS[@]}"; do
        id=$(gh api "repos/$repo/hooks" --jq ".[] | select(.config.url | endswith(\"/webhooks/$ROUTE\")) | .id" 2>/dev/null | head -1)
        if [ -n "$id" ]; then
            gh api -X PATCH "repos/$repo/hooks/$id" -F active=true -f "config[url]=$hook_url" \
                -f config[content_type]=json -f "config[secret]=$(cat "$SECRET_FILE")" >/dev/null 2>&1 \
                && echo "  · GitHub webhook on $repo → $hook_url ✓" \
                || echo "  ⚠ could not update webhook $id on $repo"
        else
            gh api -X POST "repos/$repo/hooks" -f name=web -F active=true -f 'events[]=push' \
                -f "config[url]=$hook_url" -f config[content_type]=json \
                -f "config[secret]=$(cat "$SECRET_FILE")" >/dev/null 2>&1 \
                && echo "  · GitHub webhook on $repo → $hook_url ✓" \
                || echo "  ⚠ could not add webhook on $repo (need admin; fork it and pass --repo you/fork)"
        fi
    done
}

TUNNEL_LABEL=com.skill-starter-kit.tunnel
install_tunnel_service() {
    command -v cloudflared >/dev/null 2>&1 || { command -v brew >/dev/null 2>&1 && brew install cloudflared >/dev/null 2>&1; } || true
    command -v cloudflared >/dev/null 2>&1 || { echo "  ✗ cloudflared missing — install it (https://github.com/cloudflare/cloudflared/releases) and re-run"; exit 1; }
    local bin="$HOME/.local/bin/kit-webhook"; [ -x "$bin" ] || bin="$SELF"
    local repos=""; for r in "${REPOS[@]}"; do repos="$repos --repo $r"; done
    if [ "$(uname -s)" = Darwin ]; then
        local plist="$HOME/Library/LaunchAgents/$TUNNEL_LABEL.plist"
        cat > "$plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$TUNNEL_LABEL</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>-lc</string><string>exec "$bin" tunnel$repos</string></array>
  <key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$STATE/tunnel.log</string><key>StandardErrorPath</key><string>$STATE/tunnel.log</string>
</dict></plist>
PL
        launchctl bootout "gui/$(id -u)/$TUNNEL_LABEL" 2>/dev/null || true
        launchctl bootstrap "gui/$(id -u)" "$plist" && echo "  · tunnel service $TUNNEL_LABEL (launchd, starts at login) ✓"
    else
        mkdir -p "$HOME/.config/systemd/user"
        cat > "$HOME/.config/systemd/user/skill-starter-kit-tunnel.service" <<SD
[Unit]
Description=Skill Starter Kit webhook tunnel
[Service]
ExecStart=/bin/bash -lc 'exec "$bin" tunnel$repos'
Restart=always
[Install]
WantedBy=default.target
SD
        systemctl --user daemon-reload && systemctl --user enable --now skill-starter-kit-tunnel.service \
            && echo "  · tunnel service (systemd --user) ✓" || echo "  ⚠ could not start the systemd user service"
    fi
}

case "$cmd" in
enable)
    # 1. route script: fire kit-update, return [SILENT] so no agent turn happens
    mkdir -p "$HH/scripts"
    cat > "$HH/scripts/kit-update-webhook.sh" <<SH
#!/usr/bin/env bash
# kit-webhook route script: GitHub push → kit-update (background). [SILENT] = no agent run.
payload="\$(cat)"
ref="\$(printf '%s' "\$payload" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("ref",""))' 2>/dev/null)"
case "\$ref" in refs/heads/main|refs/heads/master|"") nohup bash "$KIT_ROOT/install/kit-update.sh" --force --background >/dev/null 2>&1 </dev/null & ;; esac
echo "[SILENT]"
SH
    chmod +x "$HH/scripts/kit-update-webhook.sh"
    echo "  · route script → $HH/scripts/kit-update-webhook.sh ✓"

    # 2. webhook platform on: settings in config.yaml, only the global secret in .env
    hermes config set platforms.webhook.enabled true >/dev/null
    hermes config get platforms.webhook.extra.port 2>/dev/null | grep -q '[0-9]' \
        || hermes config set platforms.webhook.extra.port "$PORT" >/dev/null
    touch "$HH/.env"; chmod 600 "$HH/.env"
    grep -q '^WEBHOOK_SECRET=' "$HH/.env" || echo "WEBHOOK_SECRET=$(openssl rand -hex 24)" >> "$HH/.env"
    echo "  · webhook platform enabled (config.yaml platforms.webhook, port $PORT) ✓"

    # 3. subscription with a secret we keep (GitHub needs the same one)
    SECRET_FILE="$STATE/webhook-secret"
    [ -s "$SECRET_FILE" ] || { openssl rand -hex 24 > "$SECRET_FILE"; chmod 600 "$SECRET_FILE"; }
    hermes webhook remove "$ROUTE" >/dev/null 2>&1 || true
    hermes webhook subscribe "$ROUTE" --events push --script kit-update-webhook.sh \
        --secret "$(cat "$SECRET_FILE")" --description "Skill Starter Kit: GitHub push → kit-update" \
        --prompt "kit push {after}" >/dev/null 2>&1; hermes webhook list 2>/dev/null | grep -q "$ROUTE" \
        && echo "  · hermes webhook route /webhooks/$ROUTE ✓" \
        || { echo "✗ hermes webhook subscribe failed (is the gateway configured? run: hermes gateway setup)"; exit 1; }

    # 4. gateway must be running to receive events
    if curl -s -m 3 -o /dev/null "http://localhost:$PORT/health"; then
        echo "  · gateway webhook server listening on :$PORT ✓"
    elif hermes gateway status 2>/dev/null | grep -q 'PID'; then
        echo "  ⚠ gateway running but :$PORT not listening — load the webhook platform once: hermes gateway restart"
    else
        echo "  ⚠ gateway not running — start it:  hermes gateway run   (or install its service: hermes gateway install)"
    fi

    # 5. GitHub side
    if [ "$TUNNEL" = 1 ]; then
        install_tunnel_service
        echo "  · the tunnel service re-points the GitHub webhook whenever its URL changes — log: $STATE/tunnel.log"
    elif [ -n "$URL" ]; then
        github_hooks "$URL"
    else
        cat <<TXT

Last step — make port $PORT reachable from GitHub. Easiest (no account, auto-synced URL):
  kit-webhook enable --tunnel
Or with your own stable host (tailscale funnel $PORT, a cloudflared named tunnel, a reverse proxy):
  kit-webhook enable --url https://<public-host>
TXT
    fi
    ;;
tunnel)
    # foreground: run a cloudflared quick tunnel, point GitHub at each new URL it gets
    command -v cloudflared >/dev/null 2>&1 || { echo "cloudflared missing"; exit 1; }
    fifo="$STATE/tunnel.fifo"; rm -f "$fifo"; mkfifo "$fifo"
    cloudflared tunnel --no-autoupdate --url "http://localhost:$PORT" >"$fifo" 2>&1 &
    cf=$!; trap 'kill $cf 2>/dev/null; rm -f "$fifo"' EXIT
    while IFS= read -r line; do
        echo "$line"
        u=$(printf '%s' "$line" | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | head -1 || true)
        if [ -n "$u" ]; then echo "$u" > "$STATE/tunnel-url"; github_hooks "$u"; fi
    done < "$fifo"
    wait $cf
    ;;
status)
    hermes webhook list 2>/dev/null | grep -A3 "$ROUTE" || echo "  · route $ROUTE not subscribed (kit-webhook enable)"
    curl -fsS -m 3 "http://localhost:$PORT/health" >/dev/null 2>&1 && echo "  · webhook server listening on :$PORT ✓" || echo "  · webhook server not listening on :$PORT"
    [ -f "$STATE/tunnel-url" ] && echo "  · public URL: $(cat "$STATE/tunnel-url")/webhooks/$ROUTE"
    tail -5 "$STATE/update.log" 2>/dev/null || true
    ;;
disable)
    if [ "$(uname -s)" = Darwin ]; then
        launchctl bootout "gui/$(id -u)/$TUNNEL_LABEL" 2>/dev/null && echo "  · tunnel service stopped ✓"
        rm -f "$HOME/Library/LaunchAgents/$TUNNEL_LABEL.plist"
    else
        systemctl --user disable --now skill-starter-kit-tunnel.service 2>/dev/null && echo "  · tunnel service stopped ✓"
    fi
    hermes webhook remove "$ROUTE" >/dev/null 2>&1 && echo "  · route removed ✓" || echo "  · route was not subscribed"
    for repo in "${REPOS[@]}"; do
        for id in $(gh api "repos/$repo/hooks" --jq ".[] | select(.config.url | endswith(\"/webhooks/$ROUTE\")) | .id" 2>/dev/null); do
            gh api -X DELETE "repos/$repo/hooks/$id" >/dev/null 2>&1 && echo "  · GitHub webhook $id on $repo removed ✓"
        done
    done
    ;;
*) sed -n '2,23p' "$SELF"; exit 1 ;;
esac
