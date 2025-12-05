---
description: Collaborative planning (Gemini 1M context + Codex) - FREE
argument-hint: <task description>
---

# Collaborative Plan Pipeline

Run the Gemini + Codex collaborative planning:

```bash
~/.claude/scripts/plan-pipeline.sh "$ARGUMENTS"
```

## Flow

```
Gemini (1M context) → Codex (plan) → Gemini (review) → Claude
       ↓                   ↓              ↓
  deep analysis    implementation    validation
     FREE              FREE            FREE
```

## How It Works

1. **Gemini** analyzes codebase with 1M token context
2. **Codex** creates implementation plan using Gemini's analysis
3. **Gemini** reviews plan against codebase for accuracy
4. **Claude** receives combined output for final review

## After Review

| Action | Command |
|--------|---------|
| APPROVE | `/apply` (aria-coder implements) |
| MODIFY | Edit `$codex_plan`, then `/apply` |
| REJECT | `/thinking` (Opus deep reasoning) |

## Variables Created

| Variable | Contents |
|----------|----------|
| `$gemini_context` | Deep codebase analysis |
| `$codex_plan` | Implementation plan |
| `$gemini_review` | Plan validation |
| `$combined_plan` | All outputs combined |
