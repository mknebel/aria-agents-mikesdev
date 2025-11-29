#!/bin/bash
# PostToolUse hook - Stores successful Grep results in cache

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

if [[ "$TOOL_NAME" != "Grep" ]]; then
    exit 0
fi

TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')
TOOL_OUTPUT=$(echo "$INPUT" | jq -r '.tool_output // empty')
PATTERN=$(echo "$TOOL_INPUT" | jq -r '.pattern // empty')
SEARCH_PATH=$(echo "$TOOL_INPUT" | jq -r '.path // empty')

# Only cache if we got results and pattern is meaningful
if [[ -n "$TOOL_OUTPUT" ]] && [[ ${#TOOL_OUTPUT} -gt 10 ]] && [[ ${#PATTERN} -gt 2 ]]; then
    # Store in cache (limit to first 10000 chars to avoid huge caches)
    TRUNCATED="${TOOL_OUTPUT:0:10000}"
    /home/mike/.claude/scripts/search-cache.sh store "$PATTERN" "$SEARCH_PATH" "$TRUNCATED" >> /tmp/cache-debug.log 2>&1
fi

exit 0
