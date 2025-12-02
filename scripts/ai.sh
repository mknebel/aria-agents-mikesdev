#!/bin/bash
# Unified AI tool - uses your existing subscriptions
# Usage: ai.sh <tool> "prompt" [files...]
#
# Tools:
#   codex   - OpenAI Codex (your GPT account) - best for code review/generation
#   gemini  - Google Gemini (your Google account) - best for search/analysis
#   fast    - OpenRouter super-fast - best for quick generation
#
# Examples:
#   ai.sh codex "Review this code for bugs"
#   ai.sh gemini "Find authentication code" @src/**/*.php
#   ai.sh fast "Write a PHP email validator"
#
# All outputs saved to /tmp/claude_vars/{tool}_last for pass-by-reference

TOOL="${1:-fast}"
shift
PROMPT="$*"

# Ensure var directory exists
VAR_DIR="/tmp/claude_vars"
mkdir -p "$VAR_DIR"

# Function to save output and display
save_and_output() {
    local tool_name="$1"
    local output="$2"

    # Save to variable store
    echo "$output" > "$VAR_DIR/${tool_name}_last"

    # Display to user
    echo "$output"
}

case "$TOOL" in
    codex|c)
        echo "🤖 Codex (GPT)..." >&2
        RESULT=$(codex "$PROMPT" 2>&1)
        save_and_output "codex" "$RESULT"
        echo "📁 Saved to \$codex_last" >&2
        ;;

    gemini|g)
        echo "🔍 Gemini..." >&2
        RESULT=$(gemini "$PROMPT" 2>&1)
        save_and_output "gemini" "$RESULT"
        echo "📁 Saved to \$gemini_last" >&2
        ;;

    fast|f)
        echo "⚡ OpenRouter (fastest)..." >&2
        KEY=$(cat ~/.config/openrouter/api_key 2>/dev/null)
        if [ -z "$KEY" ]; then
            echo "Error: No OpenRouter key" >&2
            exit 1
        fi

        START=$(date +%s.%N)
        API_RESULT=$(curl -s https://openrouter.ai/api/v1/chat/completions \
            -H "Authorization: Bearer $KEY" \
            -H "Content-Type: application/json" \
            -d "{
                \"model\": \"deepseek/deepseek-chat\",
                \"messages\": [{\"role\": \"user\", \"content\": $(echo "$PROMPT" | jq -Rs .)}],
                \"max_tokens\": 8000
            }")
        END=$(date +%s.%N)

        RESULT=$(echo "$API_RESULT" | jq -r '.choices[0].message.content // .error.message')
        save_and_output "openrouter" "$RESULT"
        echo "" >&2
        echo "⏱️ $(echo "$END - $START" | bc)s | 📁 Saved to \$openrouter_last" >&2
        ;;

    *)
        echo "Usage: ai.sh <codex|gemini|fast> \"prompt\" [files...]"
        echo ""
        echo "Tools:"
        echo "  codex  - Code review/generation (your GPT account)"
        echo "  gemini - Search/analysis (your Google account)"
        echo "  fast   - Quick generation (OpenRouter)"
        echo ""
        echo "Outputs saved to /tmp/claude_vars/{tool}_last"
        ;;
esac
