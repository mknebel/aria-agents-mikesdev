#!/bin/bash
# ARIA Enforcement Hook - Blocks non-compliant behavior
# Runs on PreToolUse to enforce ARIA workflow

INPUT=$(cat) || exit 0
command -v jq >/dev/null || exit 0

TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[ -z "$TOOL" ] && exit 0

STATE_FILE="$HOME/.claude/.aria-state"
[ ! -f "$STATE_FILE" ] && echo '{"reads":0,"writes":0,"greps":0,"files_touched":[]}' > "$STATE_FILE"

READS=$(jq -r '.reads // 0' "$STATE_FILE" 2>/dev/null)
WRITES=$(jq -r '.writes // 0' "$STATE_FILE" 2>/dev/null)

# Enforcement messages
warn() {
    echo "{\"status\":\"⚠️ ARIA VIOLATION: $1\"}"
}

block() {
    echo "{\"status\":\"🚫 ARIA BLOCKED: $1\",\"block\":true}"
    exit 1
}

case "$TOOL" in
    Grep)
        # Grep tool uses ripgrep (rg) internally - this is fine
        # But too many greps might indicate need for ctx/gemini
        GREPS=$(jq -r '.greps // 0' "$STATE_FILE" 2>/dev/null)
        GREPS=$((GREPS + 1))
        jq ".greps = $GREPS" "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
        if [ "$GREPS" -gt 5 ]; then
            warn "Many grep searches ($GREPS). Consider ctx or gemini @. for broader context"
        fi
        echo "{\"status\":\"✓ ARIA: Using Grep (ripgrep)\"}"
        ;;

    Read)
        READS=$((READS + 1))
        jq ".reads = $READS" "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
        if [ "$READS" -gt 4 ]; then
            warn "Too many reads ($READS). Use ctx or gemini @. for context gathering"
        fi
        ;;

    Write|Edit|MultiEdit)
        # Check content length for inline code generation
        CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)
        if [ -n "$CONTENT" ]; then
            LINES=$(echo "$CONTENT" | wc -l)
            if [ "$LINES" -gt 10 ]; then
                warn "Large inline edit ($LINES lines). Consider using codex-save.sh for code generation"
            fi
        fi

        WRITES=$((WRITES + 1))
        jq ".writes = $WRITES" "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

        # Track files touched
        FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
        if [ -n "$FILE" ]; then
            jq ".files_touched += [\"$FILE\"] | .files_touched |= unique" "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
            FILES_COUNT=$(jq '.files_touched | length' "$STATE_FILE" 2>/dev/null)
            if [ "$FILES_COUNT" -gt 3 ]; then
                warn ">3 files touched ($FILES_COUNT). Should have run /plan first"
            fi
        fi
        ;;

    Bash)
        CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

        # Check for bash grep (should use Grep tool or rg)
        if [[ "$CMD" == *"grep "* ]] && [[ "$CMD" != *"rg "* ]]; then
            warn "Using bash grep. Prefer Grep tool (uses ripgrep) or rg command"
        fi

        # Check for direct git commits (should use haiku agent)
        if [[ "$CMD" == *"git commit"* ]] || [[ "$CMD" == *"git push"* ]]; then
            warn "Direct git command. Consider Task(aria-admin, haiku) for CLI operations"
        fi

        # Check for direct npm/composer operations
        if [[ "$CMD" == *"npm install"* ]] || [[ "$CMD" == *"composer install"* ]]; then
            warn "Direct package manager. Consider Task(aria-admin, haiku) for CLI operations"
        fi

        # Positive: Using external tools
        if [[ "$CMD" == *"ctx "* ]] || [[ "$CMD" == *"gemini "* ]]; then
            echo "{\"status\":\"✓ ARIA: External context tool\"}"
        fi
        if [[ "$CMD" == *"codex"* ]] || [[ "$CMD" == *"quality-gate"* ]]; then
            echo "{\"status\":\"✓ ARIA: External tool\"}"
        fi
        if [[ "$CMD" == *"plan-pipeline"* ]]; then
            echo "{\"status\":\"✓ ARIA: Planning pipeline\"}"
        fi
        if [[ "$CMD" == *"design-pipeline"* ]]; then
            echo "{\"status\":\"✓ ARIA: Design pipeline\"}"
        fi
        ;;

    Task)
        AGENT=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null)
        MODEL=$(echo "$INPUT" | jq -r '.tool_input.model // "default"' 2>/dev/null)

        # Check for correct model usage
        if [[ "$AGENT" == "aria-ui-ux" ]] && [[ "$MODEL" != "opus" ]]; then
            warn "aria-ui-ux should use opus model for UI quality"
        fi

        if [[ "$AGENT" == "aria-thinking" ]] && [[ "$MODEL" != "opus" ]]; then
            warn "aria-thinking should use opus model"
        fi

        # Positive feedback
        echo "{\"status\":\"✓ ARIA: Delegating to $AGENT ($MODEL)\"}"
        ;;
esac

exit 0
