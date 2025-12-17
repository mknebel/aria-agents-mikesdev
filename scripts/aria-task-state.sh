#!/bin/bash
# ARIA Task State Management
# Tracks per-task state for retry/escalation logic
# State files: /tmp/aria-task-[TASK_HASH].json

# Model tier mapping (1=codex-mini to 7=opus)
ARIA_TIER_MAP=(
    "codex-mini"    # 1
    "gpt-5.1"       # 2
    "codex"         # 3
    "codex-max"     # 4
    "claude-haiku"  # 5
    "claude-opus"   # 6
    "aria-thinking" # 7
)

# Get task state file path from task_id (8-char hash)
_aria_task_file() {
    local task_id="$1"
    echo "/tmp/aria-task-${task_id}.json"
}

# Get lock file for concurrency
_aria_task_lock() {
    local task_id="$1"
    echo "/tmp/aria-task-${task_id}.lock"
}

# Hash task description to get stable task_id
_aria_task_hash() {
    local task_desc="$1"
    echo -n "$task_desc" | sha256sum 2>/dev/null | cut -c1-8
}

# Initialize task state and return task_id
aria_task_init() {
    local task_desc="$1"
    [[ -z "$task_desc" ]] && return 1

    local task_id=$(_aria_task_hash "$task_desc")
    local state_file=$(_aria_task_file "$task_id")

    # Only create if doesn't exist
    if [[ ! -f "$state_file" ]]; then
        cat > "$state_file" << EOF
{
  "task_id": "$task_id",
  "task_desc": $(jq -R . <<< "$task_desc"),
  "attempt_count": 0,
  "model_tier": 1,
  "created_at": "$(date +%s)",
  "failures": [],
  "escalation_log": [],
  "quality_gate_results": []
}
EOF
    fi

    echo "$task_id"
    return 0
}

# Get field value from task state
aria_task_get() {
    local task_id="$1"
    local field="$2"
    [[ -z "$task_id" ]] || [[ -z "$field" ]] && return 1

    local state_file=$(_aria_task_file "$task_id")
    [[ ! -f "$state_file" ]] && return 1

    jq -r ".$field // empty" "$state_file" 2>/dev/null
}

# Set field value in task state (with locking)
aria_task_set() {
    local task_id="$1"
    local field="$2"
    local value="$3"
    [[ -z "$task_id" ]] || [[ -z "$field" ]] && return 1

    local state_file=$(_aria_task_file "$task_id")
    local lock_file=$(_aria_task_lock "$task_id")
    [[ ! -f "$state_file" ]] && return 1

    (
        flock -x 200 2>/dev/null || true
        # Handle different value types
        if [[ "$value" =~ ^[0-9]+$ ]]; then
            jq ".$field = $value" "$state_file" > "${state_file}.tmp" 2>/dev/null
        else
            # Quote string values
            jq ".$field = $(jq -R . <<< "$value")" "$state_file" > "${state_file}.tmp" 2>/dev/null
        fi
        mv "${state_file}.tmp" "$state_file" 2>/dev/null
    ) 200>"$lock_file"

    return 0
}

# Increment attempt counter and return new value
aria_task_increment_attempt() {
    local task_id="$1"
    [[ -z "$task_id" ]] && return 1

    local state_file=$(_aria_task_file "$task_id")
    local lock_file=$(_aria_task_lock "$task_id")
    [[ ! -f "$state_file" ]] && return 1

    # Use a temp file to capture output from subshell
    local tmp_out=$(mktemp)
    (
        flock -x 200 2>/dev/null || true
        local current=$(jq -r '.attempt_count // 0' "$state_file" 2>/dev/null)
        local new_count=$((current + 1))
        jq ".attempt_count = $new_count" "$state_file" > "${state_file}.tmp" 2>/dev/null
        mv "${state_file}.tmp" "$state_file" 2>/dev/null
        echo "$new_count" > "$tmp_out"
    ) 200>"$lock_file"

    cat "$tmp_out" 2>/dev/null
    rm -f "$tmp_out"
    return 0
}

# Get current model tier (1-7)
aria_task_get_tier() {
    local task_id="$1"
    [[ -z "$task_id" ]] && return 1

    local state_file=$(_aria_task_file "$task_id")
    [[ ! -f "$state_file" ]] && return 1

    jq -r '.model_tier // 1' "$state_file" 2>/dev/null
}

# Get model name from tier number
_aria_task_tier_to_model() {
    local tier="$1"
    [[ -z "$tier" ]] && tier=1

    # Bounds check: 1-7
    if [[ $tier -lt 1 ]]; then tier=1; fi
    if [[ $tier -gt 7 ]]; then tier=7; fi

    # Array is 0-indexed, tier is 1-indexed
    echo "${ARIA_TIER_MAP[$((tier - 1))]}"
}

# Escalate task to higher tier and log reason
aria_task_escalate() {
    local task_id="$1"
    local reason="$2"
    [[ -z "$task_id" ]] && return 1

    local state_file=$(_aria_task_file "$task_id")
    local lock_file=$(_aria_task_lock "$task_id")
    [[ ! -f "$state_file" ]] && return 1

    local tmp_out=$(mktemp)
    (
        flock -x 200 2>/dev/null || true

        local current_tier=$(jq -r '.model_tier // 1' "$state_file" 2>/dev/null)
        local new_tier=$((current_tier + 1))

        # Cap at tier 7
        if [[ $new_tier -gt 7 ]]; then
            new_tier=7
        fi

        # Update tier
        local tmp=$(mktemp)
        jq ".model_tier = $new_tier" "$state_file" > "$tmp" 2>/dev/null

        # Append escalation log entry
        jq ".escalation_log += [{
            \"timestamp\": \"$(date +%s)\",
            \"reason\": $(jq -R . <<< "$reason"),
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

# Record a failure for the current attempt
aria_task_record_failure() {
    local task_id="$1"
    local error_summary="$2"
    [[ -z "$task_id" ]] && return 1

    local state_file=$(_aria_task_file "$task_id")
    local lock_file=$(_aria_task_lock "$task_id")
    [[ ! -f "$state_file" ]] && return 1

    (
        flock -x 200 2>/dev/null || true

        local attempt=$(jq -r '.attempt_count // 0' "$state_file" 2>/dev/null)
        local model_tier=$(jq -r '.model_tier // 1' "$state_file" 2>/dev/null)
        local model=$(_aria_task_tier_to_model "$model_tier")
        local timestamp=$(date +%s)

        jq ".failures += [{
            \"attempt\": $attempt,
            \"error\": $(jq -R . <<< "$error_summary"),
            \"model\": \"$model\",
            \"timestamp\": \"$timestamp\"
        }]" "$state_file" > "${state_file}.tmp" 2>/dev/null

        mv "${state_file}.tmp" "$state_file" 2>/dev/null
    ) 200>"$lock_file"

    return 0
}

# Get formatted failure context for prompt injection
aria_task_get_failure_context() {
    local task_id="$1"
    [[ -z "$task_id" ]] && return 1

    local state_file=$(_aria_task_file "$task_id")
    [[ ! -f "$state_file" ]] && return 0

    local failures=$(jq -r '.failures[] | "Attempt \(.attempt) (model: \(.model)): \(.error)"' "$state_file" 2>/dev/null)

    if [[ -n "$failures" ]]; then
        echo "Previous failures:"
        echo "$failures" | sed 's/^/  /'
    fi

    return 0
}

# Clean up task state file (call on success)
aria_task_cleanup() {
    local task_id="$1"
    [[ -z "$task_id" ]] && return 1

    local state_file=$(_aria_task_file "$task_id")
    local lock_file=$(_aria_task_lock "$task_id")

    rm -f "$state_file" "$lock_file" 2>/dev/null
    return 0
}

# Get full task state as JSON (for inspection/debugging)
aria_task_state() {
    local task_id="$1"
    [[ -z "$task_id" ]] && return 1

    local state_file=$(_aria_task_file "$task_id")
    [[ ! -f "$state_file" ]] && return 1

    cat "$state_file" 2>/dev/null
    return 0
}

# List all active task states
aria_task_list() {
    local count=0
    for state_file in /tmp/aria-task-*.json; do
        if [[ -f "$state_file" ]]; then
            local task_id=$(jq -r '.task_id // ""' "$state_file" 2>/dev/null)
            local attempt=$(jq -r '.attempt_count // 0' "$state_file" 2>/dev/null)
            local tier=$(jq -r '.model_tier // 1' "$state_file" 2>/dev/null)
            local desc=$(jq -r '.task_desc // ""' "$state_file" 2>/dev/null | cut -c1-50)

            printf "%-8s | Attempts: %d | Tier: %d | %s\n" "$task_id" "$attempt" "$tier" "$desc"
            ((count++))
        fi
    done

    if [[ $count -eq 0 ]]; then
        echo "No active task states"
    fi
    return 0
}
