# Claude Code Multi-Model Setup Guide

A token-efficient setup that combines Claude Code with external AI tools (Gemini, Codex, OpenRouter) to reduce costs and improve speed.

## Overview

Instead of using Claude for everything, this setup routes tasks to the best tool:

| Task | Tool | Cost | Speed |
|------|------|------|-------|
| Search/Analysis | Gemini CLI | FREE (Google account) | Fast |
| Complex Code/Review | Codex CLI | FREE (ChatGPT subscription) | Fast |
| Simple Code | OpenRouter API | ~$0.14/M tokens | Very Fast |
| Planning/Architecture | Claude | Subscription | Best quality |

**Result**: 80-90% reduction in Claude token usage for typical coding sessions.

---

## Prerequisites

- **Claude Code CLI** installed and authenticated
- **Google account** (for Gemini - free tier: 60 req/min, 1M token context)
- **ChatGPT Plus/Pro subscription** (for Codex - included free)
- **OpenRouter account** with API key (optional, for ultra-fast generation)

---

## Installation

### 1. Install Gemini CLI

```bash
npm install -g @google/gemini-cli
gemini  # Run once to authenticate with Google
```

### 2. Install Codex CLI

```bash
npm install -g @openai/codex
codex  # Run once to authenticate with OpenAI
```

### 3. Configure OpenRouter (Optional)

```bash
# Get API key from https://openrouter.ai/keys
mkdir -p ~/.config/openrouter
echo "sk-or-v1-your-key-here" > ~/.config/openrouter/api_key

# Add to shell profile for persistence
echo 'export OPENROUTER_API_KEY=$(cat ~/.config/openrouter/api_key 2>/dev/null)' >> ~/.bashrc
```

---

## Setup Files

### Create the AI helper script

Save as `~/.claude/scripts/ai.sh`:

```bash
#!/bin/bash
# Unified AI tool - uses your existing subscriptions
# Usage: ai.sh <tool> "prompt" [files...]

TOOL="${1:-fast}"
shift
PROMPT="$*"

case "$TOOL" in
    codex|c)
        echo "🤖 Codex (GPT)..." >&2
        codex "$PROMPT"
        ;;
    gemini|g)
        echo "🔍 Gemini..." >&2
        gemini "$PROMPT"
        ;;
    fast|f)
        echo "⚡ OpenRouter..." >&2
        KEY=$(cat ~/.config/openrouter/api_key 2>/dev/null)
        curl -s https://openrouter.ai/api/v1/chat/completions \
            -H "Authorization: Bearer $KEY" \
            -H "Content-Type: application/json" \
            -d "{
                \"model\": \"deepseek/deepseek-chat\",
                \"messages\": [{\"role\": \"user\", \"content\": $(echo "$PROMPT" | jq -Rs .)}],
                \"max_tokens\": 8000
            }" | jq -r '.choices[0].message.content'
        ;;
esac
```

Make executable:
```bash
chmod +x ~/.claude/scripts/ai.sh
```

### Create routing mode file

```bash
echo "fast" > ~/.claude/routing-mode
```

### Update Claude's global instructions

Save as `~/.claude/CLAUDE.md`:

```markdown
# Global Rules - FOLLOW STRICTLY

## CRITICAL: Use External Tools First (Saves Claude Tokens)

Check `~/.claude/routing-mode` for current mode. Default is **fast** (external tools).

### Fast Mode (Default) - Use External Tools via Bash

| Task Type | Tool | Command |
|-----------|------|---------|
| Search/Analysis | Gemini (FREE) | `gemini "query" @files` |
| Simple code | OpenRouter | `ai.sh fast "prompt"` |
| Complex code | Codex (FREE) | `codex "implement..."` |
| Code review | Codex (FREE) | `codex "review..."` |
| Write tests | Codex (FREE) | `codex "write tests..."` |

**Run these via the Bash tool.** They use your existing subscriptions - not Claude tokens.

### Switch Modes
- `/mode fast` - Use external tools (saves tokens)
- `/mode aria` - Use Claude agents (best quality)
```

### Create the mode toggle command

Save as `~/.claude/commands/mode.md`:

```markdown
---
description: Toggle routing mode between external tools (fast) and Claude agents (aria)
argument-hint: [fast|aria|status]
---

# Routing Mode Toggle

Based on the argument:

### "fast" or "external":
\`\`\`bash
echo "fast" > ~/.claude/routing-mode && echo "✅ Mode: FAST (external tools)"
\`\`\`

### "aria" or "claude":
\`\`\`bash
echo "aria" > ~/.claude/routing-mode && echo "✅ Mode: ARIA (Claude agents)"
\`\`\`

### "status" or empty:
\`\`\`bash
cat ~/.claude/routing-mode 2>/dev/null || echo "fast"
\`\`\`
```

---

## Usage

### Direct Commands

```bash
# Search codebase (Gemini - FREE, 1M token context)
gemini "find where user authentication happens" @src/**/*.php

# Generate simple code (OpenRouter - ~$0.14/M tokens)
ai.sh fast "write a PHP function to validate email"

# Complex implementation (Codex - FREE with ChatGPT sub)
codex "implement JWT authentication for this Express app"

# Code review (Codex - FREE)
codex "review this code for security vulnerabilities"

# Write tests (Codex - FREE)
codex "write unit tests for UserController"
```

### Within Claude Code

When in fast mode, Claude will suggest external tools. Just tell it what you want:

```
"find where users login"        → Claude suggests: gemini "query" @files
"write a validation function"   → Claude suggests: ai.sh fast "prompt"
"implement the payment system"  → Claude suggests: codex "implement..."
"review this for security"      → Claude suggests: codex "review..."
```

### Switch Modes

```
/mode fast    # Use external tools (default)
/mode aria    # Use Claude agents
/mode status  # Show current mode
```

---

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                      YOUR PROMPT                            │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ ~/.claude/      │
                    │ routing-mode    │
                    │ = "fast"        │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              ▼                             ▼
       ┌─────────────┐              ┌──────────────┐
       │ FAST MODE   │              │ ARIA MODE    │
       │ (external)  │              │ (Claude)     │
       └──────┬──────┘              └──────┬───────┘
              │                            │
    ┌─────────┼─────────┐                  │
    ▼         ▼         ▼                  ▼
┌───────┐ ┌───────┐ ┌────────┐      ┌────────────┐
│Gemini │ │Codex  │ │OpenRtr │      │Claude      │
│(FREE) │ │(FREE) │ │($0.14M)│      │Agents      │
└───────┘ └───────┘ └────────┘      └────────────┘
```

---

## Cost Comparison

### Before (All Claude)

| Task | Tokens | Cost |
|------|--------|------|
| Search codebase | 2,000 | Subscription |
| Generate code | 5,000 | Subscription |
| Review code | 2,000 | Subscription |
| Write tests | 3,000 | Subscription |
| **Total** | **12,000 Claude tokens** | Uses quota |

### After (Hybrid)

| Task | Tool | Claude Tokens | External Cost |
|------|------|---------------|---------------|
| Search codebase | Gemini | 0 | FREE |
| Generate code | OpenRouter | 0 | $0.001 |
| Review code | Codex | 0 | FREE |
| Write tests | Codex | 0 | FREE |
| Planning only | Claude | 1,500 | Subscription |
| **Total** | | **1,500 Claude tokens** | ~$0.001 |

**Savings: 87.5% fewer Claude tokens**

---

## Tool Capabilities

### Gemini CLI
- **Context**: 1M tokens (can analyze entire codebases)
- **Cost**: FREE (60 requests/min)
- **Best for**: Search, analysis, understanding code
- **Syntax**: `gemini "prompt" @file1 @file2` or `gemini "prompt" @src/**/*.php`

### Codex CLI
- **Model**: GPT-4/GPT-5 (your ChatGPT subscription)
- **Cost**: FREE (included with ChatGPT Plus/Pro)
- **Best for**: Complex implementation, code review, tests
- **Modes**:
  - Interactive: `codex "task"`
  - Auto-edit: `codex --approval-mode auto-edit "task"`
  - Full-auto: `codex --approval-mode full-auto "task"`

### OpenRouter
- **Models**: DeepSeek, Grok, Qwen, etc.
- **Cost**: $0.14-2.00 per million tokens
- **Best for**: Quick simple code generation
- **Speed**: 0.5-3 seconds per request

---

## Troubleshooting

### Gemini not working
```bash
gemini  # Re-authenticate
```

### Codex not working
```bash
codex  # Re-authenticate with OpenAI
```

### OpenRouter errors
- Check API key: `cat ~/.config/openrouter/api_key`
- Check balance: https://openrouter.ai/account
- Some models require privacy settings change: https://openrouter.ai/settings/privacy

### Claude not suggesting external tools
```bash
cat ~/.claude/routing-mode  # Should say "fast"
echo "fast" > ~/.claude/routing-mode  # Reset if needed
```

---

## Summary

| Tool | Auth | Cost | Use For |
|------|------|------|---------|
| Gemini | Google account | FREE | Search, analysis |
| Codex | ChatGPT subscription | FREE | Complex code, review, tests |
| OpenRouter | API key | ~$0.14/M | Quick generation |
| Claude | Subscription | Quota | Planning, architecture |

This setup maximizes value from your existing subscriptions while minimizing Claude token usage.
