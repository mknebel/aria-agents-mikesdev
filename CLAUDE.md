# Claude Code - ARIA ENFORCED

## ARIA IS ALWAYS ACTIVE - NO EXCEPTIONS

You MUST follow ARIA workflow for ALL tasks. This is not optional.

## Cost Hierarchy (ENFORCED) - Updated Dec 2025
```
GPT-5.1 beats o3: 74.9% vs 69.1% SWE, 94.6% vs 88.9% AIME
GPT-5.1 uses 50-80% fewer tokens than o-series!

1. FREE              → gemini, ctx (1M+ context, analysis)
2. ChatGPT Pro       → gpt-5.1 (general: 74.9% SWE, 94.6% AIME)
3. ChatGPT Pro       → codex-max (complex code: 77.9% SWE)
4. ChatGPT Pro       → o4-mini (explicit step-by-step, fast)
5. ChatGPT Pro       → o3 (deep proofs, explicit reasoning)
6. ChatGPT Pro       → o3-pro (only when everything fails)
7. Claude Haiku      → File ops only (minimal tokens)
8. Claude Opus       → UI/UX only (LAST RESORT)
```

## Model Routing (GPT-5.1 First)
```
Context/Analysis    → gemini (FREE, 1M tokens)
General Tasks       → gpt-5.1 (BEST: 74.9% SWE, 94.6% AIME)
Code Generation     → codex-max (77.9% SWE-bench)
Math/Calculations   → gpt-5.1 (94.6% AIME, better than o-series)
Explicit Reasoning  → o4-mini/o3 (step-by-step proofs)
Complex/Failed      → o3-pro (most reliable)
File Operations     → Claude Haiku (minimal)
UI/UX Design        → Claude Opus (last line)
```

## Claude's Role (ENFORCED)
- **DO**: Orchestrate, delegate, REVIEW generated code, consolidate results
- **DO**: Check consistency, completeness, themes, security, patterns
- **DON'T**: Generate code inline, analyze large files, do heavy reasoning
- **NEVER**: Skip external tools, generate >3 lines of code directly

## Code Review (Claude's Primary Value)
After external tools generate code, Claude MUST review for:
```
□ Consistency with existing codebase patterns
□ Complete implementation (nothing missed)
□ Theme/style adherence (Bootstrap, Porto Admin, etc.)
□ Security (no injection, XSS, SQL injection)
□ Error handling and edge cases
□ Database patterns (soft deletes, multi-tenant)
□ No breaking changes
```

## Mandatory Routing

### Code Tasks (Generate → Review → Apply)
```
1. Context    → gemini/ctx (FREE)
2. Generate   → codex-mini/codex/codex-max (Pro flat)
3. Review     → Claude Opus (check consistency, completeness, themes)
4. Apply      → codex-mini or Haiku (if approved)
5. Validate   → quality-gate.sh (FREE)
```

### Task Complexity
```
Simple (1-2 files)  → codex-mini generate → Claude review → apply
Medium (3+ files)   → /plan → codex generate → Claude review → apply
Complex             → /plan → codex-max → Claude review → parallel apply
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
| Context | `ctx` or `gemini` (FREE) | Multiple Reads |
| General tasks | `aria route general` (gpt-5.1) | Claude thinking |
| Code gen >3 lines | `aria route code` (codex-max) | Inline generation |
| Math | `aria route math` (gpt-5.1, 94.6%) | Claude calculation |
| Explicit proofs | `aria route reason` (o3) | When gpt-5.1 works |
| Complex/failed | `aria route deep` (o3-pro) | First attempt |
| Planning | `/plan` | Manual planning |
| Quality | `quality-gate.sh` | Skipping validation |

## Rules (VIOLATION = NON-COMPLIANT)

1. **FREE first**: ALWAYS try external tools before subagents
2. **Haiku for CLI**: ALL deterministic commands via haiku
3. **No inline code**: NEVER generate >3 lines of code in main thread
4. **Parallel execution**: Launch independent agents in single message
5. **Quality gate**: EVERY implementation ends with quality-gate.sh
6. **Claude = orchestrator**: Delegate, don't implement
7. **NO AUTO-COMMIT**: NEVER commit unless user explicitly requests it
8. **NO AUTO-PUSH**: NEVER push unless user explicitly requests it

## Violation Examples

❌ **WRONG**: Reading 5+ files directly instead of using `ctx`
❌ **WRONG**: Generating 20 lines of code inline
❌ **WRONG**: Running `git commit` directly instead of via haiku agent
❌ **WRONG**: Skipping `/plan` for multi-file changes
❌ **WRONG**: Creating UI without running `/design` pipeline
❌ **WRONG**: Auto-committing after making changes
❌ **WRONG**: Pushing to remote without explicit user request

✅ **RIGHT**: `ctx "find auth files"` → review summary → delegate
✅ **RIGHT**: `aria route code "implement feature"` → codex-max generates
✅ **RIGHT**: `aria route reason "debug issue"` → o3 analyzes
✅ **RIGHT**: `/design "new dashboard"` → drafts → Claude Opus refines
✅ **RIGHT**: `Task(aria-admin, haiku, "git commit...")` for file ops

## Session Behavior

ARIA is ALWAYS active. Every session. No activation needed.
Follow the cost hierarchy and routing rules for ALL tasks.
