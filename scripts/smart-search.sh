#!/bin/bash
# Smart Search - Grep + LLM analysis (DeepSeek, Gemini, or Codex)
# Saves Claude tokens by having cheaper models analyze search results
#
# Usage:
#   smart-search.sh "query" [path] [--gemini|--codex|--deepseek]
#   smart-search.sh "error handling" src/
#   smart-search.sh "authentication" . --gemini

# Parse args
BACKEND="deepseek"
QUERY=""
SEARCH_PATH="."

for arg in "$@"; do
    case "$arg" in
        --gemini) BACKEND="gemini" ;;
        --codex) BACKEND="codex" ;;
        --deepseek) BACKEND="deepseek" ;;
        *)
            if [ -z "$QUERY" ]; then
                QUERY="$arg"
            else
                SEARCH_PATH="$arg"
            fi
            ;;
    esac
done

[ -z "$QUERY" ] && echo "Usage: smart-search.sh \"query\" [path] [--gemini|--codex|--deepseek]" && exit 1

VAR_DIR="/tmp/claude_vars"
mkdir -p "$VAR_DIR"

echo "🔍 Searching: $QUERY in $SEARCH_PATH (backend: $BACKEND)" >&2

# Run grep
RESULTS=$(rg -n "$QUERY" "$SEARCH_PATH" 2>/dev/null | head -100)

if [ -z "$RESULTS" ]; then
    echo "No matches found for: $QUERY"
    exit 0
fi

MATCH_COUNT=$(echo "$RESULTS" | wc -l)
echo "📊 Found $MATCH_COUNT matches, analyzing with $BACKEND..." >&2

PROMPT="Analyze these search results for \"$QUERY\":
1. List the most relevant files and line numbers
2. Briefly describe what each match does
3. Identify the main location(s)

Results:
$RESULTS

Be concise. Format: file:line - brief description"

# Call appropriate backend
case "$BACKEND" in
    gemini)
        ANALYSIS=$(echo "$PROMPT" | gemini 2>/dev/null)
        ;;
    codex)
        ANALYSIS=$(codex "$PROMPT" 2>/dev/null)
        ;;
    deepseek|*)
        OPENROUTER_KEY=$(cat ~/.config/openrouter/api_key 2>/dev/null)
        [ -z "$OPENROUTER_KEY" ] && echo "Error: No OpenRouter API key" && exit 1
        RESPONSE=$(curl -s https://openrouter.ai/api/v1/chat/completions \
            -H "Authorization: Bearer $OPENROUTER_KEY" \
            -H "Content-Type: application/json" \
            -d "{
                \"model\": \"deepseek/deepseek-chat\",
                \"messages\": [{\"role\": \"user\", \"content\": $(echo "$PROMPT" | jq -Rs .)}],
                \"max_tokens\": 1000
            }")
        ANALYSIS=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // "Analysis failed"')
        ;;
esac

# Save results
echo "$RESULTS" > "$VAR_DIR/smart_search_raw"
echo "$ANALYSIS" > "$VAR_DIR/smart_search_last"

echo "$ANALYSIS"
echo "" >&2
echo "📁 Raw: \$smart_search_raw | Analysis: \$smart_search_last" >&2
