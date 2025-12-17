#!/bin/bash
# ARIA Iteration Breaker - Loop detection and circuit breaker for ARIA routing
# Prevents infinite retry cycles by detecting patterns and forcing escalation or human intervention
# Usage: aria-iteration-breaker.sh <command> [task_id] [reason]

set -euo pipefail

# Source dependencies
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

# Loop detection thresholds
LOOP_SAME_ERROR_COUNT=2           # Same error appearing N times = loop
LOOP_NO_TIER_CHANGE_ATTEMPTS=3    # N failures without tier change = stuck
LOOP_QG_FAIL_REPEAT=2             # Quality gate failing on same check = loop

# Blocked tasks state directory
BLOCKED_TASKS_DIR="/tmp/aria-blocked-tasks"
BLOCKED_TASKS_STATE="$BLOCKED_TASKS_DIR/blocked.json"

# Logging
VAR_DIR="/tmp/claude_vars"
ITERATION_BREAKER_LOG="$VAR_DIR/aria-iteration-breaker.log"
mkdir -p "$VAR_DIR" "$BLOCKED_TASKS_DIR"

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

_breaker_log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${msg}" >> "$ITERATION_BREAKER_LOG" 2>/dev/null || true

    case "$level" in
        INFO)   echo -e "${BLUE}ℹ ${msg}${NC}" >&2 ;;
        SUCCESS) echo -e "${GREEN}✓ ${msg}${NC}" >&2 ;;
        WARN)   echo -e "${YELLOW}⚠ ${msg}${NC}" >&2 ;;
        ERROR)  echo -e "${RED}✗ ${msg}${NC}" >&2 ;;
        ALERT)  echo -e "${MAGENTA}🔄 ${msg}${NC}" >&2 ;;
    esac
}

_breaker_debug() {
    if [[ "${ARIA_BREAKER_DEBUG:-0}" == "1" ]]; then
        _breaker_log INFO "[DEBUG] $*"
    fi
}

# =============================================================================
# ERROR SIMILARITY MATCHING
# =============================================================================

# Calculate Levenshtein distance between two strings (simplified)
# Returns 0 if strings are similar (>80%), 1 if different
_error_similarity() {
    local str1="$1"
    local str2="$2"
    local threshold="${3:-80}"  # Default 80% similarity

    # Exact match is 100% similar
    if [[ "$str1" == "$str2" ]]; then
        return 0
    fi

    # Quick heuristic: if first 50 chars match, likely same error
    local prefix1="${str1:0:50}"
    local prefix2="${str2:0:50}"

    if [[ "$prefix1" == "$prefix2" ]]; then
        return 0
    fi

    # Check if one contains the other (for variations)
    if [[ "$str1" == *"$str2"* ]] || [[ "$str2" == *"$str1"* ]]; then
        return 0
    fi

    # Extract error type (e.g., "TypeError:", "SyntaxError:")
    local type1=$(echo "$str1" | grep -oE '^[A-Za-z]*Error: ' | head -1)
    local type2=$(echo "$str2" | grep -oE '^[A-Za-z]*Error: ' | head -1)

    if [[ -n "$type1" ]] && [[ "$type1" == "$type2" ]]; then
        return 0
    fi

    return 1
}

# =============================================================================
# LOOP DETECTION FUNCTIONS
# =============================================================================

# Count how many times an error appears in failure history
_count_error_occurrences() {
    local task_id="$1"
    local search_error="$2"
    [[ -z "$task_id" ]] && return 0

    local state_file=$(_aria_task_file "$task_id")
    [[ ! -f "$state_file" ]] && return 0

    local count=0
    while IFS= read -r failure; do
        if _error_similarity "$failure" "$search_error"; then
            ((count++))
        fi
    done < <(jq -r '.failures[] | .error // empty' "$state_file" 2>/dev/null)

    echo "$count"
}

# Get the most recent error message
_get_latest_error() {
    local task_id="$1"
    [[ -z "$task_id" ]] && return 1

    local state_file=$(_aria_task_file "$task_id")
    [[ ! -f "$state_file" ]] && return 1

    jq -r '.failures[-1] | .error // empty' "$state_file" 2>/dev/null
}

# Check if tier has changed between attempts
_has_tier_changed() {
    local task_id="$1"
    [[ -z "$task_id" ]] && return 1

    local state_file=$(_aria_task_file "$task_id")
    [[ ! -f "$state_file" ]] && return 1

    # Get unique tiers from escalation log
    local tiers=$(jq -r '.escalation_log[] | .from_tier' "$state_file" 2>/dev/null | sort -u | wc -l)

    if [[ $tiers -gt 1 ]]; then
        return 0  # Tier changed
    fi
    return 1  # No tier change
}

# Get the count of failures at current tier without escalation
_failures_at_current_tier() {
    local task_id="$1"
    [[ -z "$task_id" ]] && return 0

    local state_file=$(_aria_task_file "$task_id")
    [[ ! -f "$state_file" ]] && return 0

    local current_tier=$(jq -r '.model_tier // 1' "$state_file" 2>/dev/null)
    local last_escalation_attempt=$(jq -r '.escalation_log[-1] | .timestamp // 0' "$state_file" 2>/dev/null)

    # Count failures that occurred after the last escalation
    local count=0
    while IFS= read -r attempt; do
        ((count++))
    done < <(jq -r ".failures[] | select(.model == \"$(aria_task_get "$task_id" model_tier)\") | .attempt" "$state_file" 2>/dev/null)

    echo "$count"
}

# Analyze quality gate failures
_analyze_qg_failures() {
    local task_id="$1"
    [[ -z "$task_id" ]] && return 0

    local state_file=$(_aria_task_file "$task_id")
    [[ ! -f "$state_file" ]] && return 0

    local qg_count=0
    local qg_checks=()

    while IFS= read -r check; do
        if [[ -n "$check" ]]; then
            ((qg_count++))
            qg_checks+=("$check")
        fi
    done < <(jq -r '.failures[] | select(.error | contains("Quality gate")) | .error' "$state_file" 2>/dev/null)

    if [[ $qg_count -ge $LOOP_QG_FAIL_REPEAT ]]; then
        # Check if same check is failing repeatedly
        local first_check="${qg_checks[0]:-}"
        local same_check_count=0

        for check in "${qg_checks[@]}"; do
            if _error_similarity "$check" "$first_check"; then
                ((same_check_count++))
            fi
        done

        if [[ $same_check_count -ge $LOOP_QG_FAIL_REPEAT ]]; then
            echo "quality_gate_loop"
            return 0
        fi
    fi

    return 1
}

# Primary loop detection function
aria_loop_check() {
    local task_id="$1"
    [[ -z "$task_id" ]] && return 1

    local state_file=$(_aria_task_file "$task_id")
    [[ ! -f "$state_file" ]] && return 1

    _breaker_debug "Checking for loops in task $task_id"

    # Check for same error repeating
    local latest_error=$(_get_latest_error "$task_id")
    if [[ -n "$latest_error" ]]; then
        local same_error_count=$(_count_error_occurrences "$task_id" "$latest_error")
        if [[ $same_error_count -ge $LOOP_SAME_ERROR_COUNT ]]; then
            _breaker_log ALERT "Loop detected: Same error appearing $same_error_count times"
            return 0
        fi
    fi

    # Check for stuck tier (failures without escalation)
    local attempt_count=$(jq -r '.attempt_count // 0' "$state_file" 2>/dev/null)
    if [[ $attempt_count -ge $LOOP_NO_TIER_CHANGE_ATTEMPTS ]]; then
        if ! _has_tier_changed "$task_id"; then
            local escalations=$(jq -r '.escalation_log | length' "$state_file" 2>/dev/null)
            if [[ $escalations -eq 0 ]]; then
                _breaker_log ALERT "Loop detected: $attempt_count attempts without tier change"
                return 0
            fi
        fi
    fi

    # Check for quality gate loops
    if _analyze_qg_failures "$task_id" > /dev/null; then
        _breaker_log ALERT "Loop detected: Quality gate failing on same check repeatedly"
        return 0
    fi

    _breaker_debug "No loop detected for task $task_id"
    return 1
}

# =============================================================================
# LOOP ANALYSIS
# =============================================================================

# Deep analysis of loop pattern
aria_loop_analyze() {
    local task_id="$1"
    [[ -z "$task_id" ]] && return 1

    local state_file=$(_aria_task_file "$task_id")
    [[ ! -f "$state_file" ]] && return 1

    _breaker_log INFO "Analyzing loop pattern for task $task_id"

    local task_desc=$(jq -r '.task_desc // ""' "$state_file" 2>/dev/null)
    local attempt_count=$(jq -r '.attempt_count // 0' "$state_file" 2>/dev/null)
    local current_tier=$(jq -r '.model_tier // 1' "$state_file" 2>/dev/null)
    local current_model=$(aria_task_get "$task_id" model_tier)

    # Collect failure details
    local latest_error=$(_get_latest_error "$task_id")
    local same_error_count=$(_count_error_occurrences "$task_id" "$latest_error")
    local escalations=$(jq -r '.escalation_log | length' "$state_file" 2>/dev/null)

    # Identify pattern type
    local pattern_type="unknown"
    if [[ $same_error_count -ge $LOOP_SAME_ERROR_COUNT ]]; then
        pattern_type="repeated_error"
    elif [[ $escalations -eq 0 ]] && [[ $attempt_count -ge $LOOP_NO_TIER_CHANGE_ATTEMPTS ]]; then
        pattern_type="stuck_tier"
    elif _analyze_qg_failures "$task_id" > /dev/null; then
        pattern_type="quality_gate_loop"
    fi

    # Build JSON analysis
    cat << EOF
{
  "task_id": "$task_id",
  "task_desc": $(jq -R . <<< "$task_desc"),
  "pattern_type": "$pattern_type",
  "attempt_count": $attempt_count,
  "current_tier": $current_tier,
  "current_model": "$current_model",
  "escalations_done": $escalations,
  "repeated_error_count": $same_error_count,
  "latest_error": $(jq -R . <<< "$latest_error"),
  "analysis_timestamp": "$(date +%s)",
  "suggested_action": "$(aria_loop_suggest_action "$task_id" "$pattern_type")"
}
EOF

    return 0
}

# Suggest next action based on pattern
aria_loop_suggest_action() {
    local task_id="$1"
    local pattern_type="$2"
    [[ -z "$task_id" ]] && return 1

    local state_file=$(_aria_task_file "$task_id")
    local current_tier=$(jq -r '.model_tier // 1' "$state_file" 2>/dev/null)

    case "$pattern_type" in
        repeated_error)
            if [[ $current_tier -lt 6 ]]; then
                echo "Force escalate 2 tiers (skip ineffective middle tier)"
            else
                echo "HUMAN_INTERVENTION_REQUIRED: Already at high tier, fundamental issue"
            fi
            ;;
        stuck_tier)
            if [[ $current_tier -lt 6 ]]; then
                echo "Escalate to higher tier - current tier not solving problem"
            else
                echo "HUMAN_INTERVENTION_REQUIRED: Stuck at max tier"
            fi
            ;;
        quality_gate_loop)
            echo "HUMAN_INTERVENTION_REQUIRED: Quality gate fundamentally broken, needs code review"
            ;;
        *)
            echo "Unknown pattern - human review recommended"
            ;;
    esac
}

# =============================================================================
# ESCALATION AND CIRCUIT BREAKING
# =============================================================================

# Force escalation, jumping 2 tiers instead of 1
aria_force_escalate() {
    local task_id="$1"
    local reason="${2:-Loop detected, forcing escalation}"
    [[ -z "$task_id" ]] && return 1

    local state_file=$(_aria_task_file "$task_id")
    local lock_file=$(_aria_task_lock "$task_id")
    [[ ! -f "$state_file" ]] && return 1

    _breaker_log WARN "Force escalating task $task_id: $reason"

    local tmp_out=$(mktemp)
    (
        flock -x 200 2>/dev/null || true

        local current_tier=$(jq -r '.model_tier // 1' "$state_file" 2>/dev/null)
        local new_tier=$((current_tier + 2))  # Jump 2 tiers

        # Cap at tier 7
        if [[ $new_tier -gt 7 ]]; then
            new_tier=7
        fi

        # Check if already at max
        if [[ $current_tier -ge 7 ]]; then
            echo "HUMAN_INTERVENTION_REQUIRED"
            echo "already_at_max_tier" > "$tmp_out"
            return 0
        fi

        # Update tier
        local tmp=$(mktemp)
        jq ".model_tier = $new_tier" "$state_file" > "$tmp" 2>/dev/null

        # Append escalation log entry
        jq ".escalation_log += [{
            \"timestamp\": \"$(date +%s)\",
            \"reason\": $(jq -R . <<< "$reason"),
            \"forced\": true,
            \"from_tier\": $current_tier,
            \"to_tier\": $new_tier
        }]" "$tmp" > "${state_file}.tmp" 2>/dev/null

        rm -f "$tmp"
        mv "${state_file}.tmp" "$state_file" 2>/dev/null
        echo "$new_tier" > "$tmp_out"
    ) 200>"$lock_file"

    cat "$tmp_out" 2>/dev/null
    rm -f "$tmp_out"
    return 0
}

# Full circuit breaker - mark task as blocked and generate human summary
aria_circuit_break() {
    local task_id="$1"
    local reason="${2:-Circuit breaker triggered}"
    [[ -z "$task_id" ]] && return 1

    local state_file=$(_aria_task_file "$task_id")
    [[ ! -f "$state_file" ]] && return 1

    _breaker_log ERROR "Circuit breaker activated for task $task_id"

    # Generate analysis
    local analysis=$(aria_loop_analyze "$task_id" 2>/dev/null || echo "{}")

    # Create blocked task record
    local blocked_time=$(date +%s)
    local task_desc=$(jq -r '.task_desc // ""' "$state_file" 2>/dev/null)
    local attempt_count=$(jq -r '.attempt_count // 0' "$state_file" 2>/dev/null)
    local current_tier=$(jq -r '.model_tier // 1' "$state_file" 2>/dev/null)

    # Initialize or update blocked tasks state
    if [[ ! -f "$BLOCKED_TASKS_STATE" ]]; then
        echo "{\"blocked_tasks\": []}" > "$BLOCKED_TASKS_STATE"
    fi

    # Add this task to blocked list
    jq ".blocked_tasks += [{
        \"task_id\": \"$task_id\",
        \"task_desc\": $(jq -R . <<< "$task_desc"),
        \"reason\": $(jq -R . <<< "$reason"),
        \"blocked_at\": \"$blocked_time\",
        \"attempts\": $attempt_count,
        \"final_tier\": $current_tier,
        \"analysis\": $analysis
    }]" "$BLOCKED_TASKS_STATE" > "${BLOCKED_TASKS_STATE}.tmp" 2>/dev/null

    mv "${BLOCKED_TASKS_STATE}.tmp" "$BLOCKED_TASKS_STATE" 2>/dev/null

    # Mark task state as blocked
    (
        flock -x 200 2>/dev/null || true
        jq ".blocked = true | .blocked_at = \"$blocked_time\" | .block_reason = $(jq -R . <<< "$reason")" \
            "$state_file" > "${state_file}.tmp" 2>/dev/null
        mv "${state_file}.tmp" "$state_file" 2>/dev/null
    ) 200>"$(_aria_task_lock "$task_id")"

    # Generate human-readable summary
    local summary_file="$BLOCKED_TASKS_DIR/${task_id}-summary.txt"
    _generate_human_summary "$task_id" "$reason" "$analysis" > "$summary_file"

    echo "$summary_file"
    return 0
}

# Generate human-readable summary for blocked task
_generate_human_summary() {
    local task_id="$1"
    local reason="$2"
    local analysis="$3"

    local task_desc=$(echo "$analysis" | jq -r '.task_desc // ""')
    local pattern=$(echo "$analysis" | jq -r '.pattern_type // "unknown"')
    local attempts=$(echo "$analysis" | jq -r '.attempt_count // 0')
    local tier=$(echo "$analysis" | jq -r '.current_tier // 0')
    local error=$(echo "$analysis" | jq -r '.latest_error // ""')
    local action=$(echo "$analysis" | jq -r '.suggested_action // ""')

    cat << EOF
═══════════════════════════════════════════════════════════════════════════════
ARIA ITERATION BREAKER - TASK BLOCKED
═══════════════════════════════════════════════════════════════════════════════

Task ID: $task_id
Blocked At: $(date '+%Y-%m-%d %H:%M:%S')

Task Description:
  $task_desc

Loop Pattern: $pattern
Attempts: $attempts
Current Tier: $tier
Blocked Reason: $reason

═══════════════════════════════════════════════════════════════════════════════
REPEATED ERROR
═══════════════════════════════════════════════════════════════════════════════

$error

═══════════════════════════════════════════════════════════════════════════════
SUGGESTED ACTION
═══════════════════════════════════════════════════════════════════════════════

$action

═══════════════════════════════════════════════════════════════════════════════
NEXT STEPS
═══════════════════════════════════════════════════════════════════════════════

1. Review the task description and error message above
2. Identify the root cause (not a retry issue)
3. One of:
   a) Fix the underlying code/requirements and restart
   b) Escalate to human review if fundamental blocker
   c) Queue task for later when related issues are resolved

4. When ready, cleanup this task:
   aria-iteration-breaker.sh cleanup $task_id

═══════════════════════════════════════════════════════════════════════════════
EOF
}

# =============================================================================
# STATUS AND MANAGEMENT
# =============================================================================

# Show all blocked tasks
aria_iteration_status() {
    echo "ARIA Iteration Breaker Status"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""

    if [[ ! -f "$BLOCKED_TASKS_STATE" ]]; then
        echo "No blocked tasks"
        return 0
    fi

    local count=$(jq -r '.blocked_tasks | length' "$BLOCKED_TASKS_STATE" 2>/dev/null || echo 0)

    if [[ $count -eq 0 ]]; then
        echo "No blocked tasks"
        return 0
    fi

    echo "Blocked Tasks: $count"
    echo "───────────────────────────────────────────────────────────────────────────────"

    jq -r '.blocked_tasks[] | "\(.task_id) | Attempts: \(.attempts) | Tier: \(.final_tier) | Pattern: \(.analysis.pattern_type)"' \
        "$BLOCKED_TASKS_STATE" 2>/dev/null | column -t -s '|'

    echo ""
    echo "Summary files in: $BLOCKED_TASKS_DIR"
    echo ""
}

# Cleanup blocked task (remove from state)
aria_iteration_cleanup() {
    local task_id="$1"
    [[ -z "$task_id" ]] && return 1

    if [[ -f "$BLOCKED_TASKS_STATE" ]]; then
        jq ".blocked_tasks |= map(select(.task_id != \"$task_id\"))" \
            "$BLOCKED_TASKS_STATE" > "${BLOCKED_TASKS_STATE}.tmp" 2>/dev/null
        mv "${BLOCKED_TASKS_STATE}.tmp" "$BLOCKED_TASKS_STATE" 2>/dev/null
    fi

    # Clean up summary file
    rm -f "$BLOCKED_TASKS_DIR/${task_id}-summary.txt" 2>/dev/null

    # Remove task state
    aria_task_cleanup "$task_id" 2>/dev/null || true

    _breaker_log SUCCESS "Cleaned up blocked task $task_id"
    return 0
}

# =============================================================================
# CLI INTERFACE
# =============================================================================

_print_help() {
    cat << 'HELP'
ARIA Iteration Breaker - Loop detection and circuit breaker

Usage:
  aria-iteration-breaker.sh <command> [arguments]

Commands:
  check <task_id>          Check if task is in a loop
  analyze <task_id>        Deep analysis of loop pattern (JSON output)
  force-escalate <task_id> Force escalation, jumping 2 tiers
  break <task_id>          Activate circuit breaker for task
  status                   Show all blocked tasks
  cleanup <task_id>        Remove task from blocked list
  help                     Show this help message

Examples:
  # Check if task is stuck
  aria-iteration-breaker.sh check abc12345

  # Analyze the problem
  aria-iteration-breaker.sh analyze abc12345 | jq .

  # Force escalation (jump 2 tiers)
  aria-iteration-breaker.sh force-escalate abc12345 "Same error repeating"

  # Full circuit break
  aria-iteration-breaker.sh break abc12345 "Fundamental issue detected"

  # View all blocked tasks
  aria-iteration-breaker.sh status

  # Clean up when task is fixed
  aria-iteration-breaker.sh cleanup abc12345

Output:
  - Loop detection returns 0 (loop found) or 1 (no loop)
  - Analysis returns JSON with pattern details
  - Circuit break generates human-readable summary file
  - Blocked tasks directory: $BLOCKED_TASKS_DIR

Environment:
  ARIA_BREAKER_DEBUG=1     Enable debug output

HELP
}

# Main CLI
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    command="${1:-help}"
    shift || true

    case "$command" in
        check)
            if [[ -z "${1:-}" ]]; then
                echo "Error: task_id required for 'check' command" >&2
                exit 1
            fi
            aria_loop_check "$1"
            exit $?
            ;;
        analyze)
            if [[ -z "${1:-}" ]]; then
                echo "Error: task_id required for 'analyze' command" >&2
                exit 1
            fi
            aria_loop_analyze "$1"
            exit $?
            ;;
        force-escalate)
            if [[ -z "${1:-}" ]]; then
                echo "Error: task_id required for 'force-escalate' command" >&2
                exit 1
            fi
            local reason="${2:-Forced escalation by circuit breaker}"
            result=$(aria_force_escalate "$1" "$reason")
            if [[ "$result" == "HUMAN_INTERVENTION_REQUIRED" ]]; then
                _breaker_log ERROR "Task already at maximum tier, human intervention required"
                exit 1
            else
                _breaker_log SUCCESS "Escalated to tier $result"
                exit 0
            fi
            ;;
        break)
            if [[ -z "${1:-}" ]]; then
                echo "Error: task_id required for 'break' command" >&2
                exit 1
            fi
            local reason="${2:-Circuit breaker triggered}"
            summary_file=$(aria_circuit_break "$1" "$reason")
            if [[ -f "$summary_file" ]]; then
                echo ""
                cat "$summary_file"
                _breaker_log ERROR "Circuit breaker activated. Review summary above."
                exit 0
            else
                _breaker_log ERROR "Failed to generate circuit break summary"
                exit 1
            fi
            ;;
        status)
            aria_iteration_status
            exit $?
            ;;
        cleanup)
            if [[ -z "${1:-}" ]]; then
                echo "Error: task_id required for 'cleanup' command" >&2
                exit 1
            fi
            aria_iteration_cleanup "$1"
            exit $?
            ;;
        log)
            tail -50 "$ITERATION_BREAKER_LOG" 2>/dev/null || echo "No log file"
            exit 0
            ;;
        help|--help|-h)
            _print_help
            exit 0
            ;;
        *)
            echo "Unknown command: $command" >&2
            _print_help >&2
            exit 2
            ;;
    esac
fi
