#!/bin/bash
# llm-protocol.sh - Efficient inter-LLM communication
#
# Uses structured JSON responses + summary-first pattern
# Reduces token usage by 60-80% between model calls
#
# Response format:
# {
#   "status": "success|error|needs_review",
#   "summary": "50 words max",
#   "confidence": 0.0-1.0,
#   "issues": [],
#   "result": "full content or pointer"
# }

set -e

SCRIPTS_DIR="$HOME/.claude/scripts"
VAR_DIR="/tmp/claude_vars"

# Standard response schema for all LLM calls
RESPONSE_SCHEMA='{
  "type": "object",
  "properties": {
    "status": {"type": "string", "enum": ["success", "error", "needs_review"]},
    "summary": {"type": "string", "maxLength": 200},
    "confidence": {"type": "number", "minimum": 0, "maximum": 1},
    "issues": {"type": "array", "items": {"type": "string"}},
    "result": {"type": "string"}
  },
  "required": ["status", "summary", "result"]
}'

# Wrap prompt to request structured response
wrap_prompt_structured() {
    local prompt="$1"
    cat <<EOF
$prompt

IMPORTANT: Respond in this exact JSON format:
{
  "status": "success" or "error" or "needs_review",
  "summary": "Brief 1-2 sentence summary of what you did",
  "confidence": 0.0 to 1.0,
  "issues": ["list", "of", "issues"] or [],
  "result": "The actual code/content here"
}

Only output valid JSON, nothing else.
EOF
}

# Parse structured response
parse_response() {
    local response="$1"
    local field="$2"

    # Try to extract JSON from response
    local json=$(echo "$response" | grep -Pzo '\{[\s\S]*\}' | head -1)

    if [[ -n "$json" ]]; then
        echo "$json" | jq -r ".$field // empty" 2>/dev/null
    else
        # Fallback: return raw response
        echo "$response"
    fi
}

# Efficient LLM call with structured response
call_structured() {
    local provider="$1"
    local prompt="$2"
    local var_name="${3:-llm_structured_last}"

    local wrapped=$(wrap_prompt_structured "$prompt")
    local response

    case "$provider" in
        codex)
            response=$(codex "$wrapped" 2>/dev/null)
            ;;
        gemini)
            response=$(gemini "$wrapped" 2>/dev/null)
            ;;
        fast|qa|tools)
            response=$("$SCRIPTS_DIR/ai.sh" "$provider" "$wrapped" 2>/dev/null)
            ;;
    esac

    # Save full response
    echo "$response" > "$VAR_DIR/${var_name}.json"

    # Extract and save summary separately (for efficient passing)
    local summary=$(parse_response "$response" "summary")
    local status=$(parse_response "$response" "status")
    local confidence=$(parse_response "$response" "confidence")

    # Save summary file (tiny, for quick reads)
    cat > "$VAR_DIR/${var_name}.summary" <<EOF
status: $status
confidence: $confidence
summary: $summary
full: @var:${var_name}
EOF

    # Return summary for immediate use
    echo "$summary"
}

# Read only summary (efficient)
read_summary() {
    local var_name="$1"
    cat "$VAR_DIR/${var_name}.summary" 2>/dev/null
}

# Read full result (when needed)
read_result() {
    local var_name="$1"
    parse_response "$(cat "$VAR_DIR/${var_name}.json")" "result"
}

# Check if needs review
needs_review() {
    local var_name="$1"
    local status=$(parse_response "$(cat "$VAR_DIR/${var_name}.json")" "status")
    [[ "$status" == "needs_review" || "$status" == "error" ]]
}

# Get issues list
get_issues() {
    local var_name="$1"
    parse_response "$(cat "$VAR_DIR/${var_name}.json")" "issues"
}

# Main dispatch
case "${1:-}" in
    call)
        shift
        call_structured "$@"
        ;;
    summary)
        shift
        read_summary "$@"
        ;;
    result)
        shift
        read_result "$@"
        ;;
    needs-review)
        shift
        needs_review "$@"
        ;;
    issues)
        shift
        get_issues "$@"
        ;;
    *)
        cat <<'HELP'
llm-protocol.sh - Efficient inter-LLM communication

Usage:
  llm-protocol.sh call <provider> "prompt" [var_name]
  llm-protocol.sh summary <var_name>
  llm-protocol.sh result <var_name>
  llm-protocol.sh needs-review <var_name>
  llm-protocol.sh issues <var_name>

Structured Response Format:
  {
    "status": "success|error|needs_review",
    "summary": "Brief summary",
    "confidence": 0.0-1.0,
    "issues": [],
    "result": "Full content"
  }

Benefits:
  - 60-80% token reduction between LLM calls
  - Read summary first, full content only when needed
  - Structured parsing (no text guessing)
  - Confidence scores for decision making

Example:
  # Generate with structured response
  llm-protocol.sh call codex "implement login" codex_impl

  # Read just the summary (tiny)
  llm-protocol.sh summary codex_impl

  # Check if needs review
  llm-protocol.sh needs-review codex_impl && echo "Needs review!"

  # Get full result only when applying
  llm-protocol.sh result codex_impl
HELP
        ;;
esac
