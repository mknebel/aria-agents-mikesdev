#!/bin/bash
# recent-changes.sh - List recently changed files
#
# For AI agents to understand what was recently modified.
# Uses git if available, falls back to filesystem timestamps.
#
# Usage:
#   recent-changes                 # Default: last 20 files, compact format
#   recent-changes -n 50           # Last 50 files
#   recent-changes --json          # JSON output
#   recent-changes --tsv           # TSV output
#   recent-changes --since "1 hour ago"   # Git: changes since time
#   recent-changes --uncommitted   # Git: only uncommitted changes
#
# Examples:
#   recent-changes                 # What changed recently?
#   recent-changes --uncommitted   # What's not committed yet?
#   recent-changes --json -n 10    # Top 10 as JSON

set -e

# Parse arguments
FORMAT="compact"
LIMIT=20
SINCE=""
UNCOMMITTED=false
PROJECT_ROOT="$(pwd)"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) FORMAT="json"; shift ;;
        --tsv) FORMAT="tsv"; shift ;;
        -n) LIMIT="$2"; shift 2 ;;
        --since) SINCE="$2"; shift 2 ;;
        --uncommitted) UNCOMMITTED=true; shift ;;
        -p|--path) PROJECT_ROOT="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: recent-changes [options]"
            echo ""
            echo "Options:"
            echo "  -n N              Limit to N files (default: 20)"
            echo "  --json            JSON output"
            echo "  --tsv             TSV output"
            echo "  --since \"TIME\"    Git: changes since (e.g., '1 hour ago')"
            echo "  --uncommitted     Git: only show uncommitted changes"
            echo "  -p, --path PATH   Project root (default: pwd)"
            exit 0
            ;;
        *) shift ;;
    esac
done

cd "$PROJECT_ROOT"

# Check if git repo
IS_GIT=false
if git rev-parse --git-dir >/dev/null 2>&1; then
    IS_GIT=true
fi

# Collect changes
declare -a FILES
declare -A FILE_STATUS
declare -A FILE_TIME

if [[ "$IS_GIT" == "true" ]]; then
    if [[ "$UNCOMMITTED" == "true" ]]; then
        # Uncommitted changes only
        while IFS= read -r line; do
            status="${line:0:2}"
            file="${line:3}"
            [[ -z "$file" ]] && continue
            FILES+=("$file")
            FILE_STATUS["$file"]="$status"
            FILE_TIME["$file"]="uncommitted"
        done < <(git status --porcelain 2>/dev/null | head -n "$LIMIT")
    elif [[ -n "$SINCE" ]]; then
        # Changes since specified time
        while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            FILES+=("$file")
            FILE_STATUS["$file"]="M"
            FILE_TIME["$file"]="$SINCE"
        done < <(git log --since="$SINCE" --name-only --pretty=format: 2>/dev/null | sort -u | grep -v '^$' | head -n "$LIMIT")
    else
        # Recent commits
        while IFS='|' read -r time file; do
            [[ -z "$file" ]] && continue
            [[ -n "${FILE_TIME[$file]}" ]] && continue  # Skip duplicates
            FILES+=("$file")
            FILE_STATUS["$file"]="M"
            FILE_TIME["$file"]="$time"
        done < <(git log --name-only --pretty=format:"%ar|" -n 50 2>/dev/null | \
            awk -F'|' '/\|$/{time=$1; next} NF{print time "|" $0}' | head -n "$LIMIT")
    fi
else
    # Fallback: filesystem timestamps
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        FILES+=("$file")
        FILE_STATUS["$file"]="?"
        mtime=$(stat -c %Y "$file" 2>/dev/null || echo "0")
        FILE_TIME["$file"]=$(date -d "@$mtime" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
    done < <(find "$PROJECT_ROOT" -type f \( -name "*.php" -o -name "*.js" -o -name "*.ts" \) \
        ! -path "*/node_modules/*" ! -path "*/vendor/*" ! -path "*/.git/*" \
        -printf '%T@ %P\n' 2>/dev/null | sort -rn | head -n "$LIMIT" | awk '{print $2}')
fi

# Output
case "$FORMAT" in
    json)
        echo "["
        FIRST=true
        for file in "${FILES[@]}"; do
            [[ "$FIRST" != "true" ]] && echo ","
            FIRST=false
            status="${FILE_STATUS[$file]}"
            time="${FILE_TIME[$file]}"
            echo "  {\"path\":\"$file\",\"status\":\"$status\",\"time\":\"$time\"}"
        done
        echo "]"
        ;;

    tsv)
        echo -e "path\tstatus\ttime"
        for file in "${FILES[@]}"; do
            status="${FILE_STATUS[$file]}"
            time="${FILE_TIME[$file]}"
            echo -e "$file\t$status\t$time"
        done
        ;;

    compact|*)
        echo "## Recent Changes"
        echo ""
        if [[ "$IS_GIT" == "true" ]]; then
            echo "Source: git"
        else
            echo "Source: filesystem"
        fi
        echo ""
        for file in "${FILES[@]}"; do
            status="${FILE_STATUS[$file]}"
            time="${FILE_TIME[$file]}"
            case "$status" in
                "M "*|" M"|"MM") echo "  [modified] $file ($time)" ;;
                "A "*|" A") echo "  [added]    $file ($time)" ;;
                "D "*|" D") echo "  [deleted]  $file ($time)" ;;
                "??") echo "  [untracked] $file" ;;
                *) echo "  [changed]  $file ($time)" ;;
            esac
        done
        ;;
esac
