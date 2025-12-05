#!/bin/bash
# ARIA Enforcer Hook - Enhanced with state tracking, blocking, and scoring
# Runs on PreToolUse to enforce ARIA workflow

INPUT=$(cat) || exit 0
command -v jq >/dev/null || exit 0

TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[[ -z "$TOOL" ]] && exit 0

# Source ARIA modules
ARIA_DIR="$HOME/.claude/scripts"
[[ -f "$ARIA_DIR/aria-state.sh" ]] && source "$ARIA_DIR/aria-state.sh"
[[ -f "$ARIA_DIR/aria-block.sh" ]] && source "$ARIA_DIR/aria-block.sh"
[[ -f "$ARIA_DIR/aria-cache.sh" ]] && source "$ARIA_DIR/aria-cache.sh"

# Extract target from tool input
TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // .tool_input.pattern // empty' 2>/dev/null)

# Output helpers
output_status() {
    echo "{\"status\":\"$1\"}"
}

output_warn() {
    echo "{\"status\":\"⚠️ $1\"}"
}

output_block() {
    echo "{\"block\":true,\"reason\":\"🛑 $1\"}"
    exit 1
}

case "$TOOL" in
    Read)
        # Check if file cache is valid (aria-cache.sh)
        if type aria_cache_file_valid &>/dev/null && [[ -n "$TARGET" ]]; then
            if aria_cache_file_valid "$TARGET" 2>/dev/null; then
                aria_inc "cache_hits" 2>/dev/null
                output_status "⚡ File cache valid: $(basename "$TARGET")"
            fi
        fi

        # Check if indexed/cached answer exists (search cache fallback)
        CACHE_DIR="$HOME/.claude/cache/search-cache"
        if [[ -d "$CACHE_DIR" && -n "$TARGET" ]]; then
            # Check if file is in recent search results (already have context)
            RECENT_CACHE=$(find "$CACHE_DIR" -name "*.txt" -mmin -30 -exec grep -l "$TARGET" {} \; 2>/dev/null | head -1)
            if [[ -n "$RECENT_CACHE" ]]; then
                aria_inc "cache_hits" 2>/dev/null
                output_status "💡 File in recent search cache - consider using cached context"
            fi
        fi

        # Check blocking level
        if type aria_check &>/dev/null; then
            LEVEL=$(aria_check "Read" "$TARGET")
            case "$LEVEL" in
                SKIP)
                    aria_inc "cache_hits" 2>/dev/null
                    output_status "⏭️ Cached: $TARGET"
                    exit 0
                    ;;
                SOFT)
                    output_warn "$(aria_get_message SOFT)"
                    ;;
                FIRM)
                    output_warn "$(aria_get_message FIRM)"
                    ;;
                HARD)
                    output_block "$(aria_get_message HARD)"
                    ;;
            esac
        fi

        # Track operation
        aria_inc "reads" 2>/dev/null
        aria_inc "tool_calls" 2>/dev/null
        aria_inc "tool_success" 2>/dev/null
        [[ -f "$TARGET" ]] && aria_track_file "$TARGET" "Read" 2>/dev/null
        ;;

    Grep|Glob)
        if type aria_check &>/dev/null; then
            LEVEL=$(aria_check "Grep" "$TARGET")
            case "$LEVEL" in
                SOFT) output_warn "$(aria_get_message SOFT)" ;;
                FIRM) output_warn "$(aria_get_message FIRM)" ;;
                HARD) output_block "$(aria_get_message HARD)" ;;
            esac
        fi

        aria_inc "greps" 2>/dev/null
        aria_inc "tool_calls" 2>/dev/null
        aria_inc "tool_success" 2>/dev/null

        # Note: Search results caching (aria_cache_search_set) happens in post-tool hook
        # or via external tools (ctx, gemini) that handle their own caching

        output_status "✓ Using Grep (ripgrep)"
        ;;

    Write|Edit|MultiEdit)
        # Check for blind coding
        if type aria_check &>/dev/null; then
            LEVEL=$(aria_check "Write" "$TARGET")
            [[ "$LEVEL" == "FIRM" ]] && output_warn "Writing without reading first. Consider reading the file first."
        fi

        # Check content length
        CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)
        if [[ -n "$CONTENT" ]]; then
            LINES=$(echo "$CONTENT" | wc -l)
            if [[ $LINES -gt 15 ]]; then
                output_warn "Large inline edit ($LINES lines). Consider codex-save.sh"
            fi
        fi

        aria_inc "writes" 2>/dev/null
        aria_inc "tool_calls" 2>/dev/null
        aria_inc "tool_success" 2>/dev/null
        [[ -f "$TARGET" ]] && aria_track_file "$TARGET" "Write" 2>/dev/null
        ;;

    Bash)
        CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

        # Track external tool usage (positive!)
        if [[ "$CMD" == *"ctx "* ]] || [[ "$CMD" == *"ctx\""* ]]; then
            aria_inc "external" 2>/dev/null
            aria_log_model "gemini" 2>/dev/null
            output_status "✓ External: ctx (FREE)"
        elif [[ "$CMD" == *"gemini "* ]] || [[ "$CMD" == *"gemini\""* ]]; then
            aria_inc "external" 2>/dev/null
            aria_log_model "gemini" 2>/dev/null
            output_status "✓ External: Gemini (FREE)"
        elif [[ "$CMD" == *"codex "* ]]; then
            aria_inc "external" 2>/dev/null
            if [[ "$CMD" == *"codex-max"* ]] || [[ "$CMD" == *"gpt-5.1-codex-max"* ]]; then
                aria_log_model "codex_max" 2>/dev/null
            elif [[ "$CMD" == *"codex-mini"* ]]; then
                aria_log_model "codex_mini" 2>/dev/null
            elif [[ "$CMD" == *"o3"* ]]; then
                aria_log_model "o3" 2>/dev/null
            elif [[ "$CMD" == *"o4"* ]]; then
                aria_log_model "o4_mini" 2>/dev/null
            fi
            output_status "✓ External: Codex"
        elif [[ "$CMD" == *"quality-gate"* ]]; then
            aria_inc "external" 2>/dev/null
            output_status "✓ Quality Gate"
        elif [[ "$CMD" == *"plan-pipeline"* ]]; then
            aria_inc "external" 2>/dev/null
            output_status "✓ Planning Pipeline"
        elif [[ "$CMD" == *"design-pipeline"* ]]; then
            aria_inc "external" 2>/dev/null
            output_status "✓ Design Pipeline"
        fi

        # Warnings for suboptimal patterns
        if [[ "$CMD" == *"grep "* ]] && [[ "$CMD" != *"rg "* ]]; then
            output_warn "Use Grep tool or 'rg' instead of bash grep"
        fi

        aria_inc "tool_calls" 2>/dev/null
        aria_inc "tool_success" 2>/dev/null
        ;;

    Task)
        AGENT=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null)
        MODEL=$(echo "$INPUT" | jq -r '.tool_input.model // "haiku"' 2>/dev/null)

        # Log model usage
        if [[ "$MODEL" == "opus" ]]; then
            aria_log_model "claude_opus" 2>/dev/null
        else
            aria_log_model "claude_haiku" 2>/dev/null
        fi

        aria_inc "tasks" 2>/dev/null
        aria_inc "tool_calls" 2>/dev/null
        aria_inc "tool_success" 2>/dev/null

        # Check for recommended model usage
        if [[ "$AGENT" == "aria-ui-ux" ]] && [[ "$MODEL" != "opus" ]]; then
            output_warn "aria-ui-ux should use opus for UI quality"
        elif [[ "$AGENT" == "aria-thinking" ]] && [[ "$MODEL" != "opus" ]]; then
            output_warn "aria-thinking should use opus"
        else
            output_status "✓ Task: $AGENT ($MODEL)"
        fi
        ;;

    *)
        # Other tools - just track
        aria_inc "tool_calls" 2>/dev/null
        aria_inc "tool_success" 2>/dev/null
        ;;
esac

exit 0
