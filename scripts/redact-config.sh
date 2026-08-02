#!/usr/bin/env bash
# Redact live configs for public publishing
# Usage: ./scripts/redact-config.sh [--check]
#   --check: only check for unredacted patterns, don't modify
#
# NOTE: the repo now IS the live config dir (~/.config/opencode), so configs are
# portabilized in place (bare command names, ~ paths). This script is a leak
# SCANNER for the pre-public-publish gate: it greps every tracked file for
# machine-specific or personal patterns that must not ship publicly.
#
# Exit code: 0 = safe to publish (or only known-intentional matches), 1 = leaks found.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# search|display-name — grep -E regexes. Matches print as ⚠️ (blocking).
WARN_PATTERNS=(
  "/home/[a-z]|/Users/:absolute-home-path"
  "111849193\+B67687@users\.noreply\.github\.com:personal-commit-identity"
  "(sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36}|github_pat_[a-zA-Z0-9_]{22,}|sk-or-[a-zA-Z0-9]{20,}|sk-ant-[a-zA-Z0-9]{20,}|xai-[a-zA-Z0-9]{20,}|dsk-[a-zA-Z0-9]{20,}|api[_-]?key[\"']?\s*[:=]\s*[\"'][A-Za-z0-9]):possible-api-key"
  "(gho_|ghs_|ghu_|ghr_)[a-zA-Z0-9]{36}:github-oauth-token"
  "AKIA[0-9A-Z]{16}:aws-access-key"
  "xox[baprs]-:slack-token"
  "-----BEGIN [A-Z ]*PRIVATE KEY-----:pem-private-key"
  "AIza[0-9A-Za-z_-]{35}:google-api-key"
  "glpat-[A-Za-z0-9]{20,}:gitlab-pat"
  "hf_[A-Za-z0-9]{20,}:huggingface-token"
)

# search|display-name — informational matches (expandable ~ paths, fine to ship).
INFO_PATTERNS=(
  "PROTOCOL_DIR=~/|\.local/share/opencode:hook-path-uses-expandable-tilde"
)

# Known-intentional matches: "rel-file:pattern-name" — reported but not blocking.
ALLOWED=(
  ".opencode/rules/build-workflow.mdc:personal-commit-identity"
  "scripts/redact-config.sh:absolute-home-path"
  )

check_file() {
  local file="$1"
  local rel="${file#"$REPO_DIR"/}"
  local found=false
  local warned=false
  local p

  for p in "${WARN_PATTERNS[@]}"; do
    local search="${p%%:*}"
    local name="${p#*:}"
    if grep -E "$search" "$file" >/dev/null 2>&1; then
      if [[ " ${ALLOWED[*]} " == *" ${rel}:${name} "* ]]; then
        echo "  ℹ️  ${rel}: ${name} (allowed)"
      else
        echo "  ⚠️  ${rel}: ${name}"
        warned=true
      fi
      found=true
    fi
  done

  for p in "${INFO_PATTERNS[@]}"; do
    local search="${p%%:*}"
    local name="${p#*:}"
    if grep -E "$search" "$file" >/dev/null 2>&1; then
      echo "  ℹ️  ${rel}: ${name}"
      found=true
    fi
  done

  [ "$found" = "false" ] && echo "  ✅ ${rel}"
  [ "$warned" = "true" ] && return 1
  return 0
}

case "${1:-}" in
  --check)
    echo "=== Scanning repo for unredacted patterns ==="
    echo "Repo: ${REPO_DIR}"
    echo ""
    exit_code=0
    while IFS= read -r file; do
      if ! check_file "$file"; then
        exit_code=1
      fi
    done < <(git -C "$REPO_DIR" ls-files | grep -vE '\.(png|jpg|svg|lock)$')
    echo ""
    if [ "$exit_code" -eq 0 ]; then
      echo "Done. Clean — safe to publish."
    else
      echo "Done. ⚠️  leaks found — fix before publishing (ℹ️ allowed/expandable are fine)."
    fi
    exit "$exit_code"
    ;;
  *)
    echo "=== Redact mode ==="
    echo "Repo IS the live config dir — no copy-redact needed."
    echo "Portabilization is done in place (bare command names, ~ paths)."
    echo "Run: ./scripts/redact-config.sh --check"
    echo "to scan before publishing publicly."
    ;;
esac
