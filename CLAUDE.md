# Claude Code

## Workflow
`plan-pipeline.sh "task"` → Review → aria-coder applies → quality-gate.sh

Complex/failed → aria-thinking (Opus) → Plan → Haiku implements.

## Size Limits (Enforced)
| Type | Max | Check |
|------|-----|-------|
| Agent | 35 | `~/.claude/hooks/check-size.sh` |
| Command | 40 | auto |

**Rules**: No code >3 lines (use scripts/) | No ASCII diagrams | One line per rule

## Docs
Agents: ~/.claude/agents/ | Scripts: ~/.claude/scripts/ | Templates: ~/.claude/templates/
