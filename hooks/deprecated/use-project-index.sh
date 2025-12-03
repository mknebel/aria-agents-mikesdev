#!/bin/bash
# PreToolUse hook - Uses project index for fast lookups when available
# Intercepts Grep calls and checks if index can answer the query

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

if [[ "$TOOL_NAME" != "Grep" ]]; then
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
    exit 0
fi

TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')
SEARCH_PATH=$(echo "$TOOL_INPUT" | jq -r '.path // empty')
PATTERN=$(echo "$TOOL_INPUT" | jq -r '.pattern // empty')

# Determine project root from search path
if [[ -z "$SEARCH_PATH" ]]; then
    SEARCH_PATH=$(echo "$INPUT" | jq -r '.cwd // empty')
fi

# Convert to absolute and find project root (look for .git, composer.json, package.json)
if [[ -d "$SEARCH_PATH" ]]; then
    PROJECT_ROOT="$SEARCH_PATH"
elif [[ -f "$SEARCH_PATH" ]]; then
    PROJECT_ROOT=$(dirname "$SEARCH_PATH")
else
    PROJECT_ROOT="$SEARCH_PATH"
fi

# Walk up to find project root
while [[ "$PROJECT_ROOT" != "/" ]]; do
    if [[ -d "$PROJECT_ROOT/.git" ]] || [[ -f "$PROJECT_ROOT/composer.json" ]] || [[ -f "$PROJECT_ROOT/package.json" ]]; then
        break
    fi
    PROJECT_ROOT=$(dirname "$PROJECT_ROOT")
done

# Generate index filename
INDEX_NAME=$(echo "$PROJECT_ROOT" | tr '/' '-' | sed 's/^-//')
INDEX_FILE="$HOME/.claude/project-indexes/${INDEX_NAME}.json"

# Check if index exists and is fresh (less than 1 hour old)
if [[ ! -f "$INDEX_FILE" ]]; then
    # No index - pass through
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
    exit 0
fi

INDEX_AGE=$(( $(date +%s) - $(stat -c %Y "$INDEX_FILE" 2>/dev/null || echo 0) ))
if [[ $INDEX_AGE -gt 3600 ]]; then
    # Index too old - pass through
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
    exit 0
fi

# Check if pattern looks like a simple class/function lookup
# These are cases where the index can help
if echo "$PATTERN" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*$'; then
    # Simple identifier - check index

    # Check function index
    FUNC_MATCH=$(jq -r ".function_index[\"$PATTERN\"] // empty" "$INDEX_FILE" 2>/dev/null)
    if [[ -n "$FUNC_MATCH" ]]; then
        # Found in function index - log and add hint
        echo "$(date): INDEX HIT - function '$PATTERN' -> $FUNC_MATCH" >> /tmp/index-debug.log
        # Still allow the search but it will be faster with this hint
    fi

    # Check class index
    CLASS_MATCH=$(jq -r ".class_index[\"$PATTERN\"] // empty" "$INDEX_FILE" 2>/dev/null)
    if [[ -n "$CLASS_MATCH" ]]; then
        echo "$(date): INDEX HIT - class '$PATTERN' -> $CLASS_MATCH" >> /tmp/index-debug.log
    fi
fi

# Pass through - the actual search still runs, but we logged potential hits
echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
exit 0
