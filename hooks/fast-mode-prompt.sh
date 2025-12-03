#!/bin/bash
# Consolidated: UserPromptSubmit hook for fast mode routing
# Replaces: enforce-agent-delegation.sh, implementation-mode-reminder.sh, fast-route.sh

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.user_prompt // ""' 2>/dev/null)
[[ -z "$PROMPT" || ${#PROMPT} -lt 5 ]] && exit 0

MODE=$(cat ~/.claude/routing-mode 2>/dev/null || echo "fast")
PROMPT_LOWER="${PROMPT,,}"

# Pattern categories
SEARCH="find|search|where|locate|look for|show me|list all"
SIMPLE="(write a|create a|generate a|add a).*(function|method|helper)"
COMPLEX="implement|build|refactor|fix|create system|add feature"
ANALYSIS="analyze|explain|summarize|understand|how does"
TESTS="test|write tests|add tests"
BROWSER="screenshot|browser|e2e|playwright|verify.*page"
REVIEW="review|check|audit"
UI_DESIGN="css|html|design|layout|responsive|frontend|component|modal|form|tailwind"

# Determine route
TOOL="" CMD="" FALLBACK=""

if [[ "$PROMPT_LOWER" =~ $BROWSER ]]; then
    TOOL="browser.sh" CMD="browser.sh screenshot <url>" FALLBACK="aria_qa-html-verifier"
elif [[ "$PROMPT_LOWER" =~ $UI_DESIGN ]]; then
    # UI/Design uses Claude directly
    exit 0
elif [[ "$PROMPT_LOWER" =~ $SEARCH ]]; then
    TOOL="Gemini" CMD="gemini \"query\" @files" FALLBACK="Explore"
elif [[ "$PROMPT_LOWER" =~ $TESTS ]]; then
    TOOL="Codex" CMD="codex \"write tests...\"" FALLBACK="aria-qa"
elif [[ "$PROMPT_LOWER" =~ $COMPLEX ]]; then
    TOOL="Codex" CMD="codex \"implement...\"" FALLBACK="aria-coder"
elif [[ "$PROMPT_LOWER" =~ $SIMPLE ]]; then
    TOOL="OpenRouter" CMD="ai.sh fast \"prompt\"" FALLBACK="aria-coder"
elif [[ "$PROMPT_LOWER" =~ $ANALYSIS ]]; then
    TOOL="Gemini" CMD="gemini \"query\" @files" FALLBACK="Explore"
elif [[ "$PROMPT_LOWER" =~ $REVIEW ]]; then
    TOOL="Codex" CMD="codex \"review...\"" FALLBACK="code-review"
else
    exit 0
fi

if [[ "$MODE" == "aria" ]]; then
    cat << EOF
<user-prompt-submit-hook>
🔄 ARIA MODE: Use $FALLBACK agent
Task tool with subagent_type="$FALLBACK"
</user-prompt-submit-hook>
EOF
else
    cat << EOF
<user-prompt-submit-hook>
⚡ FAST MODE - MANDATORY WORKFLOW:

1. ctx "query" → saves \$ctx_last
2. llm codex|fast|qa "@var:ctx_last" → uses reference
3. NEVER inline large data - always @var:name

Recommended: $CMD
Fallback: $FALLBACK

Mode: fast | /mode aria to switch
</user-prompt-submit-hook>
EOF
fi
exit 0
