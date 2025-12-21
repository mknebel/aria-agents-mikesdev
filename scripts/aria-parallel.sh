#!/bin/bash
# ARIA Parallel Routing - Execute multiple ARIA tasks simultaneously
# Usage: aria-parallel.sh "task1_type:prompt1" "task2_type:prompt2" ...

source ~/.claude/scripts/aria-state.sh 2>/dev/null
source ~/.claude/scripts/aria-route.sh 2>/dev/null

# Parse task format: "type:prompt"
parse_task() {
    local task="$1"
    local type="${task%%:*}"
    local prompt="${task#*:}"
    echo "$type|$prompt"
}

# Execute single task in background
execute_task() {
    local task_id="$1"
    local type="$2"
    local prompt="$3"
    local output_file="/tmp/aria_parallel_${task_id}.out"

    aria_route "$type" "$prompt" > "$output_file" 2>&1
    echo "$?" > "/tmp/aria_parallel_${task_id}.exit"
}

# Main parallel execution
main() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: aria-parallel.sh 'type1:prompt1' 'type2:prompt2' ..."
        echo "Example: aria-parallel.sh 'context:find X' 'context:find Y'"
        exit 1
    fi

    local pids=()
    local task_ids=()
    local start_time=$(date +%s)

    echo "Starting $# parallel ARIA tasks..."
    echo ""

    # Launch all tasks in parallel
    for i in $(seq 1 $#); do
        local task="${!i}"
        local parsed=$(parse_task "$task")
        local type=$(echo "$parsed" | cut -d'|' -f1)
        local prompt=$(echo "$parsed" | cut -d'|' -f2-)
        local task_id="task_${i}_$$"

        echo "[$i] Launching: $type - $(echo "$prompt" | cut -c1-50)..."

        execute_task "$task_id" "$type" "$prompt" &
        pids+=($!)
        task_ids+=("$task_id")
    done

    echo ""
    echo "Waiting for all tasks to complete..."
    echo ""

    # Wait for all tasks
    local failed=0
    for i in "${!pids[@]}"; do
        wait "${pids[$i]}"
        local task_id="${task_ids[$i]}"
        local exit_code=$(cat "/tmp/aria_parallel_${task_id}.exit" 2>/dev/null || echo "1")

        if [[ "$exit_code" == "0" ]]; then
            echo "✓ Task $((i+1)) completed successfully"
        else
            echo "✗ Task $((i+1)) failed (exit code: $exit_code)"
            ((failed++))
        fi

        # Show output
        if [[ -f "/tmp/aria_parallel_${task_id}.out" ]]; then
            echo "Output:"
            cat "/tmp/aria_parallel_${task_id}.out" | head -10
            echo ""
        fi
    done

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo ""
    echo "═══════════════════════════════════════"
    echo "Parallel Execution Complete"
    echo "Total tasks: $#"
    echo "Successful: $(($# - failed))"
    echo "Failed: $failed"
    echo "Duration: ${duration}s"
    echo "═══════════════════════════════════════"

    # Cleanup
    for task_id in "${task_ids[@]}"; do
        rm -f "/tmp/aria_parallel_${task_id}.out" "/tmp/aria_parallel_${task_id}.exit"
    done

    return $failed
}

main "$@"
