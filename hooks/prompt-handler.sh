#!/bin/bash
# prompt-handler.sh - Consolidated UserPromptSubmit hook
# Combines: fast-mode-prompt, auto-route-query, auto-index-project

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
USER_MESSAGE=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)

[[ -z "$CWD" ]] && exit 0

# ─────────────────────────────────────────────
# 1. FAST MODE PROMPT (if enabled)
# ─────────────────────────────────────────────
MODE_FILE="$HOME/.claude/routing-mode"
if [[ -f "$MODE_FILE" ]] && [[ "$(cat "$MODE_FILE")" == "fast" ]]; then
    # Suggest tool based on prompt
    MSG_LOWER="${USER_MESSAGE,,}"

    if [[ "$MSG_LOWER" =~ (implement|write|create|build|add|generate|fix|refactor) ]]; then
        CMD="ctx \"keyword\" && llm auto \"implement @var:ctx_last\""
    elif [[ "$MSG_LOWER" =~ (review|check|analyze|audit) ]]; then
        CMD="ctx \"keyword\" && llm qa \"review @var:ctx_last\""
    elif [[ "$MSG_LOWER" =~ (find|search|where|locate) ]]; then
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
MSG_LOWER="${USER_MESSAGE,,}"
SEARCH="find |search |where is|where are|list all|show me|locate"
EXCLUDE="implement|write|create|fix |add |generate|build|refactor"

if [[ "$MSG_LOWER" =~ $SEARCH ]] && [[ ! "$MSG_LOWER" =~ $EXCLUDE ]]; then
    cat << EOF
<user-prompt-submit-hook>
🔍 Search query detected. Consider:
   ctx "$USER_MESSAGE"
</user-prompt-submit-hook>
EOF
fi

# ─────────────────────────────────────────────
# 3. AUTO-INDEX PROJECT (background)
# ─────────────────────────────────────────────
PROJECT_ROOT="$CWD"
while [[ "$PROJECT_ROOT" != "/" ]]; do
    [[ -d "$PROJECT_ROOT/.git" || -f "$PROJECT_ROOT/composer.json" || -f "$PROJECT_ROOT/package.json" ]] && break
    PROJECT_ROOT="${PROJECT_ROOT%/*}"
done
[[ "$PROJECT_ROOT" == "" || "$PROJECT_ROOT" == "/" ]] && exit 0

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

# Build in background
mkdir -p "$INDEX_DIR"
nohup ~/.claude/scripts/build-project-index.sh "$PROJECT_ROOT" >/dev/null 2>&1 &

exit 0
