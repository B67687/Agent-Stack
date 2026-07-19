#!/usr/bin/env bash
# model-verifier.sh — Check configured models, detect new premium models.
set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
OMO="$CONFIG_DIR/oh-my-openagent.jsonc"
OPENCODE="$CONFIG_DIR/opencode.jsonc"

echo "=== Model Verifier ==="
echo ""

# Extract configured models
configured_models=$(python3 -c "
import json5, re
models = set()
for path in ['$OMO', '$OPENCODE']:
    with open(path) as f:
        c = f.read()
    for m in re.findall(r'\"model\"\s*:\s*\"([a-zA-Z0-9_./-]+)\"', c):
        models.add(m)
for m in sorted(models):
    print(m)
")

echo "Configured models ($(echo "$configured_models" | wc -l):"
echo "$configured_models" | sed 's/^/  /'
echo ""

# Fetch available models
available_models=$(opencode models 2>/dev/null | grep -oE 'opencode(?:-go)?/[a-zA-Z0-9_.-]+' | sort -u || true)

if [ -z "$available_models" ]; then
    echo "⚠️  Could not fetch available models (opencode CLI unavailable)"
    exit 0
fi

echo "Available: $(echo "$available_models" | wc -l) models"
echo ""

# 1. Check each configured model
missing=0
while IFS= read -r model; do
    if echo "$available_models" | grep -qF "$model"; then
        echo "  ✅ $model"
    elif echo "$model" | grep -q "opencode-go/"; then
        echo "  ⏭️  $model — Go-tier model (not listed in free models)"
    else
        echo "  ❌ $model — NOT FOUND in available models"
        missing=$((missing + 1))
        family=$(echo "$model" | sed 's/-\+[a-z]*$//')
        alt=$(echo "$available_models" | grep "^$family" | head -3)
        if [ -n "$alt" ]; then
            echo "     Possible replacements:"
            echo "$alt" | sed 's/^/     → /'
        fi
    fi
done <<< "$configured_models"

# 2. Detect NEW premium models not in our config
echo ""
echo "--- New Premium Model Detection ---"
OUR_PREFIXES="opencode-go/deepseek|opencode/deepseek|opencode/mimo"
PREMIUM_KEYWORDS="gpt|claude|gemini|kimi|glm|minimax|nemotron|grok|hy3|big-pickle"

NEW_PREMIUM=$(echo "$available_models" | grep -iE "$PREMIUM_KEYWORDS" | while IFS= read -r m; do
    if ! echo "$m" | grep -qE "$OUR_PREFIXES"; then
        echo "$m"
    fi
done)

if [ -n "$NEW_PREMIUM" ]; then
    count=$(echo "$NEW_PREMIUM" | wc -l)
    echo "  ⚠️  $count premium models detected (not in our config):"
    echo "$NEW_PREMIUM" | sed 's/^/     📡 /'
    echo ""
    echo "  Note: These are blocked by disabled_providers + skip_task_agent_fallback."
    echo "  Review periodically to see if any should be added to disabled_providers."
else
    echo "  ✅ No new premium models detected"
fi

# 3. Check if any premium models recently added to the available list
echo ""
echo "--- Model List Changes ---"
CACHE_FILE="/tmp/opencode-model-cache.txt"
if [ -f "$CACHE_FILE" ]; then
    OLD_COUNT=$(wc -l < "$CACHE_FILE")
    NEW_COUNT=$(echo "$available_models" | wc -l)
    ADDED=$(comm -13 <(sort "$CACHE_FILE") <(echo "$available_models" | sort) | grep -v '^$' || true)
    REMOVED=$(comm -23 <(sort "$CACHE_FILE") <(echo "$available_models" | sort) | grep -v '^$' || true)
    
    if [ -n "$ADDED" ]; then
        premium_added=$(echo "$ADDED" | grep -iE "$PREMIUM_KEYWORDS" || true)
        if [ -n "$premium_added" ]; then
            echo "  ⚠️  New premium models since last check:"
            echo "$premium_added" | sed 's/^/     🆕 /'
        fi
    fi
    if [ -n "$REMOVED" ]; then
        echo "  ⚠️  Models removed since last check:"
        echo "$REMOVED" | sed 's/^/     💀 /'
    fi
    if [ -z "$ADDED" ] && [ -z "$REMOVED" ]; then
        echo "  ✅ Model list unchanged (${OLD_COUNT} models)"
    fi
fi

# Save current list for next check
echo "$available_models" > "$CACHE_FILE"

echo ""
if [ "$missing" -eq 0 ]; then
    echo "✅ All configured models are available"
else
    echo "⚠️  $missing configured model(s) not found — update configs"
fi