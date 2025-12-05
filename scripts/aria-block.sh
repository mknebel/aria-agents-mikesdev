#!/bin/bash
# ARIA Graduated Blocking
# SOFT → FIRM → HARD with override capability

source ~/.claude/scripts/aria-state.sh 2>/dev/null

ARIA_OVERRIDE="$HOME/.claude/.aria-override"

aria_override_active() {
    if [[ -f "$ARIA_OVERRIDE" ]]; then
        local age=$(($(date +%s) - $(stat -c %Y "$ARIA_OVERRIDE" 2>/dev/null || echo 0)))
        if [[ $age -lt 3600 ]]; then
            return 0
        fi
        rm -f "$ARIA_OVERRIDE"
    fi
    return 1
}

aria_set_override() {
    touch "$ARIA_OVERRIDE"
    echo "ARIA override active for 1 hour"
    echo "Run 'aria override clear' to remove"
}

aria_clear_override() {
    rm -f "$ARIA_OVERRIDE"
    echo "ARIA override cleared"
}

# Returns: ALLOW | SKIP | SOFT | FIRM | HARD
aria_check() {
    local op="$1"
    local target="$2"

    # Override bypasses all checks
    aria_override_active && { echo "ALLOW"; return; }

    local reads=$(aria_get reads)
    local greps=$(aria_get greps)
    local writes=$(aria_get writes)
    local external=$(aria_get external)

    case "$op" in
        Read)
            # Skip unchanged files (cache hit)
            if [[ -f "$target" ]] && ! aria_file_changed "$target"; then
                echo "SKIP"
                return
            fi

            # Thresholds depend on external tool usage
            if [[ $external -eq 0 ]]; then
                # No external tools used - stricter limits
                [[ $reads -ge 8 ]] && { echo "HARD"; return; }
                [[ $reads -ge 5 ]] && { echo "FIRM"; return; }
                [[ $reads -ge 3 ]] && { echo "SOFT"; return; }
            else
                # External tools used - more lenient
                [[ $reads -ge 15 ]] && { echo "FIRM"; return; }
            fi
            echo "ALLOW"
            ;;

        Grep)
            if [[ $external -eq 0 ]]; then
                [[ $greps -ge 8 ]] && { echo "HARD"; return; }
                [[ $greps -ge 5 ]] && { echo "FIRM"; return; }
                [[ $greps -ge 3 ]] && { echo "SOFT"; return; }
            fi
            echo "ALLOW"
            ;;

        Write|Edit|MultiEdit)
            # Writing without reading = blind coding
            if [[ $reads -eq 0 && $writes -eq 0 ]]; then
                echo "FIRM"
                return
            fi
            echo "ALLOW"
            ;;

        Task)
            # Always allow task delegation
            echo "ALLOW"
            ;;

        *)
            echo "ALLOW"
            ;;
    esac
}

aria_get_message() {
    local level="$1"
    case "$level" in
        SKIP)
            echo "File unchanged since last read (cached)"
            ;;
        SOFT)
            echo "Tip: Use 'ctx' or 'gemini @.' for broader context"
            ;;
        FIRM)
            echo "Warning: Many operations without external tools. Run 'ctx' first or 'aria override'"
            ;;
        HARD)
            echo "Blocked: Too many direct operations. Run 'ctx \"query\"' or 'aria override' to continue"
            ;;
        ALLOW)
            echo ""
            ;;
    esac
}

aria_get_emoji() {
    case "$1" in
        SKIP) echo "⏭️" ;;
        SOFT) echo "💡" ;;
        FIRM) echo "⚠️" ;;
        HARD) echo "🛑" ;;
        ALLOW) echo "✓" ;;
    esac
}

# CLI interface - only run when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "$1" in
        override|o)
            case "$2" in
                clear|c) aria_clear_override ;;
                *) aria_set_override ;;
            esac
            ;;
        check|c)
            aria_check "$2" "$3"
            ;;
        status|s)
            if aria_override_active; then
                local age=$(($(date +%s) - $(stat -c %Y "$ARIA_OVERRIDE")))
                local remaining=$(((3600 - age) / 60))
                echo "Override ACTIVE (${remaining}m remaining)"
            else
                echo "Override inactive"
            fi
            ;;
    esac
fi
