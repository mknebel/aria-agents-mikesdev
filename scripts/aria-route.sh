#!/bin/bash
# ARIA Model Router
# Routes tasks to optimal models based on task type

source ~/.claude/scripts/aria-state.sh 2>/dev/null
source ~/.claude/scripts/aria-session.sh 2>/dev/null

# Session mode (set ARIA_NO_SESSION=1 to disable)
ARIA_SESSION_ENABLED=${ARIA_SESSION_ENABLED:-1}

# Model definitions with characteristics (Updated 2025-12-19)
# Latest Gemini 3 and GPT-5.2 models (verified with codex CLI)
# CONTEXT-FIRST ARCHITECTURE: Gemini 3 Flash (1M context) gathers context, then routes to agents
declare -A MODEL_INFO=(
    # Context Layer (FREE - ALWAYS USE FIRST) - Gemini 3 Flash with 1M token context
    ["context"]='gemini-3-flash|Context layer: 1M tokens, searches, analysis|FREE'

    # Instant tier (Haiku replacement)
    ["instant"]='gemini-3-flash|Fast, cheap, Haiku replacement|FREE'
    ["quick"]='gemini-3-flash|Quick responses, light reasoning|FREE'

    # Standard tier - Gemini 3 Flash for fast execution with pre-gathered context
    ["general"]='gpt-5.1|Broad knowledge, general reasoning|Pro sub'
    ["code"]='gemini-3-flash|Code implementation (use after context)|FREE'
    ["test"]='gemini-3-flash|Testing and verification (use after context)|FREE'

    # Power tier (complex tasks) - Use paid models with pre-digested context
    ["complex"]='gpt-5.1-codex-max|Complex code (receives context from Gemini)|Pro sub'
    ["max"]='gpt-5.2|Maximum capability (receives context from Gemini)|Pro sub'
)

# Reasoning level flags (append to model with -c reasoning=X)
# codex-max: low, medium, high, extra_high
# codex-mini: medium, high
# gpt-5.1: low, medium, high

# CONTEXT-FIRST ARCHITECTURE (Updated 2025-12-19):
# 1. gemini-3-flash (FREE, 1M context) - ALWAYS gather context FIRST
#    - Searches codebase, reads files, analyzes patterns
#    - Returns summarized context to other agents
# 2. gemini-3-flash (FREE) - code implementation, testing (using pre-gathered context)
# 3. gpt-5.1 (Pro) - general reasoning (receives pre-digested context from Gemini)
# 4. gpt-5.1-codex-max (Pro) - complex code (receives context from Gemini)
# 5. gpt-5.2 (Pro) - maximum capability (receives context from Gemini)
# 6. Claude Haiku - file operations fallback
# 7. Claude Opus - UI/UX only (last resort)

aria_get_model() {
    local task_type="${1:-code}"
    local info="${MODEL_INFO[$task_type]}"

    if [[ -n "$info" ]]; then
        echo "$info" | cut -d'|' -f1
    else
        echo "gemini-3-flash"  # Default to Gemini 3 Flash for speed
    fi
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

    # Build prompt with session context (if enabled)
    if [[ "$ARIA_SESSION_ENABLED" == "1" ]] && type aria_session_build_prompt &>/dev/null; then
        full_prompt=$(aria_session_build_prompt "$user_prompt")
        echo "🤖 Routing to: $model${reasoning:+ (reasoning: $reasoning)} [session: $(aria_session_current 2>/dev/null | cut -c1-8)]" >&2
    else
        full_prompt="$user_prompt"
        echo "🤖 Routing to: $model${reasoning:+ (reasoning: $reasoning)}" >&2
    fi

    # Use codex exec for non-interactive
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
        esac
        aria_inc "external"
    else
        echo "Error: codex CLI not found" >&2
        return 1
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
    echo "  STANDARD TIER"
    printf "  %-12s %-24s %-40s %s\n" "general" "gpt-5.1" "Broad knowledge, general reasoning" "Pro sub"
    echo ""
    echo "  POWER TIER (complex tasks only)"
    printf "  %-12s %-24s %-40s %s\n" "complex" "gpt-5.1-codex-max" "Complex code problems" "Pro sub"
    printf "  %-12s %-24s %-40s %s\n" "max" "gpt-5.2" "Hardest problems, maximum capability" "Pro sub"

    echo ""
    echo ""
    echo "  Context-First Architecture (optimized for tokens + speed):"
    echo "  ────────────────────────────────────────────────────────────────"
    echo "  1. gemini-3-flash      Context layer (1M tokens, FREE)"
    echo "                         ↓ gathers context, returns to agents"
    echo "  2. gemini-3-flash      Code/tests (receives context, FREE)"
    echo "  3. gpt-5.1             General reasoning (receives context)"
    echo "  4. gpt-5.1-codex-max   Complex code (receives context)"
    echo "  5. gpt-5.2             Hardest problems (receives context)"
    echo ""
    echo "  Usage Pattern (ALWAYS start with context):"
    echo "  ────────────────────────────────────────────────────────────────"
    echo "  # Step 1: ALWAYS gather context FIRST (Gemini 1M, FREE)"
    echo "  aria route context \"gather all payment code and patterns\""
    echo ""
    echo "  # Step 2: Then route to appropriate agent"
    echo "  aria route code \"implement feature\"         # Gemini (uses context)"
    echo "  aria route test \"run tests\"                # Gemini (uses context)"
    echo "  aria route general \"explain architecture\"  # GPT-5.1 (uses context)"
    echo "  aria route complex \"solve hard bug\"        # Codex Max (uses context)"
    echo "  aria route max \"redesign system\"           # GPT-5.2 (uses context)"
    echo ""
    echo "  💡 Key: Gemini's 1M context gathers everything, agents get summaries!"
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
