# Claude Code

## Session Start
Any of these activate ARIA workflow:
- `/aria` - activate for session
- "use aria" / "aria mode" - activate for session
- "aria <task>" - run task with ARIA workflow immediately

Examples: `aria fix the login bug` | `aria implement user auth`

## ARIA Workflow
```
plan-pipeline.sh → Review → aria-coder → quality-gate.sh
    (FREE)                   (Haiku)       (MANDATORY)
```

## External-First (MANDATORY)
| Action | Tool | NEVER |
|--------|------|-------|
| Context | `ctx` or `gemini @.` | Multiple Reads |
| Code >3 lines | `codex-save.sh` | Inline generation |
| Quick check | `ai.sh fast` | Full analysis |

## Triggers
- >3 files OR "implement/refactor/build" → `plan-pipeline.sh` first
- Complex/failed → aria-thinking (Opus)

## Docs
Agents: `~/.claude/agents/` | Scripts: `~/.claude/scripts/`
