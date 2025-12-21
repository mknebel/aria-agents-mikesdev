#!/bin/bash
# ARIA Session Memory Management
# Maintains conversation history across aria route calls
# Provides context from previous interactions to LLMs

# Configuration
SESSION_DIR="${HOME}/.claude/cache/sessions"
CURRENT_LINK="${SESSION_DIR}/current"
MAX_HISTORY_TURNS=${MAX_HISTORY_TURNS:-50}
MAX_CONTEXT_TOKENS=${MAX_CONTEXT_TOKENS:-1000000}  # Use Gemini 3 Flash full 1M context capacity
SESSION_PREFIX="session_"

# Colors for CLI output
COLOR_RESET='\033[0m'
COLOR_BOLD='\033[1m'
COLOR_GREEN='\033[0;32m'
COLOR_BLUE='\033[0;34m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'

# Initialize session directory
_aria_session_init_dir() {
    mkdir -p "$SESSION_DIR" 2>/dev/null
    chmod 700 "$SESSION_DIR" 2>/dev/null
}

# Validate session ID format
_aria_session_validate_id() {
    local id="$1"
    [[ "$id" =~ ^[a-zA-Z0-9_-]+$ ]] && return 0 || return 1
}

# Generate unique session ID
_aria_session_gen_id() {
    local timestamp=$(date +%s)
    local random=$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 6)
    echo "${SESSION_PREFIX}${timestamp}_${random}"
}

# Ensure session directory and current link exist
_aria_session_ensure() {
    _aria_session_init_dir

    if [[ ! -L "$CURRENT_LINK" ]]; then
        # Create first session if none exists
        local first_id=$(aria_session_init 2>/dev/null)
        if [[ -n "$first_id" ]]; then
            return 0
        fi
    fi
}

# Create new session and set as current
aria_session_init() {
    _aria_session_init_dir

    local session_id=$(_aria_session_gen_id)
    local session_file="${SESSION_DIR}/${session_id}.jsonl"
    local meta_file="${SESSION_DIR}/${session_id}.meta"

    # Create empty JSONL file
    touch "$session_file"
    chmod 600 "$session_file"

    # Create metadata
    cat > "$meta_file" <<EOF
{
  "id": "$session_id",
  "created": $(date +%s),
  "modified": $(date +%s),
  "turn_count": 0,
  "token_count": 0
}
EOF
    chmod 600 "$meta_file"

    # Set as current session
    ln -sf "$session_file" "$CURRENT_LINK" 2>/dev/null

    echo "$session_id"
}

# Get current session ID
aria_session_current() {
    _aria_session_ensure

    if [[ -L "$CURRENT_LINK" ]]; then
        local file=$(readlink "$CURRENT_LINK")
        basename "$file" .jsonl
    fi
}

# List all sessions
aria_session_list() {
    _aria_session_ensure

    if [[ ! -d "$SESSION_DIR" ]]; then
        echo "No sessions found."
        return 1
    fi

    local current=$(aria_session_current)
    local count=0

    echo ""
    echo -e "${COLOR_BOLD}Available Sessions:${COLOR_RESET}"
    echo "────────────────────────────────────────────────────────────────"

    for meta_file in "$SESSION_DIR"/${SESSION_PREFIX}*.meta; do
        [[ ! -f "$meta_file" ]] && continue

        local id=$(jq -r '.id' "$meta_file" 2>/dev/null)
        local created=$(jq -r '.created' "$meta_file" 2>/dev/null)
        local turns=$(jq -r '.turn_count' "$meta_file" 2>/dev/null)

        local marker=" "
        if [[ "$id" == "$current" ]]; then
            marker="*"
        fi

        # Format timestamp
        local created_date=""
        if command -v date &>/dev/null; then
            created_date=$(date -d "@$created" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
        fi

        count=$((count + 1))
        printf "%s %-40s  Turns: %3d  Created: %s\n" "$marker" "$id" "$turns" "$created_date"
    done

    echo "────────────────────────────────────────────────────────────────"
    [[ $count -eq 0 ]] && echo "No sessions found." || echo "Total: $count sessions (${COLOR_BOLD}*${COLOR_RESET} = current)"
    echo ""
}

# Switch to different session
aria_session_switch() {
    local session_id="$1"

    if [[ -z "$session_id" ]]; then
        echo "Error: Session ID required" >&2
        return 1
    fi

    if ! _aria_session_validate_id "$session_id"; then
        echo "Error: Invalid session ID format" >&2
        return 1
    fi

    local session_file="${SESSION_DIR}/${session_id}.jsonl"
    local meta_file="${SESSION_DIR}/${session_id}.meta"

    if [[ ! -f "$session_file" ]] || [[ ! -f "$meta_file" ]]; then
        echo "Error: Session not found: $session_id" >&2
        return 1
    fi

    ln -sf "$session_file" "$CURRENT_LINK" 2>/dev/null

    echo "Switched to session: $session_id"
}

# Clear current session history
aria_session_clear() {
    _aria_session_ensure

    local session_id=$(aria_session_current)
    [[ -z "$session_id" ]] && session_id=$(aria_session_init)

    local session_file="${SESSION_DIR}/${session_id}.jsonl"
    local meta_file="${SESSION_DIR}/${session_id}.meta"

    # Clear history file
    > "$session_file"

    # Reset metadata
    cat > "$meta_file" <<EOF
{
  "id": "$session_id",
  "created": $(date +%s),
  "modified": $(date +%s),
  "turn_count": 0,
  "token_count": 0
}
EOF

    echo "Cleared session: $session_id"
}

# Delete a session
aria_session_delete() {
    local session_id="$1"

    if [[ -z "$session_id" ]]; then
        echo "Error: Session ID required" >&2
        return 1
    fi

    local session_file="${SESSION_DIR}/${session_id}.jsonl"
    local meta_file="${SESSION_DIR}/${session_id}.meta"
    local current=$(aria_session_current)

    if [[ ! -f "$session_file" ]]; then
        echo "Error: Session not found: $session_id" >&2
        return 1
    fi

    # Don't delete current session
    if [[ "$session_id" == "$current" ]]; then
        echo "Error: Cannot delete current session. Switch to another first." >&2
        return 1
    fi

    rm -f "$session_file" "$meta_file"
    echo "Deleted session: $session_id"
}

# Add user message to session
aria_session_add_user() {
    local message="$1"
    local model="${2:-claude-haiku}"

    if [[ -z "$message" ]]; then
        return 1
    fi

    _aria_session_ensure

    local session_id=$(aria_session_current)
    [[ -z "$session_id" ]] && session_id=$(aria_session_init)

    local session_file="${SESSION_DIR}/${session_id}.jsonl"

    # Add message as JSONL
    local json=$(printf '%s\n' "{\"role\": \"user\", \"content\": $(printf '%s' "$message" | jq -R '.'), \"timestamp\": $(date +%s), \"model\": \"$model\"}")
    echo "$json" >> "$session_file"

    _aria_session_update_meta "$session_id"
}

# Add assistant response to session
aria_session_add_assistant() {
    local response="$1"
    local model="${2:-claude-haiku}"

    if [[ -z "$response" ]]; then
        return 1
    fi

    _aria_session_ensure

    local session_id=$(aria_session_current)
    [[ -z "$session_id" ]] && session_id=$(aria_session_init)

    local session_file="${SESSION_DIR}/${session_id}.jsonl"

    # Add response as JSONL
    local json=$(printf '%s\n' "{\"role\": \"assistant\", \"content\": $(printf '%s' "$response" | jq -R '.'), \"timestamp\": $(date +%s), \"model\": \"$model\"}")
    echo "$json" >> "$session_file"

    _aria_session_update_meta "$session_id"
}

# Update session metadata
_aria_session_update_meta() {
    local session_id="$1"
    local meta_file="${SESSION_DIR}/${session_id}.meta"
    local session_file="${SESSION_DIR}/${session_id}.jsonl"

    [[ ! -f "$meta_file" ]] && return 1

    local turn_count=$(wc -l < "$session_file" 2>/dev/null || echo 0)

    # Estimate tokens (rough: ~4 chars per token)
    local token_count=$(($(wc -c < "$session_file" 2>/dev/null || echo 0) / 4))

    # Update metadata
    cat > "$meta_file" <<EOF
{
  "id": "$session_id",
  "created": $(jq -r '.created' "$meta_file" 2>/dev/null || echo $(date +%s)),
  "modified": $(date +%s),
  "turn_count": $turn_count,
  "token_count": $token_count
}
EOF
}

# Get formatted history for last N turns
aria_session_get_history() {
    local max_turns="${1:-$MAX_HISTORY_TURNS}"

    _aria_session_ensure

    local session_id=$(aria_session_current)
    [[ -z "$session_id" ]] && return 1

    local session_file="${SESSION_DIR}/${session_id}.jsonl"
    [[ ! -f "$session_file" ]] && return 1

    # Get last N turns (pairs of user+assistant)
    local turn_count=$(wc -l < "$session_file")
    local lines_to_skip=$((turn_count > (max_turns * 2) ? turn_count - (max_turns * 2) : 0))

    if [[ $lines_to_skip -gt 0 ]]; then
        tail -n +$((lines_to_skip + 1)) "$session_file"
    else
        cat "$session_file"
    fi
}

# Get context that fits in token limit
aria_session_get_context() {
    local max_tokens="${1:-$MAX_CONTEXT_TOKENS}"

    _aria_session_ensure

    local session_id=$(aria_session_current)
    [[ -z "$session_id" ]] && return 0

    local session_file="${SESSION_DIR}/${session_id}.jsonl"
    [[ ! -f "$session_file" ]] && return 0

    local total_tokens=0
    local lines_to_include=0

    # Count backwards from end to find how many lines fit in token budget
    while IFS= read -r line; do
        local line_tokens=$((${#line} / 4))
        if (( total_tokens + line_tokens <= max_tokens )); then
            total_tokens=$((total_tokens + line_tokens))
            lines_to_include=$((lines_to_include + 1))
        else
            break
        fi
    done < <(tac "$session_file")

    if [[ $lines_to_include -gt 0 ]]; then
        # Get last N lines preserving order
        local total_lines=$(wc -l < "$session_file")
        tail -n "$lines_to_include" "$session_file" | sort -V
    fi
}

# Build prompt with history context
aria_session_build_prompt() {
    local new_message="$1"
    local max_tokens="${2:-$MAX_CONTEXT_TOKENS}"

    if [[ -z "$new_message" ]]; then
        echo "Error: New message required" >&2
        return 1
    fi

    local history=$(aria_session_get_context "$max_tokens")

    # Build formatted prompt
    if [[ -n "$history" ]]; then
        cat <<EOF
Previous conversation:
---
$history
---

Current request:
$new_message
EOF
    else
        echo "$new_message"
    fi
}

# Display formatted session history
aria_session_show() {
    _aria_session_ensure

    local session_id=$(aria_session_current)
    [[ -z "$session_id" ]] && {
        echo "No current session"
        return 1
    }

    local session_file="${SESSION_DIR}/${session_id}.jsonl"
    local meta_file="${SESSION_DIR}/${session_id}.meta"

    [[ ! -f "$session_file" ]] && {
        echo "Session file not found"
        return 1
    }

    echo ""
    echo -e "${COLOR_BOLD}Session: ${COLOR_BLUE}$session_id${COLOR_RESET}"

    if [[ -f "$meta_file" ]]; then
        local turns=$(jq -r '.turn_count' "$meta_file" 2>/dev/null || echo "?")
        local tokens=$(jq -r '.token_count' "$meta_file" 2>/dev/null || echo "?")
        echo -e "Turns: ${COLOR_GREEN}$turns${COLOR_RESET}  |  Tokens: ${COLOR_YELLOW}$tokens${COLOR_RESET}"
    fi

    echo "────────────────────────────────────────────────────────────────"

    # Display conversation
    local last_role=""
    while IFS= read -r line; do
        local role=$(echo "$line" | jq -r '.role' 2>/dev/null)
        local content=$(echo "$line" | jq -r '.content' 2>/dev/null)

        if [[ "$role" != "$last_role" ]]; then
            if [[ "$role" == "user" ]]; then
                echo ""
                echo -e "${COLOR_GREEN}User:${COLOR_RESET}"
            elif [[ "$role" == "assistant" ]]; then
                echo ""
                echo -e "${COLOR_BLUE}Assistant:${COLOR_RESET}"
            fi
            last_role="$role"
        fi

        # Wrap text at 80 chars
        echo "$content" | fold -s -w 78 | sed 's/^/  /'
    done < "$session_file"

    echo ""
    echo "────────────────────────────────────────────────────────────────"
    echo ""
}

# CLI interface - only run when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "$1" in
        new)
            session_id=$(aria_session_init)
            echo -e "Created new session: ${COLOR_GREEN}$session_id${COLOR_RESET}"
            ;;
        current|cur)
            aria_session_current
            ;;
        list|ls)
            aria_session_list
            ;;
        show|view)
            aria_session_show
            ;;
        switch|sw)
            if [[ -z "$2" ]]; then
                echo "Usage: aria-session.sh switch <session_id>"
                exit 1
            fi
            aria_session_switch "$2"
            ;;
        clear|reset)
            echo "Are you sure? This will clear the current session history."
            echo "Press Enter to confirm or Ctrl+C to cancel."
            read -r
            aria_session_clear
            ;;
        delete|rm)
            if [[ -z "$2" ]]; then
                echo "Usage: aria-session.sh delete <session_id>"
                exit 1
            fi
            aria_session_delete "$2"
            ;;
        -h|--help|help)
            cat <<EOF
aria-session.sh - ARIA Session Memory Management

USAGE:
  aria-session.sh [command] [args]

COMMANDS:
  new              Create new session and set as current
  current          Show current session ID
  list             List all sessions
  show             Show current session history
  switch <id>      Switch to different session
  clear            Clear current session history
  delete <id>      Delete a session
  help             Show this help message

FUNCTIONS (when sourced):
  aria_session_init                    Create new session
  aria_session_current                 Get current session ID
  aria_session_list                    List sessions
  aria_session_switch <id>             Switch sessions
  aria_session_clear                   Clear history
  aria_session_delete <id>             Delete session
  aria_session_add_user <msg> [model]  Add user message
  aria_session_add_assistant <msg> [model]  Add response
  aria_session_get_history [turns]     Get formatted history
  aria_session_get_context [tokens]    Get context fitting token limit
  aria_session_build_prompt <msg> [tokens]  Build prompt with context
  aria_session_show                    Display history

EXAMPLES:
  # Create new session
  aria-session.sh new

  # View current session
  aria-session.sh show

  # Switch to another session
  aria-session.sh switch session_1234567890_abc123

  # List all sessions
  aria-session.sh list

  # Use in scripts
  source aria-session.sh
  aria_session_add_user "What is 2+2?" "gpt-5.1"
  prompt=\$(aria_session_build_prompt "Now multiply by 3")
  aria_session_add_assistant "\$response"

CONFIGURATION:
  MAX_HISTORY_TURNS=10        (max turns to include in history)
  MAX_CONTEXT_TOKENS=4000     (token limit for context)

SESSION STORAGE:
  ~/.claude/cache/sessions/
    current              -> Symlink to active session
    session_*.jsonl      -> Conversation history
    session_*.meta       -> Session metadata

EOF
            ;;
        *)
            if [[ -n "$1" ]]; then
                echo "Unknown command: $1"
                echo "Use 'aria-session.sh help' for usage information"
                exit 1
            else
                aria_session_list
            fi
            ;;
    esac
fi
