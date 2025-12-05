# Claude Code

## Workflow
`plan-pipeline.sh "task"` → Review → aria-coder applies → quality-gate.sh

Complex/failed → aria-thinking (Opus) → Plan → Haiku implements.

## External-First (Saves 85% tokens)
| Task | Use | NOT |
|------|-----|-----|
| Context | `ctx "query"` or `gemini` | Multiple Reads |
| Generate | `codex-save.sh` or `llm` | Direct output >10 lines |
| Search | `ctx` then Read specific | Grep loops |

**Auto-invoke**: >3 files or "implement/refactor/build" → `plan-pipeline.sh` first

## Size Limits
Agent ≤35 | Command ≤40 | Code >3 lines → scripts/

## Cache
`cached-read.sh` | `cached-structure.sh` | `cache-manager.sh stats`

## Docs
Agents: ~/.claude/agents/ | Scripts: ~/.claude/scripts/
