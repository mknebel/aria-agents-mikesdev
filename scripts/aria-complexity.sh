#!/bin/bash
# ARIA Complexity Assessment - Task routing tier determination
# Analyzes task context and determines optimal model tier (1-3)
# Tier 1: Simple (instant/codex-mini) - bugs, typos, quick fixes
# Tier 2: Standard (gpt-5.1/codex) - refactors, standard features
# Tier 3: Complex (codex-max) - architecture, multi-system, rewrites

source ~/.claude/scripts/aria-state.sh 2>/dev/null

# Debug mode
ARIA_COMPLEXITY_DEBUG="${ARIA_COMPLEXITY_DEBUG:-0}"

# Lock file for concurrent access
ARIA_COMPLEXITY_LOCK="$HOME/.claude/.aria-complexity.lock"

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

_aria_complexity_debug() {
    if [[ "$ARIA_COMPLEXITY_DEBUG" == "1" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

_aria_complexity_count_files() {
    local text="$1"
    # Match common file paths: /path, ~/path, ./path, file.ext
    # Count unique matches (case-insensitive deduplication)
    echo "$text" | grep -oiE '(/[a-z0-9_./\-]+|~/[a-z0-9_./\-]+|\./[a-z0-9_./\-]+|[a-z0-9_\-]+\.[a-z0-9]+)' | sort -u | wc -l
}

_aria_complexity_keyword_score() {
    local text="$1"
    local score=0
    local text_lower=$(echo "$text" | tr '[:upper:]' '[:lower:]')

    # Keywords that increase complexity
    local increase_count=0
    [[ "$text_lower" =~ refactor ]] && ((increase_count++))
    [[ "$text_lower" =~ rewrite ]] && ((increase_count++))
    [[ "$text_lower" =~ architecture ]] && ((increase_count++))
    [[ "$text_lower" =~ database\ migration ]] && ((increase_count++))
    [[ "$text_lower" =~ api\ integration ]] && ((increase_count++))
    [[ "$text_lower" =~ multi.system ]] && ((increase_count++))
    score=$((score + increase_count))
    _aria_complexity_debug "Increase keywords found: $increase_count (score +$increase_count)"

    # Keywords that decrease complexity
    local decrease_count=0
    [[ "$text_lower" =~ (^|[[:space:]])fix([[:space:]]|$) ]] && ((decrease_count++))
    [[ "$text_lower" =~ (^|[[:space:]])bug([[:space:]]|$) ]] && ((decrease_count++))
    [[ "$text_lower" =~ (^|[[:space:]])typo([[:space:]]|$) ]] && ((decrease_count++))
    [[ "$text_lower" =~ (^|[[:space:]])simple([[:space:]]|$) ]] && ((decrease_count++))
    [[ "$text_lower" =~ (^|[[:space:]])quick([[:space:]]|$) ]] && ((decrease_count++))
    score=$((score - decrease_count))
    _aria_complexity_debug "Decrease keywords found: $decrease_count (score -$decrease_count)"

    echo "$score"
}

_aria_complexity_multi_system() {
    local text="$1"
    local systems=0

    # Check for database keywords
    if echo "$text" | grep -iq "database\|sql\|db\|migration\|schema"; then
        ((systems++))
        _aria_complexity_debug "Database system detected"
    fi

    # Check for API keywords
    if echo "$text" | grep -iq "api\|endpoint\|rest\|graphql\|webhook"; then
        ((systems++))
        _aria_complexity_debug "API system detected"
    fi

    # Check for frontend keywords
    if echo "$text" | grep -iq "frontend\|react\|vue\|angular\|ui\|component\|page"; then
        ((systems++))
        _aria_complexity_debug "Frontend system detected"
    fi

    # Check for backend keywords (in addition to API)
    if echo "$text" | grep -iq "backend\|server\|service\|worker"; then
        ((systems++))
        _aria_complexity_debug "Backend system detected"
    fi

    # Return score: +1 if 2+ systems detected, +2 if 3+ systems detected
    if [[ $systems -ge 3 ]]; then
        echo "2"
    elif [[ $systems -ge 2 ]]; then
        echo "1"
    else
        echo "0"
    fi
}

_aria_complexity_validate_input() {
    local task_context="$1"

    # Validate input
    if [[ -z "$task_context" ]]; then
        _aria_complexity_debug "Error: Empty task context provided"
        return 1
    fi

    return 0
}

# =============================================================================
# MAIN ASSESSMENT FUNCTION
# =============================================================================

aria_assess_complexity() {
    local task_context="$1"
    local error_file="${2:-}"

    # Input validation
    if ! _aria_complexity_validate_input "$task_context"; then
        echo "2"  # Default to standard tier on invalid input
        return 1
    fi

    _aria_complexity_debug "Starting complexity assessment"
    _aria_complexity_debug "Task length: ${#task_context} chars"
    [[ -n "$error_file" ]] && _aria_complexity_debug "Error file: $error_file"

    # Base tier (standard)
    local tier=2

    # FACTOR 1: File count
    local file_count=$(_aria_complexity_count_files "$task_context")
    local file_tier_adjust=$((file_count / 3))
    tier=$((tier + file_tier_adjust))
    _aria_complexity_debug "Files found: $file_count (tier adjust: +$file_tier_adjust)"

    # FACTOR 2: Keyword scoring
    local keyword_score=$(_aria_complexity_keyword_score "$task_context")
    tier=$((tier + keyword_score))
    _aria_complexity_debug "Keyword score: $keyword_score (tier adjust: +$keyword_score)"

    # FACTOR 3: Multi-system detection
    local multi_system=$(_aria_complexity_multi_system "$task_context")
    tier=$((tier + multi_system))
    _aria_complexity_debug "Multi-system score: $multi_system (tier adjust: +$multi_system)"

    # FACTOR 4: Error context
    if [[ -n "$error_file" && -f "$error_file" && -s "$error_file" ]]; then
        tier=$((tier + 1))
        _aria_complexity_debug "Error context found: +1 tier"
    elif [[ -n "$error_file" ]]; then
        _aria_complexity_debug "Error file specified but not found or empty: $error_file"
    fi

    # Clamp to valid range [1, 3]
    if [[ $tier -lt 1 ]]; then
        tier=1
    elif [[ $tier -gt 3 ]]; then
        tier=3
    fi

    _aria_complexity_debug "Final tier: $tier"

    # Log the assessment (if aria_log_model available)
    if type aria_inc &>/dev/null; then
        aria_inc "complexity_assessments"
    fi

    # Output only the tier number
    echo "$tier"
    return 0
}

# =============================================================================
# BATCH ASSESSMENT (for testing multiple tasks)
# =============================================================================

aria_assess_batch() {
    local input_file="$1"

    if [[ ! -f "$input_file" ]]; then
        echo "Error: Input file not found: $input_file" >&2
        return 2
    fi

    echo "Task Assessment Results"
    echo "════════════════════════════════════════════════════════════════"

    local line_num=0
    while IFS= read -r task; do
        ((line_num++))
        [[ -z "$task" ]] && continue

        local tier=$(aria_assess_complexity "$task")
        local tier_name="Unknown"

        case "$tier" in
            1) tier_name="Simple (instant/codex-mini)" ;;
            2) tier_name="Standard (gpt-5.1/codex)" ;;
            3) tier_name="Complex (codex-max)" ;;
        esac

        printf "[%2d] Tier %d (%s)\n" "$line_num" "$tier" "$tier_name"
        printf "     Task: %.70s...\n" "$task"
        echo ""
    done < "$input_file"
}

# =============================================================================
# CLI INTERFACE (only run when executed directly)
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        assess)
            shift
            aria_assess_complexity "$@"
            ;;
        batch)
            shift
            aria_assess_batch "$@"
            ;;
        debug)
            shift
            ARIA_COMPLEXITY_DEBUG=1 aria_assess_complexity "$@"
            ;;
        help)
            cat << 'HELP'
ARIA Complexity Assessment Tool

Usage:
  aria-complexity.sh assess "task description" [error_file]
  aria-complexity.sh batch input_file
  aria-complexity.sh debug "task description" [error_file]
  aria-complexity.sh help

Examples:
  # Simple assessment
  aria-complexity.sh assess "Fix typo in README"
  # Output: 1

  # Complex assessment
  aria-complexity.sh assess "Refactor database migration API for multi-system sync"
  # Output: 3

  # With error context
  aria-complexity.sh assess "Fix compilation error" /tmp/error.log

  # Batch processing
  aria-complexity.sh batch /tmp/tasks.txt

  # Debug mode
  aria-complexity.sh debug "Refactor architecture" --verbose

Output: Tier number (1, 2, or 3)

Tier Reference:
  1 = Simple (instant/codex-mini)
  2 = Standard (gpt-5.1 or gpt-5.1-codex)
  3 = Complex (gpt-5.1-codex-max)
HELP
            ;;
        *)
            if [[ -n "$1" ]]; then
                aria_assess_complexity "$@"
            else
                echo "ARIA Complexity Assessment"
                echo "Usage: aria-complexity.sh assess|batch|debug|help [args]"
                echo "Try: aria-complexity.sh help"
                exit 1
            fi
            ;;
    esac
fi
