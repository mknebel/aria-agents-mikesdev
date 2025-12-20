#!/bin/bash
# ARIA Model Router
# Routes tasks to optimal models based on task type

source ~/.claude/scripts/aria-state.sh 2>/dev/null
source ~/.claude/scripts/aria-session.sh 2>/dev/null

# Session mode (set ARIA_NO_SESSION=1 to disable)
ARIA_SESSION_ENABLED=${ARIA_SESSION_ENABLED:-1}

# Model definitions with characteristics (Updated 2025-12-20)
# Latest Gemini 3 and GPT-5.2 models (verified with codex CLI)
# CONTEXT-FIRST ARCHITECTURE: Gemini 3 Flash (1M context) gathers context, then routes to agents
declare -A MODEL_INFO=(
    # Context Layer (FREE - ALWAYS USE FIRST) - Gemini 3 Flash with 1M token context
    ["context"]='gemini-3-flash|Context layer: 1M tokens, searches, analysis|FREE'

    # Planning tier - Claude Opus for architectural planning
    ["plan"]='claude-opus|Software architecture, implementation planning|Claude sub'

    # Instant tier (Haiku replacement)
    ["instant"]='gemini-3-flash|Fast, cheap, Haiku replacement|FREE'
    ["quick"]='gemini-3-flash|Quick responses, light reasoning|FREE'

    # Standard tier - Gemini 3 Flash for fast execution with pre-gathered context
    ["general"]='gpt-5.1|Broad knowledge, general reasoning|Pro sub'
    ["code"]='gemini-3-flash|Code implementation (use after context)|FREE'
    ["test"]='gemini-3-flash|Testing and verification (use after context)|FREE'

    # Power tier (complex tasks) - Claude Opus for complex/hard coding
    ["complex"]='claude-opus|Complex code (receives context from Gemini)|Claude sub'
    ["max"]='claude-opus|Maximum capability, hard coding (receives context from Gemini)|Claude sub'
)

# Reasoning level flags (append to model with -c reasoning=X)
# codex-max: low, medium, high, extra_high
# codex-mini: medium, high
# gpt-5.1: low, medium, high

# CONTEXT-FIRST ARCHITECTURE (Updated 2025-12-20):
# 1. gemini-3-flash (FREE, 1M context) - ALWAYS gather context FIRST
#    - Searches codebase, reads files, analyzes patterns
#    - Returns summarized context to other agents
# 2. claude-opus (Claude sub) - planning and architecture
# 3. gemini-3-flash (FREE) - code implementation, testing (using pre-gathered context)
# 4. gpt-5.1 (Pro) - general reasoning (receives pre-digested context from Gemini)
# 5. claude-opus (Claude sub) - complex code and hard coding (receives context from Gemini)
# 6. Claude Haiku - file operations fallback

aria_get_model() {
    local task_type="${1:-code}"
    local info="${MODEL_INFO[$task_type]}"

    if [[ -n "$info" ]]; then
        echo "$info" | cut -d'|' -f1
    else
        echo "gemini-3-flash"  # Default to Gemini 3 Flash for speed
    fi
}

# Prepend justfile-first context to prompt (Updated 2025-12-20)
aria_prepend_justfile_context() {
    local user_prompt="$1"
    local working_dir="${PWD}"

    cat <<'EOF'
JUSTFILE-FIRST + ARIA-FIRST: Max efficiency and token savings
- just cx "query" (not grep/find/ctx) - AI-powered code search
- just s "pattern" (not rg/search) - Pattern search
- just t (not grep TODO) - Find all TODOs
- just st (not git status) - Git status
- just ci "msg" (not git commit) - Commit with auto-attribution
- just co "msg" (not git commit + push) - Commit and push
- just db-* (not mysql) - Database commands
- just l (not tail logs) - View logs
- just --list - See all available commands

Working directory:
EOF
    echo "$working_dir"
    echo ""
    echo "Task:"
    echo "$user_prompt"
}

aria_route() {
    local task_type="$1"
    shift
    local user_prompt="$*"
    local full_prompt=""
    local response=""

    local model_spec=$(aria_get_model "$task_type")

    # Parse model:reasoning_level format
    local model="${model_spec%%:*}"
    local reasoning="${model_spec##*:}"
    [[ "$reasoning" == "$model" ]] && reasoning=""

    # Prepend justfile context for task types that need it (unless ARIA_NO_JUSTFILE=1)
    local enhanced_prompt="$user_prompt"
    if [[ "${ARIA_NO_JUSTFILE:-0}" != "1" ]]; then
        case "$task_type" in
            context|code|test|plan)
                # Add justfile-first context for these task types
                enhanced_prompt=$(aria_prepend_justfile_context "$user_prompt")
                ;;
        esac
    fi

    # Build prompt with session context (if enabled)
    if [[ "$ARIA_SESSION_ENABLED" == "1" ]] && type aria_session_build_prompt &>/dev/null; then
        full_prompt=$(aria_session_build_prompt "$enhanced_prompt")
        echo "🤖 Routing to: $model${reasoning:+ (reasoning: $reasoning)} [session: $(aria_session_current 2>/dev/null | cut -c1-8)]" >&2
    else
        full_prompt="$enhanced_prompt"
        echo "🤖 Routing to: $model${reasoning:+ (reasoning: $reasoning)}" >&2
    fi

    # Route to appropriate CLI based on model type
    if [[ "$model" == gemini-* ]]; then
        # Use gemini CLI for Gemini models
        if command -v gemini &>/dev/null; then
            response=$(gemini "$full_prompt" 2>&1)

            # Output response
            echo "$response"

            # Save to session (if enabled)
            if [[ "$ARIA_SESSION_ENABLED" == "1" ]] && type aria_session_add_user &>/dev/null; then
                aria_session_add_user "$user_prompt" "$model" 2>/dev/null
                aria_session_add_assistant "$response" "$model" 2>/dev/null
            fi

            # Log model usage
            aria_log_model "gemini"
            aria_inc "external"
        else
            echo "Error: gemini CLI not found" >&2
            return 1
        fi
    elif [[ "$model" == claude-* ]]; then
        # Use claude CLI for Claude models (Opus, Sonnet, Haiku)
        if command -v claude &>/dev/null; then
            # Extract model name (opus, sonnet, haiku)
            local claude_model="${model#claude-}"
            response=$(claude --print --model "$claude_model" "$full_prompt" 2>&1)

            # Output response
            echo "$response"

            # Save to session (if enabled)
            if [[ "$ARIA_SESSION_ENABLED" == "1" ]] && type aria_session_add_user &>/dev/null; then
                aria_session_add_user "$user_prompt" "$model" 2>/dev/null
                aria_session_add_assistant "$response" "$model" 2>/dev/null
            fi

            # Log model usage
            aria_log_model "claude_${claude_model}"
            aria_inc "external"
        else
            echo "Error: claude CLI not found" >&2
            return 1
        fi
    else
        # Use codex CLI for ChatGPT models (gpt-5.1, gpt-5.2, codex-max, etc.)
        if command -v codex &>/dev/null; then
            if [[ -n "$reasoning" ]]; then
                response=$(codex -c model="$model" -c reasoning="$reasoning" exec "$full_prompt" 2>&1)
            else
                response=$(codex -c model="$model" exec "$full_prompt" 2>&1)
            fi

            # Output response
            echo "$response"

            # Save to session (if enabled)
            if [[ "$ARIA_SESSION_ENABLED" == "1" ]] && type aria_session_add_user &>/dev/null; then
                aria_session_add_user "$user_prompt" "$model" 2>/dev/null
                aria_session_add_assistant "$response" "$model" 2>/dev/null
            fi

            # Log model usage
            case "$model" in
                *codex-max*) aria_log_model "codex_max" ;;
                *codex-mini*) aria_log_model "codex_mini" ;;
                gpt-5.1-codex) aria_log_model "codex" ;;
                gpt-5.1) aria_log_model "gpt51" ;;
                gpt-5.2) aria_log_model "gpt52" ;;
            esac
            aria_inc "external"
        else
            echo "Error: codex CLI not found" >&2
            return 1
        fi
    fi
}

aria_gemini() {
    local prompt="$*"

    echo "🤖 Using: Gemini 3 (FREE)" >&2

    if command -v gemini &>/dev/null; then
        gemini "$prompt"
        aria_log_model "gemini"
        aria_inc "external"
    else
        echo "Error: gemini CLI not found" >&2
        return 1
    fi
}

aria_show_models() {
    echo ""
    echo "ARIA Model Routing (Updated Dec 2025)"
    echo "══════════════════════════════════════════════════════════════════"
    echo ""
    printf "  %-12s %-24s %-40s %s\n" "Type" "Model" "Best For" "Cost"
    echo "  ────────────────────────────────────────────────────────────────"

    echo "  FREE TIER (Gemini 3 Flash - super fast!)"
    printf "  %-12s %-24s %-40s %s\n" "context" "gemini-3-flash" "Searches, analysis, 1M+ context" "FREE"
    printf "  %-12s %-24s %-40s %s\n" "instant" "gemini-3-flash" "Fast, cheap, quick tasks" "FREE"
    printf "  %-12s %-24s %-40s %s\n" "quick" "gemini-3-flash" "Light reasoning, quick responses" "FREE"
    printf "  %-12s %-24s %-40s %s\n" "code" "gemini-3-flash" "Code implementation (super fast)" "FREE"
    printf "  %-12s %-24s %-40s %s\n" "test" "gemini-3-flash" "Testing and verification" "FREE"
    echo ""
    echo "  PLANNING TIER"
    printf "  %-12s %-24s %-40s %s\n" "plan" "claude-opus" "Architecture, implementation planning" "Claude sub"
    echo ""
    echo "  STANDARD TIER"
    printf "  %-12s %-24s %-40s %s\n" "general" "gpt-5.1" "Broad knowledge, general reasoning" "Pro sub"
    echo ""
    echo "  POWER TIER (complex tasks only)"
    printf "  %-12s %-24s %-40s %s\n" "complex" "claude-opus" "Complex code problems" "Claude sub"
    printf "  %-12s %-24s %-40s %s\n" "max" "claude-opus" "Hardest problems, hard coding" "Claude sub"

    echo ""
    echo ""
    echo "  Context-First Architecture (optimized for tokens + speed):"
    echo "  ────────────────────────────────────────────────────────────────"
    echo "  1. gemini-3-flash      Context layer (1M tokens, FREE)"
    echo "                         ↓ gathers context, returns to orchestrator"
    echo "  2. claude-opus         Planning (receives context)"
    echo "                         ↓ creates implementation plan"
    echo "  3. gemini-3-flash      Code/tests (executes plan, FREE)"
    echo "  4. gpt-5.1             General reasoning (receives context)"
    echo "  5. claude-opus         Complex code (receives context)"
    echo "  6. claude-opus         Hardest problems, hard coding (receives context)"
    echo ""
    echo "  Usage Pattern (ALWAYS start with context → plan → execute):"
    echo "  ────────────────────────────────────────────────────────────────"
    echo "  # Step 1: ALWAYS gather context FIRST (Gemini 1M, FREE)"
    echo "  aria route context \"gather all payment code and patterns\""
    echo ""
    echo "  # Step 2: Plan with Opus (receives context)"
    echo "  aria route plan \"design cart validation system\""
    echo ""
    echo "  # Step 3: Execute with appropriate agent"
    echo "  aria route code \"implement feature\"         # Gemini (uses plan)"
    echo "  aria route test \"run tests\"                # Gemini (uses plan)"
    echo "  aria route general \"explain architecture\"  # GPT-5.1 (uses context)"
    echo "  aria route complex \"solve hard bug\"        # Claude Opus (uses context)"
    echo "  aria route max \"redesign system\"           # Claude Opus (uses context)"
    echo ""
    echo "  💡 Key: Context → Planning → Execution for optimal results!"
    echo ""
    echo "  Available Codex Models (for reference):"
    echo "  ────────────────────────────────────────────────────────────────"
    echo "  gpt-5.1-codex-max:  Complex code problems"
    echo "  gpt-5.1-codex:      Standard codex"
    echo "  gpt-5.1-codex-mini: Cheaper alternative"
    echo "  gpt-5.2:            Latest frontier (hardest problems)"
    echo "  gpt-5.1:            General reasoning"
    echo ""
}

# CLI interface - only run when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "$1" in
        models|m)
            aria_show_models
            ;;
        gemini|g)
            shift
            aria_gemini "$@"
            ;;
        *)
            if [[ -n "$1" && -n "$2" ]]; then
                aria_route "$@"
            else
                aria_show_models
            fi
            ;;
    esac
fi
