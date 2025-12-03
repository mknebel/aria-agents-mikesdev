#!/bin/bash
# ctx.sh - Hybrid context builder (fast local + indexed semantic)
#
# NEW: Fast path using ripgrep for simple patterns (~1s)
#      Falls back to indexed search for semantic queries (~5s)
#
# Usage:
#   ctx "pattern"         # Auto: tries fast first, then indexed
#   ctx -f "pattern"      # Force fast (ripgrep only)
#   ctx -s "query"        # Force semantic (indexed search)
#   ctx "query" -n 20     # Limit results
#   ctx "query" --force   # Skip dedup check

set -e

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

VAR_DIR="/tmp/claude_vars"
SCRIPTS_DIR="$HOME/.claude/scripts"
mkdir -p "$VAR_DIR"

# Parse arguments
QUERY=""
MODE="auto"  # auto, fast, semantic
LIMIT=30
PROJECT_ROOT="$(pwd)"
SAVE=true
FORCE=false
FORMAT="compact"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--fast) MODE="fast"; shift ;;
        -s|--semantic) MODE="semantic"; shift ;;
        --json) FORMAT="json"; shift ;;
        --tsv) FORMAT="tsv"; shift ;;
        -n) LIMIT="$2"; shift 2 ;;
        -p|--path) PROJECT_ROOT="$2"; shift 2 ;;
        --no-save) SAVE=false; shift ;;
        --force) FORCE=true; shift ;;
        -*) echo "Unknown option: $1" >&2; exit 1 ;;
        *) QUERY="$QUERY $1"; shift ;;
    esac
done

QUERY=$(echo "$QUERY" | xargs)

if [[ -z "$QUERY" ]]; then
    cat << 'HELP'
ctx - Hybrid context builder (fast + semantic)

Usage: ctx "query" [options]

Modes:
  (default)     Auto: fast first, semantic if no results
  -f, --fast    Fast only (ripgrep pattern match)
  -s, --semantic Semantic only (indexed search)

Options:
  -n N          Limit to N results (default: 30)
  -p PATH       Search in specific path
  --force       Skip deduplication check
  --no-save     Don't save to $ctx_last

Examples:
  ctx "auth login"        # Auto mode → $ctx_last
  ctx -f "function.*pay"  # Fast regex search
  ctx -s "payment flow"   # Semantic search
HELP
    exit 1
fi

# Deduplication check
META_FILE="$VAR_DIR/ctx_last.meta"
if [[ -f "$META_FILE" ]] && ! $FORCE; then
    IFS='|' read -r ts size lines old_query < "$META_FILE"
    age=$(( $(date +%s) - ts ))
    norm_old="${old_query,,}"
    norm_new="${QUERY,,}"

    if [[ "$norm_old" == "$norm_new" && $age -lt 300 ]]; then
        age_fmt=$((age / 60))m$((age % 60))s
        echo -e "${YELLOW}⚠️  Cached (${age_fmt} ago): $lines lines${NC}" >&2
        read -t 2 -p "   Use cached? [Y/n]: " response < /dev/tty 2>/dev/null || response="y"
        if [[ "${response,,}" != "n" ]]; then
            cat "$VAR_DIR/ctx_last.txt"
            exit 0
        fi
    fi
fi

# Fast search function (ripgrep)
fast_search() {
    local query="$1"
    local limit="$2"

    echo -e "${CYAN}⚡ Fast search: $query${NC}" >&2

    # Build ripgrep pattern
    local pattern="$query"

    # Search with ripgrep
    local results
    results=$(rg -l -i --type-add 'code:*.{php,js,ts,py,rb,go,java,c,cpp,h}' -t code "$pattern" "$PROJECT_ROOT" 2>/dev/null | head -n "$limit" || true)

    if [[ -z "$results" ]]; then
        return 1
    fi

    # Format output
    echo "## Context for: $query (fast)"
    echo ""
    echo "$results" | while read -r file; do
        echo "[$( basename "${file%.*}" | tr '[:lower:]' '[:upper:]' )] $file"
        # Show matching lines with context
        rg -n -i -C1 "$pattern" "$file" 2>/dev/null | head -20 || true
        echo ""
    done
}

# Semantic search function (indexed)
semantic_search() {
    local query="$1"
    local limit="$2"

    echo -e "${BLUE}🔍 Semantic search: $query${NC}" >&2

    # Ensure index exists
    local index_name
    index_name=$(echo "$PROJECT_ROOT" | md5sum | cut -d' ' -f1)
    local index_dir="$HOME/.claude/indexes/$index_name"

    if [[ ! -f "$index_dir/inverted.json" ]]; then
        echo "Building index..." >&2
        "$HOME/.claude/scripts/index-v2/build-index.sh" "$PROJECT_ROOT" >&2 2>/dev/null || true
    fi

    # Run search
    local results
    results=$("$HOME/.claude/scripts/index-v2/search.sh" "$query" "$PROJECT_ROOT" 2>/dev/null || true)

    if [[ -z "$results" || "$results" == "No matches found." ]]; then
        return 1
    fi

    echo "## Context for: $query (semantic)"
    echo ""
    echo "$results" | head -n $((limit * 4))
}

# Execute search based on mode
OUTPUT=""
case "$MODE" in
    fast)
        OUTPUT=$(fast_search "$QUERY" "$LIMIT") || OUTPUT="No matches found for: $QUERY"
        ;;
    semantic)
        OUTPUT=$(semantic_search "$QUERY" "$LIMIT") || OUTPUT="No matches found for: $QUERY"
        ;;
    auto)
        # Try fast first
        OUTPUT=$(fast_search "$QUERY" "$LIMIT" 2>/dev/null) || {
            # Fall back to semantic
            OUTPUT=$(semantic_search "$QUERY" "$LIMIT" 2>/dev/null) || OUTPUT="No matches found for: $QUERY"
        }
        ;;
esac

# Output result
echo "$OUTPUT"

# Auto-save to variable
if $SAVE && [[ -n "$OUTPUT" && "$OUTPUT" != "No matches"* ]]; then
    echo "$OUTPUT" | "$SCRIPTS_DIR/var.sh" save "ctx_last" - "$QUERY" >/dev/null 2>&1 || true
fi
