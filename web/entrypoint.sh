#!/bin/sh
# Start the Next.js UI on localhost:3000 and Caddy on $PORT in front of it.
set -eu
: "${PORT:=8080}"
: "${WEB_USER:=admin}"
: "${GORTEX_UPSTREAM:=http://gortex.railway.internal:7411}"
[ -n "${WEB_PASSWORD:-}" ] || { echo "WEB_PASSWORD is empty. Refusing to serve the UI without a password." >&2; exit 1; }
[ -n "${GORTEX_DAEMON_HTTP_TOKEN:-}" ] || { echo "GORTEX_DAEMON_HTTP_TOKEN is empty; the UI cannot reach the daemon." >&2; exit 1; }
WEB_PASSWORD_HASH="$(caddy hash-password --plaintext "$WEB_PASSWORD")"
export WEB_PASSWORD_HASH WEB_USER GORTEX_UPSTREAM GORTEX_DAEMON_HTTP_TOKEN PORT
PORT=3000 HOSTNAME=127.0.0.1 node server.js &
for _ in $(seq 1 30); do wget -q -O /dev/null http://127.0.0.1:3000/ 2>/dev/null && break; sleep 1; done
exec caddy run --config /app/Caddyfile --adapter caddyfile
