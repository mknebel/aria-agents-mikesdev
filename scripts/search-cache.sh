#!/bin/bash
# Search Cache Manager - Stores and retrieves cached search results
# Usage:
#   search-cache.sh check "pattern" "path"  - Check if cached
#   search-cache.sh store "pattern" "path" "result_file"  - Store result
#   search-cache.sh clear  - Clear all cache
#   search-cache.sh stats  - Show cache stats

ACTION="$1"
CACHE_DIR="$HOME/.claude/cache/search-cache"
CACHE_INDEX="$CACHE_DIR/index.json"
CACHE_TTL=3600  # 1 hour in seconds

mkdir -p "$CACHE_DIR"

# Initialize index if needed
if [[ ! -f "$CACHE_INDEX" ]]; then
    echo '{"entries":[]}' > "$CACHE_INDEX"
fi

# Normalize pattern for comparison (lowercase, remove extra spaces)
normalize() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr -s ' ' | sed 's/[^a-z0-9 ]//g' | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/ $//'
}

# Generate cache key from pattern + path
cache_key() {
    local pattern="$1"
    local path="$2"
    echo "${pattern}|${path}" | md5sum | cut -d' ' -f1
}

case "$ACTION" in
    check)
        PATTERN="$2"
        PATH_ARG="$3"

        if [[ -z "$PATTERN" ]]; then
            echo "MISS"
            exit 0
        fi

        NORMALIZED=$(normalize "$PATTERN")
        KEY=$(cache_key "$NORMALIZED" "$PATH_ARG")
        RESULT_FILE="$CACHE_DIR/${KEY}.txt"

        # Check if cache file exists and is fresh
        if [[ -f "$RESULT_FILE" ]]; then
            AGE=$(( $(date +%s) - $(stat -c %Y "$RESULT_FILE" 2>/dev/null || echo 0) ))
            if [[ $AGE -lt $CACHE_TTL ]]; then
                echo "HIT"
                echo "$RESULT_FILE"
                exit 0
            fi
        fi

        # Check for similar patterns in index
        SIMILAR=$(jq -r --arg norm "$NORMALIZED" '.entries[] | select(.normalized == $norm) | .key' "$CACHE_INDEX" 2>/dev/null | head -1)
        if [[ -n "$SIMILAR" ]]; then
            SIMILAR_FILE="$CACHE_DIR/${SIMILAR}.txt"
            if [[ -f "$SIMILAR_FILE" ]]; then
                AGE=$(( $(date +%s) - $(stat -c %Y "$SIMILAR_FILE" 2>/dev/null || echo 0) ))
                if [[ $AGE -lt $CACHE_TTL ]]; then
                    echo "SIMILAR"
                    echo "$SIMILAR_FILE"
                    exit 0
                fi
            fi
        fi

        echo "MISS"
        ;;

    store)
        PATTERN="$2"
        PATH_ARG="$3"
        RESULT="$4"

        if [[ -z "$PATTERN" ]] || [[ -z "$RESULT" ]]; then
            echo "Usage: search-cache.sh store 'pattern' 'path' 'result_content'"
            exit 1
        fi

        NORMALIZED=$(normalize "$PATTERN")
        KEY=$(cache_key "$NORMALIZED" "$PATH_ARG")
        RESULT_FILE="$CACHE_DIR/${KEY}.txt"

        # Store result
        echo "$RESULT" > "$RESULT_FILE"

        # Update index
        jq --arg key "$KEY" --arg pattern "$PATTERN" --arg norm "$NORMALIZED" --arg path "$PATH_ARG" --arg ts "$(date -Iseconds)" \
            '.entries = [.entries[] | select(.key != $key)] + [{"key": $key, "pattern": $pattern, "normalized": $norm, "path": $path, "timestamp": $ts}]' \
            "$CACHE_INDEX" > "${CACHE_INDEX}.tmp" && mv "${CACHE_INDEX}.tmp" "$CACHE_INDEX"

        echo "STORED: $KEY"
        ;;

    clear)
        rm -f "$CACHE_DIR"/*.txt
        echo '{"entries":[]}' > "$CACHE_INDEX"
        echo "Cache cleared"
        ;;

    stats)
        echo "=== Search Cache Stats ==="
        echo "Cache directory: $CACHE_DIR"
        echo "Cache files: $(ls -1 "$CACHE_DIR"/*.txt 2>/dev/null | wc -l)"
        echo "Total size: $(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)"
        echo "Index entries: $(jq '.entries | length' "$CACHE_INDEX" 2>/dev/null)"
        echo ""
        echo "Recent entries:"
        jq -r '.entries | sort_by(.timestamp) | reverse | .[0:5] | .[] | "  \(.pattern) (\(.timestamp))"' "$CACHE_INDEX" 2>/dev/null
        ;;

    *)
        echo "Usage: search-cache.sh <check|store|clear|stats> [args...]"
        exit 1
        ;;
esac
