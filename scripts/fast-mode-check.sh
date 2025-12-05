#!/bin/bash
# fast-mode-check.sh - Enforces fast mode patterns
#
# Run at session start to verify fast mode is active and remind of rules
# Can also be called to check a proposed action against fast mode rules

set -e

ROUTING_FILE="$HOME/.claude/routing-mode"
VAR_DIR="/tmp/claude_vars"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get current mode
get_mode() {
    cat "$ROUTING_FILE" 2>/dev/null || echo "fast"
}

# Session start check
cmd_start() {
    local mode=$(get_mode)

    # Reset session state for new session
    echo '{"index_used":false,"ctx_used":false,"files_read":0}' > "$HOME/.claude/.session-state"

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  MODE: ${GREEN}${mode^^}${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if [[ "$mode" == "fast" ]]; then
        echo -e "
${GREEN}FAST MODE ACTIVE${NC} - External tools handle heavy lifting

${BLUE}RULES:${NC}
  1. Search: /lookup → ctx → Grep (in order)
  2. Code gen: llm codex \"task @var:ctx_last\"
  3. Review: llm gemini \"analyze @var:name\"
  4. Quick: llm fast \"question\"
  5. Apply: Claude Edit tool (final review)

${BLUE}CLAUDE'S ROLE:${NC}
  - Orchestrate (~200 tokens)
  - Final review (~500 tokens)
  - UI/UX polish (~500 tokens)
  - Apply edits (~300 tokens)

${BLUE}COMMANDS:${NC}
  /smart \"task\"   - Adaptive pipeline
  /fast \"task\"    - Direct fast mode
  /mode aria      - Switch to Claude agents

${YELLOW}Token target: ~1,500/task (vs ~15,000 Claude-only)${NC}
"
    else
        echo -e "
${YELLOW}ARIA MODE ACTIVE${NC} - Claude agents handle tasks

Switch to fast mode for 90% token savings:
  /mode fast
"
    fi

    # Show cache stats
    if [[ -f ~/.claude/scripts/cache-manager.sh ]]; then
        echo -e "\n${BLUE}Cache Status:${NC}"
        ~/.claude/scripts/cache-manager.sh stats 2>/dev/null | tail -6
    fi
}

# Check if an action follows fast mode rules
cmd_check() {
    local action="$1"
    local mode=$(get_mode)

    [[ "$mode" != "fast" ]] && return 0

    local violations=()

    # Check for direct Claude heavy lifting (would be caught by token usage)
    # This is informational - Claude should self-check

    case "$action" in
        *"generate"*|*"implement"*|*"write code"*)
            if [[ ! "$action" =~ "llm"|"codex"|"gemini" ]]; then
                violations+=("Code generation should use: llm codex \"task\"")
            fi
            ;;
        *"analyze"*|*"review"*)
            if [[ ! "$action" =~ "llm"|"gemini" ]]; then
                violations+=("Analysis should use: llm gemini \"task\"")
            fi
            ;;
        *"search"*|*"find"*)
            if [[ ! "$action" =~ "ctx"|"lookup"|"/lookup" ]]; then
                violations+=("Search should use: ctx \"query\" or /lookup")
            fi
            ;;
    esac

    if [[ ${#violations[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  Fast Mode Suggestions:${NC}"
        for v in "${violations[@]}"; do
            echo -e "  - $v"
        done
        return 1
    fi

    return 0
}

# Set mode
cmd_set() {
    local mode="$1"

    if [[ "$mode" != "fast" && "$mode" != "aria" ]]; then
        echo "Usage: fast-mode-check.sh set <fast|aria>"
        return 1
    fi

    echo "$mode" > "$ROUTING_FILE"
    echo -e "${GREEN}Mode set to: ${mode}${NC}"

    cmd_start
}

# Show quick reference
cmd_ref() {
    cat <<'EOF'
FAST MODE QUICK REFERENCE
═══════════════════════════════════════════════════════════════

SEARCH (Index First)
  /lookup ClassName           # Instant, FREE
  ctx "semantic query"        # Local search, FREE
  Grep "pattern"              # Only if above fail

CODE GENERATION
  Simple:  llm codex "implement X @var:ctx_last"
  Medium:  parallel-pipeline.sh "task"
  Complex: /smart "task"

REVIEW/ANALYSIS
  llm gemini "analyze @var:name"
  llm qa "thorough review of @var:code"

QUICK QUESTIONS
  llm fast "what is X?"

VARIABLES
  ctx "query"                 # → $ctx_last
  var summary name            # Read 500 chars
  var get name                # Full content

CLAUDE DOES
  - Final review (~500 tokens)
  - UI/UX work (direct)
  - Apply edits (~300 tokens)
  - Orchestrate (~200 tokens)

CLAUDE DOESN'T
  - Heavy code gen (use codex)
  - Bulk analysis (use gemini)
  - Quick checks (use fast)

EOF
}

# List available templates
cmd_templates() {
    echo -e "${BLUE}Available Templates:${NC}"
    echo ""
    if [[ -d "$HOME/.claude/templates" ]]; then
        for f in "$HOME/.claude/templates"/*.md; do
            [[ -f "$f" ]] || continue
            local name=$(basename "$f" .md)
            local desc=$(head -1 "$f" | sed 's/^# //')
            echo -e "  ${GREEN}$name${NC} - $desc"
        done
    else
        echo "  No templates found"
    fi
    echo ""
    echo "Use: cat ~/.claude/templates/<name>.md"
}

# Show session stats from hook log
cmd_stats() {
    local log="$HOME/.claude/fast-reminders.log"
    local state="$HOME/.claude/.session-state"

    echo -e "${BLUE}Session Statistics:${NC}"
    echo ""

    if [[ -f "$state" ]]; then
        local files=$(jq -r '.files_read // 0' "$state" 2>/dev/null)
        local idx=$(jq -r '.index_used // false' "$state" 2>/dev/null)
        local ctx=$(jq -r '.ctx_used // false' "$state" 2>/dev/null)

        echo -e "  Files read: ${files}"
        echo -e "  Index used: ${idx}"
        echo -e "  Ctx used:   ${ctx}"
    fi

    if [[ -f "$log" ]]; then
        echo ""
        echo -e "${BLUE}Recent Tool Activity:${NC}"
        tail -10 "$log" | sed 's/^/  /'
    fi
}

# Main dispatch
case "${1:-start}" in
    start|s)
        cmd_start
        ;;
    check|c)
        shift
        cmd_check "$*"
        ;;
    set)
        shift
        cmd_set "$@"
        ;;
    ref|reference|r)
        cmd_ref
        ;;
    mode)
        get_mode
        ;;
    templates|t)
        cmd_templates
        ;;
    stats|st)
        cmd_stats
        ;;
    *)
        cat <<'HELP'
fast-mode-check.sh - Fast mode enforcement

Usage:
  fast-mode-check.sh start     # Show mode and rules (resets session)
  fast-mode-check.sh check     # Check an action
  fast-mode-check.sh set       # Set mode (fast|aria)
  fast-mode-check.sh ref       # Quick reference
  fast-mode-check.sh mode      # Just print current mode
  fast-mode-check.sh templates # List available templates
  fast-mode-check.sh stats     # Show session stats
HELP
        ;;
esac
