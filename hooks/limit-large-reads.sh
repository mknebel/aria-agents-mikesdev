#!/bin/bash
# PreToolUse hook to limit Read calls on large files

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

if [[ "$TOOL_NAME" == "Read" ]]; then
    TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')
    FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty')
    HAS_LIMIT=$(echo "$TOOL_INPUT" | jq 'has("limit")')

    # Check file size (lines)
    if [[ -f "$FILE_PATH" && "$HAS_LIMIT" == "false" ]]; then
        LINES=$(wc -l < "$FILE_PATH" 2>/dev/null || echo "0")
        if [[ "$LINES" -gt 500 ]]; then
            # Add limit for large files
            UPDATED=$(echo "$TOOL_INPUT" | jq -c '. + {"limit": 300}')
            echo "{\"decision\":\"allow\",\"updatedInput\":$UPDATED}"
            exit 0
        fi
    fi
fi

echo '{"decision":"allow"}'
exit 0
