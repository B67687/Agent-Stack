#!/usr/bin/env bash
# egress-proxy.sh — L2 host-side egress gate: Squid CONNECT-only allowlist
# proxy + socat Unix-socket bridge (Anthropic sandbox-runtime topology).
#
# Runs as a systemd USER unit (egress-proxy@.service). Squid listens on
# 127.0.0.1:13128 (CONNECT-only, dstdomain allowlist, deny-wins). A socat
# UNIX-LISTEN socket bridges the bwrap sandbox into Squid: the sandbox
# bind-mounts this socket and all its traffic physically must traverse it.
#
#   sandbox (no NICs/routes) --UDS--> socat bridge --TCP 127.0.0.1:13128-->
#       Squid --dstdomain allowlist--> internet (or 403 DENIED)
#
# Fail-closed: if Squid is down, no socket -> sandbox has NO network.
#
# Requires: squid + socat installed.  Install: sudo apt install squid socat
# State/logs: ~/.cache/opencode/egress/  (writable as the invoking user)
set -euo pipefail

EGRESS_DIR="$HOME/.cache/opencode/egress"
EGRESS_SOCK="$EGRESS_DIR/egress.sock"
SQUID_TEMPLATE="$HOME/.config/opencode/egress/squid.conf"
SQUID_CONF="$EGRESS_DIR/squid.runtime.conf"
SQUID_BIN="$(command -v squid || echo /usr/sbin/squid)"
SQUID_PORT=13128

mkdir -p "$EGRESS_DIR/cache"

start_squid() {
  # Already up? (process match OR port open — either means healthy)
  if pgrep -f "squid.*squid.runtime.conf" >/dev/null 2>&1 || \
     ss -ltn 2>/dev/null | grep -q "127.0.0.1:$SQUID_PORT"; then
    return 0
  fi
  # Clear stale PID file from a previous instance (squid refuses to start
  # with a leftover squid.pid: 'FATAL: Squid is already running').
  if [ -f "$EGRESS_DIR/squid.pid" ]; then
    old_pid=$(cat "$EGRESS_DIR/squid.pid" 2>/dev/null || echo 0)
    if [ -n "$old_pid" ] && ! kill -0 "$old_pid" 2>/dev/null; then
      rm -f "$EGRESS_DIR/squid.pid"
    fi
  fi
  # Render template -> runtime conf (portable, ${HOME} substituted)
  envsubst < "$SQUID_TEMPLATE" > "$SQUID_CONF"
  # First run only: create swap dirs (skip if they exist to avoid races)
  if [ ! -d "$EGRESS_DIR/cache/00" ]; then
    "$SQUID_BIN" -f "$SQUID_CONF" -z >/dev/null 2>&1 || true
  fi
  nohup "$SQUID_BIN" -f "$SQUID_CONF" -N >>"$EGRESS_DIR/squid-run.log" 2>&1 &
  # Wait for listen
  for _ in $(seq 1 30); do
    if ss -ltn 2>/dev/null | grep -q "127.0.0.1:$SQUID_PORT"; then
      return 0
    fi
    sleep 0.5
  done
  echo "egress-proxy: squid failed to start (see $EGRESS_DIR/squid-run.log)" >&2
  return 1
}

cleanup() {
  pkill -f "squid.*squid.runtime.conf" 2>/dev/null || true
  rm -f "$EGRESS_SOCK"
}
trap cleanup EXIT

start_squid

# Foreground: the Unix-socket bridge. systemd tracks THIS process.
# fork=accept multiple sandbox connections; unlink-early=clean stale socket.
exec socat "UNIX-LISTEN:$EGRESS_SOCK,fork,reuseaddr,unlink-early" \
  "TCP:127.0.0.1:$SQUID_PORT"
