#!/bin/bash
# PreToolUse hook to enforce -C:10 context on Grep/Search calls

INPUT=$(cat)

# Debug logging
echo "=== $(date) ===" >> /tmp/hook-debug.log
echo "INPUT: $INPUT" >> /tmp/hook-debug.log

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')

echo "TOOL_NAME: $TOOL_NAME" >> /tmp/hook-debug.log

if [[ "$TOOL_NAME" == "Grep" ]]; then
    HAS_CONTEXT=$(echo "$TOOL_INPUT" | jq 'has("-C")')
    echo "HAS_CONTEXT: $HAS_CONTEXT" >> /tmp/hook-debug.log

    if [[ "$HAS_CONTEXT" == "false" ]]; then
        UPDATED_INPUT=$(echo "$TOOL_INPUT" | jq -c '. + {"-C": 10}')
        echo "OUTPUT (modified): {\"decision\":\"allow\",\"updatedInput\":$UPDATED_INPUT}" >> /tmp/hook-debug.log
        echo "{\"decision\":\"allow\",\"updatedInput\":$UPDATED_INPUT}"
        exit 0
    fi
fi

echo "OUTPUT: {\"decision\":\"allow\"}" >> /tmp/hook-debug.log
echo '{"decision":"allow"}'
exit 0
