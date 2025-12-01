#!/bin/bash
# Unified OpenRouter API caller for aria agents
# Usage: call-openrouter.sh <model> <prompt> [max_tokens]
set -euo pipefail

MODEL=${1:-"qwen/qwen3-coder"}
PROMPT=${2:-""}
MAX_TOKENS=${3:-8000}

if [[ -z "$PROMPT" ]]; then
  echo "Usage: call-openrouter.sh <model> <prompt> [max_tokens]" >&2
  exit 1
fi

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

PAYLOAD=$(jq -n \
  --arg model "$MODEL" \
  --arg prompt "$PROMPT" \
  --argjson max_tokens "$MAX_TOKENS" \
  '{
    model: $model,
    messages: [{"role": "user", "content": $prompt}],
    max_tokens: $max_tokens
  }')

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
