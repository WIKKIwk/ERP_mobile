#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$SCRIPT_DIR"

for FILE in ".core_tunnel.pid" ".core_domain_tunnel.pid" ".mobileapi.pid"; do
	if [ -f "$APP_ROOT/$FILE" ]; then
		PID="$(cat "$APP_ROOT/$FILE" 2>/dev/null || true)"
		if [ -n "${PID:-}" ]; then
			kill "$PID" 2>/dev/null || true
		fi
		rm -f "$APP_ROOT/$FILE"
	fi
done

rm -f "$APP_ROOT/.core_tunnel_url" "$APP_ROOT/.core_domain_url" "$APP_ROOT/.core_domain_tunnel.yml"
