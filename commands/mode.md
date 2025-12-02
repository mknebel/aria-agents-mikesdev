---
description: Toggle routing mode between external tools (fast) and Aria agents (Claude)
argument-hint: [fast|aria|status]
---

# Routing Mode Toggle

Toggle between external tools (fast, token-saving) and Aria agents (Claude-based).

## Current Mode

Check the current mode:
```bash
cat ~/.claude/routing-mode 2>/dev/null || echo "fast (default)"
```

## Usage

Based on the argument provided:

### If argument is "fast" or "external":
Set mode to use external tools (Gemini, Codex, OpenRouter):
```bash
echo "fast" > ~/.claude/routing-mode && echo "✅ Mode set to FAST (external tools)"
echo ""
echo "Routes to:"
echo "  - Search → gemini CLI (FREE)"
echo "  - Simple code → OpenRouter/DeepSeek (~$0.14/M)"
echo "  - Complex code → Claude spec + OpenRouter"
echo "  - Review → codex CLI (FREE)"
echo ""
echo "Benefits: 80-100% Claude token savings, often faster"
```

### If argument is "aria" or "agents" or "claude":
Set mode to use Aria agents (Claude subagents):
```bash
echo "aria" > ~/.claude/routing-mode && echo "✅ Mode set to ARIA (Claude agents)"
echo ""
echo "Routes to:"
echo "  - Coding → aria-coder agent"
echo "  - Search → Explore agent"
echo "  - Testing → aria-qa agent"
echo "  - Docs → aria-docs agent"
echo ""
echo "Benefits: Best reasoning, consistent quality"
```

### If argument is "status" or empty:
Show current mode and explain options:
```bash
CURRENT=$(cat ~/.claude/routing-mode 2>/dev/null || echo "fast")
echo "Current routing mode: $CURRENT"
echo ""
echo "Available modes:"
echo "  /mode fast  - Use external tools (saves Claude tokens)"
echo "  /mode aria  - Use Aria agents (Claude subagents)"
echo ""
echo "Current setting persists across sessions."
```

## Mode Comparison

| Aspect | fast (external) | aria (Claude) |
|--------|-----------------|---------------|
| Token cost | $0-2/M (external) | Claude subscription |
| Speed | Often 2-5x faster | Baseline |
| Quality | Good for defined tasks | Best reasoning |
| Best for | Simple code, search | Complex logic |

The argument provided: $ARGUMENTS
