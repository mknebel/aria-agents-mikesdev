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

| Task Type | Route | Command | Cost |
|-----------|-------|---------|------|
| Search/explore | Gemini | `gemini "query" @files` | FREE |
| Quick code gen | OpenRouter | `ai.sh fast "task"` | ~$0.001 |
| Tool-use tasks | OpenRouter | `ai.sh tools "task"` | ~$0.01 |
| Simple code | Codex | `codex "implement..."` | FREE |
| Code review | Codex → Claude | `smart-review.sh file` | FREE → Paid |
| Complex code | Claude | Just ask Claude | Paid |
| UI/Design | Claude | Just ask Claude | Paid |

## OpenRouter Models (via ai.sh)

| Command | Model | Best For |
|---------|-------|----------|
| `ai.sh fast` | Grok-3-mini | Quick code snippets |
| `ai.sh tools` | DeepSeek V3 | Tool-use, file operations |
| `ai.sh agent` | Browser preset | UI testing, screenshots |

## Token Comparison
| Approach | Claude Tokens | When to Use |
|----------|---------------|-------------|
| External tools | ~15-20% | Simple tasks |
| Claude direct | 100% | Complex/UI tasks |
| Hybrid | ~40-60% | Mixed workloads |

The task to execute: $ARGUMENTS
