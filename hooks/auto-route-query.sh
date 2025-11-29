#!/bin/bash
# UserPromptSubmit hook - Auto-routes queries to cheapest capable model

INPUT=$(cat)

# Extract the user's message
USER_MESSAGE=$(echo "$INPUT" | jq -r '.user_prompt // empty' | tr '[:upper:]' '[:lower:]')

# Debug logging
echo "=== $(date) ===" >> /tmp/auto-route-debug.log
echo "USER_MESSAGE: $USER_MESSAGE" >> /tmp/auto-route-debug.log

# Search-related keywords → Route to Gemini agent
SEARCH_PATTERNS="find |search |where is|where are|list all|show me|locate |look for|which files|what files"

if echo "$USER_MESSAGE" | grep -qiE "$SEARCH_PATTERNS"; then
    # Don't route if already using a command or asking about code generation
    EXCLUDE_PATTERNS="implement|write code|create |fix |add feature|generate|build"

    if ! echo "$USER_MESSAGE" | grep -qiE "$EXCLUDE_PATTERNS"; then
        echo "ROUTED: Search query → Gemini agent" >> /tmp/auto-route-debug.log

        # Get original prompt to pass through
        ORIGINAL=$(echo "$INPUT" | jq -r '.user_prompt // empty')

        # Add routing instruction
        MODIFIED="Use the parallel-work-manager-fast agent (Gemini) for this search task. Query: $ORIGINAL"

        # Return modified prompt
        echo "{\"decision\":\"allow\",\"updatedPrompt\":\"$MODIFIED\"}"
        exit 0
    fi
fi

echo "PASSTHROUGH: Not a search query" >> /tmp/auto-route-debug.log
echo '{"decision":"allow"}'
exit 0
