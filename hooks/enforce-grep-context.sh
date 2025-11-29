#!/bin/bash
# PreToolUse hook to enforce -C:10 context on Grep/Search calls

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')

# Debug logging (optional)
echo "$(date): $TOOL_NAME" >> /tmp/hook-debug.log

if [[ "$TOOL_NAME" == "Grep" ]]; then
    HAS_CONTEXT=$(echo "$TOOL_INPUT" | jq 'has("-C")')

    if [[ "$HAS_CONTEXT" == "false" ]]; then
        UPDATED=$(echo "$TOOL_INPUT" | jq -c '. + {"-C": 10}')
        cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","updatedInput":$UPDATED}}
EOF
        exit 0
    fi
fi

echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
exit 0
