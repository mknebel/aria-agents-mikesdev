#!/bin/bash
# PreToolUse hook - Checks search cache before running Grep
# If cached result exists and is fresh, logs the hit (actual caching TBD in PostToolUse)

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

if [[ "$TOOL_NAME" != "Grep" ]]; then
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
    exit 0
fi

TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')
PATTERN=$(echo "$TOOL_INPUT" | jq -r '.pattern // empty')
SEARCH_PATH=$(echo "$TOOL_INPUT" | jq -r '.path // empty')

# Check cache
CACHE_RESULT=$(/home/mike/.claude/scripts/search-cache.sh check "$PATTERN" "$SEARCH_PATH" 2>/dev/null)
CACHE_STATUS=$(echo "$CACHE_RESULT" | head -1)

if [[ "$CACHE_STATUS" == "HIT" ]] || [[ "$CACHE_STATUS" == "SIMILAR" ]]; then
    CACHE_FILE=$(echo "$CACHE_RESULT" | tail -1)
    echo "$(date): CACHE $CACHE_STATUS for '$PATTERN' -> $CACHE_FILE" >> /tmp/cache-debug.log
    # Note: We still allow the search to run, but logging shows cache would help
    # Full cache return would require modifying tool output, which is complex
fi

echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
exit 0
