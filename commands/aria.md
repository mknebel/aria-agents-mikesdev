---
description: Enable ARIA workflow for this session
argument-hint:
---

ARIA SESSION ACTIVE. All tasks use external-first workflow:

## Workflow
```
plan-pipeline.sh → Review → aria-coder → quality-gate.sh
    (FREE)                   (Haiku)       (MANDATORY)
```

## External-First (MANDATORY)
| Action | Tool |
|--------|------|
| Context | `ctx` or `gemini @.` |
| Code >3 lines | `codex-save.sh` |
| Quick check | `ai.sh fast` |

## Agent Routing
| Task | Agent |
|------|-------|
| Implementation | aria-coder (Haiku) |
| Complex/Failed | aria-thinking (Opus) |
| QA/Docs/Git | aria-* (Haiku) |

Ready for task.
