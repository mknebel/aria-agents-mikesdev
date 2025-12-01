#!/bin/bash
# Enforce agent delegation for tasks that should use subagents
# Outputs a reminder message that Claude sees before responding

# Read the user's prompt from stdin (hook receives JSON)
INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // .message // ""' 2>/dev/null | tr '[:upper:]' '[:lower:]')

# Skip if empty
[ -z "$PROMPT" ] && exit 0

# Patterns that should ALWAYS use agents
CODING_PATTERNS="(add|create|implement|build|write|fix|update|refactor|change|modify|edit) .*(code|function|method|class|component|feature|bug|error)"
SEARCH_PATTERNS="(find|search|where|locate|look for|show me) .*(file|function|class|code|implementation|handler)"
TEST_PATTERNS="(test|write tests|add tests|create tests|run tests)"
DOC_PATTERNS="(document|write docs|add documentation|update readme)"
GIT_PATTERNS="(commit|push|pull|branch|merge|changelog)"
REVIEW_PATTERNS="(review|check|audit|security|validate)"

# Check for delegation triggers
SHOULD_DELEGATE=""
SUGGESTED_AGENT=""

if echo "$PROMPT" | grep -qiE "$CODING_PATTERNS"; then
    SHOULD_DELEGATE="yes"
    SUGGESTED_AGENT="aria-coder"
elif echo "$PROMPT" | grep -qiE "$SEARCH_PATTERNS"; then
    SHOULD_DELEGATE="yes"
    SUGGESTED_AGENT="Explore"
elif echo "$PROMPT" | grep -qiE "$TEST_PATTERNS"; then
    SHOULD_DELEGATE="yes"
    SUGGESTED_AGENT="aria-qa"
elif echo "$PROMPT" | grep -qiE "$DOC_PATTERNS"; then
    SHOULD_DELEGATE="yes"
    SUGGESTED_AGENT="aria-docs"
elif echo "$PROMPT" | grep -qiE "$GIT_PATTERNS"; then
    SHOULD_DELEGATE="yes"
    SUGGESTED_AGENT="aria-admin"
elif echo "$PROMPT" | grep -qiE "$REVIEW_PATTERNS"; then
    SHOULD_DELEGATE="yes"
    SUGGESTED_AGENT="code-review"
fi

# Output reminder if delegation is needed
if [ -n "$SHOULD_DELEGATE" ]; then
    cat << EOF
<user-prompt-submit-hook>
🔄 AGENT DELEGATION REQUIRED

This task should be delegated to: **$SUGGESTED_AGENT**

Use the Task tool with subagent_type="$SUGGESTED_AGENT" instead of handling directly.

Quick reference:
- Coding/implementation → aria-coder
- File/code search → Explore
- Testing/QA → aria-qa
- Documentation → aria-docs
- Git operations → aria-admin
- Security review → code-review

DO NOT use Grep/Read/Edit directly for this task. Spawn a subagent.
</user-prompt-submit-hook>
EOF
fi

exit 0
