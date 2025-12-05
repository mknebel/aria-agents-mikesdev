#!/bin/bash
# ARIA Agent Context - Shared memory for spawned agents
# Simple file-based context that persists across Task() calls

CONTEXT_FILE="${HOME}/.claude/cache/agent-context.md"
CONTEXT_MAX_LINES=${CONTEXT_MAX_LINES:-100}

# Ensure directory exists
mkdir -p "$(dirname "$CONTEXT_FILE")" 2>/dev/null

# Initialize context file if missing
aria_agent_context_init() {
    if [[ ! -f "$CONTEXT_FILE" ]]; then
        cat > "$CONTEXT_FILE" << 'EOF'
# Agent Context Log
This file tracks what agents have done in this session.
Each agent should read this before starting and append their summary when done.

---

EOF
    fi
}

# Get context for agent prompt (last N lines)
aria_agent_context_get() {
    local max_lines="${1:-50}"
    aria_agent_context_init
    tail -n "$max_lines" "$CONTEXT_FILE" 2>/dev/null
}

# Add entry to context
aria_agent_context_add() {
    local agent_type="$1"
    local summary="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    aria_agent_context_init

    cat >> "$CONTEXT_FILE" << EOF

## [$timestamp] $agent_type
$summary

EOF

    # Trim if too long
    aria_agent_context_trim
}

# Trim context file to max lines
aria_agent_context_trim() {
    if [[ -f "$CONTEXT_FILE" ]]; then
        local lines=$(wc -l < "$CONTEXT_FILE")
        if [[ $lines -gt $CONTEXT_MAX_LINES ]]; then
            local keep=$((CONTEXT_MAX_LINES / 2))
            echo "# Agent Context Log (trimmed)" > "${CONTEXT_FILE}.tmp"
            echo "" >> "${CONTEXT_FILE}.tmp"
            tail -n "$keep" "$CONTEXT_FILE" >> "${CONTEXT_FILE}.tmp"
            mv "${CONTEXT_FILE}.tmp" "$CONTEXT_FILE"
        fi
    fi
}

# Clear all context
aria_agent_context_clear() {
    rm -f "$CONTEXT_FILE"
    aria_agent_context_init
    echo "Agent context cleared"
}

# Show context
aria_agent_context_show() {
    aria_agent_context_init
    cat "$CONTEXT_FILE"
}

# Build prompt prefix with context
aria_agent_context_prompt() {
    local new_task="$1"
    local context=$(aria_agent_context_get 50)

    cat << EOF
## Previous Agent Activity
The following is a log of what previous agents have done in this session.
Use this context to understand what has already been accomplished.

$context

---

## Your Task
$new_task

---

IMPORTANT: When you complete your task, your summary will be logged for future agents.
EOF
}

# CLI interface
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-show}" in
        show|s)
            aria_agent_context_show
            ;;
        get|g)
            aria_agent_context_get "${2:-50}"
            ;;
        add|a)
            shift
            agent_type="${1:-unknown}"
            shift
            summary="$*"
            aria_agent_context_add "$agent_type" "$summary"
            echo "Context added"
            ;;
        clear|c)
            aria_agent_context_clear
            ;;
        prompt|p)
            shift
            aria_agent_context_prompt "$*"
            ;;
        *)
            echo "Usage: aria-agent-context.sh <command>"
            echo ""
            echo "Commands:"
            echo "  show          Show full context"
            echo "  get [lines]   Get last N lines of context"
            echo "  add <agent> <summary>  Add entry"
            echo "  clear         Clear all context"
            echo "  prompt <task> Build prompt with context"
            ;;
    esac
fi
