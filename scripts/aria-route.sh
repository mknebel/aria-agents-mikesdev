#!/bin/bash
# ARIA Model Router
# Routes tasks to optimal models based on task type

source ~/.claude/scripts/aria-state.sh 2>/dev/null

# Model definitions with characteristics
declare -A MODEL_INFO=(
    ["quick"]='gpt-5.1-codex-mini|Fast Q&A, low cost|$0.25/1M'
    ["code"]='gpt-5.1-codex-max|Code generation, 77.9% SWE-bench|Pro sub'
    ["reason"]='o3|Deep reasoning, 71% SWE-bench|Pro sub'
    ["fast"]='o4-mini|Quick reasoning, great math|Pro sub'
    ["refactor"]='gpt-5.1-codex-max|Multi-file, long context|Pro sub'
    ["math"]='o4-mini|99.5% AIME score|Pro sub'
    ["chat"]='gpt-5.1|General conversation|Pro sub'
    ["context"]='gemini|1M+ context, FREE|FREE'
)

aria_get_model() {
    local task_type="${1:-code}"
    local info="${MODEL_INFO[$task_type]}"

    if [[ -n "$info" ]]; then
        echo "$info" | cut -d'|' -f1
    else
        echo "gpt-5.1-codex-max"
    fi
}

aria_route() {
    local task_type="$1"
    shift
    local prompt="$*"

    local model=$(aria_get_model "$task_type")

    echo "🤖 Routing to: $model" >&2

    # Use codex exec for non-interactive
    if command -v codex &>/dev/null; then
        codex -c model="$model" exec "$prompt"

        # Log model usage
        case "$model" in
            *codex-max*) aria_log_model "codex_max" ;;
            *codex-mini*) aria_log_model "codex_mini" ;;
            *o3*) aria_log_model "o3" ;;
            *o4*) aria_log_model "o4_mini" ;;
            *gpt-5.1) aria_log_model "gpt51" ;;
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
    echo "ARIA Model Routing (Codex CLI)"
    echo "══════════════════════════════════════════════════════════════════"
    echo ""
    printf "  %-12s %-24s %-30s %s\n" "Type" "Model" "Best For" "Cost"
    echo "  ────────────────────────────────────────────────────────────────"

    for type in quick code reason fast refactor math chat context; do
        local info="${MODEL_INFO[$type]}"
        local model=$(echo "$info" | cut -d'|' -f1)
        local desc=$(echo "$info" | cut -d'|' -f2)
        local cost=$(echo "$info" | cut -d'|' -f3)
        printf "  %-12s %-24s %-30s %s\n" "$type" "$model" "$desc" "$cost"
    done

    echo ""
    echo "Available OpenAI Models (via -c model=X):"
    echo "  ────────────────────────────────────────────────────────────────"
    echo "  gpt-5.1-codex-max    Default, best for agentic coding (77.9% SWE)"
    echo "  gpt-5.1-codex-mini   Fast, cheap Q&A (\$0.25/1M input)"
    echo "  gpt-5.1              General purpose coding"
    echo "  o3                   Deep reasoning (slow but thorough)"
    echo "  o4-mini              Fast reasoning, great for math (99.5% AIME)"
    echo ""
    echo "Usage:"
    echo "  aria route code \"implement user authentication\""
    echo "  aria route fast \"fix this typo\""
    echo "  aria route reason \"debug this complex issue\""
    echo "  aria route context \"analyze the entire codebase\""
    echo ""
    echo "Direct Codex Usage (non-interactive):"
    echo "  codex exec \"prompt\"                    # Use default model"
    echo "  codex -c model=o4-mini exec \"prompt\"   # Use specific model"
    echo ""
    echo "Note: Interactive commands like /model require a terminal."
    echo "      For scripts, use -c model=X flag instead."
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
