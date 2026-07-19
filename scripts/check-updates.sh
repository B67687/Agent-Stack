#!/usr/bin/env bash
set -uo pipefail

# Release Update Checker — tracks OMO and OpenCode via GitHub releases.
# Compares tracked tags against latest upstream releases.
# Outputs: JSON array of updates, or empty array [] if none.
#
# Cooldown policy:
#   - Skips if last check was < 72 hours ago (throttle file: .last-update-check)
#   - Only flags releases that are >= 72 hours old (avoids day-zero updates)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VERSIONS_FILE="$PROJECT_DIR/docs/VERSIONS.md"
COOLDOWN_FILE="$PROJECT_DIR/.last-update-check"
COOLDOWN_HOURS=72

red()    { printf "\033[31m%s\033[0m\n" "$*" 1>&2; }
green()  { printf "\033[32m%s\033[0m\n" "$*" 1>&2; }
bold()   { printf "\033[1m%s\033[0m\n" "$*" 1>&2; }

throttle_check() {
  if [ -f "$COOLDOWN_FILE" ]; then
    local last_check="$(cat "$COOLDOWN_FILE" 2>/dev/null)"
    if [ -n "$last_check" ]; then
      local now="$(date +%s)"
      local elapsed=$(( (now - last_check) / 3600 ))
      if [ "$elapsed" -lt "$COOLDOWN_HOURS" ]; then
        local remaining=$(( COOLDOWN_HOURS - elapsed ))
        green "  Skipped — last check ${elapsed}h ago, ${remaining}h remaining (cooldown: ${COOLDOWN_HOURS}h)" 1>&2
        echo '[]'
        exit 0
      fi
    fi
  fi
  date +%s > "$COOLDOWN_FILE"
}

tracked_version() {
  local pkg="$1"
  sed -n "s/^| $pkg[[:space:]]*|[[:space:]]*\([^[:space:]]*\).*/\1/p" "$VERSIONS_FILE" | head -1
}

get_latest_gh_release() {
  local repo="$1"
  gh release list -R "$repo" -L 1 --json tagName,publishedAt --jq '.[0]' 2>/dev/null
}

get_release_notes() {
  local repo="$1" tag="$2"
  gh release view "$tag" -R "$repo" --json body --jq '.body' 2>/dev/null | head -60
}

# Returns 0 if release is >= COOLDOWN_HOURS old, 1 if too fresh
release_aged_check() {
  local published_at="$1"
  if [ -z "$published_at" ] || [ "$published_at" = "null" ]; then
    return 0  # no date info — allow through
  fi
  local release_epoch="$(date -d "$published_at" +%s 2>/dev/null)"
  local now="$(date +%s)"
  local age_hours=$(( (now - release_epoch) / 3600 ))
  if [ "$age_hours" -lt "$COOLDOWN_HOURS" ]; then
    green "  Too fresh — released ${age_hours}h ago (cooldown: ${COOLDOWN_HOURS}h)" 1>&2
    return 1
  fi
  return 0
}

main() {
  throttle_check
  local updates='[]'

  bold "=== Release Update Check ==="
  echo "Checked at: $(date -u '+%Y-%m-%dT%H:%M:%SZ')" 1>&2
  echo "" 1>&2

  # --- 1. OMO (code-yeongyu/oh-my-openagent) ---
  bold "[1/2] oh-my-openagent..." 1>&2
  local omo_cur omo_latest_json omo_latest_tag omo_latest_date
  omo_cur=$(tracked_version "OMO")
  omo_latest_json=$(get_latest_gh_release "code-yeongyu/oh-my-openagent")
  omo_latest_tag=$(echo "$omo_latest_json" | jq -r '.tagName // empty')
  omo_latest_date=$(echo "$omo_latest_json" | jq -r '.publishedAt // empty')

  if [ -z "$omo_latest_tag" ]; then
    red "  FAILED — GitHub CLI unreachable for code-yeongyu/oh-my-openagent" 1>&2
  elif [ "$omo_latest_tag" != "$omo_cur" ]; then
    if release_aged_check "$omo_latest_date"; then
      green "  UPDATE: $omo_cur → $omo_latest_tag" 1>&2
      local omo_notes
      omo_notes=$(get_release_notes "code-yeongyu/oh-my-openagent" "$omo_latest_tag")
      updates=$(echo "$updates" | jq \
        --arg pkg "OMO" \
        --arg cur "$omo_cur" \
        --arg latest "$omo_latest_tag" \
        --arg notes "$omo_notes" \
        '. + [{
          "package": $pkg,
          "current_version": $cur,
          "latest_version": $latest,
          "notes": $notes,
          "source": "github-releases (code-yeongyu/oh-my-openagent)",
          "update_cmd": "npm install -g oh-my-openagent@latest",
          "repo": "code-yeongyu/oh-my-openagent"
        }]')
    fi
  else
    green "  up-to-date: $omo_cur" 1>&2
  fi

  # --- 2. OpenCode (opencode-ai/opencode) ---
  bold "[2/2] OpenCode..." 1>&2
  local oc_cur oc_latest_json oc_latest_tag oc_latest_date
  oc_cur=$(tracked_version "OpenCode")
  oc_latest_json=$(get_latest_gh_release "opencode-ai/opencode")
  oc_latest_tag=$(echo "$oc_latest_json" | jq -r '.tagName // empty')
  oc_latest_date=$(echo "$oc_latest_json" | jq -r '.publishedAt // empty')

  if [ -z "$oc_latest_tag" ]; then
    red "  FAILED — GitHub CLI unreachable for opencode-ai/opencode" 1>&2
  elif [ "$oc_latest_tag" != "$oc_cur" ]; then
    if release_aged_check "$oc_latest_date"; then
      green "  UPDATE: $oc_cur → $oc_latest_tag" 1>&2
      local oc_notes
      oc_notes=$(get_release_notes "opencode-ai/opencode" "$oc_latest_tag")
      updates=$(echo "$updates" | jq \
        --arg pkg "OpenCode" \
        --arg cur "$oc_cur" \
        --arg latest "$oc_latest_tag" \
        --arg notes "$oc_notes" \
        '. + [{
          "package": $pkg,
          "current_version": $cur,
          "latest_version": $latest,
          "notes": $notes,
          "source": "github-releases (opencode-ai/opencode)",
          "update_cmd": "opencode upgrade",
          "repo": "opencode-ai/opencode"
        }]')
    fi
  else
    green "  up-to-date: $oc_cur" 1>&2
  fi

  echo "" 1>&2
  echo "$updates" | jq -c .
}

main "$@"
