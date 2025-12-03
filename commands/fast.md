---
description: Run task with 4-tier hybrid workflow (fast + token-efficient)
argument-hint: <task description>
---

# Fast Hybrid Workflow

Execute this task using the optimized 4-tier workflow for maximum speed and minimal Claude token usage.

## Smart Routing Check

First, determine if this task should use Claude directly:

**Use Claude for (quality-critical):**
- Complex logic: payment, security, auth, database, migration, refactor
- UI/Design: css, html, design, layout, responsive, frontend, component, modal, form
- Keywords: complex, tricky, critical, production

**Use External Tools for (cost-efficient):**
- Simple searches and exploration
- Boilerplate code generation
- Standard patterns
- Documentation lookup

## Workflow by Task Type

### For Complex/UI Tasks → Claude Direct
If the task matches complexity indicators above, proceed with Claude directly:
- Read necessary files
- Implement the solution
- Claude excels at UI design, complex logic, and implementing fixes

### For Simple Tasks → 4-Tier Workflow

#### Step 1: Context (Gemini - FREE)
```bash
gemini "Find relevant code patterns and files for: $ARGUMENTS" @src/**/*.php
```

#### Step 2: Generation (OpenRouter/Codex)
For simple implementations:
```bash
codex "implement: $ARGUMENTS"
```
Or for quick generation:
```bash
ai.sh fast "$ARGUMENTS"
```

#### Step 3: Review (Codex - FREE)
```bash
codex "Review this code for quality issues: [paste code]"
```

#### Step 4: Implement Fixes (Claude)
If review finds issues, Claude implements the fixes (Codex can only identify, not fix).

## Quick Reference

| Task Type | Route | Command |
|-----------|-------|---------|
| Search/explore | Gemini | `gemini "query" @files` |
| Simple code | Codex | `codex "implement..."` |
| Code review | Codex → Claude | `smart-review.sh file` |
| Complex code | Claude | Just ask Claude |
| UI/Design | Claude | Just ask Claude |

## Token Comparison
| Approach | Claude Tokens | When to Use |
|----------|---------------|-------------|
| External tools | ~15-20% | Simple tasks |
| Claude direct | 100% | Complex/UI tasks |
| Hybrid | ~40-60% | Mixed workloads |

The task to execute: $ARGUMENTS
