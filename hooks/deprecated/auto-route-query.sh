#!/bin/bash
# UserPromptSubmit hook - Auto-routes search queries to Gemini agent
# Optimized: Uses bash pattern matching instead of grep

INPUT=$(cat)
USER_MESSAGE=$(echo "$INPUT" | jq -r '.user_prompt // empty' 2>/dev/null)
[[ -z "$USER_MESSAGE" ]] && exit 0

# Convert to lowercase using bash
MSG_LOWER="${USER_MESSAGE,,}"

# Search patterns (bash regex)
SEARCH="find |search |where is|where are|list all|show me|locate |look for|which file|what file"
EXCLUDE="implement|write|create|fix |add |generate|build|refactor"

# Use bash regex matching (faster than grep)
if [[ "$MSG_LOWER" =~ $SEARCH ]] && [[ ! "$MSG_LOWER" =~ $EXCLUDE ]]; then
    cat << EOF
<user-prompt-submit-hook>
🔍 Search detected - use: ctx "$USER_MESSAGE" or gemini "$USER_MESSAGE" @src
</user-prompt-submit-hook>
EOF
fi

exit 0
