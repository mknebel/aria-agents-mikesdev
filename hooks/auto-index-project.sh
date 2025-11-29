#!/bin/bash
# UserPromptSubmit hook - Auto-indexes project if index is missing or stale
# Runs in background to not block the session

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

if [[ -z "$CWD" ]]; then
    exit 0
fi

# Find project root (look for .git, composer.json, package.json)
PROJECT_ROOT="$CWD"
while [[ "$PROJECT_ROOT" != "/" ]]; do
    if [[ -d "$PROJECT_ROOT/.git" ]] || [[ -f "$PROJECT_ROOT/composer.json" ]] || [[ -f "$PROJECT_ROOT/package.json" ]]; then
        break
    fi
    PROJECT_ROOT=$(dirname "$PROJECT_ROOT")
done

if [[ "$PROJECT_ROOT" == "/" ]]; then
    exit 0
fi

# Generate index filename
INDEX_NAME=$(echo "$PROJECT_ROOT" | tr '/' '-' | sed 's/^-//')
INDEX_FILE="$HOME/.claude/project-indexes/${INDEX_NAME}.json"

# Check if index exists and is fresh (less than 1 hour old)
NEEDS_INDEX=false

if [[ ! -f "$INDEX_FILE" ]]; then
    NEEDS_INDEX=true
    echo "$(date): No index for $PROJECT_ROOT - will build" >> /tmp/auto-index-debug.log
else
    INDEX_AGE=$(( $(date +%s) - $(stat -c %Y "$INDEX_FILE" 2>/dev/null || echo 0) ))
    if [[ $INDEX_AGE -gt 3600 ]]; then
        NEEDS_INDEX=true
        echo "$(date): Index stale ($INDEX_AGE sec) for $PROJECT_ROOT - will rebuild" >> /tmp/auto-index-debug.log
    fi
fi

# Build index in background if needed (don't block the session)
if [[ "$NEEDS_INDEX" == "true" ]]; then
    nohup /home/mike/.claude/scripts/build-project-index.sh "$PROJECT_ROOT" >> /tmp/auto-index-debug.log 2>&1 &
fi

exit 0
