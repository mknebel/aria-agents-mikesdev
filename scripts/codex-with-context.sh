#!/bin/bash
# codex-with-context.sh - Run codex with Index V2 context
#
# Usage:
#   codex-with-context.sh "search query" "task description"
#   codex-with-context.sh "auth" "add password reset flow"
#   codex-with-context.sh "payment" "fix checkout validation"
#
# The search query finds relevant code context from the index,
# then passes it to codex along with your task.

set -e

QUERY="$1"
TASK="${@:2}"

if [[ -z "$QUERY" || -z "$TASK" ]]; then
    echo "Usage: codex-with-context.sh \"search query\" \"task description\""
    echo ""
    echo "Examples:"
    echo "  codex-with-context.sh \"auth\" \"add password reset flow\""
    echo "  codex-with-context.sh \"payment\" \"fix checkout validation\""
    echo "  codex-with-context.sh \"user model\" \"add email verification field\""
    exit 1
fi

INDEX_SEARCH="$HOME/.claude/scripts/index-v2/search.sh"
PROJECT_ROOT="$(pwd)"

echo "🔍 Searching index for: $QUERY" >&2

# Get context from index (stderr goes to terminal, stdout captured)
CONTEXT=$("$INDEX_SEARCH" "$QUERY" "$PROJECT_ROOT" 2>&2)

if [[ -z "$CONTEXT" || "$CONTEXT" == "No matches found." ]]; then
    echo "⚠️  No index matches, running codex without context..." >&2
    codex "$TASK"
    exit 0
fi

# Count files found
FILE_COUNT=$(echo "$CONTEXT" | grep -c '^\[' || echo 0)
echo "📊 Found $FILE_COUNT relevant files" >&2
echo "" >&2

# Build prompt with context
PROMPT="## Relevant Code Context

The following files and functions are relevant to this task:

$CONTEXT

## Task

$TASK

## Instructions

1. Use the context above to understand existing patterns and conventions
2. Follow the same coding style as the existing code
3. Integrate with existing functions/classes where appropriate
4. Keep changes minimal and focused on the task"

# Run codex with the enriched prompt
echo "🚀 Running codex with context..." >&2
echo "$PROMPT" | codex -
