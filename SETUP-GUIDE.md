# Claude Code Multi-Model Setup Guide

A token-efficient setup using ARIA workflow with integrated external tools.

## Overview

ARIA (Agent-based Routing and Integration Architecture) automatically routes tasks to the optimal tool:

| Task | Tool | Cost | Speed |
|------|------|------|-------|
| Context/Analysis | Gemini CLI | FREE | Fast |
| Code Generation | Codex CLI | FREE | Fast |
| Quick Checks | OpenRouter | ~$0.001 | Very Fast |
| Application | Claude (Haiku) | 0.1x | Fast |
| Deep Reasoning | Claude (Opus) | 10x | Best quality |

**Result**: 85-93% reduction in Claude token usage.

---

## Prerequisites

- **Claude Code CLI** installed and authenticated
- **Google account** (for Gemini - free tier: 60 req/min, 1M token context)
- **ChatGPT Plus/Pro subscription** (for Codex - included free)
- **OpenRouter account** with API key (optional, for ultra-fast checks)

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
mkdir -p ~/.config/openrouter
echo "sk-or-v1-your-key-here" > ~/.config/openrouter/api_key
```

---

## ARIA Workflow

```
┌─────────────────────────────────────────────────────┐
│  1. PARALLEL PLANNING (FREE)                        │
│     gemini @. "analyze" ─┬─► merged context         │
│     codex "plan task"   ─┘                          │
├─────────────────────────────────────────────────────┤
│  2. USER REVIEW                                     │
│     APPROVE → step 3a | REJECT → step 3b            │
├─────────────────────────────────────────────────────┤
│  3a. IMPLEMENT (FREE → Haiku apply)                 │
│     codex-save.sh → aria-coder applies              │
│                                                     │
│  3b. DEEP REASONING (Opus)                          │
│     aria-thinking → revised plan → Haiku implements │
├─────────────────────────────────────────────────────┤
│  4. QUALITY GATE (MANDATORY)                        │
│     quality-gate.sh → PASS/FAIL                     │
└─────────────────────────────────────────────────────┘
```

---

## Quick Reference

| Need | Command |
|------|---------|
| Plan task | `plan-pipeline.sh "description"` |
| Generate code | `codex-save.sh "prompt"` |
| Search context | `ctx "what to find"` |
| Quick answer | `ai.sh fast "question"` |
| Quality check | `quality-gate.sh` |

---

## External-First Rules (MANDATORY)

| Action | Tool | NEVER | Savings |
|--------|------|-------|---------|
| Context | `ctx "query"` | Multiple Reads | 100% |
| Generate >3 lines | `codex-save.sh` | Inline code | 100% |
| Quick check | `ai.sh fast` | Full analysis | 100% |
| Architecture | `gemini @.` | Manual exploration | 100% |

---

## Usage Examples

```bash
# Search codebase (Gemini - FREE, 1M token context)
gemini "find where user authentication happens" @src/**/*.php

# Generate code and save to variable
codex-save.sh "implement JWT authentication"

# Quick check (OpenRouter - ~$0.001)
ai.sh fast "what does this regex do: ^[a-z]+$"

# Full planning pipeline
plan-pipeline.sh "add user authentication"
```

---

## Tool Capabilities

### Gemini CLI
- **Context**: 1M tokens (can analyze entire codebases)
- **Cost**: FREE (60 requests/min)
- **Best for**: Search, analysis, understanding code
- **Syntax**: `gemini "prompt" @file` or `gemini "prompt" @.`

### Codex CLI
- **Model**: GPT-4/GPT-5 (your ChatGPT subscription)
- **Cost**: FREE (included with ChatGPT Plus/Pro)
- **Best for**: Complex implementation, code review, tests

### OpenRouter (via ai.sh)
- **Models**: DeepSeek, Grok, Qwen, etc.
- **Cost**: $0.14-2.00 per million tokens
- **Best for**: Quick simple checks
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

---

## Summary

| Tool | Auth | Cost | Use For |
|------|------|------|---------|
| Gemini | Google account | FREE | Context, analysis |
| Codex | ChatGPT subscription | FREE | Code generation |
| OpenRouter | API key | ~$0.001 | Quick checks |
| Claude Haiku | Subscription | 0.1x | Apply changes |
| Claude Opus | Subscription | 10x | Complex reasoning |

ARIA automatically routes to the optimal tool - no manual mode switching needed.
