#!/bin/sh
# Start script for the Open Agent Connector API on Railway.
set -eu

fail() { echo "open-agent-connector: $*" >&2; exit "${RC:-1}"; }

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
  http://?*|https://?*) ;;
  # Fall back to the public domain Railway reports for the "web" service, if any.
  *) [ -n "${RAILWAY_SERVICE_WEB_URL:-}" ] && ORIGIN="https://${RAILWAY_SERVICE_WEB_URL}" ;;
esac
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
# run.py listens on one dual-stack socket ([::]:PORT), so Railway's private network reaches it over IPv6 and IPv4.
export PORT
python /usr/local/lib/oac-run.py &
APP_PID=$!
trap 'kill -TERM "$APP_PID" 2>/dev/null; wait "$APP_PID"; exit 143' TERM INT
set +e
wait "$APP_PID"
RC=$?
# The API never stops on its own: any exit (crash, kill, OOM) ends the service non-zero so Railway restarts it.
[ "$RC" -ne 0 ] || RC=1
fail "the API process stopped (exit $RC); exiting so Railway restarts the service"
