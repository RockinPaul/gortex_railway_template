#!/bin/sh
# Clone or update the repos listed in GORTEX_REPOS, track them, keep them synced, then run the daemon.
# Runs as root on purpose: Railway volumes are root-owned on first mount.
set -eu

: "${PORT:=7411}"
: "${GORTEX_REPOS:=}"
: "${GORTEX_TOOLS:=readonly}"
: "${GORTEX_SYNC_INTERVAL:=300}"
REPOS_DIR=/data/repos
STORE=/data/data/gortex/store.sqlite

if [ -z "${GORTEX_DAEMON_HTTP_TOKEN:-}" ]; then
  echo "GORTEX_DAEMON_HTTP_TOKEN is empty. Refusing to expose the daemon without a token." >&2
  exit 1
fi

mkdir -p "$REPOS_DIR" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
# This script is pid 1, so no daemon can be running: drop pid/socket files left by an unclean stop,
# otherwise gortex reports "daemon already running (pid 1)" and exits.
rm -f "${GORTEX_DAEMON_PIDFILE:-/tmp/gortex.pid}" "${GORTEX_DAEMON_SOCKET:-/tmp/gortex.sock}" "$XDG_CACHE_HOME/gortex/daemon.pid"
export GIT_TERMINAL_PROMPT=0 GORTEX_AUTOSTART=0
[ -z "${GIT_TOKEN:-}" ] || export GIT_ASKPASS=/app/askpass.sh

# Entries are "url" or "name=url", comma-separated. Names: letters, digits, - _ .
set -f
for entry in $(echo "$GORTEX_REPOS" | tr ',' ' '); do
  case "$entry" in
    *=*) name="${entry%%=*}"; url="${entry#*=}" ;;
    *)   url="$entry"; name="${url%/}"; name="${name##*/}"; name="${name%.git}" ;;
  esac
  case "$name" in
    ""|*[!A-Za-z0-9_.-]*|.*) echo "skipping '$entry': bad repo name '$name'" >&2; continue ;;
  esac
  dir="$REPOS_DIR/$name"
  if [ -d "$dir/.git" ]; then
    git -C "$dir" pull --ff-only --quiet || echo "warning: could not fast-forward $name; serving the current checkout" >&2
  else
    echo "cloning $name from $url"
    git clone --quiet --single-branch "$url" "$dir" || { echo "warning: could not clone $name from $url; skipping it" >&2; rm -rf "$dir"; continue; }
  fi
  gortex track "$dir" --no-progress >/dev/null || { echo "warning: could not track $name; skipping it" >&2; continue; }
  echo "tracking $name at $dir"
done
set +f

if [ "$GORTEX_SYNC_INTERVAL" -gt 0 ] 2>/dev/null; then
  (
    while sleep "$GORTEX_SYNC_INTERVAL"; do
      for dir in "$REPOS_DIR"/*/; do
        [ -d "$dir/.git" ] || continue
        git -C "$dir" pull --ff-only --quiet || echo "sync: could not fast-forward $dir" >&2
      done
    done
  ) &
fi

# [::] binds IPv4 and IPv6: Railway's private network is IPv6-only and the public proxy needs IPv4.
exec gortex daemon start \
  --http-addr "[::]:${PORT}" \
  --backend-path "$STORE" \
  --tools "$GORTEX_TOOLS" \
  --no-progress
