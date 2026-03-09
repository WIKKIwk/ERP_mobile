#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$SCRIPT_DIR"
CORE_URL="${CORE_URL:-http://127.0.0.1:8081}"
TUNNEL_NAME="${TUNNEL_NAME:-accord-vision-core}"
PUBLIC_HOSTNAME="${PUBLIC_HOSTNAME:-core.wspace.sbs}"
TUNNEL_LOG="$APP_ROOT/.core_domain_tunnel.log"
TUNNEL_PID="$APP_ROOT/.core_domain_tunnel.pid"
TUNNEL_URL_FILE="$APP_ROOT/.core_domain_url"
TUNNEL_CONFIG="$APP_ROOT/.core_domain_tunnel.yml"

BACKEND_ROOT="${BACKEND_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
API_URL="$CORE_URL" BACKEND_ROOT="$BACKEND_ROOT" "$APP_ROOT/ensure_core.sh"

TUNNEL_ID="$(cloudflared tunnel list 2>/dev/null | awk -v name="$TUNNEL_NAME" '$2 == name {print $1; exit}')"
if [ -z "${TUNNEL_ID:-}" ]; then
	echo "Tunnel topilmadi: $TUNNEL_NAME" >&2
	exit 1
fi

CREDENTIALS_FILE="$HOME/.cloudflared/${TUNNEL_ID}.json"
if [ ! -f "$CREDENTIALS_FILE" ]; then
	echo "Tunnel credentials topilmadi: $CREDENTIALS_FILE" >&2
	exit 1
fi

if [ -f "$TUNNEL_PID" ]; then
	PID="$(cat "$TUNNEL_PID" 2>/dev/null || true)"
	if [ -n "${PID:-}" ] && kill -0 "$PID" 2>/dev/null; then
		printf 'https://%s\n' "$PUBLIC_HOSTNAME" >"$TUNNEL_URL_FILE"
		cat "$TUNNEL_URL_FILE"
		exit 0
	fi
	rm -f "$TUNNEL_PID"
fi

cat >"$TUNNEL_CONFIG" <<EOF
tunnel: $TUNNEL_ID
credentials-file: $CREDENTIALS_FILE

ingress:
  - hostname: $PUBLIC_HOSTNAME
    service: $CORE_URL
  - service: http_status:404
EOF

rm -f "$TUNNEL_LOG"
nohup cloudflared tunnel --config "$TUNNEL_CONFIG" run "$TUNNEL_NAME" >"$TUNNEL_LOG" 2>&1 &
echo $! >"$TUNNEL_PID"

for _ in $(seq 1 80); do
	if curl -fsS "https://$PUBLIC_HOSTNAME/healthz" >/dev/null 2>&1; then
		printf 'https://%s\n' "$PUBLIC_HOSTNAME" >"$TUNNEL_URL_FILE"
		cat "$TUNNEL_URL_FILE"
		exit 0
	fi
	sleep 0.5
done

echo "domain tunnel failed; see $TUNNEL_LOG" >&2
exit 1
