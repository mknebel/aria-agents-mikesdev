#!/bin/bash
# ARIA Model Router
# Routes tasks to optimal models based on task type

source ~/.claude/scripts/aria-state.sh 2>/dev/null

# Model definitions with characteristics (Updated Dec 2025)
# GPT-5.1 beats o3 on coding (74.9% vs 69.1%) AND math (94.6% vs 88.9%)
# GPT-5.1 uses 50-80% fewer tokens than o-series
# Source: Codex CLI model selector
declare -A MODEL_INFO=(
    # Context (FREE - always first)
    ["context"]='gemini|1M+ context, analysis|FREE'

    # Instant tier (Haiku replacement - test these!)
    ["instant"]='gpt-5.1-codex-mini|Fast, cheap, Haiku replacement|Pro sub'
    ["quick"]='gpt-5.1:low|Quick responses, light reasoning|Pro sub'

    # Standard tier (most tasks)
    ["general"]='gpt-5.1|Broad knowledge, strong reasoning|Pro sub'
    ["code"]='gpt-5.1-codex|Codex optimized|Pro sub'

    # Power tier (complex tasks)
    ["complex"]='gpt-5.1-codex-max|Flagship, deep+fast reasoning|Pro sub'
    ["max"]='gpt-5.1-codex-max:extra_high|Maximum reasoning depth|Pro sub'

    # o-series (explicit step-by-step only)
    ["explicit"]='o4-mini|Quick explicit reasoning|Pro sub'
    ["proof"]='o3|Deep step-by-step proofs|Pro sub'
    ["reliable"]='o3-pro|Most reliable, last resort|Pro sub'
)

# Reasoning level flags (append to model with -c reasoning=X)
# codex-max: low, medium, high, extra_high
# codex-mini: medium, high
# gpt-5.1: low, medium, high

# Claude-saving priority order:
# 1. gemini (FREE) - context gathering, file analysis
# 2. gpt-5.1-codex-mini (instant) - Haiku replacement for quick tasks
# 3. gpt-5.1 (general) - standard tasks, broad knowledge
# 4. gpt-5.1-codex (code) - code-optimized tasks
# 5. gpt-5.1-codex-max (complex) - flagship for hard problems
# 6. o4-mini/o3 (explicit) - only for step-by-step proofs
# 7. o3-pro (reliable) - only when everything else fails
# 8. Claude Haiku - file operations only (if codex-mini doesn't work)
# 9. Claude Opus - UI/UX only (last resort)

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

    local model_spec=$(aria_get_model "$task_type")

    # Parse model:reasoning_level format
    local model="${model_spec%%:*}"
    local reasoning="${model_spec##*:}"
    [[ "$reasoning" == "$model" ]] && reasoning=""

    echo "🤖 Routing to: $model${reasoning:+ (reasoning: $reasoning)}" >&2

    # Use codex exec for non-interactive
    if command -v codex &>/dev/null; then
        if [[ -n "$reasoning" ]]; then
            codex -c model="$model" -c reasoning="$reasoning" exec "$prompt"
        else
            codex -c model="$model" exec "$prompt"
        fi

        # Log model usage
        case "$model" in
            *codex-max*) aria_log_model "codex_max" ;;
            *codex-mini*) aria_log_model "codex_mini" ;;
            gpt-5.1-codex) aria_log_model "codex" ;;
            gpt-5.1) aria_log_model "gpt51" ;;
            o3-pro) aria_log_model "o3_pro" ;;
            o3) aria_log_model "o3" ;;
            o4-mini) aria_log_model "o4_mini" ;;
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

    echo "  FREE TIER"
    printf "  %-12s %-24s %-40s %s\n" "context" "gemini" "1M+ context, analysis" "FREE"
    echo ""
    echo "  INSTANT TIER (Haiku replacement - test these!)"
    printf "  %-12s %-24s %-40s %s\n" "instant" "gpt-5.1-codex-mini" "Fast, cheap, quick tasks" "Pro sub"
    printf "  %-12s %-24s %-40s %s\n" "quick" "gpt-5.1 (low)" "Light reasoning, quick responses" "Pro sub"
    echo ""
    echo "  STANDARD TIER (most tasks)"
    printf "  %-12s %-24s %-40s %s\n" "general" "gpt-5.1" "Broad knowledge, strong reasoning" "Pro sub"
    printf "  %-12s %-24s %-40s %s\n" "code" "gpt-5.1-codex" "Code-optimized" "Pro sub"
    echo ""
    echo "  POWER TIER (complex tasks)"
    printf "  %-12s %-24s %-40s %s\n" "complex" "gpt-5.1-codex-max" "Flagship, deep+fast reasoning" "Pro sub"
    printf "  %-12s %-24s %-40s %s\n" "max" "codex-max (extra_high)" "Maximum reasoning depth" "Pro sub"
    echo ""
    echo "  O-SERIES (explicit step-by-step only)"
    printf "  %-12s %-24s %-40s %s\n" "explicit" "o4-mini" "Quick explicit reasoning" "Pro sub"
    printf "  %-12s %-24s %-40s %s\n" "proof" "o3" "Deep step-by-step proofs" "Pro sub"
    printf "  %-12s %-24s %-40s %s\n" "reliable" "o3-pro" "Most reliable, last resort" "Pro sub"

    echo ""
    echo "  Priority Order:"
    echo "  ────────────────────────────────────────────────────────────────"
    echo "  1. gemini           FREE, 1M+ context"
    echo "  2. codex-mini       Haiku replacement (TEST vs Haiku!)"
    echo "  3. gpt-5.1          General tasks"
    echo "  4. gpt-5.1-codex    Code-optimized"
    echo "  5. codex-max        Complex problems"
    echo "  6. o4-mini/o3       Explicit step-by-step proofs"
    echo "  7. o3-pro           Only when everything fails"
    echo "  8. Haiku            File ops only (fallback)"
    echo "  9. Opus             UI/UX only (last resort)"
    echo ""
    echo "  Usage:"
    echo "  ────────────────────────────────────────────────────────────────"
    echo "  aria route context \"analyze codebase\"      # FREE"
    echo "  aria route instant \"quick fix\"             # Fast (test vs Haiku)"
    echo "  aria route general \"solve problem\"         # Standard"
    echo "  aria route code \"implement feature\"        # Code-optimized"
    echo "  aria route complex \"hard problem\"          # Power"
    echo "  aria route proof \"prove theorem\"           # o3 explicit"
    echo ""
    echo "  Reasoning Levels (codex CLI):"
    echo "  ────────────────────────────────────────────────────────────────"
    echo "  codex-max:  low, medium, high, extra_high"
    echo "  codex-mini: medium, high"
    echo "  gpt-5.1:    low, medium, high"
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
