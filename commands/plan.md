---
description: Plan task with external tools (Gemini+Codex FREE)
argument-hint: <task description>
---

# Plan Pipeline Entry Point

Run the external-first planning pipeline:

```bash
~/.claude/scripts/plan-pipeline.sh "$ARGUMENTS"
```

## Flow

```
Gemini (context, FREE) → Codex (plan, FREE) → You review
```

## After Review

| Action | Command |
|--------|---------|
| APPROVE | `/apply` to implement |
| MODIFY | Edit plan, then `/apply` |
| REJECT | `/thinking` for Opus reasoning |

## Variables Created

- `$codex_plan` - The implementation plan
- `$gemini_context` - Gathered context (cached 10 min)
