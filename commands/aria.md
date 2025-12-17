---
description: ARIA status check (ARIA is ALWAYS enforced)
argument-hint:
---

## ARIA IS ALWAYS ENFORCED - THIS IS A STATUS CHECK

ARIA workflow is **permanently active**. This command shows current rules.

Claude = orchestrator. External tools + subagents do the work. **No exceptions.**

## Cost Hierarchy (STRICT)
```
1. FREE tools first   → just ctx/just q, ctx, gemini, codex-save.sh, quality-gate.sh
2. Haiku for simple   → git commands, file operations (simple, clearly-defined tasks)
3. Sonnet for coding  → aria-coder, aria-qa (implementation, testing, code review)
4. Opus for planning  → system-architect, Explore, aria-thinking (planning, architecture, complex reasoning)
5. Opus for UI/UX     → aria-ui-ux (visual/UX needs highest quality)
```

**Prefer justfile commands when available** - `just ctx`, `just q`, `just lint`, `just test`, etc.

**Model Selection Strategy:**
- **Haiku**: Simple, mechanical tasks only (git status, file operations)
- **Sonnet**: Implementation, coding, testing (balanced speed/quality/cost)
- **Opus**: Planning, architecture, task definition, complex reasoning (highest quality strategic work)

## Claude's Role
- **DO**: Orchestrate, delegate, consolidate results
- **DON'T**: Generate code, analyze large files, do heavy reasoning

## Task Routing

### Simple (1-2 files, clear fix)
```
FREE tools only → just q → done
```

### Medium (3+ files, implementation)
```
just ctx/gemini → Task(aria-coder, sonnet) → just q
```

### Complex (architecture, multi-system)
```
Task(Explore, opus) + Task(system-architect, opus)  [parallel, planning phase]
        ↓
Task(aria-coder, sonnet) + Task(aria-qa, sonnet)   [parallel, implementation phase]
        ↓
just q
```

### UI Requests (modify existing UI)
```
Task(aria-ui-ux, opus) → just q
```
Use Claude Opus for UI work - better visual/UX reasoning.

### New Design (create new UI/component)
```
/design "component description"
    ↓
┌───────────────────────────────────────────────────────┐
│           PHASE 1: PARALLEL DRAFTS                    │
├───────────────┬───────────────┬───────────────────────┤
│ Gemini        │ ChatGPT       │ Codex                 │
│ (latest)      │ gpt-5.1       │ codex-max             │
│ FREE          │ Pro sub       │ Pro sub               │
└───────┬───────┴───────┬───────┴───────────┬───────────┘
        └───────────────┴───────────────────┘
                        ↓
┌───────────────────────────────────────────────────────┐
│     PHASE 2: CLAUDE OPUS - FINAL REFINEMENT           │
│  • Reviews all 3 drafts                               │
│  • Extracts best elements from each                   │
│  • Applies superior UI/UX expertise                   │
│  • Creates final, polished design                     │
└───────────────────────────────────────────────────────┘
                        ↓
                     just q
```

**Usage:** `/design "responsive dashboard with charts and filters"`

**Flow:**
1. Script runs Gemini + ChatGPT + Codex in parallel (3 drafts)
2. Claude Opus (aria-ui-ux) reviews ALL drafts as input
3. Claude extracts best elements, discards weak parts
4. **Claude creates the FINAL refined design** (not just picking one)
5. Implement Claude's refined design
6. just q

**Claude Opus is the LAST LINE - it improves upon all others.**

**Variables created:**
- `$gemini_design`: Gemini draft (FREE)
- `$chatgpt_design`: ChatGPT gpt-5.1 draft (fast)
- `$codex_design`: Codex gpt-5.1-codex-max draft (agentic)
- `$design_comparison`: All drafts for Claude to refine

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
| Context | `just ctx "query"` (or `ctx "query"`) | Multiple Reads |
| Code gen | `codex-save.sh` | Inline generation |
| Analysis | `ai.sh fast` | Claude analysis |
| Planning | `/plan` (Gemini+Codex) | Manual planning |
| Lint | `just lint` / `composer cs-check` / `npm run lint` | Guessing |
| Test | `just test` / `composer test` / `npm test` | Assuming pass |
| Quality | `just q` / `quality-gate.sh` | Skipping |

## CLI Execution (Haiku - Simple Tasks Only)
Simple, mechanical CLI commands can use Haiku:
```bash
# Pattern: Task(aria-admin, haiku) for simple CLI work
Task(aria-admin, haiku, prompt:"Run: git status")
Task(aria-admin, haiku, prompt:"Run: git add . && git commit -m 'msg'")
```

**CLI commands that can use Haiku (simple, clearly-defined):**
- git status, git add, git commit, git push (basic operations)
- File operations (copy, move, delete)
- Simple checks (file existence, directory listing)

**Use Opus for:**
- Any task requiring decision-making or analysis
- Code generation or modification
- Complex git operations (rebases, conflict resolution)
- Deployment decisions

## Rules
1. **FREE first**: Always try external tools before subagents (prefer `just` commands)
2. **Haiku for simple only**: Simple, mechanical tasks (git status, file ops)
3. **Opus for coding**: All implementation, architecture, and analysis tasks
4. **Parallel when independent**: Single message, multiple Task calls
5. **Claude orchestrates only**: No code generation in main thread
6. **Quality gate mandatory**: Every implementation ends with `just q`

## Agent Prompt Template
```
EXTERNAL-FIRST: Use these before Claude processing:
- just ctx "query" (or ctx "query") / gemini @. for context
- codex-save.sh for code generation
- ai.sh fast for quick analysis
- Run just q / lint/test/quality-gate.sh for validation
- Check just --list for available project commands
```

Ready for task.
