#!/bin/bash
# Fast code generation via OpenRouter
# Usage: fast-gen.sh "Your prompt here" [model]
# Models: deepseek (default), qwen, gemini, grok (needs privacy settings)

PROMPT="$1"
MODEL="${2:-deepseek}"

KEY=$(cat ~/.config/openrouter/api_key 2>/dev/null)
if [ -z "$KEY" ]; then
    echo "Error: OpenRouter API key not found at ~/.config/openrouter/api_key"
    exit 1
fi

case "$MODEL" in
    # WORKING - Tested & confirmed
    deepseek)  MODEL_ID="deepseek/deepseek-chat" ;;        # Fast, $0.14/$0.28 per 1M
    qwen)      MODEL_ID="qwen/qwen3-235b-a22b" ;;          # Good quality, ~3s
    gemini)    MODEL_ID="google/gemini-2.0-flash-001" ;;   # Fast, good

    # REQUIRES PRIVACY SETTINGS CHANGE (https://openrouter.ai/settings/privacy)
    grok)      MODEL_ID="x-ai/grok-3-mini-beta" ;;         # Needs: disable zero-retention
    grok-fast) MODEL_ID="x-ai/grok-4-fast" ;;              # Needs: disable zero-retention

    # Pass through custom model IDs
    *)         MODEL_ID="$MODEL" ;;
esac

echo "⚡ Generating with $MODEL_ID..." >&2

START=$(date +%s.%N)

RESULT=$(curl -s https://openrouter.ai/api/v1/chat/completions \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"$MODEL_ID\",
    \"messages\": [{\"role\": \"user\", \"content\": $(echo "$PROMPT" | jq -Rs .)}],
    \"max_tokens\": 8000
  }")

END=$(date +%s.%N)
DURATION=$(echo "$END - $START" | bc)

# Extract content
CONTENT=$(echo "$RESULT" | jq -r '.choices[0].message.content // .error.message // "Error: Unknown"')

echo "$CONTENT"
echo "" >&2
echo "⏱️  Generated in ${DURATION}s" >&2
