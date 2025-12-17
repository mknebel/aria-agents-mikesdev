#!/bin/bash
# ARIA Smart Router - Orchestrator with retry loop and auto-escalation
# Handles task routing with complexity assessment, model tier selection, and intelligent retry logic
# Usage: aria-smart-route.sh <type> "<description>" [max_attempts]

set -euo pipefail

# Source dependencies
source ~/.claude/scripts/aria-state.sh 2>/dev/null || {
    echo "Error: aria-state.sh not found" >&2
    exit 2
}
source ~/.claude/scripts/aria-route.sh 2>/dev/null || {
    echo "Error: aria-route.sh not found" >&2
    exit 2
}
source ~/.claude/scripts/aria-complexity.sh 2>/dev/null || {
    echo "Error: aria-complexity.sh not found" >&2
    exit 2
}
source ~/.claude/scripts/aria-task-state.sh 2>/dev/null || {
    echo "Error: aria-task-state.sh not found" >&2
    exit 2
}
source ~/.claude/scripts/aria-config.sh 2>/dev/null || {
    echo "Error: aria-config.sh not found" >&2
    exit 2
}

# =============================================================================
# CONFIGURATION
# =============================================================================

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Model tier mapping (matches aria-route.sh tiers)
declare -A TIER_MODELS=(
    [1]="gpt-5.1-codex-mini"     # Fast, cheap, Haiku replacement
    [2]="gpt-5.1-codex"          # Balanced, code-optimized
    [3]="gpt-5.1-codex-max"      # Maximum capability
)

# Task type to initial route mapping
declare -A TASK_ROUTES=(
    [code]="code"
    [design]="complex"
    [complex]="complex"
    [analysis]="context"
    [instant]="instant"
    [general]="general"
)

# VAR dir for persistence
VAR_DIR="/tmp/claude_vars"
SMART_ROUTE_LOG="$VAR_DIR/aria-smart-route.log"
mkdir -p "$VAR_DIR"

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

_aria_smart_log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${msg}" >> "$SMART_ROUTE_LOG" 2>/dev/null || true

    # Also log to stderr with colors
    case "$level" in
        INFO)   echo -e "${BLUE}ℹ ${msg}${NC}" >&2 ;;
        SUCCESS) echo -e "${GREEN}✓ ${msg}${NC}" >&2 ;;
        WARN)   echo -e "${YELLOW}⚠ ${msg}${NC}" >&2 ;;
        ERROR)  echo -e "${RED}✗ ${msg}${NC}" >&2 ;;
        DEBUG)  [[ "${ARIA_SMART_DEBUG:-0}" == "1" ]] && echo -e "${CYAN}DEBUG: ${msg}${NC}" >&2 ;;
    esac
}

_aria_smart_debug() {
    if [[ "${ARIA_SMART_DEBUG:-0}" == "1" ]]; then
        _aria_smart_log DEBUG "$@"
    fi
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

_aria_smart_validate_args() {
    local task_type="$1"
    local task_desc="$2"

    if [[ -z "$task_type" ]]; then
        echo "Error: task_type required" >&2
        return 2
    fi

    if [[ -z "$task_desc" ]]; then
        echo "Error: task_description required" >&2
        return 2
    fi

    return 0
}

# =============================================================================
# TIER MANAGEMENT
# =============================================================================

_aria_smart_get_model() {
    local tier="$1"
    [[ -z "$tier" ]] && tier=2

    # Bounds check
    if [[ $tier -lt 1 ]]; then tier=1; fi
    if [[ $tier -gt 3 ]]; then tier=3; fi

    echo "${TIER_MODELS[$tier]}"
}

_aria_smart_tier_name() {
    local tier="$1"
    case "$tier" in
        1) echo "Tier 1 (Fast)" ;;
        2) echo "Tier 2 (Balanced)" ;;
        3) echo "Tier 3 (Maximum)" ;;
        *) echo "Unknown" ;;
    esac
}

# =============================================================================
# TASK EXECUTION
# =============================================================================

_aria_smart_build_prompt() {
    local original_prompt="$1"
    local task_id="$2"
    local attempt="$3"

    if [[ $attempt -eq 1 ]]; then
        # First attempt: use original prompt as-is
        echo "$original_prompt"
    else
        # Retry attempt: inject failure context
        local failure_context=$(aria_task_get_failure_context "$task_id" 2>/dev/null || true)

        if [[ -n "$failure_context" ]]; then
            cat << EOF
${original_prompt}

---

PREVIOUS ATTEMPT FAILED - RETRY WITH IMPROVEMENTS:

${failure_context}

Please try again with a different approach or more careful implementation.
EOF
        else
            echo "$original_prompt"
        fi
    fi
}

_aria_smart_execute_task() {
    local task_type="$1"
    local task_id="$2"
    local prompt="$3"
    local attempt="$4"
    local tier="$5"
    local model="$6"

    _aria_smart_log INFO "Executing task (attempt $attempt, tier $tier, $(_aria_smart_tier_name $tier))"

    # Build full prompt with failure context if retry
    local full_prompt=$(_aria_smart_build_prompt "$prompt" "$task_id" "$attempt")

    # Execute via aria-route
    _aria_smart_debug "Calling aria_route with task_type=$task_type"
    local output
    output=$(aria_route "$task_type" "$full_prompt" 2>&1) || {
        local exit_code=$?
        _aria_smart_log ERROR "aria_route failed with exit code $exit_code"
        aria_task_record_failure "$task_id" "aria_route failed with exit code $exit_code"
        return 1
    }

    # Save output to temp file for quality gate
    local output_file=$(aria_temp_file "smart_route_output_${task_id}.txt")
    echo "$output" > "$output_file"

    echo "$output"
    return 0
}

_aria_smart_verify_task() {
    local task_type="$1"
    local task_id="$2"
    local output_file="$3"

    # For code tasks, run quality gate
    if [[ "$task_type" == "code" ]]; then
        _aria_smart_log INFO "Running quality gate..."

        if quality-gate.sh . --skip-tests 2>&1 | tee -a "$SMART_ROUTE_LOG"; then
            _aria_smart_log SUCCESS "Quality gate passed"
            return 0
        else
            local qg_output=$(quality-gate.sh . --skip-tests 2>&1 | tail -20)
            _aria_smart_log ERROR "Quality gate failed"
            aria_task_record_failure "$task_id" "Quality gate failed: $qg_output"
            return 1
        fi
    else
        # For non-code tasks, simple validation
        if [[ -s "$output_file" ]]; then
            _aria_smart_log SUCCESS "Task completed with output"
            return 0
        else
            _aria_smart_log ERROR "No output from task"
            aria_task_record_failure "$task_id" "No output generated"
            return 1
        fi
    fi
}

# =============================================================================
# MAIN ORCHESTRATOR
# =============================================================================

aria_smart_route() {
    local task_type="$1"
    local task_desc="$2"
    local max_attempts="${3:-3}"

    # Validate arguments
    _aria_smart_validate_args "$task_type" "$task_desc" || return 2

    # Initialize logging
    _aria_smart_log INFO "Starting smart route: type=$task_type"
    _aria_smart_debug "Task description: ${task_desc:0:100}..."

    # Initialize task state
    local task_id
    task_id=$(aria_task_init "$task_desc") || {
        _aria_smart_log ERROR "Failed to initialize task state"
        return 1
    }
    _aria_smart_log INFO "Task ID: $task_id"

    # Assess complexity
    _aria_smart_log INFO "Assessing task complexity..."
    local assessed_tier
    assessed_tier=$(aria_assess_complexity "$task_desc") || assessed_tier=2
    _aria_smart_log INFO "Initial assessment: Tier $assessed_tier"
    aria_task_set "$task_id" "model_tier" "$assessed_tier"

    # Initialize temp directory for this task
    aria_init_temp
    local task_output_dir=$(aria_temp_file "smart_route_${task_id}")
    mkdir -p "$task_output_dir"

    # Retry loop
    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        _aria_smart_log INFO "Attempt $attempt of $max_attempts"

        # Get current tier and model
        local current_tier
        current_tier=$(aria_task_get_tier "$task_id") || current_tier=2
        local model=$(_aria_smart_get_model "$current_tier")

        _aria_smart_log INFO "Using model: $model ($(_aria_smart_tier_name $current_tier))"

        # Execute task
        local output_file="${task_output_dir}/attempt_${attempt}.txt"
        if _aria_smart_execute_task "$task_type" "$task_id" "$task_desc" "$attempt" "$current_tier" "$model" > "$output_file" 2>&1; then
            # Verify task success
            if _aria_smart_verify_task "$task_type" "$task_id" "$output_file"; then
                _aria_smart_log SUCCESS "Task completed successfully"

                # Save final output
                cat "$output_file"

                # Cleanup task state
                aria_task_cleanup "$task_id" 2>/dev/null || true
                aria_inc "smart_route_success"

                return 0
            else
                _aria_smart_log WARN "Task output failed verification"

                # Escalate every 2 failures
                if [[ $((attempt % 2)) -eq 0 ]]; then
                    local new_tier
                    new_tier=$(aria_task_escalate "$task_id" "Verification failed after attempt $attempt") || true
                    _aria_smart_log INFO "Escalating to tier $new_tier"
                fi
            fi
        else
            _aria_smart_log WARN "Task execution failed"

            # Escalate every 2 failures
            if [[ $((attempt % 2)) -eq 0 ]]; then
                local new_tier
                new_tier=$(aria_task_escalate "$task_id" "Execution failed on attempt $attempt") || true
                _aria_smart_log INFO "Escalating to tier $new_tier"
            fi
        fi

        # Increment attempt
        aria_task_increment_attempt "$task_id" > /dev/null 2>&1 || true
        ((attempt++))
    done

    # All attempts exhausted
    _aria_smart_log ERROR "Task failed after $max_attempts attempts"

    # Save final state for debugging
    local final_state=$(aria_temp_file "smart_route_final_state_${task_id}.json")
    aria_task_state "$task_id" > "$final_state" 2>/dev/null || true

    aria_inc "smart_route_failed"
    return 1
}

# =============================================================================
# CLI INTERFACE
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        help)
            cat << 'HELP'
ARIA Smart Router - Intelligent task routing with retry and escalation

Usage:
  aria-smart-route.sh <type> "<description>" [max_attempts]

Arguments:
  type              Task type: code, design, complex, analysis, instant, general
  description       Task description (quoted string)
  max_attempts      Maximum retry attempts (default: 3)

Examples:
  # Code generation with auto-retry
  aria-smart-route.sh code "Implement user authentication module" 3

  # Complex design task
  aria-smart-route.sh complex "Redesign database schema for multi-tenancy" 3

  # Quick code fix
  aria-smart-route.sh code "Fix typo in README.md" 1

Features:
  - Automatic complexity assessment (tier 1-3)
  - Intelligent retry with escalation
  - Quality gate verification for code tasks
  - Failure context injection in retries
  - Detailed logging to /tmp/claude_vars/aria-smart-route.log

Return Codes:
  0 = Success
  1 = Failed after all attempts
  2 = Invalid arguments

Environment:
  ARIA_SMART_DEBUG=1     Enable debug output

HELP
            exit 0
            ;;
        status)
            echo "ARIA Smart Router Status"
            echo "═══════════════════════════════════════"
            aria_task_list
            echo ""
            echo "Recent log entries:"
            tail -10 "$SMART_ROUTE_LOG" 2>/dev/null || echo "No log entries"
            exit 0
            ;;
        log)
            tail -50 "$SMART_ROUTE_LOG" 2>/dev/null || echo "No log file"
            exit 0
            ;;
        *)
            if [[ -z "${1:-}" ]] || [[ -z "${2:-}" ]]; then
                echo "ARIA Smart Router"
                echo "Usage: aria-smart-route.sh <type> \"<description>\" [max_attempts]"
                echo "Try: aria-smart-route.sh help"
                exit 2
            fi

            # Run main function
            aria_smart_route "$@"
            exit $?
            ;;
    esac
fi
