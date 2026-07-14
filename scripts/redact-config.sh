#!/usr/bin/env bash
# Redact live configs for public publishing
# Usage: ./scripts/redact-config.sh [--check]
#   --check: only check for unredacted patterns, don't modify
set -euo pipefail

CONFIG_DIR="${HOME}/.config/opencode"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

PATTERNS=(
  "${HOME}/.local/share/opencode:{{OPENDATA_DIR}}"
  "${HOME}/.cache/ms-playwright/chromium-1223/chrome-linux64/chrome:{{PLAYWRIGHT_CHROME}}"
)

redact_file() {
  local src="$1"
  local dest="$2"
  local check_only="${3:-false}"

  if [ ! -f "$src" ]; then
    echo "❌ Source not found: $src"
    return 1
  fi

  if [ "$check_only" = "true" ]; then
    local found=false
    for pattern in "${PATTERNS[@]}"; do
      local search="${pattern%%:*}"
      if grep -F "$search" "$src" >/dev/null 2>&1; then
        echo "  ⚠️  Unredacted: ${search}"
        found=true
      fi
    done
    if [ "$found" = "false" ]; then
      echo "  ✅ Clean"
    fi
    return 0
  fi

  # Copy then redact
  cp "$src" "$dest"
  for pattern in "${PATTERNS[@]}"; do
    local search="${pattern%%:*}"
    local replace="${pattern#*:}"
    if [[ "$(uname)" == "Darwin" ]]; then
      sed -i '' "s|${search}|${replace}|g" "$dest"
    else
      sed -i "s|${search}|${replace}|g" "$dest"
    fi
  done
  echo "  ✅ Redacted: $(basename "$dest")"
}

case "${1:-}" in
  --check)
    echo "=== Checking for unredacted patterns ==="
    echo ""
    echo "opencode.jsonc:"
    redact_file "${CONFIG_DIR}/opencode.jsonc" "" true
    echo "oh-my-openagent.jsonc:"
    redact_file "${CONFIG_DIR}/oh-my-openagent.jsonc" "" true
    ;;
  *)
    echo "=== Redacting configs for publishing ==="
    echo ""
    echo "Copying from ${CONFIG_DIR} → ${REPO_DIR}"
    echo ""
    redact_file "${CONFIG_DIR}/opencode.jsonc" "${REPO_DIR}/opencode.jsonc"
    redact_file "${CONFIG_DIR}/oh-my-openagent.jsonc" "${REPO_DIR}/oh-my-openagent.jsonc"
    echo ""
    echo "Done. Review the files before committing."
    ;;
esac
