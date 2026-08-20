#!/usr/bin/env bash
# egress-relay.sh — in-sandbox egress relay (exec'd inside the bwrap netns).
#
# The sandbox has NO NICs/routes (--unshare-net). This script:
#   1. starts a socat relay: 127.0.0.1:3128 (HTTP) -> bind-mounted egress.sock
#   2. exports HTTP(S)_PROXY pointing at that relay
#   3. execs the agent command with the proxy env
#
# All sandbox traffic therefore must traverse: sandbox relay -> host socat
# bridge -> Squid allowlist -> internet. There is physically no other path.
#
# NOTE: HTTP proxy leg only (Squid speaks HTTP CONNECT, not SOCKS5). Tools
# that require SOCKS-only egress are unsupported at L2 (documented).
set -euo pipefail

EGRESS_SOCK="$HOME/.cache/opencode/egress/egress.sock"

# Fail-closed: refuse to launch the agent if the gate is down (no socket).
if [ ! -S "$EGRESS_SOCK" ]; then
  echo "egress-relay: egress gate down (no $EGRESS_SOCK) — refusing to start (fail-closed)" >&2
  exit 1
fi

# HTTP relay: sandbox loopback:3128 -> host egress gate
socat "TCP-LISTEN:3128,fork,reuseaddr,bind=127.0.0.1" \
  "UNIX-CONNECT:$EGRESS_SOCK" &
RELAY_PID=$!

# Local traffic must bypass the proxy (opencode server, LSP, MCP, plugins)
export HTTP_PROXY="http://127.0.0.1:3128"
export HTTPS_PROXY="http://127.0.0.1:3128"
export http_proxy="http://127.0.0.1:3128"
export https_proxy="http://127.0.0.1:3128"
export ALL_PROXY="http://127.0.0.1:3128"
export all_proxy="http://127.0.0.1:3128"
export NO_PROXY="127.0.0.1,localhost,::1"
export no_proxy="127.0.0.1,localhost,::1"
# npm honors its own config keys; wire them so npm install works via the gate
export npm_config_proxy="http://127.0.0.1:3128"
export npm_config_https_proxy="http://127.0.0.1:3128"
export npm_config_noproxy="127.0.0.1,localhost"

cleanup() { kill "$RELAY_PID" 2>/dev/null || true; }
trap cleanup EXIT

exec "$@"
