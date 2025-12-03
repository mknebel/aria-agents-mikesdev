#!/bin/bash
# ctx.sh - Context builder (NO AI call)
#
# For use by any AI agent (Codex, Claude, etc.) that needs indexed context.
# This is the "data provider" - it does NOT call any AI.
#
# Usage:
#   ctx "query"                    # Default: compact format
#   ctx "query" --json             # JSON output
#   ctx "query" --tsv              # TSV output (path, symbol, line, score)
#   ctx "query" -n 20              # Limit to N results (default: 30)
#
# Examples:
#   ctx "auth login"               # Find auth-related code
#   ctx "payment checkout" --json  # JSON for machine parsing
#   ctx "user model" -n 10         # Top 10 results only

set -e

# Parse arguments
QUERY=""
FORMAT="compact"
LIMIT=30
PROJECT_ROOT="$(pwd)"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) FORMAT="json"; shift ;;
        --tsv) FORMAT="tsv"; shift ;;
        -n) LIMIT="$2"; shift 2 ;;
        -p|--path) PROJECT_ROOT="$2"; shift 2 ;;
        -*) echo "Unknown option: $1" >&2; exit 1 ;;
        *) QUERY="$QUERY $1"; shift ;;
    esac
done

QUERY=$(echo "$QUERY" | xargs)  # Trim whitespace

if [[ -z "$QUERY" ]]; then
    echo "Usage: ctx \"query\" [--json|--tsv] [-n limit]" >&2
    echo "" >&2
    echo "Context builder for AI agents. Returns indexed search results." >&2
    echo "Does NOT call any AI - just provides context data." >&2
    exit 1
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
SEARCH_OUTPUT=$("$HOME/.claude/scripts/index-v2/search.sh" "$QUERY" "$PROJECT_ROOT" 2>/dev/null || true)

if [[ -z "$SEARCH_OUTPUT" || "$SEARCH_OUTPUT" == "No matches found." ]]; then
    case "$FORMAT" in
        json) echo "[]" ;;
        tsv) echo "# No results" ;;
        *) echo "No matches found for: $QUERY" ;;
    esac
    exit 0
fi

# Parse and format output
case "$FORMAT" in
    json)
        # Convert to JSON array
        echo "["
        FIRST=true
        echo "$SEARCH_OUTPUT" | grep '^\[' | head -n "$LIMIT" | while IFS= read -r line; do
            # Parse: [category] path/to/file (score: N)
            category=$(echo "$line" | sed 's/^\[\([^]]*\)\].*/\1/')
            path=$(echo "$line" | sed 's/^\[[^]]*\] \([^ ]*\).*/\1/')
            score=$(echo "$line" | grep -oE 'score: [0-9]+' | grep -oE '[0-9]+' || echo "1")

            if [[ "$FIRST" != "true" ]]; then echo ","; fi
            FIRST=false

            # Get functions from file index
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
        ;;

    tsv)
        # TSV header
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
        ;;

    compact|*)
        # Human-readable compact format (also good for AI context)
        echo "## Context for: $QUERY"
        echo ""
        echo "$SEARCH_OUTPUT" | head -n $((LIMIT * 4))  # Include match lines
        ;;
esac
