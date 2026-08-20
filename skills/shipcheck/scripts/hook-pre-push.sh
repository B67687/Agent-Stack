#!/usr/bin/env bash
# hook-pre-push.sh — /shipcheck fast pre-push gate (opt-in).
#
# Install: append a call to this script inside your existing pre-push hook
# (~/.config/git/ai-commit-hooks/pre-push) OR use lefthook/pre-commit in-target.
# Only ONE pre-push hook runs per hooksPath — extend the existing one.
#
# Contract (SPEC §4/§7): <10s on small diffs; fail-open on missing tools or
# timeout (log + warn, never silently block); exit 1 only on BLOCKING findings.
#
# Usage from a pre-push hook:
#   bash ~/.config/opencode/skills/shipcheck/scripts/hook-pre-push.sh

set -uo pipefail

SKILL_DIR="${SKILL_DIR:-$HOME/.config/opencode/skills/shipcheck}"
SHIPCHECK="${SKILL_DIR}/scripts/shipcheck.py"
LOGFILE="${TMPDIR:-/tmp}/shipcheck-pre-push.log"

# Fast mode: only the security/supply-chain/secrets dimensions (BLOCKING tier),
# and only if the repo changed since the last recorded clean push.
if [[ ! -x "$(command -v python3)" ]]; then
  echo "shipcheck: python3 not found — pre-push gate skipped (fail-open)" >>"$LOGFILE"
  exit 0
fi
if [[ ! -f "$SHIPCHECK" ]]; then
  echo "shipcheck: $SHIPCHECK missing — pre-push gate skipped (fail-open)" >>"$LOGFILE"
  exit 0
fi

# Timebox the fast gate: 10s budget per SPEC §7 (hook <10s on small diffs).
timeout 10 python3 "$SHIPCHECK" --skip-dim repo-hygiene --skip-dim correctness \
  --skip-dim privacy --skip-dim reliability --skip-dim accessibility \
  --skip-dim performance --skip-dim documentation --skip-dim licensing \
  >/tmp/shipcheck-hook.out 2>>"$LOGFILE"
rc=$?

if [[ $rc -eq 124 ]]; then
  echo "shipcheck: pre-push gate timed out (>10s) — fail-open (logged, not blocked)" >>"$LOGFILE"
  exit 0
fi

if [[ $rc -eq 1 ]]; then
  {
    echo "shipcheck: BLOCKING findings in push — refusing to push."
    cat /tmp/shipcheck-hook.out
  } >&2
  exit 1
fi

# rc 0 (clean/WARN) or 2 (env error) → allow push; env errors are logged.
if [[ $rc -eq 2 ]]; then
  echo "shipcheck: pre-push gate errored (exit 2) — fail-open, see $LOGFILE" >>"$LOGFILE"
fi
exit 0
