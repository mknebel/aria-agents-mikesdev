# ARIA Task State Management (`aria-task-state.sh`)

Per-task state tracking for retry/escalation logic, complementing the session-level `aria-state.sh`.

## Overview

- **Purpose**: Track individual task execution state across retries with model escalation
- **State Files**: `/tmp/aria-task-[TASK_HASH].json` (8-char SHA256 hash of task description)
- **Concurrency**: flock-protected reads/writes for safe parallel access
- **Integration**: Designed to work with ARIA retry/escalation workflow

## Quick Start

```bash
# Source the script
source /home/mike/.claude/scripts/aria-task-state.sh

# Initialize a task
task_id=$(aria_task_init "Generate database migration")
# Output: abc12345

# Track attempts and failures
attempt=$(aria_task_increment_attempt "$task_id")
# Output: 1

aria_task_record_failure "$task_id" "Timeout after 30s"

# Get failure context for LLM prompt injection
context=$(aria_task_get_failure_context "$task_id")
# Output:
# Previous failures:
#   Attempt 1 (model: codex-mini): Timeout after 30s

# Escalate to next model tier on persistent failures
new_tier=$(aria_task_escalate "$task_id" "Model exhausted")
# Output: 2

# On success, clean up task state
aria_task_cleanup "$task_id"
```

## API Reference

### aria_task_init(task_desc) -> task_id

Initialize a new task and create state file.

**Arguments:**
- `task_desc` (string): Description of the task

**Returns:**
- stdout: 8-character task ID (first 8 chars of SHA256 hash)
- exit code: 0 on success, 1 on error

**Example:**
```bash
task_id=$(aria_task_init "Build authentication system")
```

**State File Created:**
```json
{
  "task_id": "abc12345",
  "task_desc": "Build authentication system",
  "attempt_count": 0,
  "model_tier": 1,
  "created_at": "1765014774",
  "failures": [],
  "escalation_log": [],
  "quality_gate_results": []
}
```

---

### aria_task_get(task_id, field) -> value

Read a field from task state.

**Arguments:**
- `task_id` (string): 8-char task ID
- `field` (string): JSON field path (e.g., "attempt_count", "model_tier", "custom_field")

**Returns:**
- stdout: Field value or empty string if not found
- exit code: 0 on success, 1 if task not found

**Example:**
```bash
count=$(aria_task_get "$task_id" "attempt_count")
tier=$(aria_task_get "$task_id" "model_tier")
```

---

### aria_task_set(task_id, field, value)

Set a field in task state (with locking for concurrent access).

**Arguments:**
- `task_id` (string): 8-char task ID
- `field` (string): JSON field path
- `value` (string or int): New value

**Returns:**
- exit code: 0 on success, 1 on error

**Example:**
```bash
aria_task_set "$task_id" "model_tier" 3
aria_task_set "$task_id" "custom_tag" "high_priority"
```

---

### aria_task_increment_attempt(task_id) -> count

Increment attempt counter (with locking).

**Arguments:**
- `task_id` (string): 8-char task ID

**Returns:**
- stdout: New attempt count
- exit code: 0 on success, 1 on error

**Example:**
```bash
attempt=$(aria_task_increment_attempt "$task_id")
echo "This is attempt #$attempt"
```

---

### aria_task_get_tier(task_id) -> tier

Get current model tier (1-7).

**Arguments:**
- `task_id` (string): 8-char task ID

**Returns:**
- stdout: Tier number (1-7)
- exit code: 0 on success, 1 on error

**Tier Mapping:**
```
1 = codex-mini
2 = gpt-5.1
3 = codex
4 = codex-max
5 = claude-haiku
6 = claude-opus
7 = aria-thinking
```

**Example:**
```bash
tier=$(aria_task_get_tier "$task_id")
case $tier in
    1) model="codex-mini" ;;
    2) model="gpt-5.1" ;;
    3) model="codex" ;;
esac
echo "Attempting with $model..."
```

---

### aria_task_escalate(task_id, reason) -> new_tier

Escalate task to next higher model tier and log the reason.

**Arguments:**
- `task_id` (string): 8-char task ID
- `reason` (string): Reason for escalation

**Returns:**
- stdout: New tier (1-7, capped at 7)
- exit code: 0 on success, 1 on error

**Side Effects:**
- Increments `model_tier` by 1 (max 7)
- Appends entry to `escalation_log` with timestamp, reason, from/to tiers

**Example:**
```bash
new_tier=$(aria_task_escalate "$task_id" "codex-mini timeout")
if [[ $new_tier -lt 7 ]]; then
    echo "Escalated to tier $new_tier, retrying..."
else
    echo "Already at max tier 7 (aria-thinking), giving up"
fi
```

---

### aria_task_record_failure(task_id, error_summary)

Record a failure for the current attempt.

**Arguments:**
- `task_id` (string): 8-char task ID
- `error_summary` (string): Error message/summary

**Returns:**
- exit code: 0 on success, 1 on error

**Side Effects:**
- Appends entry to `failures[]` with:
  - `attempt`: Current attempt count
  - `error`: Error message
  - `model`: Model name at current tier
  - `timestamp`: Unix timestamp

**Example:**
```bash
if [[ $? -ne 0 ]]; then
    aria_task_record_failure "$task_id" "Command failed: $RESULT"
fi
```

---

### aria_task_get_failure_context(task_id) -> formatted_string

Get all recorded failures formatted for LLM prompt injection.

**Arguments:**
- `task_id` (string): 8-char task ID

**Returns:**
- stdout: Formatted multi-line string (empty if no failures)
- exit code: 0

**Output Format:**
```
Previous failures:
  Attempt 1 (model: codex-mini): Timeout after 30s
  Attempt 2 (model: gpt-5.1): Rate limit exceeded
```

**Example:**
```bash
context=$(aria_task_get_failure_context "$task_id")
if [[ -n "$context" ]]; then
    # Inject into LLM prompt for context
    prompt="$prompt

$context

Please address the previous failures and try again."
fi
```

---

### aria_task_cleanup(task_id)

Remove task state file and lock file (call on success).

**Arguments:**
- `task_id` (string): 8-char task ID

**Returns:**
- exit code: 0

**Example:**
```bash
if aria_my_task "$task_id"; then
    aria_task_cleanup "$task_id"
fi
```

---

### aria_task_state(task_id) -> json

Get full task state as JSON (for debugging/inspection).

**Arguments:**
- `task_id` (string): 8-char task ID

**Returns:**
- stdout: Full JSON state object
- exit code: 0 on success, 1 if task not found

**Example:**
```bash
aria_task_state "$task_id" | jq '.failures | length'
```

---

### aria_task_list()

List all active task states (debugging utility).

**Returns:**
- stdout: Formatted table of active tasks
- exit code: 0

**Example:**
```bash
aria_task_list
# Output:
# abc12345 | Attempts: 3 | Tier: 2 | Build user authentication syst
# def67890 | Attempts: 1 | Tier: 1 | Generate database migration
# No active task states
```

---

## Usage Patterns

### Basic Retry Loop with Escalation

```bash
#!/bin/bash
source /home/mike/.claude/scripts/aria-task-state.sh

task_id=$(aria_task_init "Generate API schema")

max_tiers=7
while true; do
    tier=$(aria_task_get_tier "$task_id")
    [[ $tier -gt $max_tiers ]] && break

    attempt=$(aria_task_increment_attempt "$task_id")
    echo "Attempt $attempt (tier $tier)"

    # Execute task
    if aria_codex "Generate schema..." > /tmp/output.txt 2>&1; then
        echo "Success!"
        aria_task_cleanup "$task_id"
        exit 0
    else
        error=$(cat /tmp/output.txt)
        aria_task_record_failure "$task_id" "$error"

        # Don't escalate on first attempt
        if [[ $attempt -gt 1 ]]; then
            aria_task_escalate "$task_id" "Attempt $attempt failed"
        fi
    fi
done

echo "Task exhausted all tiers"
aria_task_cleanup "$task_id"
exit 1
```

### LLM Prompt with Failure Context

```bash
source /home/mike/.claude/scripts/aria-task-state.sh

task_id=$(aria_task_init "Refactor authentication module")

# On retry, inject failure context
if [[ -n "$(aria_task_get_failure_context "$task_id")" ]]; then
    context=$(aria_task_get_failure_context "$task_id")
    prompt="$prompt

$context

Given the above failures, please try a different approach."
fi

codex "$prompt"
```

### Monitoring Task Progress

```bash
source /home/mike/.claude/scripts/aria-task-state.sh

# Show all active tasks with their state
aria_task_list

# Get detailed info on a specific task
task_id="abc12345"
echo "Task: $(aria_task_get "$task_id" "task_desc")"
echo "Attempts: $(aria_task_get "$task_id" "attempt_count")"
echo "Tier: $(aria_task_get "$task_id" "model_tier")"
echo "Failures:"
aria_task_get_failure_context "$task_id"
```

---

## State File Structure

```json
{
  "task_id": "abc12345",
  "task_desc": "Description of the task",
  "attempt_count": 3,
  "model_tier": 2,
  "created_at": "1765014774",
  "failures": [
    {
      "attempt": 1,
      "error": "Timeout after 30 seconds",
      "model": "codex-mini",
      "timestamp": "1765014775"
    },
    {
      "attempt": 2,
      "error": "Out of memory",
      "model": "codex-mini",
      "timestamp": "1765014780"
    }
  ],
  "escalation_log": [
    {
      "timestamp": "1765014780",
      "reason": "codex-mini exhausted",
      "from_tier": 1,
      "to_tier": 2
    }
  ],
  "quality_gate_results": []
}
```

---

## Implementation Details

### Concurrency & Locking

- Uses `flock` for atomic read-modify-write operations
- Lock files: `/tmp/aria-task-[TASK_HASH].lock`
- Non-blocking (grace: `|| true`), compatible with parallel bash subshells

### File Management

- State files: `/tmp/aria-task-[TASK_HASH].json`
- Hash: First 8 chars of `sha256sum` of task description
- Same task description always generates same task_id (idempotent)

### JSON Manipulation

- All JSON operations via `jq` (robust, portable)
- Proper escaping for shell special characters
- Empty field access returns empty string (jq `// empty`)

### Error Handling

- All functions return 0 on success, 1 on error
- All stderr output suppressed (`2>/dev/null`)
- Graceful fallbacks (uninitialized fields default to sensible values)

---

## Testing

Run the comprehensive test suite:

```bash
/home/mike/.claude/scripts/aria-task-state-tests.sh
```

Tests cover:
- Task initialization
- Attempt tracking
- Failure recording and context
- Model tier escalation
- Concurrent access (5+ parallel operations)
- Custom field read/write
- Cleanup

---

## Integration with ARIA Workflow

This module is designed to work with the broader ARIA retry/escalation system:

1. **aria-state.sh**: Session-level tracking (reads, writes, model usage)
2. **aria-task-state.sh**: Per-task tracking (attempts, escalations, failures)
3. **aria-thinking**: When task exhausts all tiers or requires complex reasoning

Example integration:

```bash
source /home/mike/.claude/scripts/aria-state.sh
source /home/mike/.claude/scripts/aria-task-state.sh

task_id=$(aria_task_init "Complex refactoring")
aria_inc "tasks"  # Track in session stats

while [[ $(aria_task_get_tier "$task_id") -lt 7 ]]; do
    attempt=$(aria_task_increment_attempt "$task_id")

    if my_codex_task "$task_id"; then
        aria_inc "tool_success"
        aria_task_cleanup "$task_id"
        break
    else
        aria_inc "tool_fail"
        aria_task_record_failure "$task_id" "$error"
        aria_task_escalate "$task_id" "Tier attempt failed"
    fi
done
```

---

## Troubleshooting

### Task State File Not Found

```bash
# Check if task_id is correct
aria_task_list

# Verify file exists
ls -la /tmp/aria-task-abc12345.json
```

### Concurrent Access Issues

Files are flock-protected. If issues persist:

```bash
# Remove stale lock files
rm /tmp/aria-task-*.lock

# Check file permissions
ls -la /tmp/aria-task-*.json
```

### JSON Parse Errors

```bash
# Validate task state JSON
aria_task_state "abc12345" | jq .

# View raw file (should be valid JSON)
cat /tmp/aria-task-abc12345.json | jq .
```

---

## Performance Notes

- **Read**: O(1) - single jq field extraction
- **Write**: O(1) - atomic jq update with locking
- **Concurrent**: Safe for 10+ parallel operations (flock serializes writes)
- **Cleanup**: O(1) - single file deletion

State files are typically <5KB and suitable for /tmp.

---

## See Also

- `/home/mike/.claude/scripts/aria-state.sh` - Session state tracking
- `/home/mike/.claude/scripts/aria-task-state-tests.sh` - Test suite
- ARIA retry/escalation workflow documentation
