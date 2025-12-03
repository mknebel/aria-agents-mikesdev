#!/bin/bash
# var.sh - Session variable manager for LLM chains
#
# Saves variables to /tmp/claude_vars/ with metadata.
# Variables are cleared on system restart (session-scoped).
#
# Usage:
#   var save <name> <content>    # Save variable (content from stdin if -)
#   var save <name> - <query>    # Save from stdin with query metadata
#   var get <name>               # Get variable content
#   var get <name> --head N      # Get first N lines
#   var get <name> --meta        # Get metadata only
#   var path <name>              # Get file path (for @file: refs)
#   var fresh <name> [minutes]   # Check if fresh (default 5 min)
#   var list                     # List all variables
#   var clear                    # Clear all variables
#
# Examples:
#   echo "data" | var save myvar -
#   var get myvar
#   var fresh myvar 5 && echo "still fresh"

set -e

VAR_DIR="/tmp/claude_vars"
mkdir -p "$VAR_DIR"

# ANSI colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

cmd_save() {
    local name="$1"
    local content="$2"
    local query="${3:-}"

    [[ -z "$name" ]] && echo "Usage: var save <name> <content|->" >&2 && exit 1

    local var_file="$VAR_DIR/${name}.txt"
    local meta_file="$VAR_DIR/${name}.meta"

    # Read from stdin if content is -
    if [[ "$content" == "-" ]]; then
        cat > "$var_file"
    else
        echo "$content" > "$var_file"
    fi

    # Save metadata (timestamp, size, query)
    local size=$(wc -c < "$var_file")
    local lines=$(wc -l < "$var_file")
    local ts=$(date +%s)
    echo "${ts}|${size}|${lines}|${query}" > "$meta_file"

    # Format size for display
    local size_fmt
    if [[ $size -gt 1048576 ]]; then
        size_fmt="$(echo "scale=1; $size/1048576" | bc)MB"
    elif [[ $size -gt 1024 ]]; then
        size_fmt="$(echo "scale=1; $size/1024" | bc)KB"
    else
        size_fmt="${size}B"
    fi

    echo -e "${GREEN}✓${NC} Saved \$${name} (${size_fmt}, ${lines} lines)" >&2
    echo "@var:${name}"
}

cmd_get() {
    local name="$1"
    shift
    local head_lines=""
    local meta_only=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --head) head_lines="$2"; shift 2 ;;
            --meta) meta_only=true; shift ;;
            *) shift ;;
        esac
    done

    [[ -z "$name" ]] && echo "Usage: var get <name> [--head N] [--meta]" >&2 && exit 1

    local var_file="$VAR_DIR/${name}.txt"
    local meta_file="$VAR_DIR/${name}.meta"

    [[ ! -f "$var_file" ]] && echo "Variable not found: $name" >&2 && exit 1

    if $meta_only; then
        if [[ -f "$meta_file" ]]; then
            IFS='|' read -r ts size lines query < "$meta_file"
            local age=$(( $(date +%s) - ts ))
            local age_fmt
            if [[ $age -lt 60 ]]; then
                age_fmt="${age}s ago"
            elif [[ $age -lt 3600 ]]; then
                age_fmt="$(( age / 60 ))m ago"
            else
                age_fmt="$(( age / 3600 ))h ago"
            fi
            echo "timestamp: $ts"
            echo "age: $age_fmt"
            echo "size: $size bytes"
            echo "lines: $lines"
            echo "query: $query"
        else
            echo "No metadata for: $name" >&2
        fi
        return
    fi

    if [[ -n "$head_lines" ]]; then
        head -n "$head_lines" "$var_file"
    else
        cat "$var_file"
    fi
}

cmd_path() {
    local name="$1"
    [[ -z "$name" ]] && echo "Usage: var path <name>" >&2 && exit 1

    local var_file="$VAR_DIR/${name}.txt"
    [[ ! -f "$var_file" ]] && echo "Variable not found: $name" >&2 && exit 1

    echo "$var_file"
}

cmd_fresh() {
    local name="$1"
    local max_age="${2:-5}"  # Default 5 minutes

    [[ -z "$name" ]] && echo "Usage: var fresh <name> [minutes]" >&2 && exit 1

    local meta_file="$VAR_DIR/${name}.meta"

    [[ ! -f "$meta_file" ]] && exit 1  # Not fresh if no metadata

    IFS='|' read -r ts size lines query < "$meta_file"
    local age=$(( $(date +%s) - ts ))
    local max_seconds=$(( max_age * 60 ))

    if [[ $age -lt $max_seconds ]]; then
        exit 0  # Fresh
    else
        exit 1  # Stale
    fi
}

cmd_list() {
    echo -e "${BLUE}Session Variables${NC} ($VAR_DIR)"
    echo "─────────────────────────────────────────────"

    local count=0
    shopt -s nullglob
    for var_file in "$VAR_DIR"/*.txt; do

        local name=$(basename "$var_file" .txt)
        local meta_file="$VAR_DIR/${name}.meta"

        local size=$(wc -c < "$var_file")
        local size_fmt
        if [[ $size -gt 1048576 ]]; then
            size_fmt="$(echo "scale=1; $size/1048576" | bc)MB"
        elif [[ $size -gt 1024 ]]; then
            size_fmt="$(printf "%.1f" $(echo "scale=1; $size/1024" | bc))KB"
        else
            size_fmt="${size}B"
        fi

        local age_fmt="?"
        local query=""
        if [[ -f "$meta_file" ]]; then
            IFS='|' read -r ts sz ln query < "$meta_file"
            local age=$(( $(date +%s) - ts ))
            if [[ $age -lt 60 ]]; then
                age_fmt="${age}s"
            elif [[ $age -lt 3600 ]]; then
                age_fmt="$(( age / 60 ))m"
            else
                age_fmt="$(( age / 3600 ))h"
            fi
        fi

        printf "  %-20s %8s  %6s" "\$${name}" "$size_fmt" "$age_fmt"
        [[ -n "$query" ]] && printf "  [%s]" "$query"
        echo

        ((count++)) || true
    done

    [[ $count -eq 0 ]] && echo "  (no variables)" || true
    echo "─────────────────────────────────────────────"
    echo "Total: $count variables"
    shopt -u nullglob
    return 0
}

cmd_clear() {
    rm -f "$VAR_DIR"/*.txt "$VAR_DIR"/*.meta 2>/dev/null || true
    echo -e "${GREEN}✓${NC} Cleared all session variables"
}

# Resolve @var:name references in text
cmd_resolve() {
    local text="$1"
    local llm_type="${2:-openrouter}"  # codex, gemini, openrouter

    # Find all @var:name references
    while [[ "$text" =~ @var:([a-zA-Z0-9_]+) ]]; do
        local var_name="${BASH_REMATCH[1]}"
        local var_file="$VAR_DIR/${var_name}.txt"

        if [[ ! -f "$var_file" ]]; then
            echo "Warning: Variable not found: $var_name" >&2
            text="${text/@var:$var_name/[MISSING: $var_name]}"
            continue
        fi

        case "$llm_type" in
            codex)
                # Codex can read files - pass path
                text="${text/@var:$var_name/@file:$var_file}"
                ;;
            gemini)
                # Gemini can read files - pass path
                text="${text/@var:$var_name/@$var_file}"
                ;;
            openrouter|*)
                # OpenRouter can't read files - inline content (max 20KB)
                local content
                local size=$(wc -c < "$var_file")
                if [[ $size -gt 20480 ]]; then
                    content="[Content truncated - ${size} bytes, showing first 20KB]\n$(head -c 20480 "$var_file")\n[...truncated]"
                    echo "Warning: $var_name truncated from ${size}B to 20KB" >&2
                else
                    content=$(cat "$var_file")
                fi
                # Escape for JSON/inline
                content=$(echo "$content" | sed 's/"/\\"/g' | tr '\n' ' ')
                text="${text/@var:$var_name/$content}"
                ;;
        esac
    done

    echo "$text"
}

# Main dispatch
case "${1:-}" in
    save) shift; cmd_save "$@" ;;
    get) shift; cmd_get "$@" ;;
    path) shift; cmd_path "$@" ;;
    fresh) shift; cmd_fresh "$@" ;;
    list) cmd_list ;;
    clear) cmd_clear ;;
    resolve) shift; cmd_resolve "$@" ;;
    *)
        cat << 'HELP'
var.sh - Session variable manager for LLM chains

Usage:
  var save <name> <content|->   Save variable (- reads from stdin)
  var get <name>                Get variable content
  var get <name> --head N       Get first N lines
  var get <name> --meta         Get metadata only
  var path <name>               Get file path
  var fresh <name> [minutes]    Check if fresh (exit 0=fresh, 1=stale)
  var list                      List all variables
  var clear                     Clear all variables
  var resolve "text" [llm]      Resolve @var: references for LLM type

Examples:
  echo "search results" | var save ctx_last -
  var get ctx_last --head 10
  var fresh ctx_last 5 && echo "still fresh"
  var resolve "analyze @var:ctx_last" codex
HELP
        ;;
esac
