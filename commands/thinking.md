---
description: Deep reasoning via aria-thinking (Opus) for complex/failed tasks
argument-hint: <problem description>
---

# Opus Deep Reasoning

For complex tasks or when simpler approaches fail.

Use the Task tool with:
- subagent_type: aria-thinking
- model: opus
- prompt: |
    Problem: $ARGUMENTS

    Analyze deeply. Create implementation plan for aria-coder (Haiku) to execute.
    Output: Analysis, Solution, Implementation Steps, Handoff instructions.

## When to Use

| Trigger | Example |
|---------|---------|
| 2+ failures | Haiku/Sonnet couldn't solve |
| Complex keywords | "architect", "security design" |
| User escalation | "think harder" |

## Output

Opus creates plan → aria-coder (Haiku) implements.
