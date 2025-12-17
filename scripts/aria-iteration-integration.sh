#!/bin/bash
# ARIA Iteration Integration - Hook for aria-smart-route.sh
# Source this in aria-smart-route to enable automatic loop detection
# Usage: source ~/.claude/scripts/aria-iteration-integration.sh

# Source the iteration breaker
source ~/.claude/scripts/aria-iteration-breaker.sh 2>/dev/null || {
    echo "Warning: aria-iteration-breaker.sh not found, loop detection disabled" >&2
    return 1
}

# =============================================================================
# INTEGRATION HOOKS FOR ARIA-SMART-ROUTE
# =============================================================================

# Hook to call after each failure
# Call from aria-smart-route after failed attempt
aria_smart_route_check_loop() {
    local task_id="$1"
    [[ -z "$task_id" ]] && return 1

    # Check if in loop
    if aria_loop_check "$task_id"; then
        # Loop detected - analyze and decide action
        local analysis=$(aria_loop_analyze "$task_id" 2>/dev/null || echo "{}")
        local pattern=$(echo "$analysis" | jq -r '.pattern_type // "unknown"')
        local current_tier=$(echo "$analysis" | jq -r '.current_tier // 1')
        local suggested=$(echo "$analysis" | jq -r '.suggested_action // ""')

        _aria_smart_log WARN "Loop detected: pattern=$pattern tier=$current_tier"

        # Auto-action based on pattern
        case "$pattern" in
            repeated_error)
                # Same error repeating - try escalating 2 tiers
                if [[ $current_tier -lt 6 ]]; then
                    local new_tier=$(aria_force_escalate "$task_id" "Loop: same error repeating")
                    _aria_smart_log WARN "Forced escalation to tier $new_tier"
                    return 0  # Continue retry with new tier
                else
                    # Already at high tier - circuit break
                    aria_circuit_break "$task_id" "Repeated error at high tier"
                    return 1  # Stop and break circuit
                fi
                ;;
            stuck_tier)
                # Not progressing - try escalation
                if [[ $current_tier -lt 6 ]]; then
                    local new_tier=$(aria_force_escalate "$task_id" "Loop: stuck at tier $current_tier")
                    _aria_smart_log WARN "Escalated to tier $new_tier due to stuck tier"
                    return 0
                else
                    aria_circuit_break "$task_id" "Stuck at maximum tier"
                    return 1
                fi
                ;;
            quality_gate_loop)
                # QG failing on same check - circuit break immediately
                aria_circuit_break "$task_id" "Quality gate loop: same check failing repeatedly"
                return 1
                ;;
            *)
                # Unknown pattern - log and continue
                _aria_smart_log DEBUG "Unknown loop pattern: $pattern, continuing"
                return 0
                ;;
        esac
    fi

    # No loop detected
    return 0
}

# Optional: Check loop status before starting task
aria_smart_route_pre_check() {
    local task_id="$1"
    [[ -z "$task_id" ]] && return 0

    # Check if task is already blocked
    if [[ -f "/tmp/aria-blocked-tasks/blocked.json" ]]; then
        local is_blocked=$(jq -r ".blocked_tasks[] | select(.task_id == \"$task_id\") | .task_id" \
            "/tmp/aria-blocked-tasks/blocked.json" 2>/dev/null)

        if [[ -n "$is_blocked" ]]; then
            _aria_smart_log ERROR "Task $task_id is already blocked by iteration breaker"
            return 1
        fi
    fi

    return 0
}

# Export functions for use in aria-smart-route
export -f aria_loop_check
export -f aria_loop_analyze
export -f aria_force_escalate
export -f aria_circuit_break
export -f aria_smart_route_check_loop
export -f aria_smart_route_pre_check
