#!/bin/bash
# Railway launcher for Metabase.
# 1. Sizes the Java heap from the container memory limit (unless JAVA_OPTS sets one).
# 2. Starts Metabase with the image's own run script.
# 3. As soon as Metabase answers, completes the first-run setup with the administrator from
#    METABASE_ADMIN_EMAIL / METABASE_ADMIN_PASSWORD, so nobody else can claim the instance.
# A bad deploy-form value never stops the deploy: it is replaced and the log says why.
set -u

HEAP_PERCENT=60
SMALL_LIMIT_MB=2048        # below this, the JVM's non-heap memory (metaspace, code cache) needs a larger share
SMALL_HEAP_PERCENT=40
SMALL_JVM_FLAGS="-XX:+UseSerialGC -XX:ReservedCodeCacheSize=128m -XX:MaxDirectMemorySize=64m"
LARGE_JVM_FLAGS="-XX:+UseG1GC -XX:G1PeriodicGCInterval=60000 -XX:MinHeapFreeRatio=10 -XX:MaxHeapFreeRatio=30"   # hand unused heap back to the OS when idle
HEAP_MIN_MB=256
HEAP_MAX_MB=2048
SETUP_WAIT_SECONDS=1200
DEFAULT_ADMIN_EMAIL="admin@example.com"
LOCAL_URL="http://127.0.0.1:${MB_JETTY_PORT:-3000}"

log() { echo "[railway] $*"; }

configure_heap() {
  case " ${JAVA_OPTS:-} " in
    *" -Xmx"*|*"MaxRAMPercentage"*) log "Java heap: using JAVA_OPTS (${JAVA_OPTS})"; return ;;
  esac
  local limit limit_mb=0 heap
  limit=$(cat /sys/fs/cgroup/memory.max 2>/dev/null || cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null || echo max)
  if [[ "$limit" =~ ^[0-9]+$ ]] && [ "$limit" -lt $((1024 * 1024 * 1024 * 1024)) ]; then
    limit_mb=$((limit / 1024 / 1024))
  fi
  local extra=""
  if [ "$limit_mb" -gt 0 ] && [ "$limit_mb" -lt "$SMALL_LIMIT_MB" ]; then
    heap=$((limit_mb * SMALL_HEAP_PERCENT / 100))
    extra=" $SMALL_JVM_FLAGS"
  elif [ "$limit_mb" -gt 0 ]; then
    heap=$((limit_mb * HEAP_PERCENT / 100))
    extra=" $LARGE_JVM_FLAGS"
  else
    heap=$HEAP_MAX_MB
    extra=" $LARGE_JVM_FLAGS"
  fi
  [ "$heap" -lt "$HEAP_MIN_MB" ] && heap=$HEAP_MIN_MB
  [ "$heap" -gt "$HEAP_MAX_MB" ] && heap=$HEAP_MAX_MB
  if [ "$limit_mb" -gt 0 ] && [ "$limit_mb" -lt 900 ]; then
    log "WARNING: only ${limit_mb} MiB of memory; Metabase needs about 1 GB and may run out of memory."
  fi
  JAVA_OPTS="${JAVA_OPTS:-} -Xmx${heap}m${extra}"
  export JAVA_OPTS
  log "Memory limit ${limit_mb:-unknown} MiB -> Java heap ${heap} MiB${extra} (override with JAVA_OPTS=-Xmx...)"
}

sanitize_encryption_key() {
  local key="${MB_ENCRYPTION_SECRET_KEY:-}"
  if [ -n "$key" ] && [ "${#key}" -lt 16 ]; then
    log "WARNING: MB_ENCRYPTION_SECRET_KEY is shorter than 16 characters; using its SHA-256 instead."
    MB_ENCRYPTION_SECRET_KEY=$(printf '%s' "$key" | sha256sum | cut -c1-64)
    export MB_ENCRYPTION_SECRET_KEY
  fi
}

json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/ }
  s=${s//$'\r'/ }
  s=${s//$'\t'/ }
  printf '%s' "$s"
}

random_password() {
  # 24 random characters plus one of each class, so every complexity setting accepts it.
  printf '%sAa1-' "$(head -c 32 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | cut -c1-24)"
}

admin_email() {
  local email
  email=$(printf '%s' "${METABASE_ADMIN_EMAIL:-}" | tr -d '[:space:]')
  if [[ "$email" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
    printf '%s' "$email"
  else
    log "WARNING: METABASE_ADMIN_EMAIL \"${METABASE_ADMIN_EMAIL:-}\" is not a valid email address; using ${DEFAULT_ADMIN_EMAIL}." >&2
    printf '%s' "$DEFAULT_ADMIN_EMAIL"
  fi
}

post_setup() {
  local token=$1 email=$2 password=$3 body
  body=$(printf '{"token":"%s","user":{"email":"%s","password":"%s","first_name":"Admin","last_name":"Railway"},"prefs":{"site_name":"%s"}}' \
    "$(json_escape "$token")" "$(json_escape "$email")" "$(json_escape "$password")" "$(json_escape "${METABASE_SITE_NAME:-Metabase}")")
  curl -sS -o /tmp/railway-setup.json -w '%{http_code}' -H 'Content-Type: application/json' -d "$body" "$LOCAL_URL/api/setup"
}

auto_setup() {
  local waited=0 props token email password code
  until curl -fsS "$LOCAL_URL/api/health" >/dev/null 2>&1; do
    sleep 1
    waited=$((waited + 1))
    if [ "$waited" -ge "$SETUP_WAIT_SECONDS" ]; then
      log "Setup: Metabase did not become healthy in ${SETUP_WAIT_SECONDS} s; skipping the admin bootstrap."
      return
    fi
  done
  props=$(curl -fsS "$LOCAL_URL/api/session/properties") || { log "Setup: could not read session properties."; return; }
  if printf '%s' "$props" | grep -q '"has-user-setup":true'; then
    log "Setup: Metabase already has an administrator; nothing to do."
    return
  fi
  token=$(printf '%s' "$props" | sed -n 's/.*"setup-token":"\([^"]*\)".*/\1/p')
  if [ -z "$token" ]; then
    log "Setup: no setup token found; open the site to finish setup."
    return
  fi
  email=$(admin_email)
  password="${METABASE_ADMIN_PASSWORD:-}"
  code=$(post_setup "$token" "$email" "$password")
  if [ "$code" = "200" ]; then
    log "Setup: administrator ${email} created with the password in METABASE_ADMIN_PASSWORD."
    return
  fi
  log "Setup: METABASE_ADMIN_PASSWORD was rejected (HTTP ${code}: $(head -c 300 /tmp/railway-setup.json)); locking the account with a random password."
  code=$(post_setup "$token" "$email" "$(random_password)")
  if [ "$code" = "200" ]; then
    log "Setup: administrator ${email} created with a random password nobody knows (login locked)."
    log "Setup: to unlock it, open a Railway shell on this service and run: java -jar /app/metabase.jar reset-password ${email}"
    log "Setup: then open {your-domain}/auth/reset_password/{token} with the printed token and choose a new password."
  else
    log "Setup: could not complete setup (HTTP ${code}: $(head -c 300 /tmp/railway-setup.json)). Open the site to finish it."
  fi
}

configure_heap
sanitize_encryption_key

/app/run_metabase.sh &
metabase_pid=$!
trap 'kill -TERM "$metabase_pid" 2>/dev/null' TERM INT

case "${METABASE_AUTO_SETUP:-true}" in
  false|FALSE|0|no) log "METABASE_AUTO_SETUP is off: the first visitor completes Metabase's setup wizard." ;;
  *) auto_setup & ;;
esac

status=0
while kill -0 "$metabase_pid" 2>/dev/null; do
  wait "$metabase_pid"
  status=$?
done
exit "$status"
