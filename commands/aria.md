---
description: Enable ARIA workflow - parallel subagents for speed + quality
argument-hint:
---

ARIA SESSION ACTIVE. Claude = orchestrator. External tools + subagents do the work.

## Cost Hierarchy (STRICT)
```
1. FREE tools first   → ctx, gemini, codex-save.sh, quality-gate.sh
2. Haiku for CLI      → git, winscp, composer, npm, lint, test (deterministic)
3. Haiku subagents    → aria-coder, aria-qa, Explore
4. Opus (UI/design)   → aria-ui-ux (visual/UX needs quality)
5. Opus (LAST RESORT) → aria-thinking (only for complex/failed tasks)
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
/design "component description"
    ↓
┌─────────────────────────────────────────────────────┐
│              PARALLEL DESIGN PLANNING               │
├─────────────────┬─────────────────┬─────────────────┤
│ Gemini          │ Codex           │ Claude Opus 4.5 │
│ (latest)        │ (latest)        │ (aria-ui-ux)    │
│ FREE            │ $               │ $$              │
└────────┬────────┴────────┬────────┴────────┬────────┘
         └────────────────┬┴─────────────────┘
                          ↓
              Compare/combine all 3 outputs
                          ↓
                   quality-gate.sh
```

**Usage:** `/design "responsive dashboard with charts and filters"`

**Flow:**
1. Script runs Gemini + Codex in parallel
2. Claude launches aria-ui-ux (Opus) for 3rd design
3. Claude evaluates all 3 by category (structure, styling, a11y, code, UX)
4. **Pick best OR merge best points** (no averaging, omit weak parts)
5. Implement winning design
6. quality-gate.sh

**Variables created:**
- `$gemini_design`: Gemini Pro design
- `$codex_design`: Codex Max design
- `$design_comparison`: Combined for review

### Failed/Blocked
```
Task(aria-thinking, opus) → then back to haiku agents
```

## Planning (Gemini + Codex Collaborative)
For tasks >3 files or "implement/refactor/build":
```
/plan "task description"
    ↓
Gemini (1M context) → Codex (plan) → Gemini (review)
    ↓
Claude reviews combined output
    ↓
/apply → aria-coder implements
```
All planning is FREE - no Claude tokens until final review.

## External-First (ALL agents)
| Task | Use | NEVER |
|------|-----|-------|
| Context | `ctx "query"` | Multiple Reads |
| Code gen | `codex-save.sh` | Inline generation |
| Analysis | `ai.sh fast` | Claude analysis |
| Planning | `/plan` (Gemini+Codex) | Manual planning |
| Lint | `composer cs-check` / `npm run lint` | Guessing |
| Test | `composer test` / `npm test` | Assuming pass |
| Quality | `quality-gate.sh` | Skipping |

## CLI Execution (Haiku)
All deterministic CLI commands route to Haiku agent:
```bash
# Pattern: Task(aria-admin, haiku) for CLI work
Task(aria-admin, haiku, prompt:"Run: git add . && git commit -m 'msg' && git push")
Task(aria-admin, haiku, prompt:"Run: winscp.com /script=deploy.txt")
Task(aria-admin, haiku, prompt:"Run: composer install && composer test")
Task(aria-admin, haiku, prompt:"Run: npm install && npm run build")
```

**CLI commands (always Haiku):**
- git (add, commit, push, pull, status)
- winscp, rsync, scp (deployments)
- composer, npm, yarn (package managers)
- lint, test, typecheck (validation)

## Rules
1. **FREE first**: Always try external tools before subagents
2. **Haiku for CLI**: All deterministic commands via aria-admin (haiku)
3. **Haiku default**: Never use opus unless task failed or explicitly complex
4. **Parallel when independent**: Single message, multiple Task calls
5. **Claude orchestrates only**: No code generation in main thread
6. **Quality gate mandatory**: Every implementation ends with `quality-gate.sh`

## Agent Prompt Template
```
EXTERNAL-FIRST: Use these before Claude processing:
- ctx "query" / gemini @. for context
- codex-save.sh for code generation
- ai.sh fast for quick analysis
- Run lint/test/quality-gate.sh for validation
```

Ready for task.
