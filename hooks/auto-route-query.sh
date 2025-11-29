#!/bin/bash
# UserPromptSubmit hook - Auto-routes search queries to Gemini agent

INPUT=$(cat)
USER_MESSAGE=$(echo "$INPUT" | jq -r '.user_prompt // empty' | tr '[:upper:]' '[:lower:]')

# Debug logging
echo "$(date): $USER_MESSAGE" >> /tmp/auto-route-debug.log

# Search-related keywords → Route to Gemini agent
SEARCH_PATTERNS="find |search |where is|where are|list all|show me all|locate |look for|which files|what files"
EXCLUDE_PATTERNS="implement|write code|create a|fix |add feature|generate|build a"

if echo "$USER_MESSAGE" | grep -qiE "$SEARCH_PATTERNS"; then
    if ! echo "$USER_MESSAGE" | grep -qiE "$EXCLUDE_PATTERNS"; then
        echo "ROUTED to agent" >> /tmp/auto-route-debug.log

        # For UserPromptSubmit, output additional context as plain text
        ORIGINAL=$(echo "$INPUT" | jq -r '.user_prompt // empty')
        echo "IMPORTANT: Route this search task to the parallel-work-manager-fast agent (uses Gemini - faster and cheaper). The search query is: $ORIGINAL"
        exit 0
    fi
fi

# Pass through - output nothing to allow original prompt
exit 0
