#!/bin/bash
# Smart Read - Read file + OpenRouter LLM summary
# Saves Claude tokens by having cheaper models summarize file contents
#
# Usage:
#   smart-read.sh <file> [question]
#   smart-read.sh src/Controller/AppController.php
#   smart-read.sh src/Service/Auth.php "how does authentication work?"

FILE="$1"
QUESTION="${2:-Summarize this file: what does it do, key functions, and important details}"

[ -z "$FILE" ] && echo "Usage: smart-read.sh <file> [question]" && exit 1
[ ! -f "$FILE" ] && echo "File not found: $FILE" && exit 1

OPENROUTER_KEY=$(cat ~/.config/openrouter/api_key 2>/dev/null)
[ -z "$OPENROUTER_KEY" ] && echo "Error: No OpenRouter API key" && exit 1

MODEL="deepseek/deepseek-chat"
VAR_DIR="/tmp/claude_vars"
mkdir -p "$VAR_DIR"

echo "📖 Reading: $FILE" >&2

# Read file (limit to 500 lines for large files)
CONTENT=$(head -500 "$FILE")
LINE_COUNT=$(wc -l < "$FILE")

if [ "$LINE_COUNT" -gt 500 ]; then
    echo "⚠️  File truncated to 500 lines (total: $LINE_COUNT)" >&2
fi

echo "🧠 Analyzing with DeepSeek..." >&2

# Send to OpenRouter
PROMPT="File: $FILE

$QUESTION

Content:
\`\`\`
$CONTENT
\`\`\`

Provide a concise, useful answer. Include specific line numbers for key code."

RESPONSE=$(curl -s https://openrouter.ai/api/v1/chat/completions \
    -H "Authorization: Bearer $OPENROUTER_KEY" \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"$MODEL\",
        \"messages\": [{\"role\": \"user\", \"content\": $(echo "$PROMPT" | jq -Rs .)}],
        \"max_tokens\": 1500
    }")

ANALYSIS=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // "Analysis failed"')

echo "$ANALYSIS" > "$VAR_DIR/smart_read_last"

echo "$ANALYSIS"
echo "" >&2
echo "📁 Saved to \$smart_read_last" >&2
