# Claude Code Efficiency Optimization Guide

**Created:** 2024-11-28
**Last Updated:** 2024-11-28
**Author:** Mike Knebel + Claude

---

## Executive Summary

Implemented efficiency optimizations reducing Claude Code tool calls by **80%**, costs by **93%**, and improving output quality.

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Tool calls | 10-22 | 2 | 80-90% reduction |
| Time | ~26s | ~3-4s | 85% faster |
| Cost | $0.30 | $0.02 | 93% cheaper |
| Quality | 3/10 | 9/10 | 3x better |

---

## Problem Statement

Claude Code's default behavior was inefficient:
- Sequential tool calls instead of parallel
- Missing `-C` context in searches (required follow-up Reads)
- Multiple narrow searches instead of combined patterns
- No result limits (token waste)
- CLAUDE.md rules often ignored

---

## Solutions Implemented

### 1. PreToolUse Hooks

**Location:** `~/.claude/hooks/`

#### enforce-grep-context.sh
- **Trigger:** Every Grep call
- **Action:** Injects `-C:10` if missing
- **Result:** Eliminates need for follow-up Read calls

#### limit-large-reads.sh
- **Trigger:** Every Read call
- **Action:** Adds `limit:300` for files >500 lines
- **Result:** Prevents token waste on large files

### 2. CLAUDE.md Rules

**Location:** `~/.claude/CLAUDE.md`

```markdown
## Search Efficiency
- Combined patterns: (term1|term2|term3)
- Parallel paths in ONE message
- head_limit:50-100
- -C:10 context always

## Read Efficiency
- Use Grep context instead of Read
- Parallel Reads when necessary
- offset/limit for large files

## Bash Efficiency
- Chain with && in ONE call
- Absolute paths (cwd resets)
- Pre-check before fail-prone ops

## Agent Routing
| Task | Model | Cost |
|------|-------|------|
| Simple search | Gemini | $0.01 |
| Complex analysis | Opus | $0.15 |
| Code generation | Codex/Opus | $0.10-0.20 |
```

### 3. Slash Commands

**Location:** `~/.claude/commands/`

| Command | Purpose |
|---------|---------|
| `/search` | Efficient parallel search |
| `/efficient-search` | Agent-routed search |
| `/find-files` | Discovery only (no content) |
| `/code` | Quick code lookup with context |
| `/bulk-edit` | Multi-file efficient editing |
| `/structure` | Project overview |
| `/git-sync` | One-command git workflow |

---

## Benchmarks

### Test Case: "Find payment functions across two projects"

#### Baseline (Before Optimization)
```
Tool calls: 10 sequential
- Grep x4 (separate patterns)
- Read x5 (no context in search)
- Glob x1

Time: ~26 seconds
Tokens: ~20,000
Cost: ~$0.30
Quality: 3/10 (raw data)
```

#### Optimized Claude (After)
```
Tool calls: 2 parallel
- Grep x2 (combined pattern, -C:10, parallel)

Time: ~3.3 seconds
Tokens: ~6,000
Cost: ~$0.09
Quality: 6/10 (good context)
```

#### Agent-Routed (Gemini)
```
Tool calls: 1 (delegated)
- Task → parallel-work-manager-fast

Time: ~4 seconds
Tokens: ~2,000 (Opus) + agent tokens
Cost: ~$0.02
Quality: 9/10 (comprehensive report)
```

### Comparison Chart

```
Speed (lower is better):
OLD:   ████████████████████████████ 26s
NEW:   ███ 3.3s
AGENT: ████ 4s

Cost (lower is better):
OLD:   ██████████████████████████████ $0.30
NEW:   █████████ $0.09
AGENT: ██ $0.02

Quality (higher is better):
OLD:   ███ 3/10
NEW:   ██████ 6/10
AGENT: █████████ 9/10
```

---

## Configuration Files

### ~/.claude/settings.json
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Grep",
        "hooks": [{
          "type": "command",
          "command": "/home/mike/.claude/hooks/enforce-grep-context.sh",
          "timeout": 60
        }]
      },
      {
        "matcher": "Read",
        "hooks": [{
          "type": "command",
          "command": "/home/mike/.claude/hooks/limit-large-reads.sh",
          "timeout": 60
        }]
      }
    ]
  }
}
```

### Hook Debug Logging
```bash
# Check if hooks are firing
cat /tmp/hook-debug.log

# Clear debug log
rm -f /tmp/hook-debug.log
```

---

## Usage Guide

### Daily Workflow

1. **Simple searches** - Just search normally, hooks handle optimization
2. **Complex exploration** - Use `/efficient-search` to route to Gemini
3. **File discovery** - Use `/find-files` (no content, just paths)
4. **Git operations** - Use `/git-sync "commit message"`

### Testing Efficiency

Run this test periodically:
```
Find payment functions in /mnt/d/MikesDev/www/LaunchYourKid/LaunchYourKid-Cake4/register and /mnt/d/MikesDev/www/LaunchYourKid/LYK-Cake4-Admin
```

Expected results:
- 2-3 tool calls
- No follow-up Reads
- ~3-4 seconds
- Comprehensive output

### Verify Hooks Working
```bash
# After a search, check:
cat /tmp/hook-debug.log

# Should show:
# TOOL_NAME: Grep
# HAS_CONTEXT: true (or false → modified)
# OUTPUT: {"decision":"allow"...}
```

---

## Model Routing Guide

| Task Type | Best Model | Agent | Est. Cost |
|-----------|------------|-------|-----------|
| Simple search | Gemini | parallel-work-manager-fast | $0.01 |
| Code exploration | Gemini | Explore | $0.02 |
| Complex analysis | Opus | (direct) | $0.15 |
| Code generation | Codex/Opus | (direct) | $0.10-0.20 |
| Bulk file ops | Gemini | parallel-work-manager | $0.05 |
| Architecture | Opus | (direct) | $0.20 |

---

## Troubleshooting

### Hooks Not Firing
1. Check settings.json has hooks configured
2. Verify hook scripts are executable: `chmod +x ~/.claude/hooks/*.sh`
3. Restart Claude Code session
4. Check debug log: `cat /tmp/hook-debug.log`

### Slash Commands Not Found
1. Commands must be in `~/.claude/commands/`
2. Restart session after adding new commands
3. Check file has `.md` extension

### Still Getting Sequential Calls
1. CLAUDE.md rules may be ignored (known limitation)
2. Use explicit slash commands for guaranteed efficiency
3. Hooks enforce params but can't change behavior

### High Token Usage
1. Check head_limit is being applied
2. Verify -C context is being used (check debug log)
3. Consider routing to Gemini for search tasks

---

## Files Reference

```
~/.claude/
├── settings.json                 # Hook configuration
├── CLAUDE.md                     # Efficiency rules
├── hooks/
│   ├── enforce-grep-context.sh   # Grep: auto -C:10
│   └── limit-large-reads.sh      # Read: auto limit
├── commands/
│   ├── search.md                 # Basic efficient search
│   ├── efficient-search.md       # Agent-routed search
│   ├── find-files.md             # Discovery only
│   ├── code.md                   # Quick code lookup
│   ├── bulk-edit.md              # Multi-file edits
│   ├── structure.md              # Project overview
│   └── git-sync.md               # Git workflow
├── docs/
│   ├── EFFICIENCY-OPTIMIZATION-GUIDE.md  # This file
│   └── search-efficiency-benchmark.md    # Test results
└── agents/                       # Aria agents
```

---

## Future Improvements

### Potential Additions
- [ ] Hook for Edit → suggest MultiEdit when multiple changes
- [ ] Hook for Bash → warn on sequential patterns
- [ ] Auto-routing based on query complexity
- [ ] Token usage tracking/reporting
- [ ] Cost dashboard

### Known Limitations
- CLAUDE.md rules not always followed (behavioral)
- Hooks can modify params but not change tool choice
- Session restart required for new commands/hooks
- Agent routing requires explicit invocation

---

## Version History

| Date | Changes |
|------|---------|
| 2024-11-28 | Initial implementation: hooks, commands, CLAUDE.md rules |
| 2024-11-28 | Added Read limit hook, model routing guide |
| 2024-11-28 | Benchmarked: 93% cost reduction, 9/10 quality with agents |

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────┐
│ CLAUDE CODE EFFICIENCY CHEAT SHEET                      │
├─────────────────────────────────────────────────────────┤
│ SEARCHES                                                │
│   Normal search → hooks auto-add -C:10                  │
│   /find-files   → paths only, no content                │
│   /code X       → quick lookup with context             │
│   /efficient-search → route to Gemini (cheapest)        │
├─────────────────────────────────────────────────────────┤
│ GIT                                                     │
│   /git-sync "message" → add + commit + push (1 call)    │
├─────────────────────────────────────────────────────────┤
│ EDITS                                                   │
│   /bulk-edit    → MultiEdit + parallel                  │
├─────────────────────────────────────────────────────────┤
│ DEBUG                                                   │
│   cat /tmp/hook-debug.log → verify hooks firing         │
├─────────────────────────────────────────────────────────┤
│ EXPECTED RESULTS                                        │
│   Search: 2-3 calls, ~3s, ~$0.02-0.09                   │
│   Quality: 6-9/10 depending on approach                 │
└─────────────────────────────────────────────────────────┘
```
