# ARIA - Token Optimizer (ALWAYS ACTIVE)

## Model Routing (enforced)
```
1. gemini       → FREE (1M+ context, analysis)
2. codex-mini   → Fast tasks (Haiku replacement)
3. gpt-5.1      → General tasks
4. codex        → Code generation
5. codex-max    → Complex problems (77.9% SWE)
6. Haiku        → File ops only (fallback)
7. Opus         → UI/UX only (last resort)
```

## Rules
- **External-first**: ctx/gemini before reads, codex before inline code
- **>3 lines code** → `aria route code "task"`
- **>3 files** → `/plan` first
- **NO auto-commit/push** without explicit request
- **Claude = orchestrator**: delegate, review, don't implement

## Workflow
```
Context (FREE) → Generate (codex) → Claude Review → /quality
```

## Quick Reference
| Task | Command |
|------|---------|
| Context | `ctx "query"` or `gemini "query"` (FREE) |
| Quick task | `aria route instant "task"` |
| Code gen | `aria route code "task"` |
| Complex | `aria route complex "task"` |
| Plan | `/plan` (multi-file changes) |
| Quality | `/quality` (lint+test+security) |

## Claude Review Checklist
- Consistency with codebase patterns
- Complete implementation
- Security (no XSS, SQL injection)
- Soft deletes, multi-tenant patterns
- No breaking changes

## Triggers
- `implement/refactor/build` → /plan first
- New UI/component → /design first
- Complex/failed → aria-thinking (opus)
