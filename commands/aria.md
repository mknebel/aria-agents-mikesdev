---
description: Enable ARIA workflow - parallel subagents for speed + quality
argument-hint:
---

ARIA SESSION ACTIVE. Claude = orchestrator. External tools + subagents do the work.

## Cost Hierarchy (STRICT)
```
1. FREE tools first   → ctx, gemini, codex-save.sh, quality-gate.sh
2. Haiku subagents    → aria-coder, aria-qa, Explore
3. Opus (UI/design)   → aria-ui-ux (visual/UX needs quality)
4. Opus (LAST RESORT) → aria-thinking (only for complex/failed tasks)
```

## Claude's Role
- **DO**: Orchestrate, delegate, consolidate results
- **DON'T**: Generate code, analyze large files, do heavy reasoning

## Task Routing

### Simple (1-2 files, clear fix)
```
FREE tools only → quality-gate.sh → done
```

### Medium (3+ files, implementation)
```
ctx/gemini → Task(aria-coder, haiku) → quality-gate.sh
```

### Complex (architecture, multi-system)
```
Task(Explore) + Task(system-architect)  [parallel, haiku]
        ↓
Task(aria-coder) + Task(aria-qa)        [parallel, haiku]
        ↓
quality-gate.sh
```

### UI Requests (modify existing UI)
```
Task(aria-ui-ux, opus) → quality-gate.sh
```
Use Claude Opus for UI work - better visual/UX reasoning.

### New Design (create new UI/component)
```
Task(aria-ui-ux, opus) + Bash(gemini "design: <request>")  [PARALLEL]
        ↓
Compare/combine both outputs → best result
        ↓
quality-gate.sh
```
Run Opus and Gemini in parallel, then pick best or merge ideas.

**Command pattern:**
```bash
# In single Claude response, call BOTH:
Task(aria-ui-ux, model:opus, prompt:"Design <component>...")
Bash(gemini "Design a <component> with: <requirements>")
# Then consolidate results
```

### Failed/Blocked
```
Task(aria-thinking, opus) → then back to haiku agents
```

## External-First (ALL agents)
| Task | Use | NEVER |
|------|-----|-------|
| Context | `ctx "query"` | Multiple Reads |
| Code gen | `codex-save.sh` | Inline generation |
| Analysis | `ai.sh fast` | Claude analysis |
| Planning | `plan-pipeline.sh` | Manual planning |
| Lint | `composer cs-check` / `npm run lint` | Guessing |
| Test | `composer test` / `npm test` | Assuming pass |
| Quality | `quality-gate.sh` | Skipping |

## Rules
1. **FREE first**: Always try external tools before subagents
2. **Haiku default**: Never use opus unless task failed or explicitly complex
3. **Parallel when independent**: Single message, multiple Task calls
4. **Claude orchestrates only**: No code generation in main thread
5. **Quality gate mandatory**: Every implementation ends with `quality-gate.sh`

## Agent Prompt Template
```
EXTERNAL-FIRST: Use these before Claude processing:
- ctx "query" / gemini @. for context
- codex-save.sh for code generation
- ai.sh fast for quick analysis
- Run lint/test/quality-gate.sh for validation
```

Ready for task.
