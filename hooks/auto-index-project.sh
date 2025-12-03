#!/bin/bash
# UserPromptSubmit hook - Auto-indexes project if index is missing or stale
# Optimized: Faster checks, background indexing

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[[ -z "$CWD" || ! -d "$CWD" ]] && exit 0

# Find project root (quick upward search)
PROJECT_ROOT="$CWD"
while [[ "$PROJECT_ROOT" != "/" ]]; do
    [[ -d "$PROJECT_ROOT/.git" || -f "$PROJECT_ROOT/composer.json" || -f "$PROJECT_ROOT/package.json" ]] && break
    PROJECT_ROOT="${PROJECT_ROOT%/*}"
done
[[ "$PROJECT_ROOT" == "" ]] && PROJECT_ROOT="/"
[[ "$PROJECT_ROOT" == "/" ]] && exit 0

# Quick index check
INDEX_DIR="$HOME/.claude/project-indexes"
INDEX_NAME="${PROJECT_ROOT//\//-}"
INDEX_NAME="${INDEX_NAME#-}"
INDEX_FILE="$INDEX_DIR/${INDEX_NAME}.json"

# Skip if fresh (< 1 hour)
if [[ -f "$INDEX_FILE" ]]; then
    NOW=$(date +%s)
    MOD=$(stat -c %Y "$INDEX_FILE" 2>/dev/null || echo 0)
    (( NOW - MOD < 3600 )) && exit 0
fi

# Build in background (non-blocking)
mkdir -p "$INDEX_DIR"
nohup ~/.claude/scripts/build-project-index.sh "$PROJECT_ROOT" >/dev/null 2>&1 &

exit 0
