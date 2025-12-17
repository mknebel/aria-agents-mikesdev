# ARIA Complexity Assessment Script

## Overview

`aria-complexity.sh` is a production-ready bash script that analyzes task descriptions and determines the optimal ARIA model tier for routing. It implements a sophisticated multi-factor complexity assessment algorithm to ensure tasks are routed to the most cost-effective and appropriate model.

## Location

```
~/.claude/scripts/aria-complexity.sh
```

## Quick Start

### Basic Usage

```bash
# Simple assessment
aria-complexity.sh assess "Fix typo in README"
# Output: 1

# Complex assessment
aria-complexity.sh assess "Refactor database migration API for multi-system sync"
# Output: 3

# With error context
aria-complexity.sh assess "Fix compilation error" /tmp/error.log
# Output: 2

# Debug mode (verbose output)
aria-complexity.sh debug "Refactor auth system"
```

### Batch Processing

Process multiple tasks at once:

```bash
# Create task file
cat > /tmp/tasks.txt << EOF
Fix typo in README
Refactor authentication system
Quick bug fix in validation
EOF

# Run batch assessment
aria-complexity.sh batch /tmp/tasks.txt
```

## Output Tiers

The script outputs a single integer (1, 2, or 3) representing the complexity tier:

| Tier | Category | Model | Use Cases |
|------|----------|-------|-----------|
| **1** | Simple | `gpt-5.1-codex-mini` (instant) | Bug fixes, typos, quick updates, simple patches |
| **2** | Standard | `gpt-5.1` or `gpt-5.1-codex` | New features, refactoring, moderate complexity |
| **3** | Complex | `gpt-5.1-codex-max` | Architecture changes, multi-system integration, rewrites |

## Assessment Algorithm

The script uses a multi-factor scoring system with a base tier of 2 (standard), then adjusts based on these factors:

### Factor 1: File Count (+1 tier per 3 files mentioned)
Detects file paths in the task description:
- Matches: `/path/to/file`, `~/file.js`, `./relative/path`, `filename.ext`
- Example: "Update src/app.js, src/utils.js, tests/app.test.js" → +1 tier

### Factor 2: Complexity Keywords

**Increases complexity (+1 per match):**
- "refactor", "rewrite", "architecture"
- "database migration", "API integration"
- "multi-system"

**Decreases complexity (-1 per match):**
- "fix", "bug", "typo"
- "simple", "quick"

Example: "Fix simple bug in auth" → -2 tier (fix, simple, bug = -3 +1 base = 0, clamped to 1)

### Factor 3: Multi-System Detection (+1-2 tiers)
Detects mentions of different system layers:
- Database: "database", "sql", "db", "migration", "schema"
- API: "api", "endpoint", "rest", "graphql", "webhook"
- Frontend: "frontend", "react", "vue", "angular", "ui", "component", "page"
- Backend: "backend", "server", "service", "worker"

Scoring:
- 2+ systems mentioned: +1 tier
- 3+ systems mentioned: +2 tiers

### Factor 4: Error Context (+1 tier)
If an error file is provided and exists with content:
- File is checked with `-f` and `-s` (non-zero size)
- Indicates a real failure requiring deeper analysis

### Clamping
Final tier is clamped to range [1, 3]:
- Minimum: 1 (for very simple tasks)
- Maximum: 3 (for very complex tasks)

## Usage Examples

### Example 1: Simple Bug Fix
```bash
$ aria-complexity.sh assess "Fix typo in documentation"
1
```
Analysis:
- Base: 2
- Keywords: -1 (fix, typo)
- Result: 1 → Route to `gpt-5.1-codex-mini`

### Example 2: Feature Implementation
```bash
$ aria-complexity.sh assess "Implement new user authentication system"
2
```
Analysis:
- Base: 2
- Keywords: 0
- Systems: 0
- Result: 2 → Route to `gpt-5.1-codex`

### Example 3: Complex Multi-System Architecture
```bash
$ aria-complexity.sh assess "Refactor database migration API for multi-system sync between frontend and backend"
3
```
Analysis:
- Base: 2
- Keywords: +2 (refactor, multi-system)
- Systems: +2 (database, API, frontend, backend detected)
- Result: 3 → Route to `gpt-5.1-codex-max`

### Example 4: Error Context
```bash
$ aria-complexity.sh assess "Fix compilation error" /tmp/error.log
2
```
Analysis:
- Base: 2
- Keywords: -1 (fix)
- Error file: +1 (exists and non-empty)
- Result: 2 → Route to standard model

## Integration with ARIA Routing

### Source in Scripts
```bash
#!/bin/bash
source ~/.claude/scripts/aria-complexity.sh

# Assess task
tier=$(aria_assess_complexity "Refactor authentication system")

# Route based on tier
case "$tier" in
    1) aria route instant "Refactor authentication system" ;;
    2) aria route code "Refactor authentication system" ;;
    3) aria route complex "Refactor authentication system" ;;
esac
```

### As CLI Function
```bash
# Function available after sourcing
aria_assess_complexity "your task description" [error_file]
```

## Environment Variables

### ARIA_COMPLEXITY_DEBUG
Enable verbose debug output:
```bash
ARIA_COMPLEXITY_DEBUG=1 aria-complexity.sh assess "task"
```

Output includes:
- Task length analysis
- File count detection
- Keyword matches and scores
- Multi-system detection details
- Error context status
- Tier calculation steps

## Command Reference

```bash
# Main modes
aria-complexity.sh assess "task" [error_file]    # Single assessment
aria-complexity.sh debug "task" [error_file]     # Assessment with debug output
aria-complexity.sh batch input_file              # Batch processing
aria-complexity.sh help                          # Show help

# Examples
aria-complexity.sh help                          # Show help
aria-complexity.sh assess "Fix bug"              # Simple assessment
aria-complexity.sh debug "Refactor API"          # Debug output
aria-complexity.sh batch /tmp/tasks.txt          # Batch mode
```

## Return Codes

| Code | Meaning |
|------|---------|
| 0 | Success - assessment completed |
| 1 | Invalid input - empty task description |
| 2 | Error - unexpected failure |

## Implementation Details

### Sources
- `aria-state.sh` - For optional logging via `aria_inc()` and `aria_log_model()`

### File Operations
- Uses lock file at `~/.claude/.aria-complexity.lock` for concurrent access
- Follows aria-state.sh locking patterns

### Code Style
- Matches `aria-route.sh` and `aria-config.sh` patterns
- Uses bash extended regex (`[[ =~ ]]`)
- Proper error handling and input validation
- Debug mode support

## Testing

### Run Tests
```bash
# Test simple task
aria-complexity.sh assess "Fix typo"
# Expected: 1

# Test complex task
aria-complexity.sh assess "Refactor database migration API for multi-system architecture"
# Expected: 3

# Test with error context
echo "Error message" > /tmp/test_error.log
aria-complexity.sh assess "Fix error" /tmp/test_error.log
# Expected: 2

# Test batch
cat > /tmp/test_tasks.txt << EOF
Fix typo
Refactor system
Quick bug
EOF
aria-complexity.sh batch /tmp/test_tasks.txt
```

## Performance

- Single assessment: <50ms (no external calls)
- Batch processing: Linear in number of tasks
- No external dependencies beyond bash built-ins
- Stateless (can run in parallel)

## Troubleshooting

### Script not found
```bash
# Ensure executable permissions
chmod +x ~/.claude/scripts/aria-complexity.sh

# Or call explicitly
bash ~/.claude/scripts/aria-complexity.sh assess "task"
```

### No output/wrong output
```bash
# Check with debug mode
ARIA_COMPLEXITY_DEBUG=1 aria-complexity.sh assess "your task"

# Verify task string is not empty
echo "Task: '$1'"
```

### Integration with aria-route not working
```bash
# Verify aria-complexity.sh is sourced correctly
source ~/.claude/scripts/aria-complexity.sh
type aria_assess_complexity

# Check aria-state.sh is available
source ~/.claude/scripts/aria-state.sh
```

## Future Enhancements

Potential improvements:
- Machine learning-based complexity scoring
- Custom keyword configuration
- Per-project complexity profiles
- Historical complexity tracking
- Integration with git diff analysis

## References

- **aria-route.sh**: Model routing based on tier
- **aria-config.sh**: Configuration and temp directory management
- **aria-state.sh**: State tracking and logging
- **ARIA_CACHE_README.md**: Caching strategy documentation
