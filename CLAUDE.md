# Claude Code - ARIA ENFORCED

## ARIA IS ALWAYS ACTIVE - NO EXCEPTIONS

You MUST follow ARIA workflow for ALL tasks. This is not optional.

## Cost Hierarchy (ENFORCED)
```
1. FREE tools first   → ctx, gemini, codex-save.sh, quality-gate.sh
2. Haiku for CLI      → git, winscp, composer, npm, lint, test
3. Haiku subagents    → aria-coder, aria-qa, Explore
4. Opus (UI/design)   → aria-ui-ux (Claude is LAST LINE for UI/UX)
5. Opus (LAST RESORT) → aria-thinking (only for complex/failed)
```

## Claude's Role (ENFORCED)
- **DO**: Orchestrate, delegate, consolidate results
- **DON'T**: Generate code inline, analyze large files, do heavy reasoning
- **NEVER**: Skip external tools, generate >3 lines of code directly

## Mandatory Routing

### Code Tasks
```
Simple (1-2 files)  → FREE tools only → quality-gate.sh
Medium (3+ files)   → /plan first → aria-coder (haiku) → quality-gate.sh
Complex             → /plan → parallel haiku agents → quality-gate.sh
```

### UI/Design Tasks
```
Modify UI    → Task(aria-ui-ux, opus) → quality-gate.sh
New Design   → /design → 3 LLM drafts → Claude Opus refines → quality-gate.sh
```
**Claude Opus is the BEST, LAST LINE of UI/UX improvement.**

### CLI Commands (ALWAYS Haiku)
```
git, winscp, composer, npm, lint, test → Task(aria-admin, haiku)
```

## Auto-Triggers (MANDATORY)

| Condition | Action |
|-----------|--------|
| >3 files touched | Run `/plan` first |
| "implement/refactor/build" | Run `/plan` first |
| New UI/component | Run `/design` first |
| Complex/failed task | Escalate to aria-thinking (opus) |

## External-First (MANDATORY)

| Task | MUST Use | NEVER |
|------|----------|-------|
| Context | `ctx` or `gemini @.` | Multiple Reads |
| Code gen >3 lines | `codex-save.sh` | Inline generation |
| Analysis | `ai.sh fast` | Full Claude analysis |
| Planning | `/plan` | Manual planning |
| Quality | `quality-gate.sh` | Skipping validation |

## Rules (VIOLATION = NON-COMPLIANT)

1. **FREE first**: ALWAYS try external tools before subagents
2. **Haiku for CLI**: ALL deterministic commands via haiku
3. **No inline code**: NEVER generate >3 lines of code in main thread
4. **Parallel execution**: Launch independent agents in single message
5. **Quality gate**: EVERY implementation ends with quality-gate.sh
6. **Claude = orchestrator**: Delegate, don't implement

## Violation Examples

❌ **WRONG**: Reading 5+ files directly instead of using `ctx`
❌ **WRONG**: Generating 20 lines of code inline
❌ **WRONG**: Running `git commit` directly instead of via haiku agent
❌ **WRONG**: Skipping `/plan` for multi-file changes
❌ **WRONG**: Creating UI without running `/design` pipeline

✅ **RIGHT**: `ctx "find auth files"` → review summary → delegate to agent
✅ **RIGHT**: `/plan "implement feature"` → review → `/apply`
✅ **RIGHT**: `/design "new dashboard"` → drafts → Claude refines
✅ **RIGHT**: `Task(aria-admin, haiku, "git commit...")` for CLI

## Session Behavior

ARIA is ALWAYS active. Every session. No activation needed.
Follow the cost hierarchy and routing rules for ALL tasks.
