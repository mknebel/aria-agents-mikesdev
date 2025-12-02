#!/bin/bash
# PreToolUse hook - Semantic deduplication cache for Grep/Search
# Normalizes search patterns and checks for semantically similar recent searches
# Cache hits prevent redundant searches and save tokens

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Only process Grep tool
if [[ "$TOOL_NAME" != "Grep" ]]; then
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
    exit 0
fi

TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')
PATTERN=$(echo "$TOOL_INPUT" | jq -r '.pattern // empty')

# Skip if no pattern
if [[ -z "$PATTERN" ]]; then
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
    exit 0
fi

# Function to generate semantic hash from pattern
generate_semantic_hash() {
    local pattern="$1"
    # Lowercase, extract 3+ char words, sort unique, hash
    echo "$pattern" | tr '[:upper:]' '[:lower:]' | grep -oE '\b[a-z]{3,}\b' | sort -u | tr '\n' ' ' | md5sum | cut -d' ' -f1
}

# Ensure cache directory exists
CACHE_DIR="/tmp/claude_semantic_cache"
mkdir -p "$CACHE_DIR" 2>/dev/null || true

# Generate semantic hash
SEMANTIC_HASH=$(generate_semantic_hash "$PATTERN")
CACHE_FILE="$CACHE_DIR/$SEMANTIC_HASH"

# Check if cache exists and is fresh (< 10 minutes old)
if [[ -f "$CACHE_FILE" ]]; then
    MTIME=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
    CURRENT_TIME=$(date +%s)
    AGE=$((CURRENT_TIME - MTIME))

    # 10 minutes = 600 seconds
    if [[ $AGE -lt 600 ]]; then
        # Cache hit - read cached result
        CACHED_RESULT=$(cat "$CACHE_FILE" 2>/dev/null || echo "")

        if [[ -n "$CACHED_RESULT" ]]; then
            # Return cached result with block decision
            cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"block","reason":"Similar search cached (hash: $SEMANTIC_HASH, age: ${AGE}s)","cachedResult":$CACHED_RESULT}}
EOF
            exit 0
        fi
    fi
fi

# Cache miss or expired - allow search to proceed
echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
exit 0
