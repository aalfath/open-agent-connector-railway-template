#!/bin/sh
# Start script for the Open Agent Connector API on Railway.
set -eu

fail() { echo "open-agent-connector: $*" >&2; exit 1; }

# Secrets come from the template (generated per deploy). Refuse to start without them, so the
# app never falls back to a token or key that nobody stored.
ADMIN="${CONNECTOR_ADMIN_TOKEN:-}"
KEY="${CONNECTOR_ENCRYPTION_KEY:-}"
[ "${#ADMIN}" -ge 32 ] || fail "CONNECTOR_ADMIN_TOKEN must be set to at least 32 characters"
[ "${#KEY}" -ge 32 ] || fail "CONNECTOR_ENCRYPTION_KEY must be set to at least 32 characters (and never changed: it decrypts stored credentials)"

# Network-facing deployment: never hand the admin token to the browser, never allow anonymous MCP.
export CONNECTOR_EXPOSE_LOCAL_TOKEN=false
export CONNECTOR_ALLOW_ANONYMOUS_MCP=false
export CONNECTOR_ALLOW_PUBLIC_ACCESS="${CONNECTOR_ALLOW_PUBLIC_ACCESS:-false}"
export CONNECTOR_PROJECT_NAME="${CONNECTOR_PROJECT_NAME:-ConnectorHub}"

# Public origin (the web service's domain): used for OAuth callback URLs and CORS.
# Railway can resolve "https://${{web.RAILWAY_PUBLIC_DOMAIN}}" to a bare "https://" before the
# domain exists, so accept only a real http(s)://host value.
ORIGIN="${CONNECTOR_PUBLIC_ORIGIN:-}"
case "$ORIGIN" in
  http://?*|https://?*) ORIGIN="${ORIGIN%/}" ;;
  *) echo "open-agent-connector: CONNECTOR_PUBLIC_ORIGIN is empty or invalid ('$ORIGIN'); OAuth callbacks will not work until it is set" >&2
     ORIGIN="http://localhost:8000" ;;
esac
export CONNECTOR_PUBLIC_ORIGIN="$ORIGIN"
# Only the public origin may be an OAuth return URL unless the deployer adds more.
export CONNECTOR_ALLOWED_RETURN_ORIGINS="${CONNECTOR_ALLOWED_RETURN_ORIGINS:-}"

# Data (SQLite database) lives on the Railway volume mounted at /app/data.
mkdir -p /app/data
touch /app/data/.write-test 2>/dev/null && rm /app/data/.write-test || fail "/app/data is not writable"

PORT="${PORT:-8000}"
echo "open-agent-connector: API on [::]:$PORT, public origin $CONNECTOR_PUBLIC_ORIGIN"
cd /app
# One worker: SQLite and upstream's in-process caches expect a single instance.
# "::" listens on IPv6 and IPv4, so Railway's private network reaches it.
exec uvicorn main:app --host :: --port "$PORT" --workers 1 --no-server-header \
  --timeout-graceful-shutdown 5 --log-level "${LOG_LEVEL:-info}"
