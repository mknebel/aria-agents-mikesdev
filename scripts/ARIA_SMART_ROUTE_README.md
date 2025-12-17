# ARIA Smart Router - Complete Guide

## Overview

`aria-smart-route.sh` is the main orchestrator for intelligent task routing with automatic complexity assessment, retry logic, and model escalation. It coordinates between multiple ARIA subsystems to deliver optimal task execution.

## Architecture

### Components

1. **aria-smart-route.sh** - Main orchestrator (this script)
2. **aria-complexity.sh** - Task complexity assessment (tier 1-3)
3. **aria-task-state.sh** - Per-task state management and retry tracking
4. **aria-route.sh** - Model routing to external services (gemini, gpt-5.1, codex-max)
5. **aria-state.sh** - Session state and metrics tracking
6. **aria-config.sh** - Temporary directory management
7. **quality-gate.sh** - Verification for code tasks

### Execution Flow

```
User Request
    ↓
aria-smart-route.sh
    ├─→ Input validation
    ├─→ Task state initialization
    ├─→ Complexity assessment (aria-complexity.sh)
    └─→ Retry Loop (max 3 attempts):
            ├─→ Get current tier
            ├─→ Build prompt (with failure context if retry)
            ├─→ Execute via aria-route.sh
            ├─→ Verify via quality-gate.sh
            └─→ On failure: escalate every 2 attempts
```

## Installation

The script is located at: `~/.claude/scripts/aria-smart-route.sh`

It should be executable. If not:
```bash
chmod +x ~/.claude/scripts/aria-smart-route.sh
```

## Usage

### Basic Syntax

```bash
aria-smart-route.sh <type> "<description>" [max_attempts]
```

### Arguments

| Argument | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| type | string | Yes | - | Task type: `code`, `design`, `complex`, `analysis`, `instant`, `general` |
| description | string | Yes | - | Clear description of the task |
| max_attempts | number | No | 3 | Maximum retry attempts before failure |

### Return Codes

| Code | Meaning |
|------|---------|
| 0 | Success - task completed and verified |
| 1 | Failure - all attempts exhausted |
| 2 | Invalid arguments provided |

## Examples

### Code Generation Task (Default)

```bash
aria-smart-route.sh code "Implement user authentication with JWT tokens" 3
```

- Assesses task as **Tier 2 (Balanced)** based on keywords
- Routes to **gpt-5.1-codex** model
- Runs quality gate to verify output
- Retries up to 3 times with escalation

### Complex Architecture Task

```bash
aria-smart-route.sh complex "Refactor database schema for multi-tenancy with API sync" 4
```

- Assesses task as **Tier 3 (Maximum)** - detects "refactor", "database", "API"
- Routes to **gpt-5.1-codex-max** immediately
- Runs quality gate verification
- Allows 4 attempts with escalation

### Quick Bug Fix

```bash
aria-smart-route.sh code "Fix typo in login error message" 1
```

- Assesses task as **Tier 1 (Fast)** - keyword "Fix"
- Routes to **gpt-5.1-codex-mini** (fast, cheap)
- No retries (max_attempts=1)
- Best for simple, certain tasks

### Design Review Task

```bash
aria-smart-route.sh design "Review proposed API schema for scalability" 2
```

- Assesses based on task description
- Routes via complex model tier
- No quality gate (design task)
- Allows 2 attempts

## Model Tiers

The router automatically escalates through model tiers based on task complexity:

### Tier 1: Fast (gpt-5.1-codex-mini)

- **Best for:** Bug fixes, typos, small features, quick tasks
- **Cost:** Lowest
- **Speed:** Fastest
- **Reasoning:** Light/medium
- **Triggers:** Keywords: fix, bug, typo, simple, quick
- **Example:** "Fix typo in README.md"

### Tier 2: Balanced (gpt-5.1-codex or gpt-5.1)

- **Best for:** Standard features, refactors, general tasks
- **Cost:** Medium
- **Speed:** Good
- **Reasoning:** Medium/high
- **Triggers:** Keywords: refactor, standard feature
- **Example:** "Add user profile management feature"

### Tier 3: Maximum (gpt-5.1-codex-max)

- **Best for:** Complex architecture, multi-system, rewrites
- **Cost:** Highest
- **Speed:** Slower but thorough
- **Reasoning:** Extra high
- **Triggers:** Keywords: refactor, rewrite, architecture, database migration, API integration, multi-system
- **Example:** "Redesign database schema for multi-tenancy"

## Complexity Assessment Algorithm

Tier is calculated based on multiple factors:

### 1. File Count (per 3 files = +1 tier)

```
Files mentioned → Count unique paths → Divide by 3 → Add to base
```

### 2. Keyword Matching

**Increase complexity (+1 each):**
- `refactor`, `rewrite`, `architecture`, `database migration`, `api integration`, `multi-system`

**Decrease complexity (-1 each):**
- `fix`, `bug`, `typo`, `simple`, `quick`

### 3. Multi-System Detection

- Database + API + Frontend = Tier 3
- Any 2 systems = Tier 2
- Single system = Tier 1

### 4. Error Context

- Previous errors in task = +1 tier

**Example:**

```
Input: "Fix typo in README"
- Base tier: 2
- Keywords: "fix" → -1
- Systems: 0 (no DB/API/UI)
- Final: 1 (clamped to 1-3 range)

Output: Tier 1
```

## Retry and Escalation Logic

### Retry Loop (Per Attempt)

1. **Get current tier** from task state
2. **Build prompt** with failure context if retry
3. **Execute** via aria-route.sh to selected model
4. **Verify** output via quality-gate.sh (for code tasks)
5. **Check success** - if all checks pass, return success
6. **Record failure** with error details
7. **Escalate** every 2 failures: tier+1 (max tier 3)
8. **Next attempt** with higher tier model

### Example Escalation Sequence

```
Attempt 1: Tier 1 (codex-mini) → Fails
Attempt 2: Tier 1 (codex-mini) → Fails → ESCALATE to Tier 2
Attempt 3: Tier 2 (codex) → Fails → ESCALATE to Tier 3
Attempt 4: Tier 3 (codex-max) → Success ✓
```

## Failure Context Injection

When a task fails and retries, the previous failure is injected into the prompt:

```
[Original task description]

---

PREVIOUS ATTEMPT FAILED - RETRY WITH IMPROVEMENTS:

Previous failures:
  Attempt 1 (model: codex-mini): Failed to handle edge case
  Attempt 2 (model: codex): Syntax error in implementation

Please try again with a different approach or more careful implementation.
```

This helps the model understand what went wrong and avoid the same issues.

## Environment Variables

### ARIA_SMART_DEBUG

Enable debug output for troubleshooting:

```bash
ARIA_SMART_DEBUG=1 aria-smart-route.sh code "test task" 1
```

Output will include:
- Task context details
- Model routing decisions
- Failure analysis
- Escalation reasoning

### ARIA_COMPLEXITY_DEBUG

Debug complexity assessment:

```bash
ARIA_COMPLEXITY_DEBUG=1 aria-smart-route.sh code "test task" 1
```

## Logging

All operations are logged to: `/tmp/claude_vars/aria-smart-route.log`

### Log Format

```
[2025-12-06 03:55:23] [INFO] Starting smart route: type=code
[2025-12-06 03:55:24] [INFO] Task ID: 030db4f5
[2025-12-06 03:55:25] [INFO] Assessing task complexity...
[2025-12-06 03:55:26] [INFO] Initial assessment: Tier 2
[2025-12-06 03:55:27] [INFO] Attempt 1 of 3
[2025-12-06 03:55:28] [INFO] Using model: gpt-5.1-codex (Tier 2 (Balanced))
```

### View Recent Logs

```bash
aria-smart-route.sh log
```

## Status and Monitoring

### View Active Tasks

```bash
aria-smart-route.sh status
```

Output:
```
ARIA Smart Router Status
═══════════════════════════════════════
No active task states

Recent log entries:
[last 10 log entries]
```

### View Full Logs

```bash
aria-smart-route.sh log
```

## Quality Gate Verification

For **code** tasks, the script runs `quality-gate.sh` to verify:

1. **Linting** (ESLint, phpcs, flake8)
2. **Static Analysis** (phpstan, TypeScript, mypy)
3. **Tests** (pytest, npm test, phpunit)
4. **Security Scan** (custom security checks)

If quality gate fails:
- Task is marked as failed
- Failure is recorded with error details
- Task escalates and retries with higher tier model

For **non-code** tasks (design, analysis, etc):
- Quality gate is skipped
- Verification is based on output existence

## Task State Files

Task state is stored temporarily at: `/tmp/aria-task-[TASK_HASH].json`

### State Structure

```json
{
  "task_id": "030db4f5",
  "task_desc": "Fix typo in README",
  "attempt_count": 2,
  "model_tier": 2,
  "created_at": "1765014959",
  "failures": [
    {
      "attempt": 1,
      "error": "Quality gate failed",
      "model": "codex-mini",
      "timestamp": "1765014960"
    }
  ],
  "escalation_log": [
    {
      "timestamp": "1765014961",
      "reason": "Verification failed after attempt 1",
      "from_tier": 1,
      "to_tier": 2
    }
  ],
  "quality_gate_results": []
}
```

State files are **automatically cleaned up** on success.

## Integration with ARIA Ecosystem

### With aria-route.sh

`aria-smart-route.sh` uses `aria_route()` function from `aria-route.sh`:

```bash
aria_route "code" "Implement feature X"
```

This routes to the appropriate model based on task type.

### With aria-complexity.sh

Uses `aria_assess_complexity()` to determine initial tier:

```bash
tier=$(aria_assess_complexity "task description")
# Output: 1, 2, or 3
```

### With aria-task-state.sh

Manages retry state with functions like:

```bash
task_id=$(aria_task_init "task description")
aria_task_escalate "$task_id" "reason"
aria_task_record_failure "$task_id" "error message"
aria_task_cleanup "$task_id"
```

### With quality-gate.sh

Verifies code output:

```bash
quality-gate.sh . --skip-tests
# Returns: 0 = pass, 1 = fail
```

### With aria-session.sh

Session context is automatically included in prompts if available.

## Common Workflows

### Workflow 1: Simple Bug Fix (No Retries)

```bash
aria-smart-route.sh code "Fix login button color in mobile view" 1
```

- Single attempt with Tier 1 model
- Fast, cheap, appropriate for simple fix

### Workflow 2: Feature Development (Multiple Retries)

```bash
aria-smart-route.sh code "Implement OAuth2 authentication flow with refresh tokens" 4
```

- Multiple attempts (4) with escalation
- Starts at Tier 2 (balanced)
- Escalates to Tier 3 if needed

### Workflow 3: Architecture Design (Complex)

```bash
aria-smart-route.sh complex "Design multi-tenant database schema with API caching layer" 3
```

- Starts at Tier 3 immediately (complex task)
- Allows retries for refinement
- No quality gate (design task)

### Workflow 4: Analysis/Review (Context)

```bash
aria-smart-route.sh analysis "Analyze proposed API security architecture for vulnerabilities" 2
```

- Routes via complex tier
- 2 attempts for thorough analysis
- Output-based verification

## Troubleshooting

### Task Fails with "No output from task"

**Cause:** Model didn't generate output

**Solution:**
1. Check if model is available: `aria route models`
2. Increase max_attempts: `aria-smart-route.sh code "task" 5`
3. Enable debug: `ARIA_SMART_DEBUG=1 aria-smart-route.sh code "task" 1`
4. Check logs: `aria-smart-route.sh log | tail -20`

### Quality Gate Fails

**Cause:** Generated code doesn't pass linting/tests

**Solution:**
1. View specific failures: Check `/tmp/claude_vars/quality_gate_last`
2. Allow more retries: Let escalation try higher tier models
3. Review error context: Check aria-smart-route.log for error details

### Task Escalates to Tier 3 Too Quickly

**Cause:** Complexity assessment might be too high

**Solution:**
1. Debug complexity: `ARIA_COMPLEXITY_DEBUG=1 aria-complexity.sh assess "your task"`
2. Simplify task description: Remove multi-system keywords if possible
3. Run with fewer attempts: Let it settle on current tier

### Logs Are Empty

**Cause:** Temp directory permissions or path issues

**Solution:**
```bash
# Check temp directory
ls -la /tmp/claude_vars/

# Check log file permissions
chmod 644 /tmp/claude_vars/aria-smart-route.log 2>/dev/null

# Verify script execution
ARIA_SMART_DEBUG=1 aria-smart-route.sh status
```

## Performance Tips

1. **Use right tier for task:**
   - Simple fixes: Tier 1 is fast and cheap
   - Complex tasks: Start with Tier 3 to avoid multiple retries

2. **Set appropriate max_attempts:**
   - Simple tasks: 1-2 attempts
   - Standard tasks: 3 attempts (default)
   - Complex tasks: 4-5 attempts

3. **Quality gate for code:**
   - Always use for code generation
   - Helps prevent bad output

4. **Batch similar tasks:**
   - Run related tasks back-to-back
   - Session context improves subsequent tasks

## Metrics Tracking

The script updates ARIA session state:

- `smart_route_success` - Successful completions
- `smart_route_failed` - Failed tasks
- `complexity_assessments` - Complexity evaluations

View summary:
```bash
aria score
```

## Security Considerations

1. **Task descriptions** are hashed for stable task IDs
2. **State files** are stored in `/tmp` with proper permissions
3. **Prompts** with failure context are clearly separated
4. **Quality gate** checks for security issues
5. **No secrets** are stored in task state

## API Reference

### Main Functions

#### aria_smart_route(task_type, task_desc, max_attempts)

Routes a task with automatic retry and escalation.

**Parameters:**
- `task_type` (string) - Type of task
- `task_desc` (string) - Task description
- `max_attempts` (number, default 3) - Maximum retry attempts

**Returns:**
- `0` - Success
- `1` - Failure
- `2` - Invalid arguments

**Example:**
```bash
aria_smart_route "code" "Implement feature X" 3
```

### Supporting Functions

(These are internal but available for advanced usage)

- `aria_assess_complexity(task_desc)` - Get complexity tier 1-3
- `aria_task_init(task_desc)` - Initialize task state
- `aria_task_escalate(task_id, reason)` - Escalate to higher tier
- `aria_task_record_failure(task_id, error)` - Record failure
- `aria_task_cleanup(task_id)` - Clean up task state
- `aria_route(type, prompt)` - Execute via model router

## Contributing

To improve aria-smart-route.sh:

1. Test new features with debug enabled
2. Add test cases to verify escalation logic
3. Check quality gate with code changes
4. Document new environment variables
5. Update this README with examples

## See Also

- `aria-route.sh` - Model routing implementation
- `aria-complexity.sh` - Complexity assessment
- `aria-task-state.sh` - Task state management
- `quality-gate.sh` - Code verification
- `aria-score.sh` - Session metrics

## Version History

- **Dec 6, 2025** - Initial release
  - Complexity assessment (Tier 1-3)
  - Retry loop with escalation
  - Quality gate integration
  - Comprehensive logging
  - CLI interface (help, status, log)

---

Last Updated: Dec 6, 2025
