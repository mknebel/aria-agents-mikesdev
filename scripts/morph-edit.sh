#!/bin/bash
# Morph V3 Fast - Ultra-fast exact code replacements (10,500 tps)
# Usage: morph-edit.sh <instruction> <file> [old_code] [new_code]
# Or pipe code: echo "old code" | morph-edit.sh "instruction" "file"
set -euo pipefail

INSTRUCTION=${1:-""}
FILE=${2:-""}
OLD_CODE=${3:-""}
NEW_CODE=${4:-""}

if [[ -z "$INSTRUCTION" ]]; then
  echo "Usage: morph-edit.sh <instruction> <file> [old_code] [new_code]" >&2
  echo "Example: morph-edit.sh 'Rename getUserById to findUser' src/User.php" >&2
  exit 1
fi

# Read file content if provided
CODE=""
if [[ -n "$FILE" && -f "$FILE" ]]; then
  CODE=$(<"$FILE")
elif [[ -n "$OLD_CODE" ]]; then
  CODE="$OLD_CODE"
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
  exit 1
fi

# Morph requires special format
PROMPT="<instruction>${INSTRUCTION}</instruction>
<code>${CODE}</code>
<update>${NEW_CODE}</update>"

API_URL="https://openrouter.ai/api/v1/chat/completions"

PAYLOAD=$(jq -n \
  --arg prompt "$PROMPT" \
  '{
    model: "morph/morph-v3-fast",
    messages: [{"role": "user", "content": $prompt}],
    max_tokens: 8000
  }')

RESPONSE=$(curl -sS "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${OPENROUTER_API_KEY}" \
  -H "HTTP-Referer: https://aria.local" \
  -H "X-Title: ARIA Morph Editor" \
  -d "$PAYLOAD")

# Extract and output result
if command -v jq >/dev/null 2>&1; then
  CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty')
  if [[ -n "$CONTENT" ]]; then
    echo "$CONTENT"

    # Optionally write back to file
    if [[ -n "$FILE" && -f "$FILE" && "${MORPH_WRITE_BACK:-}" == "true" ]]; then
      echo "$CONTENT" > "$FILE"
      echo "# Written to $FILE" >&2
    fi
  else
    echo "$RESPONSE"
  fi
else
  echo "$RESPONSE"
fi
