---
description: Run task with 4-tier hybrid workflow (fast + token-efficient)
argument-hint: <task description>
---

# Fast Hybrid Workflow

Execute this task using the optimized 4-tier workflow with **variable-passing** for maximum speed and minimal token usage.

## Variable-Passing Protocol (MANDATORY)

**Always use references, never inline data:**

```bash
# Search → auto-saves to $ctx_last
ctx "query"

# Pass reference to LLM (NOT inline data)
llm codex "implement X based on @var:ctx_last"
llm fast "summarize @var:ctx_last"

# Chain responses
llm qa "review @var:llm_response_last"
```

| Variable | Contains | Auto-saved by |
|----------|----------|---------------|
| `$ctx_last` | Last context search | `ctx "query"` |
| `$llm_response_last` | Last LLM response | `llm` command |
| `$grep_last` | Last grep result | Claude Grep |

## Smart Routing Check

**Use Claude directly for:**
- Complex logic: payment, security, auth, database, migration, refactor
- UI/Design: css, html, design, layout, responsive, frontend, component
- Keywords: complex, tricky, critical, production

**Use External Tools for:**
- Simple searches and exploration
- Boilerplate code generation
- Standard patterns
- Documentation lookup

## Workflow by Task Type

### For Complex/UI Tasks → Claude Direct
If the task matches complexity indicators, proceed with Claude directly.

### For Simple Tasks → 4-Tier Workflow with Variables

#### Step 1: Context (ctx → $ctx_last)
```bash
ctx "relevant search terms for: $ARGUMENTS"
# Auto-saves to $ctx_last
```

#### Step 2: Generation (llm with @var: reference)
```bash
# For Codex (reads file directly - BEST quality)
llm codex "implement $ARGUMENTS using @var:ctx_last"

# For quick generation (inlines content)
llm fast "$ARGUMENTS based on @var:ctx_last"
```

#### Step 3: Review (llm with chained reference)
```bash
llm qa "Review @var:llm_response_last for quality issues"
```

#### Step 4: Implement Fixes (Claude)
If review finds issues, Claude implements the fixes.

## Quick Reference

| Task | Command | Variable Saved |
|------|---------|----------------|
| Search context | `ctx "query"` | `$ctx_last` |
| Codex (file read) | `llm codex "task @var:ctx_last"` | `$llm_response_last` |
| Gemini (file read) | `llm gemini "task @var:ctx_last"` | `$llm_response_last` |
| Fast (inline) | `llm fast "task @var:ctx_last"` | `$llm_response_last` |
| QA review | `llm qa "review @var:llm_response_last"` | `$llm_response_last` |

## Variable Management

```bash
var list                    # See all session variables
var get ctx_last --meta     # Check age, size, query
var fresh ctx_last 5        # Check if <5 min old
var clear                   # Reset session
```

## Why Variables Matter

| Approach | Data Transferred | Quality |
|----------|-----------------|---------|
| Old (inline) | 21KB per chain | Truncated context |
| New (references) | 116 bytes | Full file access |

**Codex/Gemini read files directly** - they get FULL context, not truncated.

## Token Comparison

| Approach | Claude Tokens | When to Use |
|----------|---------------|-------------|
| External + vars | ~5-10% | Simple tasks |
| Claude direct | 100% | Complex/UI tasks |
| Hybrid | ~30-50% | Mixed workloads |

---

The task to execute: $ARGUMENTS

**Remember**: Use `ctx` first, then `llm` with `@var:ctx_last` references.
