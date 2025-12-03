#!/bin/bash
# prompt-handler.sh - Consolidated UserPromptSubmit hook
# Combines: fast-mode-prompt, auto-route-query, auto-index-project

INPUT=$(cat 2>/dev/null) || exit 0

# Ensure jq is available
command -v jq >/dev/null 2>&1 || exit 0

CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null) || true
USER_MESSAGE=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null) || true

if [ -z "$CWD" ]; then
    exit 0
fi

# ─────────────────────────────────────────────
# 1. FAST MODE PROMPT (if enabled)
# ─────────────────────────────────────────────
MODE_FILE="$HOME/.claude/routing-mode"
if [ -f "$MODE_FILE" ] && [ "$(cat "$MODE_FILE" 2>/dev/null)" = "fast" ]; then
    # Suggest tool based on prompt (use grep for regex matching)
    MSG_LOWER=$(echo "$USER_MESSAGE" | tr '[:upper:]' '[:lower:]')
    CMD=""

    if echo "$MSG_LOWER" | grep -qE '(implement|write|create|build|add|generate|fix|refactor)'; then
        CMD="ctx \"keyword\" && llm auto \"implement @var:ctx_last\""
    elif echo "$MSG_LOWER" | grep -qE '(review|check|analyze|audit)'; then
        CMD="ctx \"keyword\" && llm qa \"review @var:ctx_last\""
    elif echo "$MSG_LOWER" | grep -qE '(find|search|where|locate)'; then
        CMD="ctx \"$USER_MESSAGE\""
    else
        CMD="llm auto \"$USER_MESSAGE\""
    fi

    cat << EOF
<user-prompt-submit-hook>
⚡ FAST MODE - Use @var: references, not inline data
Suggested: $CMD
</user-prompt-submit-hook>
EOF
fi

# ─────────────────────────────────────────────
# 2. AUTO-ROUTE SEARCH QUERIES
# ─────────────────────────────────────────────
MSG_LOWER=$(echo "$USER_MESSAGE" | tr '[:upper:]' '[:lower:]')

if echo "$MSG_LOWER" | grep -qE '(find |search |where is|where are|list all|show me|locate)'; then
    if ! echo "$MSG_LOWER" | grep -qE '(implement|write|create|fix |add |generate|build|refactor)'; then
        cat << EOF
<user-prompt-submit-hook>
🔍 Search query detected. Consider:
   ctx "$USER_MESSAGE"
</user-prompt-submit-hook>
EOF
    fi
fi

# ─────────────────────────────────────────────
# 3. AUTO-INDEX PROJECT (background)
# ─────────────────────────────────────────────
PROJECT_ROOT="$CWD"
while [ "$PROJECT_ROOT" != "/" ]; do
    if [ -d "$PROJECT_ROOT/.git" ] || [ -f "$PROJECT_ROOT/composer.json" ] || [ -f "$PROJECT_ROOT/package.json" ]; then
        break
    fi
    PROJECT_ROOT="${PROJECT_ROOT%/*}"
done

if [ -z "$PROJECT_ROOT" ] || [ "$PROJECT_ROOT" = "/" ]; then
    exit 0
fi

INDEX_DIR="$HOME/.claude/project-indexes"
INDEX_NAME="${PROJECT_ROOT//\//-}"
INDEX_NAME="${INDEX_NAME#-}"
INDEX_FILE="$INDEX_DIR/${INDEX_NAME}.json"

# Skip if fresh (< 1 hour)
if [ -f "$INDEX_FILE" ]; then
    NOW=$(date +%s)
    MOD=$(stat -c %Y "$INDEX_FILE" 2>/dev/null || echo 0)
    if [ $((NOW - MOD)) -lt 3600 ]; then
        exit 0
    fi
fi

# Build in background
mkdir -p "$INDEX_DIR" 2>/dev/null
nohup ~/.claude/scripts/build-project-index.sh "$PROJECT_ROOT" >/dev/null 2>&1 &

exit 0
