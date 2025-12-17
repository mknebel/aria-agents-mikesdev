# ARIA Iteration Breaker - Loop Detection and Circuit Breaker

A production-ready loop detection and circuit breaker system that prevents infinite retry cycles in ARIA task routing. Detects patterns where tasks fail repeatedly with the same error, waste tokens, and never progress.

## Problem Being Solved

Tasks sometimes fail repeatedly with minimal changes between attempts:

```
Attempt 1: TypeError: Cannot read property 'map' of undefined
Attempt 2: [Added null check] TypeError: Cannot read property 'map' of undefined
Attempt 3: [Changed to optional chaining] TypeError: Cannot read property 'map' of undefined
Attempt 4: [Rewritten logic] TypeError: Cannot read property 'map' of undefined
```

This pattern wastes tokens, frustrates users, and prevents escalation to more capable models. The iteration breaker detects these patterns and forces action:

1. **Loop Detection** - Identifies when you're stuck in a pattern
2. **Smart Escalation** - Jumps 2 tiers to skip ineffective middle tier
3. **Circuit Breaking** - Halts execution and flags for human review
4. **Pattern Analysis** - Generates actionable insights about what's failing

## Architecture

### Core Files

**`aria-iteration-breaker.sh`** (24KB)
- Main loop detection and circuit breaker engine
- CLI interface for all operations
- Full task state analysis
- Human-readable summary generation

**`aria-iteration-integration.sh`** (3.8KB)
- Integration hooks for `aria-smart-route.sh`
- Pre-check and post-failure hooks
- Auto-action based on pattern type

### Integration Points

```
aria-smart-route.sh
    ↓
    [after each failure]
    ↓
aria_smart_route_check_loop()
    ↓
    [loop detected?] → aria_force_escalate() or aria_circuit_break()
```

## Loop Detection Criteria

The breaker detects loops using three mechanisms:

### 1. Repeated Error Pattern (Threshold: 2+ occurrences)

```bash
# Same error appearing multiple times = loop
aria_loop_check task_id
# Returns 0 if loop, 1 if not
```

**Detection:**
- Exact match: `"TypeError: Cannot read property 'map' of undefined"` == `"TypeError: Cannot read property 'map' of undefined"`
- Fuzzy match: Same error type prefix match or significant string overlap (80%+)
- Example: `"TypeError: ..."` matches `"TypeError: ..."`

### 2. Stuck Tier Pattern (Threshold: 3+ attempts)

When a task has made multiple attempts without advancing to a higher tier, it's likely stuck:

```bash
# 3+ failures with no escalation = stuck tier
Attempt 1: Tier 2 - Failed
Attempt 2: Tier 2 - Failed
Attempt 3: Tier 2 - Failed
# LOOP DETECTED: stuck_tier
```

### 3. Quality Gate Loop (Threshold: 2+ same check failures)

When the quality gate fails on the same check repeatedly:

```bash
# Same QG check failing repeatedly
Attempt 1: lint error on line 45
Attempt 2: lint error on line 45 (different code)
# LOOP DETECTED: quality_gate_loop
```

## Commands

### Check for Loop

```bash
aria-iteration-breaker.sh check <task_id>
```

**Returns:**
- `0` - Loop detected
- `1` - No loop

**Example:**
```bash
$ aria-iteration-breaker.sh check abc12345
🔄 Loop detected: Same error appearing 3 times
```

### Analyze Loop Pattern

```bash
aria-iteration-breaker.sh analyze <task_id>
```

**Output:** JSON with:
- `pattern_type`: "repeated_error", "stuck_tier", or "quality_gate_loop"
- `attempt_count`: Total attempts made
- `current_tier`: Current model tier (1-7)
- `repeated_error_count`: How many times same error appears
- `latest_error`: The repeated error message
- `suggested_action`: Recommended next step

**Example:**
```bash
$ aria-iteration-breaker.sh analyze abc12345 | jq .
{
  "task_id": "abc12345",
  "pattern_type": "repeated_error",
  "attempt_count": 4,
  "current_tier": 2,
  "repeated_error_count": 4,
  "latest_error": "TypeError: Cannot read property 'map' of undefined",
  "suggested_action": "Force escalate 2 tiers (skip ineffective middle tier)"
}
```

### Force Escalate (2-tier jump)

```bash
aria-iteration-breaker.sh force-escalate <task_id> [reason]
```

**Behavior:**
- Jumps 2 tiers (skips ineffective middle tier)
- Logs escalation with reason
- If at max tier → returns `HUMAN_INTERVENTION_REQUIRED`

**Example:**
```bash
$ aria-iteration-breaker.sh force-escalate abc12345 "Repeated error at tier 2"
✓ Escalated to tier 4
```

### Circuit Break (Full Stop)

```bash
aria-iteration-breaker.sh break <task_id> [reason]
```

**Actions:**
1. Marks task as "blocked"
2. Generates human-readable summary file
3. Adds to blocked tasks registry
4. Outputs summary to console

**Example:**
```bash
$ aria-iteration-breaker.sh break abc12345 "Fundamental code issue"
# Outputs detailed summary file with analysis
```

### Show All Blocked Tasks

```bash
aria-iteration-breaker.sh status
```

**Output:**
```
ARIA Iteration Breaker Status
═════════════════════════════════════════════════════════════════════════════
Blocked Tasks: 3
───────────────────────────────────────────────────────────────────────────────
abc12345  | Attempts: 4  | Tier: 2  | Pattern: repeated_error
def67890  | Attempts: 5  | Tier: 3  | Pattern: stuck_tier
ghi11111  | Attempts: 6  | Tier: 2  | Pattern: quality_gate_loop

Summary files in: /tmp/aria-blocked-tasks
```

### Clean Up Blocked Task

```bash
aria-iteration-breaker.sh cleanup <task_id>
```

**Actions:**
- Removes task from blocked registry
- Deletes summary files
- Removes task state

## Integration with aria-smart-route.sh

### Option 1: Manual Integration

In `aria-smart-route.sh`, after failed attempts:

```bash
# After each failure
if ! _aria_smart_verify_task "$task_type" "$task_id" "$output_file"; then
    # Check for loops
    if aria_loop_check "$task_id"; then
        # Loop detected - analyze
        local analysis=$(aria_loop_analyze "$task_id")

        # Force escalate or circuit break
        if [[ $(echo "$analysis" | jq -r '.current_tier') -lt 6 ]]; then
            aria_force_escalate "$task_id" "Loop detected"
            continue  # Retry with new tier
        else
            aria_circuit_break "$task_id" "Loop at max tier"
            break  # Stop and surface to user
        fi
    fi
fi
```

### Option 2: Use Integration Hook

In `aria-smart-route.sh`:

```bash
# At top of script
source ~/.claude/scripts/aria-iteration-integration.sh

# Before retry loop
aria_smart_route_pre_check "$task_id" || {
    _aria_smart_log ERROR "Task is blocked"
    return 1
}

# In retry loop, after failure
if ! _aria_smart_verify_task "$task_type" "$task_id" "$output_file"; then
    aria_smart_route_check_loop "$task_id" || break  # Break on circuit
fi
```

## Output Examples

### Blocked Task Summary

When circuit breaker activates, generates a human-readable file:

```
═══════════════════════════════════════════════════════════════════════════════
ARIA ITERATION BREAKER - TASK BLOCKED
═══════════════════════════════════════════════════════════════════════════════

Task ID: abc12345
Blocked At: 2025-12-06 04:15:32

Task Description:
  Implement React component with data fetching

Loop Pattern: repeated_error
Attempts: 4
Current Tier: 2
Blocked Reason: Same error appearing 4 times

═══════════════════════════════════════════════════════════════════════════════
REPEATED ERROR
═══════════════════════════════════════════════════════════════════════════════

TypeError: Cannot read property 'map' of undefined

═══════════════════════════════════════════════════════════════════════════════
SUGGESTED ACTION
═══════════════════════════════════════════════════════════════════════════════

Force escalate 2 tiers (skip ineffective middle tier)

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
   aria-iteration-breaker.sh cleanup abc12345

═══════════════════════════════════════════════════════════════════════════════
```

## Logging

All operations logged to: `/tmp/claude_vars/aria-iteration-breaker.log`

View recent activity:
```bash
aria-iteration-breaker.sh log
# Or directly
tail -50 /tmp/claude_vars/aria-iteration-breaker.log
```

## State Storage

### Task Analysis State
- Location: `/tmp/aria-task-{TASK_HASH}.json`
- Managed by: `aria-task-state.sh`
- Contains: Failure history, escalations, attempt count, tier progression

### Blocked Tasks Registry
- Location: `/tmp/aria-blocked-tasks/blocked.json`
- Contains: All tasks blocked by circuit breaker
- Summaries: `/tmp/aria-blocked-tasks/{task_id}-summary.txt`

### Logs
- Location: `/tmp/claude_vars/aria-iteration-breaker.log`
- Format: `[TIMESTAMP] [LEVEL] message`

## Configuration

### Tuning Thresholds

Edit constants at top of `aria-iteration-breaker.sh`:

```bash
LOOP_SAME_ERROR_COUNT=2           # Same error N times = loop
LOOP_NO_TIER_CHANGE_ATTEMPTS=3    # N attempts without escalation = stuck
LOOP_QG_FAIL_REPEAT=2             # QG check failing N times = loop
```

**Recommendations:**
- Decrease `LOOP_SAME_ERROR_COUNT` to detect loops faster (more aggressive)
- Increase to detect only obvious loops (more conservative)
- `LOOP_NO_TIER_CHANGE_ATTEMPTS=3` is standard for most workflows

### Debug Mode

```bash
export ARIA_BREAKER_DEBUG=1
aria-iteration-breaker.sh check abc12345
```

## Implementation Notes

### Error Similarity Matching

Uses multi-level fuzzy matching:

1. **Exact match** - Identical strings (fastest)
2. **Prefix match** - Same first 50 characters (good for structured errors)
3. **Contains match** - One string contains the other (variations)
4. **Error type match** - Same error type prefix (e.g., "TypeError:")

This avoids false positives when error message varies slightly but is fundamentally the same.

### Tier Escalation Logic

**Normal escalation:** +1 tier
**Forced escalation:** +2 tiers (circuit breaker's aggressive action)

| Tier | Model | Use Case |
|------|-------|----------|
| 1 | codex-mini | Fast/cheap baseline |
| 2 | gpt-5.1 | General purpose |
| 3 | codex | Code-optimized |
| 4 | codex-max | Flagship, deep reasoning |
| 5 | claude-haiku | File operations |
| 6 | claude-opus | Complex analysis |
| 7 | aria-thinking | Last resort |

At tier 6+, circuit breaker requests human intervention rather than further escalation.

### Thread Safety

All state mutations use file locking to prevent concurrent access issues:

```bash
(
    flock -x 200 2>/dev/null || true
    # [atomic update]
) 200>"$lock_file"
```

## Use Cases

### Case 1: Same Error Keeps Appearing

```bash
Task: Build React component
Attempt 1 (Tier 2): TypeError: Cannot read property 'map'
Attempt 2 (Tier 2): [Added null check] TypeError: Cannot read property 'map'
Attempt 3 (Tier 2): [Changed logic] TypeError: Cannot read property 'map'
Attempt 4 (Tier 2): [Rewritten] TypeError: Cannot read property 'map'

# Breaker detects: repeated_error at tier 2
# Action: Force escalate to tier 4
# Result: Tier 4 model identifies root cause with fresh perspective
```

### Case 2: Quality Gate Keeps Failing

```bash
Task: Add feature with tests
Attempt 1 (Tier 2): lint error on line 45
Attempt 2 (Tier 2): [Fixed line 45] lint error on line 48
Attempt 3 (Tier 2): [Fixed line 48] lint error on line 45

# Breaker detects: quality_gate_loop
# Action: Circuit break - QG issue is fundamental
# Result: Human reviews to fix underlying linting config
```

### Case 3: Making No Progress

```bash
Task: Refactor database
Attempt 1 (Tier 2): Failed (new error each time)
Attempt 2 (Tier 2): Failed (different error)
Attempt 3 (Tier 2): Failed (yet another error)

# Breaker detects: stuck_tier (3 attempts, no escalation, no tier change)
# Action: Force escalate to tier 4
# Result: More capable model solves multi-step problem
```

## Troubleshooting

### Too Many False Positives

Increase `LOOP_SAME_ERROR_COUNT`:
```bash
sed -i 's/LOOP_SAME_ERROR_COUNT=2/LOOP_SAME_ERROR_COUNT=3/' \
    ~/.claude/scripts/aria-iteration-breaker.sh
```

### Not Detecting Obvious Loops

Enable debug:
```bash
export ARIA_BREAKER_DEBUG=1
aria-iteration-breaker.sh check abc12345
# Will show detailed matching logic
```

### Task Won't Be Cleaned Up

```bash
# Force cleanup even if blocked
aria-iteration-breaker.sh cleanup abc12345

# Verify removal
aria-iteration-breaker.sh status
```

## Performance Impact

- **Check operation:** <1ms (JSON parsing only)
- **Analyze operation:** <5ms (loops through failure history)
- **Escalate operation:** <10ms (file lock + JSON update)
- **Break operation:** <50ms (generates summary file)

No impact on normal task execution. Only runs on failure paths.

## Future Enhancements

Potential improvements (not yet implemented):

1. **Pattern Learning** - Track which escalations fix which patterns
2. **Adaptive Thresholds** - Adjust based on historical success
3. **Cross-task Patterns** - Detect if multiple tasks are stuck on same issue
4. **Automatic Recovery** - Auto-restart with human-suggested fixes
5. **Metrics Dashboard** - Track loop stats and success rates
6. **Integration with Opus** - Async human review queue

## See Also

- `aria-task-state.sh` - Task state management
- `aria-smart-route.sh` - Smart routing with retry logic
- `aria-config.sh` - ARIA configuration
- `quality-gate.sh` - Code quality verification
