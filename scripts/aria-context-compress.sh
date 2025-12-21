#!/bin/bash
# ARIA Context Compression - Compress old conversation history
# Keeps recent turns verbatim, summarizes older ones

source ~/.claude/scripts/aria-session.sh 2>/dev/null

RECENT_TURNS=${RECENT_TURNS:-10}  # Keep last 10 turns verbatim

# Compress context while preserving key information
compress_context() {
    local session_id="$1"
    local recent_n="${2:-$RECENT_TURNS}"

    if [[ -z "$session_id" ]]; then
        session_id=$(aria_session_current)
    fi

    local session_file="${SESSION_DIR}/${session_id}.jsonl"

    if [[ ! -f "$session_file" ]]; then
        echo "Error: Session file not found: $session_file" >&2
        return 1
    fi

    local total_turns=$(wc -l < "$session_file")

    if [[ $total_turns -le $recent_n ]]; then
        echo "Session has only $total_turns turns, no compression needed" >&2
        return 0
    fi

    local to_compress=$((total_turns - recent_n))

    echo "Compressing $to_compress older turns (keeping last $recent_n verbatim)..." >&2

    # Extract old context
    local old_context=$(head -n $to_compress "$session_file" | jq -r '.content' | tr '\n' ' ')

    # Generate summary using ARIA
    local summary=$(~/.claude/scripts/aria route instant "Summarize this conversation history in 3-5 key points: $old_context" 2>/dev/null)

    # Create compressed session file
    local compressed_file="${session_file}.compressed"
    local backup_file="${session_file}.backup"

    # Backup original
    cp "$session_file" "$backup_file"

    # Write summary as first entry
    echo "{\"role\":\"system\",\"content\":\"Previous context summary: $summary\",\"timestamp\":$(date +%s)}" > "$compressed_file"

    # Append recent turns
    tail -n $recent_n "$session_file" >> "$compressed_file"

    # Replace original
    mv "$compressed_file" "$session_file"

    # Calculate savings
    local old_size=$(wc -c < "$backup_file")
    local new_size=$(wc -c < "$session_file")
    local saved=$((old_size - new_size))
    local percent=$((saved * 100 / old_size))

    echo "✓ Compression complete" >&2
    echo "  Old size: $old_size bytes" >&2
    echo "  New size: $new_size bytes" >&2
    echo "  Saved: $saved bytes ($percent%)" >&2
    echo "  Backup: $backup_file" >&2

    return 0
}

# Auto-compress if session is too large
auto_compress() {
    local threshold=${1:-50}  # Compress if more than 50 turns

    local session_id=$(aria_session_current 2>/dev/null)

    if [[ -z "$session_id" ]]; then
        return 0
    fi

    local session_file="${SESSION_DIR}/${session_id}.jsonl"

    if [[ ! -f "$session_file" ]]; then
        return 0
    fi

    local turns=$(wc -l < "$session_file")

    if [[ $turns -gt $threshold ]]; then
        echo "Session has $turns turns, auto-compressing..." >&2
        compress_context "$session_id" "$RECENT_TURNS"
    fi
}

# CLI interface
case "${1:-help}" in
    compress)
        compress_context "$2" "$3"
        ;;
    auto)
        auto_compress "$2"
        ;;
    *)
        echo "Usage: aria-context-compress.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  compress [session_id] [recent_turns]  - Compress old conversation history"
        echo "  auto [threshold]                       - Auto-compress if session > threshold turns"
        echo ""
        echo "Examples:"
        echo "  aria-context-compress.sh compress           # Compress current session"
        echo "  aria-context-compress.sh compress session_123 15  # Keep last 15 turns"
        echo "  aria-context-compress.sh auto 50            # Auto-compress at 50+ turns"
        ;;
esac
