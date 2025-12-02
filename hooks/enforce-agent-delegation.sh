#!/bin/bash
# Smart routing hook - routes based on ~/.claude/routing-mode setting
# Modes: "fast" (external tools) or "aria" (Claude agents)
# External tools: gemini, codex, fast-gen.sh (OpenRouter)
# Aria agents: aria-coder, aria-qa, etc. (Claude subprocesses)

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.user_prompt // .prompt // .message // ""' 2>/dev/null | tr '[:upper:]' '[:lower:]')

[ -z "$PROMPT" ] && exit 0

# Check routing mode (default: fast)
MODE=$(cat ~/.claude/routing-mode 2>/dev/null || echo "fast")

# Show mode to user (stderr goes to terminal)
if [ "$MODE" = "fast" ]; then
    echo "⚡ Fast mode (gemini/codex/openrouter)" >&2
else
    echo "🔄 Aria mode (Claude agents)" >&2
fi

# Task pattern detection
SEARCH_PATTERNS="(find|search|where|locate|look for|show me|list all)"
SIMPLE_CODE="(write a|create a|generate a|add a).*(function|method|helper|validator|utility)"
COMPLEX_CODE="(implement|build|refactor|fix all|create system|add feature|redesign)"
ANALYSIS="(analyze|explain|summarize|understand|how does)"
TEST_PATTERNS="(test|write tests|add tests|create tests)"
DOC_PATTERNS="(document|write docs|add documentation)"
GIT_PATTERNS="(commit|push|pull|branch|merge|changelog)"
REVIEW_PATTERNS="(review|check|audit|security)"

# Determine best routing
ROUTE=""
TOOL=""
COMMAND=""
FALLBACK=""

if echo "$PROMPT" | grep -qiE "$SEARCH_PATTERNS"; then
    ROUTE="EXTERNAL"
    TOOL="Gemini (your Google account)"
    COMMAND="gemini \"query\" @src/**/*.php"
    FALLBACK="Explore agent"

elif echo "$PROMPT" | grep -qiE "$SIMPLE_CODE"; then
    ROUTE="EXTERNAL"
    TOOL="OpenRouter (fast)"
    COMMAND="ai.sh fast \"prompt\""
    FALLBACK="aria-coder agent"

elif echo "$PROMPT" | grep -qiE "$COMPLEX_CODE"; then
    ROUTE="EXTERNAL"
    TOOL="Codex (your GPT account)"
    COMMAND="codex \"implement: ...\""
    FALLBACK="aria-coder agent"

elif echo "$PROMPT" | grep -qiE "$ANALYSIS"; then
    ROUTE="EXTERNAL"
    TOOL="Gemini (your Google account)"
    COMMAND="gemini \"query\" @files"
    FALLBACK="Explore agent"

elif echo "$PROMPT" | grep -qiE "$TEST_PATTERNS"; then
    ROUTE="EXTERNAL"
    TOOL="Codex (your GPT account)"
    COMMAND="codex \"write tests for: ...\""
    FALLBACK="aria-qa agent"

elif echo "$PROMPT" | grep -qiE "$DOC_PATTERNS"; then
    ROUTE="AGENT"
    TOOL="aria-docs"
    FALLBACK=""

elif echo "$PROMPT" | grep -qiE "$GIT_PATTERNS"; then
    ROUTE="AGENT"
    TOOL="aria-admin"
    FALLBACK=""

elif echo "$PROMPT" | grep -qiE "$REVIEW_PATTERNS"; then
    ROUTE="EXTERNAL"
    TOOL="Codex (your GPT account)"
    COMMAND="codex \"review: ...\""
    FALLBACK="code-review agent"
fi

# Output recommendation based on mode
if [ -n "$ROUTE" ]; then
    if [ "$MODE" = "aria" ]; then
        # ARIA MODE: Always suggest Claude agents
        AGENT=""
        case "$ROUTE" in
            EXTERNAL)
                if [ "$TOOL" = "Gemini CLI" ]; then AGENT="Explore"; fi
                if [ "$TOOL" = "OpenRouter (DeepSeek)" ]; then AGENT="aria-coder"; fi
                if [ "$TOOL" = "Codex CLI" ]; then AGENT="code-review"; fi
                ;;
            HYBRID) AGENT="aria-coder" ;;
            AGENT) AGENT="$TOOL" ;;
        esac
        [ -z "$AGENT" ] && AGENT="aria-coder"

        cat << EOF
<user-prompt-submit-hook>
🔄 ARIA MODE: Use Claude agents

**Route to**: $AGENT agent
**Command**: Task tool with subagent_type="$AGENT"

Mode: aria (Claude agents) - change with /mode fast
</user-prompt-submit-hook>
EOF
    else
        # FAST MODE: Suggest external tools
        if [ "$ROUTE" = "EXTERNAL" ] || [ "$ROUTE" = "HYBRID" ]; then
            cat << EOF
<user-prompt-submit-hook>
⚡ FAST MODE: Use external tools (saves Claude tokens)

**Recommended**: $TOOL
**Command**: $COMMAND
**Fallback**: $FALLBACK (uses Claude tokens)

Your tools (all FREE with your subscriptions):
- Search/Analysis → gemini "query" @files
- Simple code → ai.sh fast "prompt"
- Complex code → codex "implement..."
- Code review → codex "review..."
- Tests → codex "write tests..."

Mode: fast (external tools) - change with /mode aria
</user-prompt-submit-hook>
EOF
        else
            cat << EOF
<user-prompt-submit-hook>
🔄 AGENT: Use $TOOL

Task tool with subagent_type="$TOOL"

Mode: fast - but this task best handled by Claude agent
</user-prompt-submit-hook>
EOF
        fi
    fi
fi

exit 0
