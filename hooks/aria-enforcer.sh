#!/bin/bash
# ARIA Enforcer Hook - Optimized for speed
# Runs on PreToolUse to track operations and enforce workflow

INPUT=$(cat) || exit 0
command -v jq >/dev/null || exit 0

# Parse tool info once
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
[[ -z "$TOOL" ]] && exit 0

# Lazy-load state module only when needed
_load_state() {
    [[ -z "$_STATE_LOADED" ]] && {
        source "$HOME/.claude/scripts/aria-state.sh" 2>/dev/null || true
        _STATE_LOADED=1
    }
}

# Output helpers
output_status() { echo "{\"status\":\"$1\"}"; }
output_warn() { echo "{\"status\":\"\u26a0\ufe0f $1\"}"; }

case "$TOOL" in
    Read)
        _load_state
        aria_inc "reads" 2>/dev/null
        aria_inc "tool_calls" 2>/dev/null
        ;;

    Grep|Glob)
        _load_state
        aria_inc "greps" 2>/dev/null
        aria_inc "tool_calls" 2>/dev/null
        ;;

    Write|Edit|MultiEdit)
        _load_state
        aria_inc "writes" 2>/dev/null
        aria_inc "tool_calls" 2>/dev/null
        ;;

    Bash)
        CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

        # Track external tool usage (positive!)
        case "$CMD" in
            *"ctx "* | *"ctx\""*)
                _load_state
                aria_inc "external" 2>/dev/null
                aria_log_model "gemini" 2>/dev/null
                output_status "External: ctx (FREE)"
                ;;
            *"gemini "* | *"gemini\""*)
                _load_state
                aria_inc "external" 2>/dev/null
                aria_log_model "gemini" 2>/dev/null
                output_status "External: Gemini (FREE)"
                ;;
            *"codex "*)
                _load_state
                aria_inc "external" 2>/dev/null
                case "$CMD" in
                    *codex-max* | *gpt-5.1-codex-max*) aria_log_model "codex_max" ;;
                    *codex-mini*) aria_log_model "codex_mini" ;;
                    *gpt-5.1-codex*) aria_log_model "codex" ;;
                    *gpt-5.1*) aria_log_model "gpt51" ;;
                esac 2>/dev/null
                output_status "External: Codex"
                ;;
            *"quality-gate"* | *"plan-pipeline"* | *"design-pipeline"*)
                _load_state
                aria_inc "external" 2>/dev/null
                ;;
        esac

        _load_state
        aria_inc "tool_calls" 2>/dev/null
        ;;

    Task)
        _load_state
        MODEL=$(echo "$INPUT" | jq -r '.tool_input.model // "haiku"')

        if [[ "$MODEL" == "opus" ]]; then
            aria_log_model "claude_opus" 2>/dev/null
        else
            aria_log_model "claude_haiku" 2>/dev/null
        fi

        aria_inc "tasks" 2>/dev/null
        aria_inc "tool_calls" 2>/dev/null
        ;;

    *)
        _load_state
        aria_inc "tool_calls" 2>/dev/null
        ;;
esac

exit 0
