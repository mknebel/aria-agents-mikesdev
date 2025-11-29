#!/bin/bash
# PreToolUse hook to enforce -C:10 context on Grep/Search calls

INPUT=$(cat)

# Debug logging
echo "=== $(date) ===" >> /tmp/hook-debug.log
echo "INPUT: $INPUT" >> /tmp/hook-debug.log

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // .tool // empty')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // .input // empty')

echo "TOOL_NAME: $TOOL_NAME" >> /tmp/hook-debug.log

# Match both "Grep" and "Search" tool names
if [[ "$TOOL_NAME" == "Grep" ]] || [[ "$TOOL_NAME" == "Search" ]]; then
    HAS_CONTEXT=$(echo "$TOOL_INPUT" | jq 'has("-C")')
    echo "HAS_CONTEXT: $HAS_CONTEXT" >> /tmp/hook-debug.log

    if [[ "$HAS_CONTEXT" == "false" ]]; then
        UPDATED_INPUT=$(echo "$TOOL_INPUT" | jq '. + {"-C": 10}')
        OUTPUT="{\"behavior\": \"allow\", \"updatedInput\": $UPDATED_INPUT}"
        echo "OUTPUT (modified): $OUTPUT" >> /tmp/hook-debug.log
        echo "$OUTPUT"
        exit 0
    fi
fi

echo "OUTPUT (passthrough): {\"behavior\": \"allow\"}" >> /tmp/hook-debug.log
echo '{"behavior": "allow"}'
