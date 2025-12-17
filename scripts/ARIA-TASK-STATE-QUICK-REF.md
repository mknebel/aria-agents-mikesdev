# ARIA Task State - Quick Reference

**Location:** `/home/mike/.claude/scripts/aria-task-state.sh`
**Source it:** `source /home/mike/.claude/scripts/aria-task-state.sh`

## One-Liner Examples

```bash
# Initialize task
task_id=$(aria_task_init "Your task description here")

# Track attempts
attempt=$(aria_task_increment_attempt "$task_id")

# Record failures
aria_task_record_failure "$task_id" "Error message"

# Get failure context (for LLM prompt injection)
context=$(aria_task_get_failure_context "$task_id")

# Escalate to next tier
new_tier=$(aria_task_escalate "$task_id" "Reason for escalation")

# Get current tier (1-7)
tier=$(aria_task_get_tier "$task_id")

# Set/get arbitrary fields
aria_task_set "$task_id" "field_name" "value"
value=$(aria_task_get "$task_id" "field_name")

# View full state (JSON)
aria_task_state "$task_id" | jq .

# List all active tasks
aria_task_list

# Clean up on success
aria_task_cleanup "$task_id"
```

## Tier Levels (1-7)

| Tier | Model | Purpose |
|------|-------|---------|
| 1 | codex-mini | Fast, simple tasks |
| 2 | gpt-5.1 | General tasks |
| 3 | codex | Code generation |
| 4 | codex-max | Complex code problems |
| 5 | claude-haiku | When code fails, try Haiku |
| 6 | claude-opus | Complex reasoning |
| 7 | aria-thinking | Maximum capability (expensive) |

## Typical Workflow

```bash
source /home/mike/.claude/scripts/aria-task-state.sh

# Setup
task_id=$(aria_task_init "Build feature X")

# Retry loop
while [[ $(aria_task_get_tier "$task_id") -le 7 ]]; do
    # Track attempt
    attempt=$(aria_task_increment_attempt "$task_id")
    tier=$(aria_task_get_tier "$task_id")

    # Execute task
    if my_code_gen_function "$task_id"; then
        aria_task_cleanup "$task_id"
        exit 0
    fi

    # Record failure
    aria_task_record_failure "$task_id" "$error_msg"

    # Escalate if multiple failures
    if [[ $attempt -gt 1 ]]; then
        aria_task_escalate "$task_id" "Attempt $attempt failed"
    fi
done

echo "Task exhausted all tiers"
exit 1
```

## LLM Prompt Injection with Context

```bash
# Get previous failures to inform next attempt
failure_context=$(aria_task_get_failure_context "$task_id")

# Build prompt with context
if [[ -n "$failure_context" ]]; then
    prompt="$base_prompt

$failure_context

Please try a different approach to address the above issues."
fi

# Send to LLM at appropriate tier
codex "$prompt"
```

## Debugging

```bash
# List all active tasks
aria_task_list

# View specific task state
aria_task_state "abc12345" | jq .

# Get failure history
aria_task_get_failure_context "abc12345"

# Check current tier
aria_task_get_tier "abc12345"

# Check attempt count
aria_task_get "$abc12345" "attempt_count"
```

## File Locations

- **State files:** `/tmp/aria-task-[TASK_HASH].json`
- **Lock files:** `/tmp/aria-task-[TASK_HASH].lock`
- **Task hash:** First 8 chars of SHA256(task_description)

## All Functions

```
aria_task_init(desc)              → task_id
aria_task_get(id, field)          → value
aria_task_set(id, field, value)   → (0 success)
aria_task_increment_attempt(id)   → count
aria_task_get_tier(id)            → tier (1-7)
aria_task_escalate(id, reason)    → new_tier
aria_task_record_failure(id, err) → (0 success)
aria_task_get_failure_context(id) → formatted_string
aria_task_cleanup(id)             → (0 success)
aria_task_state(id)               → json
aria_task_list()                  → formatted_table
```

## Return Values

- **Functions returning stdout**: `aria_task_init`, `aria_task_get`, `aria_task_increment_attempt`, `aria_task_get_tier`, `aria_task_escalate`, `aria_task_get_failure_context`, `aria_task_state`, `aria_task_list`
- **Functions returning exit code only**: `aria_task_set`, `aria_task_record_failure`, `aria_task_cleanup`
- **Exit codes**: 0 = success, 1 = error (task not found, etc.)

## State File Structure

```json
{
  "task_id": "abc12345",
  "task_desc": "...",
  "attempt_count": 3,
  "model_tier": 2,
  "created_at": "1765014774",
  "failures": [
    {"attempt": 1, "error": "...", "model": "...", "timestamp": "..."}
  ],
  "escalation_log": [
    {"timestamp": "...", "reason": "...", "from_tier": 1, "to_tier": 2}
  ],
  "quality_gate_results": []
}
```

## Concurrency & Safety

- All write operations use `flock` for atomic, thread-safe updates
- Safe for 10+ parallel operations on same task
- Lock files automatically cleaned up with `aria_task_cleanup`

## Integration with Other ARIA Tools

- Works alongside `aria-state.sh` (session-level tracking)
- Designed for ARIA retry/escalation workflow
- When task hits tier 7 (aria-thinking) or needs complex reasoning, escalate to full analysis

## Full Documentation

See `/home/mike/.claude/scripts/ARIA-TASK-STATE.md` for complete API, patterns, and examples.
