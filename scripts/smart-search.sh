#!/bin/bash
# Smart Search - Two-pass hybrid for high quality + low cost
#
# Pass 1: ripgrep + DeepSeek (fast, broad, $0.14/M)
# Pass 2: Gemini refines top results (FREE, ~75% quality)
#
# Combined quality: ~78-80% (vs 67.8% single-pass, 80.9% Claude)
# Cost: Mostly FREE (Gemini is your Google account)
#
# Usage:
#   smart-search.sh "query" [path]
#   smart-search.sh "find authentication code" src/
#   smart-search.sh "payment handling" . --skip-refine  # Pass 1 only

set -e

# Parse args
QUERY=""
SEARCH_PATH="."
SKIP_REFINE=0

for arg in "$@"; do
    case "$arg" in
        --skip-refine|--fast) SKIP_REFINE=1 ;;
        *)
            if [[ -z "$QUERY" ]]; then
                QUERY="$arg"
            else
                SEARCH_PATH="$arg"
            fi
            ;;
    esac
done

[[ -z "$QUERY" ]] && echo "Usage: smart-search.sh \"query\" [path] [--skip-refine]" && exit 1

VAR_DIR="/tmp/claude_vars"
CACHE_SCRIPT="$HOME/.claude/scripts/search-cache.sh"
OPENROUTER_KEY=$(cat ~/.config/openrouter/api_key 2>/dev/null)

mkdir -p "$VAR_DIR"

echo "🔍 Smart Search (indexed + two-pass hybrid)" >&2
echo "📋 Query: $QUERY" >&2
echo "📁 Path: $SEARCH_PATH" >&2
echo "" >&2

# ━━━ Check/Build Index First ━━━
SEARCH_PATH_ABS=$(cd "$SEARCH_PATH" 2>/dev/null && pwd || echo "$SEARCH_PATH")
INDEX_NAME=$(echo "$SEARCH_PATH_ABS" | md5sum | cut -d' ' -f1)
INDEX_DIR="$HOME/.claude/indexes/$INDEX_NAME"
INDEX_SEARCH="$HOME/.claude/scripts/index-v2/search.sh"
INDEX_BUILD="$HOME/.claude/scripts/index-v2/build-index.sh"

# Auto-build index if missing
if [[ ! -d "$INDEX_DIR" ]] && [[ -x "$INDEX_BUILD" ]]; then
    echo "📦 No index found. Building index..." >&2
    "$INDEX_BUILD" "$SEARCH_PATH_ABS" >&2 || true
    echo "" >&2
fi

# Try index search first if available
if [[ -d "$INDEX_DIR" ]] && [[ -x "$INDEX_SEARCH" ]]; then
    echo "⚡ Using index..." >&2
    INDEX_RESULT=$("$INDEX_SEARCH" "$QUERY" "$SEARCH_PATH_ABS" 2>/dev/null || echo "")
    if [[ -n "$INDEX_RESULT" && "$INDEX_RESULT" != *"No matches"* ]]; then
        echo "$INDEX_RESULT" > "$VAR_DIR/smart_search_last"
        echo "$INDEX_RESULT"
        exit 0
    fi
    echo "📭 Index miss, falling back to ripgrep..." >&2
fi

# ━━━ Check Cache First ━━━
if [[ -x "$CACHE_SCRIPT" ]]; then
    CACHE_RESULT=$("$CACHE_SCRIPT" check "$QUERY" "$SEARCH_PATH" 2>/dev/null || echo "MISS")
    CACHE_STATUS=$(echo "$CACHE_RESULT" | head -1)
    if [[ "$CACHE_STATUS" == "HIT" || "$CACHE_STATUS" == "SIMILAR" ]]; then
        CACHE_FILE=$(echo "$CACHE_RESULT" | tail -1)
        echo "⚡ Cache $CACHE_STATUS" >&2
        cat "$CACHE_FILE"
        exit 0
    fi
fi

# ━━━ Pass 1: Fast Broad Search ━━━
echo "━━━ Pass 1: Fast scan ━━━" >&2

# Extract meaningful search terms
SEARCH_TERMS=$(echo "$QUERY" | tr ' ' '\n' | grep -E '^[a-zA-Z]{3,}' | grep -ivE '^(find|search|show|get|all|the|and|for|how|what|where|which|code|function|class|file|with|from|that|this|have|does)$' | head -5 | tr '\n' '|' | sed 's/|$//')

[[ -z "$SEARCH_TERMS" ]] && SEARCH_TERMS="$QUERY"

echo "🔎 Terms: $SEARCH_TERMS" >&2

# Run ripgrep
RG_RESULTS=$(rg -n -i --hidden --glob '!.git' --glob '!node_modules' --glob '!vendor' --glob '!*.min.js' --glob '!*.map' -e "$SEARCH_TERMS" "$SEARCH_PATH" 2>/dev/null | head -100 || true)

if [[ -z "$RG_RESULTS" ]]; then
    echo "⚠️  No matches for: $SEARCH_TERMS" >&2
    echo "No matches found."
    exit 0
fi

MATCH_COUNT=$(echo "$RG_RESULTS" | wc -l)
echo "📊 Found $MATCH_COUNT matches" >&2

# Save Pass 1
echo "$RG_RESULTS" > "$VAR_DIR/search_pass1"

# If skip refine or no API access, return Pass 1
if [[ $SKIP_REFINE -eq 1 ]]; then
    echo "" >&2
    echo "⏭️  Skipped refinement (--skip-refine)" >&2
    echo "$RG_RESULTS"
    exit 0
fi

# ━━━ Pass 1.5: DeepSeek Quick Filter (if OpenRouter available) ━━━
FILTERED_RESULTS="$RG_RESULTS"

if [[ -n "$OPENROUTER_KEY" ]] && [[ $MATCH_COUNT -gt 20 ]]; then
    echo "" >&2
    echo "━━━ Pass 1.5: Quick filter (DeepSeek) ━━━" >&2

    FILTER_PROMPT="Filter these search results for \"$QUERY\". Return ONLY the 20 most relevant lines, preserving the exact file:line:content format:

$RG_RESULTS"

    FILTER_RESPONSE=$(curl -s https://openrouter.ai/api/v1/chat/completions \
        -H "Authorization: Bearer $OPENROUTER_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"deepseek/deepseek-chat\",
            \"messages\": [{\"role\": \"user\", \"content\": $(echo "$FILTER_PROMPT" | jq -Rs .)}],
            \"max_tokens\": 2000
        }" 2>/dev/null || echo "")

    if [[ -n "$FILTER_RESPONSE" ]]; then
        FILTERED=$(echo "$FILTER_RESPONSE" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
        if [[ -n "$FILTERED" && "$FILTERED" != "null" ]]; then
            FILTERED_RESULTS="$FILTERED"
            echo "📉 Filtered to top matches" >&2
        fi
    fi
fi

# ━━━ Pass 2: Gemini Refinement (FREE) ━━━
echo "" >&2
echo "━━━ Pass 2: Refine (Gemini FREE) ━━━" >&2

# Check if gemini is available
if ! command -v gemini &>/dev/null; then
    echo "⚠️  Gemini not installed, returning filtered results" >&2
    echo "$FILTERED_RESULTS" > "$VAR_DIR/smart_search_last"
    echo "$FILTERED_RESULTS"
    exit 0
fi

GEMINI_PROMPT="I searched a codebase for: \"$QUERY\"

Here are the search results (file:line:content):

$FILTERED_RESULTS

Analyze and provide:
1. **TOP 10 most relevant matches** - file:line and why it's relevant
2. **Key files to read** - which files contain the main logic
3. **Summary** - 2-3 sentences about what you found

Be concise and specific."

echo "🧠 Analyzing with Gemini..." >&2

# Run Gemini
REFINED=$(echo "$GEMINI_PROMPT" | gemini 2>/dev/null || echo "")

if [[ -z "$REFINED" ]]; then
    echo "⚠️  Gemini failed, returning filtered results" >&2
    REFINED="$FILTERED_RESULTS"
fi

# Save results
echo "$FILTERED_RESULTS" > "$VAR_DIR/search_raw"
echo "$REFINED" > "$VAR_DIR/search_last"
echo "$REFINED" > "$VAR_DIR/smart_search_last"

# Cache results
if [[ -x "$CACHE_SCRIPT" ]]; then
    "$CACHE_SCRIPT" store "$QUERY" "$SEARCH_PATH" "$REFINED" >/dev/null 2>&1 || true
fi

echo "" >&2
echo "✅ Done | \$smart_search_last" >&2

echo "$REFINED"
