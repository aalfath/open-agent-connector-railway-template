#!/bin/sh
# Start script for the Open Agent Connector web console on Railway: Next.js on loopback, Caddy on $PORT.
set -eu
fail() { echo "open-agent-connector-web: $*" >&2; exit 1; }

export PORT="${PORT:-8080}"

# Where the FastAPI server is: http://${{server.RAILWAY_PRIVATE_DOMAIN}}:${{server.PORT}} in the template.
SERVER="${OAC_SERVER_URL:-}"
case "$SERVER" in
  http://?*:[0-9]*) ;;
  *) fail "OAC_SERVER_URL must look like http://HOST:PORT (got '$SERVER')" ;;
esac
export OAC_SERVER_URL="$SERVER"

# Public URL of this console, baked into the browser bundle in place of the build placeholder.
# An empty or bare "https://" value (domain not created yet) falls back to same-origin relative URLs.
ORIGIN="${PUBLIC_ORIGIN:-}"
case "$ORIGIN" in
  http://?*|https://?*) ORIGIN="${ORIGIN%/}" ;;
  *) echo "open-agent-connector-web: PUBLIC_ORIGIN is empty or invalid ('$ORIGIN'); using same-origin URLs" >&2; ORIGIN="" ;;
esac
case "$ORIGIN" in *[!A-Za-z0-9:/._-]*) fail "PUBLIC_ORIGIN contains unexpected characters" ;; esac

# Fresh copy of the pristine build on every start, so a changed domain is picked up on restart.
rm -r /tmp/web 2>/dev/null || true
cp -a /opt/oac-web /tmp/web
grep -rlF "__OAC_PUBLIC_ORIGIN__" /tmp/web/.next /tmp/web/server.js 2>/dev/null \
  | while IFS= read -r f; do sed -i "s#__OAC_PUBLIC_ORIGIN__#${ORIGIN}#g" "$f"; done
! grep -rqF "__OAC_PUBLIC_ORIGIN__" /tmp/web/.next || fail "could not set the public URL in the build"

# Size Node's heap and Go's threads from the container's limits, not the host's (Railway shows 32 CPUs).
MEM_MAX=$(cat /sys/fs/cgroup/memory.max 2>/dev/null || echo max)
if [ "$MEM_MAX" != "max" ]; then
  HEAP=$((MEM_MAX / 1024 / 1024 * 40 / 100)); [ "$HEAP" -lt 96 ] && HEAP=96
  export NODE_OPTIONS="--max-old-space-size=$HEAP ${NODE_OPTIONS:-}"
fi
CPUS=1
if read -r Q P < /sys/fs/cgroup/cpu.max 2>/dev/null && [ "$Q" != "max" ]; then CPUS=$(( (Q + P - 1) / P )); fi
[ "$CPUS" -ge 1 ] || CPUS=1
export GOMAXPROCS="$CPUS" UV_THREADPOOL_SIZE="${UV_THREADPOOL_SIZE:-2}"

cd /tmp/web
HOSTNAME=127.0.0.1 PORT=3000 node server.js &
NODE_PID=$!
caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &
CADDY_PID=$!
trap 'kill $NODE_PID $CADDY_PID 2>/dev/null; exit 143' TERM INT
echo "open-agent-connector-web: console on :$PORT, API at $OAC_SERVER_URL, public URL '${ORIGIN:-same-origin}'"

# If either process stops, stop the other and exit non-zero so Railway restarts the service.
while kill -0 "$NODE_PID" 2>/dev/null && kill -0 "$CADDY_PID" 2>/dev/null; do sleep 2; done
kill "$NODE_PID" "$CADDY_PID" 2>/dev/null || true
fail "a process stopped unexpectedly; exiting so Railway restarts the service"
