#!/bin/bash
# Unified OpenRouter API caller with PRESET support
# Usage: call-openrouter.sh <preset|model> <prompt> [max_tokens]
#
# Presets (use these for optimal routing):
#   qa        - QA / Doc preset (read-only, docs, test logs)
#   tools     - General Tool-Use Agent (non-browser tools)
#   browser   - Browser Agent preset (Playwright, browser automation)
#   fast      - Super Fast preset (quick generation)
#
# Direct models still supported:
#   qwen/qwen3-coder, anthropic/claude-3-haiku, etc.
#
# Examples:
#   call-openrouter.sh fast "Write a hello world in PHP"
#   call-openrouter.sh qa "Review this test output"
#   call-openrouter.sh tools "Implement file parsing"
#   call-openrouter.sh browser "Automate login flow"

set -euo pipefail

INPUT=${1:-"fast"}
PROMPT=${2:-""}
MAX_TOKENS=${3:-8000}

if [[ -z "$PROMPT" ]]; then
  echo "Usage: call-openrouter.sh <preset|model> <prompt> [max_tokens]" >&2
  echo "" >&2
  echo "Presets: qa, tools, browser, fast" >&2
  exit 1
fi

# Map preset aliases to OpenRouter preset IDs
# Format: @preset/preset-name or direct model name
case "$INPUT" in
  qa|doc|qa-doc)
    MODEL="@preset/qa-doc-preset"
    ;;
  tools|general|non-browser)
    MODEL="@preset/general-non-browser-tools"
    ;;
  browser|playwright|ui)
    MODEL="@preset/browser-agent-tools-only"
    ;;
  fast|quick|super-fast)
    MODEL="@preset/super-fast"
    ;;
  @preset/*)
    # Direct preset ID passed
    MODEL="$INPUT"
    ;;
  *)
    # Assume it's a direct model name
    MODEL="$INPUT"
    ;;
esac

# Load API key
if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
  KEY_FILE="$HOME/.config/openrouter/api_key"
  if [[ -f "$KEY_FILE" ]]; then
    OPENROUTER_API_KEY=$(<"$KEY_FILE")
    export OPENROUTER_API_KEY
  fi
fi

if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
  echo "ERROR: Missing OPENROUTER_API_KEY" >&2
  echo "Set env var or create ~/.config/openrouter/api_key" >&2
  exit 1
fi

# Build request
API_URL="https://openrouter.ai/api/v1/chat/completions"

# Check if using preset (starts with @preset/)
if [[ "$MODEL" == @preset/* ]]; then
  # Extract preset name for logging
  PRESET_NAME="${MODEL#@preset/}"
  echo "Using preset: $PRESET_NAME" >&2

  # For presets, use openrouter/auto with route parameter
  PAYLOAD=$(jq -n \
    --arg route "$MODEL" \
    --arg prompt "$PROMPT" \
    --argjson max_tokens "$MAX_TOKENS" \
    '{
      model: "openrouter/auto",
      route: $route,
      messages: [{"role": "user", "content": $prompt}],
      max_tokens: $max_tokens
    }')
else
  # Direct model call
  PAYLOAD=$(jq -n \
    --arg model "$MODEL" \
    --arg prompt "$PROMPT" \
    --argjson max_tokens "$MAX_TOKENS" \
    '{
      model: $model,
      messages: [{"role": "user", "content": $prompt}],
      max_tokens: $max_tokens
    }')
fi

# Call API
RESPONSE=$(curl -sS "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${OPENROUTER_API_KEY}" \
  -H "HTTP-Referer: https://aria.local" \
  -H "X-Title: ARIA Agent System" \
  -d "$PAYLOAD")

# Extract content
if command -v jq >/dev/null 2>&1; then
  CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty')
  if [[ -n "$CONTENT" ]]; then
    echo "$CONTENT"
  else
    # Check for error
    ERROR=$(echo "$RESPONSE" | jq -r '.error.message // empty')
    if [[ -n "$ERROR" ]]; then
      echo "API Error: $ERROR" >&2
      exit 1
    fi
    echo "$RESPONSE"
  fi
else
  echo "$RESPONSE"
fi
