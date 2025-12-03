#!/bin/bash
# Fast routing hook - uses external models for speed
# Injects instructions to use Gemini/OpenRouter/Codex instead of Claude agents

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.user_prompt // ""' 2>/dev/null | tr '[:upper:]' '[:lower:]')

[ -z "$PROMPT" ] && exit 0

# Patterns for fast external routing
SEARCH_PATTERNS="(find|search|where|locate|look for|show me|list all)"
SIMPLE_CODE_PATTERNS="(write a|create a|generate a|add a).*(function|method|class|component|validator|helper)"
COMPLEX_CODE_PATTERNS="(implement|build|refactor|fix all|create system|add feature)"
ANALYSIS_PATTERNS="(analyze|explain|summarize|review|understand)"

# Determine routing
ROUTE=""
COMMAND=""

if echo "$PROMPT" | grep -qiE "$SEARCH_PATTERNS"; then
    ROUTE="gemini"
    COMMAND="Use Gemini CLI for this search (faster, 1M context). Run: gemini \"$PROMPT\" @src/**/*.php"

elif echo "$PROMPT" | grep -qiE "$SIMPLE_CODE_PATTERNS"; then
    ROUTE="openrouter"
    COMMAND="Use OpenRouter API for simple code generation (faster). Call deepseek/deepseek-chat or x-ai/grok-3-mini-beta via curl."

elif echo "$PROMPT" | grep -qiE "$COMPLEX_CODE_PATTERNS"; then
    ROUTE="codex"
    COMMAND="Use Codex CLI for complex implementation (autonomous). Run: codex --approval-mode auto-edit \"$PROMPT\""

elif echo "$PROMPT" | grep -qiE "$ANALYSIS_PATTERNS"; then
    ROUTE="gemini"
    COMMAND="Use Gemini CLI for analysis (faster, huge context). Run: gemini \"$PROMPT\" @relevant_files"
fi

if [ -n "$ROUTE" ]; then
    cat << EOF
<user-prompt-submit-hook>
⚡ SPEED OPTIMIZATION AVAILABLE

**Recommended**: Use **$ROUTE** instead of Claude agents for faster execution.

$COMMAND

External model routing:
- gemini → Large context search/analysis (1M tokens, ~2-3s)
- openrouter → Simple code generation (Grok/DeepSeek, ~1-2s)
- codex → Complex autonomous implementation (full-auto mode)

Use Bash tool to invoke these. Fall back to Claude agents only for:
- Security-critical code
- Complex architectural decisions
- Multi-step reasoning tasks
</user-prompt-submit-hook>
EOF
fi

exit 0
