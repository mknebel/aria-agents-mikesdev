# ARIA Iteration Breaker - Quick Start Guide

## What It Does

Prevents infinite token-wasting loops when ARIA tasks fail repeatedly with the same error.

**Before:**
```
Attempt 1-4: Same TypeError repeating
Attempt 5: Still same error
Attempt 6: Finally gives up ❌ Wasted tokens
```

**After:**
```
Attempt 1: Failure detected
Attempt 2: Same error repeating
Attempt 3: Loop detected! → Force escalate to stronger model ✓
```

## Installation

Already installed! The scripts are in:
- `/home/mike/.claude/scripts/aria-iteration-breaker.sh` (main engine)
- `/home/mike/.claude/scripts/aria-iteration-integration.sh` (smart-route hook)

## 30-Second Tutorial

### Check if a task is stuck

```bash
aria-iteration-breaker.sh check abc12345
# Returns: 0 if loop detected, 1 if not
```

### Get detailed analysis (JSON)

```bash
aria-iteration-breaker.sh analyze abc12345 | jq .
# Shows pattern, attempts, suggested action
```

### Force escalation (2-tier jump)

```bash
aria-iteration-breaker.sh force-escalate abc12345 "Same error 3 times"
# Escalates from tier 2 to tier 4, skipping ineffective tier 3
```

### Stop task and flag for human review

```bash
aria-iteration-breaker.sh break abc12345 "Fundamental issue"
# Generates human-readable summary file
# Adds to blocked tasks registry
```

### View all blocked tasks

```bash
aria-iteration-breaker.sh status
# Shows all blocked tasks and their patterns
```

### Clean up a blocked task

```bash
aria-iteration-breaker.sh cleanup abc12345
# Remove from blocked registry and task state
```

## Common Patterns It Detects

### 1. Repeated Error Loop
```
TypeError: Cannot read property 'map' of undefined
[Fix 1 applied]
TypeError: Cannot read property 'map' of undefined
[Fix 2 applied]
TypeError: Cannot read property 'map' of undefined
```
**Action:** Force escalate 2 tiers

### 2. Stuck at Same Tier
```
3+ failures with no model tier change
```
**Action:** Escalate to higher tier

### 3. Quality Gate Loop
```
Lint error on same line repeating
```
**Action:** Circuit break - requires human fix

## Integration with aria-smart-route.sh

The breaker is automatically called when tasks fail. Manual integration:

```bash
# In your retry loop:
if aria_loop_check "$task_id"; then
    analysis=$(aria_loop_analyze "$task_id")

    # Auto-escalate or circuit-break based on pattern
    if [[ $(echo "$analysis" | jq -r '.current_tier') -lt 6 ]]; then
        aria_force_escalate "$task_id" "Loop detected"
    else
        aria_circuit_break "$task_id" "Loop at max tier"
        break
    fi
fi
```

## Output Examples

### Analysis Output (JSON)
```json
{
  "task_id": "abc12345",
  "pattern_type": "repeated_error",
  "attempt_count": 4,
  "current_tier": 2,
  "repeated_error_count": 4,
  "latest_error": "TypeError: Cannot read property 'map'",
  "suggested_action": "Force escalate 2 tiers"
}
```

### Summary File (Human Review)
```
═════════════════════════════════════════════════════════════
ARIA ITERATION BREAKER - TASK BLOCKED
═════════════════════════════════════════════════════════════

Task ID: abc12345
Attempts: 4
Pattern: repeated_error
Tier: 2

Repeated Error:
  TypeError: Cannot read property 'map' of undefined

Suggested Action:
  Force escalate 2 tiers

Next Steps:
  1. Review error and task description
  2. Fix underlying code issue or escalate to human
  3. When ready: aria-iteration-breaker.sh cleanup abc12345
```

## Real-World Workflow

### Scenario: Code generation keeps failing with same error

```bash
# Task is running and failing...
# (Task attempts: 1, 2, 3 with same TypeError)

# Check status
$ aria-iteration-breaker.sh status
No blocked tasks yet... (it's still trying)

# After 3-4 failed attempts, user checks
$ aria-iteration-breaker.sh analyze d8f3a2b1
{
  "task_id": "d8f3a2b1",
  "pattern_type": "repeated_error",
  "attempt_count": 4,
  "current_tier": 2,
  "repeated_error_count": 4,
  "suggested_action": "Force escalate 2 tiers"
}

# User forces escalation
$ aria-iteration-breaker.sh force-escalate d8f3a2b1 "Same error after 4 attempts"
✓ Escalated to tier 4

# Task continues with stronger model
# Stronger model identifies root cause and fixes it ✓
```

### Scenario: Quality gate fundamentally broken

```bash
# Task keeps failing quality gate checks

$ aria-iteration-breaker.sh check task_id
🔄 Loop detected: Quality gate failing on same check repeatedly

# Circuit break to prevent further wasted attempts
$ aria-iteration-breaker.sh break task_id "QG lint loop"

# Generates summary showing human what to fix
# Human reviews and fixes lint configuration
# Task restarts with fixed config ✓
```

## Configuration

### Tune Detection Thresholds

Edit `/home/mike/.claude/scripts/aria-iteration-breaker.sh`:

```bash
LOOP_SAME_ERROR_COUNT=2           # Errors needed to trigger (default: 2)
LOOP_NO_TIER_CHANGE_ATTEMPTS=3    # Attempts needed for stuck detection (default: 3)
LOOP_QG_FAIL_REPEAT=2             # QG fails needed (default: 2)
```

**Recommendations:**
- Decrease values to detect loops faster (aggressive)
- Increase values to only detect obvious loops (conservative)

### Debug Mode

```bash
export ARIA_BREAKER_DEBUG=1
aria-iteration-breaker.sh check abc12345
# Shows detailed matching logic
```

## Logs

View all operations:
```bash
aria-iteration-breaker.sh log
# Or directly:
tail -50 /tmp/claude_vars/aria-iteration-breaker.log
```

## State Storage

**Where data is stored:**
- Task state: `/tmp/aria-task-{HASH}.json`
- Blocked tasks: `/tmp/aria-blocked-tasks/blocked.json`
- Summaries: `/tmp/aria-blocked-tasks/{task_id}-summary.txt`
- Logs: `/tmp/claude_vars/aria-iteration-breaker.log`

## Performance

- **Check:** <1ms
- **Analyze:** <5ms
- **Escalate:** <10ms
- **Break:** <50ms

No impact on normal task execution (only runs on failures).

## Tests

Run integration tests:
```bash
/home/mike/.claude/scripts/aria-iteration-breaker-integration-test.sh
# Tests: error similarity, loop detection, escalation, circuit breaking, etc.
```

## Troubleshooting

### Too many false positives?
Increase `LOOP_SAME_ERROR_COUNT` to 3 or 4

### Not detecting obvious loops?
```bash
export ARIA_BREAKER_DEBUG=1
aria-iteration-breaker.sh check task_id
# Shows why no loop detected
```

### Task won't clean up?
```bash
aria-iteration-breaker.sh cleanup task_id
# Force remove from blocked registry
```

### Check logs
```bash
tail -20 /tmp/claude_vars/aria-iteration-breaker.log
```

## Advanced: Custom Integration

```bash
# Source the breaker in your script
source ~/.claude/scripts/aria-iteration-breaker.sh

# Use individual functions
if aria_loop_check "$task_id"; then
    local analysis=$(aria_loop_analyze "$task_id")
    local new_tier=$(aria_force_escalate "$task_id" "custom reason")
fi

# Use integration hook (one-liner)
source ~/.claude/scripts/aria-iteration-integration.sh
aria_smart_route_check_loop "$task_id"  # Auto-action
```

## Files

| File | Purpose |
|------|---------|
| `aria-iteration-breaker.sh` | Main engine (705 lines) |
| `aria-iteration-integration.sh` | Smart-route hooks (99 lines) |
| `aria-iteration-breaker-integration-test.sh` | Test suite (174 lines) |
| `ARIA-ITERATION-BREAKER.md` | Full documentation |
| `ARIA-ITERATION-BREAKER-QUICKSTART.md` | This file |

## Summary

Use the iteration breaker to:
1. **Detect** when tasks are stuck in loops (save tokens)
2. **Analyze** what pattern is repeating (understand issue)
3. **Escalate** intelligently (skip ineffective models)
4. **Break** when needed (flag for human intervention)
5. **Track** blocked tasks (never lose context)

**Total investment:** 5.8KB of scripts, saves hours of debugging and hundreds of tokens.
