# ARIA Smart Router - Quick Start Guide

## TL;DR

Route any task with automatic complexity assessment and retry logic:

```bash
aria-smart-route.sh code "Implement feature X" 3
```

That's it. The system handles:
- ✓ Complexity assessment (Tier 1-3)
- ✓ Automatic model selection
- ✓ Retry with escalation
- ✓ Quality verification
- ✓ Detailed logging

## Installation

Already installed at: `~/.claude/scripts/aria-smart-route.sh`

If needed:
```bash
chmod +x ~/.claude/scripts/aria-smart-route.sh
```

## Basic Usage

### Syntax

```bash
aria-smart-route.sh <type> "<description>" [attempts]
```

### Task Types

| Type | Best For | Model Path |
|------|----------|-----------|
| `code` | Code generation, implementation | Tier 1→2→3 |
| `complex` | Architecture, refactoring | Starts at Tier 3 |
| `design` | UI/UX, API design | Tier 2→3 |
| `analysis` | Code review, security | Context tier |
| `instant` | Quick tasks | Tier 1 |
| `general` | Any task | Tier 1→2→3 |

### Examples

```bash
# Simple bug fix - fast and cheap
aria-smart-route.sh code "Fix typo in login error message" 1

# Standard feature - balanced cost/capability
aria-smart-route.sh code "Add dark mode to dashboard" 3

# Complex architecture - use best model
aria-smart-route.sh complex "Refactor for multi-tenancy" 3

# Quick brainstorm - instant tier
aria-smart-route.sh instant "Suggest API design patterns" 1
```

## How It Works

```
Input Task
    ↓
Assess Complexity (Tier 1-3)
    ↓
Select Model for Tier
    ↓
Execute (aria-route → model API)
    ↓
Verify (quality-gate if code)
    ↓
Success? ─→ Return output
    ↑
Failure
    ↓
Escalate (every 2 failures: tier+1)
    ↓
Retry (with failure context injected)
    ↓
Max attempts? ─→ Fail
```

## Return Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Failed after all attempts |
| 2 | Invalid arguments |

## CLI Commands

```bash
# Get help
aria-smart-route.sh help

# View active tasks and recent logs
aria-smart-route.sh status

# View full log history
aria-smart-route.sh log
```

## Tiers Explained

### Tier 1: Fast (gpt-5.1-codex-mini)
- Fastest, cheapest
- Best for: bugs, typos, simple fixes
- Keywords trigger: "fix", "bug", "typo", "simple", "quick"
- Example: "Fix typo in README"

### Tier 2: Balanced (gpt-5.1-codex)
- Default for most tasks
- Best for: standard features, refactoring
- Keywords trigger: "refactor", "feature"
- Example: "Add user profile page"

### Tier 3: Maximum (gpt-5.1-codex-max)
- Slowest, most capable
- Best for: complex architecture, multi-system
- Keywords trigger: "refactor", "architecture", "database", "API", "multi-system"
- Example: "Redesign database for multi-tenancy"

## Complexity Assessment

Task tier is calculated from:

1. **File mentions** - More files = higher tier
2. **Keywords** - See keywords that increase/decrease tier above
3. **Multi-system detection** - Database + API + Frontend = Tier 3
4. **Error context** - Previous errors = higher tier

Example:
```
"Fix typo in README"
→ Keywords: "fix" (-1)
→ No files, no systems
→ Result: Tier 1
```

## Retry & Escalation

- **Attempt 1**: Start with assessed tier
- **Failure**: Record error, inject into next prompt
- **Every 2 failures**: Escalate tier (+1)
- **Max tier**: 3 (highest capability)
- **Max attempts**: 3 (default, configurable)

Example sequence:
```
Attempt 1: Tier 1 → Fail
Attempt 2: Tier 1 → Fail
Attempt 3: Tier 2 (escalated) → Fail
Attempt 4: Tier 3 (escalated) → Success ✓
```

## Quality Gate

For **code** tasks only:
- Runs linting (eslint, phpcs, flake8)
- Runs static analysis (phpstan, tsc, mypy)
- Runs tests (pytest, npm test, phpunit)
- Runs security scan

If it fails, task fails and retries with higher tier.

## Logging

All activity logged to: `/tmp/claude_vars/aria-smart-route.log`

View latest:
```bash
aria-smart-route.sh log | tail -20
```

Enable debug:
```bash
ARIA_SMART_DEBUG=1 aria-smart-route.sh code "task" 1
```

## Common Patterns

### Pattern 1: Single Attempt (Certain Task)
```bash
aria-smart-route.sh code "Fix typo in README.md" 1
```
- For simple, obvious fixes
- Fast, cheap, no retries

### Pattern 2: Standard (Default)
```bash
aria-smart-route.sh code "Implement user authentication" 3
```
- Most common pattern
- 3 attempts with escalation
- Balanced cost and reliability

### Pattern 3: Maximum Effort (Complex)
```bash
aria-smart-route.sh complex "Refactor for multi-tenancy with API caching" 5
```
- Complex tasks need more attempts
- Starts at Tier 3
- Escalates if needed

### Pattern 4: Analysis/Review
```bash
aria-smart-route.sh analysis "Security review of API endpoints" 2
```
- For non-code tasks
- No quality gate
- Uses context tier

## Troubleshooting

### Task fails immediately

**Check:**
1. Is task description clear? Add more details
2. Is model available? Run `aria route models`
3. Enable debug: `ARIA_SMART_DEBUG=1 aria-smart-route.sh ...`

**Fix:**
```bash
# More attempts to retry
aria-smart-route.sh code "your task" 5

# With debug output
ARIA_SMART_DEBUG=1 aria-smart-route.sh code "your task" 3
```

### Escalates too quickly

**Check:**
1. Task description has complex keywords
2. Mentions multiple systems
3. Contains file paths

**Fix:**
```bash
# Simplify description, avoid multi-system keywords
aria-smart-route.sh code "Add login button" 3

# Debug assessment
ARIA_COMPLEXITY_DEBUG=1 aria-complexity.sh assess "your task"
```

### Quality gate fails repeatedly

**Check:**
```bash
# View logs
aria-smart-route.sh log | grep -i quality

# Check specific failures
tail -50 /tmp/claude_vars/aria-smart-route.log
```

**Fix:**
- Increase attempts: `aria-smart-route.sh code "..." 5`
- Task will escalate to more capable model
- Higher tiers better at fixing code issues

## Environment Variables

```bash
# Enable debug output
ARIA_SMART_DEBUG=1 aria-smart-route.sh code "task" 1

# Debug complexity assessment
ARIA_COMPLEXITY_DEBUG=1 aria-smart-route.sh code "task" 1

# Debug task state
ARIA_TASK_DEBUG=1 aria-smart-route.sh code "task" 1
```

## Integration

Works seamlessly with:
- `aria route` - Model routing
- `aria-complexity.sh` - Tier assessment
- `aria-task-state.sh` - Retry tracking
- `quality-gate.sh` - Code verification
- `aria score` - Metrics

## Advanced Usage

### Check task status
```bash
aria-smart-route.sh status
```

### View task state directly
```bash
source ~/.claude/scripts/aria-task-state.sh
task_id=$(echo -n "task description" | sha256sum | cut -c1-8)
aria_task_state "$task_id" | jq .
```

### Manual tier assessment
```bash
source ~/.claude/scripts/aria-complexity.sh
ARIA_COMPLEXITY_DEBUG=1 aria_assess_complexity "task description"
```

## Performance Tips

1. **Use appropriate attempts:**
   - Simple: 1-2 attempts
   - Standard: 3 attempts (default)
   - Complex: 4-5 attempts

2. **Quality gate for code:**
   - Always enabled for `code` type
   - Catches problems early

3. **Clear descriptions:**
   - More detail = better assessment
   - Helps both complexity analyzer and model

4. **Task batching:**
   - Related tasks together
   - Session context helps

## Comparison: When to Use

```
Simple bug fix?
  → aria-smart-route.sh code "..." 1

Standard feature?
  → aria-smart-route.sh code "..." 3 (DEFAULT)

Complex architecture?
  → aria-smart-route.sh complex "..." 3

Quick brainstorm?
  → aria-smart-route.sh instant "..." 1

Code review?
  → aria-smart-route.sh analysis "..." 2
```

## See Also

- `ARIA_SMART_ROUTE_README.md` - Full documentation
- `aria route models` - View available models
- `aria score` - View session metrics
- `aria-complexity.sh help` - Complexity assessment
- `quality-gate.sh` - Code verification

---

**Quick Ref:** `aria-smart-route.sh <type> "<task>" [attempts]`

**Help:** `aria-smart-route.sh help`

**Status:** `aria-smart-route.sh status`

**Logs:** `aria-smart-route.sh log`

---

Last Updated: Dec 6, 2025
