#!/bin/bash
# ctx.sh - Context builder with auto-save
#
# For use by any AI agent (Codex, Claude, etc.) that needs indexed context.
# This is the "data provider" - it does NOT call any AI.
#
# NEW: Auto-saves results to $ctx_last for use with llm.sh
# NEW: Deduplication - asks before re-running same query within 5 min
#
# Usage:
#   ctx "query"                    # Default: compact format, auto-save
#   ctx "query" --json             # JSON output
#   ctx "query" --tsv              # TSV output (path, symbol, line, score)
#   ctx "query" -n 20              # Limit to N results (default: 30)
#   ctx "query" --no-save          # Don't save to variable
#   ctx "query" --force            # Skip dedup check
#
# Examples:
#   ctx "auth login"               # Find auth-related code → $ctx_last
#   ctx "payment checkout" --json  # JSON for machine parsing
#   ctx "user model" -n 10         # Top 10 results only
#
# After running, use with llm.sh:
#   llm codex "implement X based on @var:ctx_last"

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

VAR_DIR="/tmp/claude_vars"
SCRIPTS_DIR="$HOME/.claude/scripts"
mkdir -p "$VAR_DIR"

# Parse arguments
QUERY=""
FORMAT="compact"
LIMIT=30
PROJECT_ROOT="$(pwd)"
SAVE=true
FORCE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) FORMAT="json"; shift ;;
        --tsv) FORMAT="tsv"; shift ;;
        -n) LIMIT="$2"; shift 2 ;;
        -p|--path) PROJECT_ROOT="$2"; shift 2 ;;
        --no-save) SAVE=false; shift ;;
        --force|-f) FORCE=true; shift ;;
        -*) echo "Unknown option: $1" >&2; exit 1 ;;
        *) QUERY="$QUERY $1"; shift ;;
    esac
done

QUERY=$(echo "$QUERY" | xargs)  # Trim whitespace

if [[ -z "$QUERY" ]]; then
    cat << 'HELP'
ctx - Context builder with auto-save

Usage: ctx "query" [options]

Options:
  --json        JSON output format
  --tsv         TSV output format
  -n N          Limit to N results (default: 30)
  -p PATH       Search in specific project path
  --no-save     Don't save to $ctx_last
  --force       Skip deduplication check

Output saved to: $ctx_last (use with llm.sh)

Examples:
  ctx "auth login"                     # Search → $ctx_last
  llm codex "implement @var:ctx_last"  # Use saved context
HELP
    exit 1
fi

# Check for deduplication (same query in last 5 min)
META_FILE="$VAR_DIR/ctx_last.meta"
if [[ -f "$META_FILE" ]] && ! $FORCE; then
    IFS='|' read -r ts size lines old_query < "$META_FILE"
    age=$(( $(date +%s) - ts ))

    # Normalize queries for comparison
    norm_old=$(echo "$old_query" | tr '[:upper:]' '[:lower:]' | xargs)
    norm_new=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]' | xargs)

    if [[ "$norm_old" == "$norm_new" && $age -lt 300 ]]; then
        age_fmt=$((age / 60))m$((age % 60))s
        echo -e "${YELLOW}⚠️  Same query run ${age_fmt} ago${NC}" >&2
        echo -e "   Cached result: $(wc -l < "$VAR_DIR/ctx_last.txt") lines, ${size} bytes" >&2
        echo -n "   Use cached result? [Y/n/force]: " >&2
        read -r response < /dev/tty 2>/dev/null || response="y"

        case "${response,,}" in
            n|no)
                echo "Running fresh query..." >&2
                ;;
            f|force)
                echo "Forcing fresh query..." >&2
                ;;
            *)
                echo -e "${GREEN}✓ Using cached \$ctx_last${NC}" >&2
                cat "$VAR_DIR/ctx_last.txt"
                echo "@var:ctx_last"
                exit 0
                ;;
        esac
    fi
fi

# Ensure index exists
INDEX_NAME=$(echo "$PROJECT_ROOT" | md5sum | cut -d' ' -f1)
INDEX_DIR="$HOME/.claude/indexes/$INDEX_NAME"
INVERTED_INDEX="$INDEX_DIR/inverted.json"
FILES_DIR="$INDEX_DIR/files"

if [[ ! -f "$INVERTED_INDEX" ]]; then
    echo "Building index..." >&2
    "$HOME/.claude/scripts/index-v2/build-index.sh" "$PROJECT_ROOT" >&2
fi

# Run search and capture results
echo -e "${BLUE}🔍 Searching: $QUERY${NC}" >&2
SEARCH_OUTPUT=$("$HOME/.claude/scripts/index-v2/search.sh" "$QUERY" "$PROJECT_ROOT" 2>/dev/null || true)

if [[ -z "$SEARCH_OUTPUT" || "$SEARCH_OUTPUT" == "No matches found." ]]; then
    case "$FORMAT" in
        json) OUTPUT="[]" ;;
        tsv) OUTPUT="# No results" ;;
        *) OUTPUT="No matches found for: $QUERY" ;;
    esac
    echo "$OUTPUT"
    exit 0
fi

# Parse and format output
case "$FORMAT" in
    json)
        OUTPUT=$(
            echo "["
            FIRST=true
            echo "$SEARCH_OUTPUT" | grep '^\[' | head -n "$LIMIT" | while IFS= read -r line; do
                category=$(echo "$line" | sed 's/^\[\([^]]*\)\].*/\1/')
                path=$(echo "$line" | sed 's/^\[[^]]*\] \([^ ]*\).*/\1/')
                score=$(echo "$line" | grep -oE 'score: [0-9]+' | grep -oE '[0-9]+' || echo "1")

                if [[ "$FIRST" != "true" ]]; then echo ","; fi
                FIRST=false

                file_id=$(echo "$path" | md5sum | cut -d' ' -f1 | cut -c1-12)
                file_index="$FILES_DIR/${file_id}.json"
                if [[ -f "$file_index" ]]; then
                    functions=$(jq -c '.functions[].name' "$file_index" 2>/dev/null | tr '\n' ',' | sed 's/,$//' || echo "")
                else
                    functions=""
                fi

                echo "  {\"path\":\"$path\",\"category\":\"$category\",\"score\":$score,\"functions\":[$functions]}"
            done
            echo "]"
        )
        ;;

    tsv)
        OUTPUT=$(
            echo -e "path\tcategory\tscore\tfunctions"
            echo "$SEARCH_OUTPUT" | grep '^\[' | head -n "$LIMIT" | while IFS= read -r line; do
                category=$(echo "$line" | sed 's/^\[\([^]]*\)\].*/\1/')
                path=$(echo "$line" | sed 's/^\[[^]]*\] \([^ ]*\).*/\1/')
                score=$(echo "$line" | grep -oE 'score: [0-9]+' | grep -oE '[0-9]+' || echo "1")

                file_id=$(echo "$path" | md5sum | cut -d' ' -f1 | cut -c1-12)
                file_index="$FILES_DIR/${file_id}.json"
                if [[ -f "$file_index" ]]; then
                    functions=$(jq -r '.functions[].name' "$file_index" 2>/dev/null | tr '\n' ',' | sed 's/,$//' || echo "")
                else
                    functions=""
                fi

                echo -e "$path\t$category\t$score\t$functions"
            done
        )
        ;;

    compact|*)
        OUTPUT=$(
            echo "## Context for: $QUERY"
            echo ""
            echo "$SEARCH_OUTPUT" | head -n $((LIMIT * 4))
        )
        ;;
esac

# Output result
echo "$OUTPUT"

# Auto-save to variable
if $SAVE; then
    echo "$OUTPUT" | "$SCRIPTS_DIR/var.sh" save "ctx_last" - "$QUERY" >/dev/null 2>&1 || true
fi
