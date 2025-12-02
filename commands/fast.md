---
description: Run task with 4-tier hybrid workflow (fast + token-efficient)
argument-hint: <task description>
---

# Fast Hybrid Workflow

Execute this task using the optimized 4-tier workflow for maximum speed and minimal Claude token usage.

## Workflow Steps

### Step 1: Context (Gemini - FREE, 2M context)
Run this command to gather codebase context:
```bash
gemini "Find relevant code patterns and files for: $ARGUMENTS" @src/**/*.php
```

### Step 2: Planning (Claude - You do this)
Based on the Gemini context, create a detailed specification with:
- Technical requirements
- Step-by-step implementation
- Code structure
- Validation rules
- Test cases

Keep the spec concise but complete - OpenRouter needs clear instructions.

### Step 3: Generation (OpenRouter - Ultra-fast)
For simple tasks, run:
```bash
cat > /tmp/task-prompt.txt << 'PROMPT'
[Paste your specification here]
PROMPT

curl -s https://openrouter.ai/api/v1/chat/completions \
  -H "Authorization: Bearer $(cat ~/.config/openrouter/api_key)" \
  -H "Content-Type: application/json" \
  -d "{\"model\": \"x-ai/grok-3-mini-beta\", \"messages\": [{\"role\": \"user\", \"content\": $(jq -Rs . < /tmp/task-prompt.txt)}], \"max_tokens\": 4000}" | jq -r '.choices[0].message.content'
```

For complex tasks, use `deepseek/deepseek-chat` or `qwen/qwen3-235b-a22b`.

### Step 4: Review (Codex - FREE)
```bash
codex "Review this code for quality and security issues: [paste code]"
```

## Quick One-Liner
For simple code generation:
```bash
gemini "context for: $ARGUMENTS" @src/**/*.php && echo "Now generating..." && curl -s https://openrouter.ai/api/v1/chat/completions -H "Authorization: Bearer $(cat ~/.config/openrouter/api_key)" -H "Content-Type: application/json" -d '{"model": "x-ai/grok-3-mini-beta", "messages": [{"role": "user", "content": "$ARGUMENTS"}], "max_tokens": 4000}' | jq -r '.choices[0].message.content'
```

## Token Comparison
| Approach | Claude Tokens | Speed |
|----------|---------------|-------|
| Direct Claude | 100% | Baseline |
| Aria Agents | 100%+ (overhead) | Slower |
| **This Workflow** | **~15-20%** | **2-5x faster** |

The task to execute: $ARGUMENTS
