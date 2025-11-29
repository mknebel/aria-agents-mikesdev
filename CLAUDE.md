# Global Claude Code Rules

## Automated (Hooks Handle These)
- ✅ Grep context (-C:10) - auto-added
- ✅ Large file limits (300 lines) - auto-enforced
- ✅ Search caching - automatic
- ✅ Token tracking - automatic
- ✅ Project indexing - auto on first prompt

## Manual Efficiency Rules

### Searching
- Combine patterns: `(term1|term2|term3)` - ONE search
- Parallel calls in ONE message for different paths
- Use `output_mode:"files_with_matches"` for discovery
- Max 3 tool calls per search task

### Editing
- MultiEdit for 2+ changes in same file
- Parallel Edit calls for multiple files
- Don't Read before Write for new files

### Bash
- Chain with `&&`: `git add -A && git commit -m "msg" && git push`
- Use absolute paths (cwd resets between calls)

## Quick Commands
```
/menu          - Your command menu
/cost-report   - Token usage
/index-project - Rebuild index
/summarize     - Session handoff
```

## Project-Specific
See each project's CLAUDE.md for local rules.
