#!/bin/bash
# Hook: Detect implementation trigger phrases and remind to use external tools
# Runs on UserPromptSubmit

INPUT=$(cat)
USER_PROMPT=$(echo "$INPUT" | jq -r '.user_prompt // ""' 2>/dev/null)

# Check mode - only activate in fast mode
MODE=$(cat ~/.claude/routing-mode 2>/dev/null || echo "fast")
[[ "$MODE" != "fast" ]] && exit 0

# Skip if prompt is too short
[[ ${#USER_PROMPT} -lt 5 ]] && exit 0

TRIGGERS_FILE="$HOME/.claude/implementation-triggers.txt"
[[ ! -f "$TRIGGERS_FILE" ]] && exit 0

# Check if any trigger phrase is present in user prompt (case-insensitive)
PROMPT_LOWER="${USER_PROMPT,,}"
MATCHED=false

# Use mapfile for efficient reading
mapfile -t triggers < "$TRIGGERS_FILE"
for trigger in "${triggers[@]}"; do
    # Skip comments and empty lines
    [[ "$trigger" =~ ^# ]] && continue
    [[ -z "$trigger" ]] && continue

    trigger_lower="${trigger,,}"
    if [[ "$PROMPT_LOWER" == *"$trigger_lower"* ]]; then
        MATCHED=true
        break
    fi
done

if [[ "$MATCHED" == "true" ]]; then
    # Check for complexity indicators - if complex, suggest Claude
    COMPLEX_INDICATORS="complex|tricky|careful|critical|production|security|auth|payment|database|migration|refactor"
    if [[ "$PROMPT_LOWER" =~ $COMPLEX_INDICATORS ]]; then
        cat << 'EOF'
<user-prompt-submit-hook>
COMPLEX CODE DETECTED - Claude recommended for accuracy.

For complex logic, use Claude directly (current mode).
Use /mode aria for full Claude agent access if needed.

External tools (gemini, codex) are good for:
- Simple searches and exploration
- Boilerplate code
- Documentation lookup
</user-prompt-submit-hook>
EOF
    else
        cat << 'EOF'
<user-prompt-submit-hook>
FAST MODE - Simple implementation detected.

For routine code, external tools work well:
- gemini "query" @files (search/explore)
- codex "implement..." (code generation)

For complex/critical code, use Claude directly or /mode aria.
</user-prompt-submit-hook>
EOF
    fi
fi

exit 0
