#!/bin/bash
# ARIA Semantic Cache - Match queries by meaning, not exact text
# Normalizes queries and finds similar cached results

CACHE_DIR="$HOME/.claude/cache/semantic"
CACHE_TTL=3600  # 1 hour

# Initialize cache directory
init_cache() {
    mkdir -p "$CACHE_DIR"
}

# Normalize query for semantic matching
normalize_query() {
    local query="$1"
    # Convert to lowercase, remove punctuation, sort words
    echo "$query" | \
        tr '[:upper:]' '[:lower:]' | \
        tr -d '[:punct:]' | \
        tr ' ' '\n' | \
        grep -v '^$' | \
        sort | \
        tr '\n' ' ' | \
        sed 's/ $//'
}

# Generate semantic cache key
semantic_key() {
    local query="$1"
    local normalized=$(normalize_query "$query")
    echo -n "$normalized" | md5sum | cut -d' ' -f1
}

# Calculate similarity between two queries (simple word overlap)
calc_similarity() {
    local query1="$1"
    local query2="$2"

    local norm1=$(normalize_query "$query1")
    local norm2=$(normalize_query "$query2")

    local words1=$(echo "$norm1" | wc -w)
    local words2=$(echo "$norm2" | wc -w)

    # Count common words
    local common=0
    for word in $norm1; do
        if echo "$norm2" | grep -wq "$word"; then
            ((common++))
        fi
    done

    # Similarity = common words / total unique words
    local total=$((words1 + words2 - common))
    if [[ $total -eq 0 ]]; then
        echo "0"
    else
        echo "scale=2; ($common * 100) / $total" | bc
    fi
}

# Get cached result if similar query exists
get_semantic_cache() {
    local query="$1"
    local threshold="${2:-70}"  # 70% similarity threshold

    init_cache

    local key=$(semantic_key "$query")
    local cache_file="$CACHE_DIR/${key}.cache"
    local meta_file="$CACHE_DIR/${key}.meta"

    # Check exact match first
    if [[ -f "$cache_file" && -f "$meta_file" ]]; then
        local age=$(($(date +%s) - $(stat -c %Y "$cache_file")))
        if [[ $age -lt $CACHE_TTL ]]; then
            echo "✓ Exact semantic match (age: ${age}s)" >&2
            cat "$cache_file"
            return 0
        fi
    fi

    # Search for similar queries
    for meta in "$CACHE_DIR"/*.meta; do
        [[ -f "$meta" ]] || continue

        local cached_query=$(cat "$meta" 2>/dev/null)
        local similarity=$(calc_similarity "$query" "$cached_query")

        if (( $(echo "$similarity >= $threshold" | bc -l) )); then
            local cached_file="${meta%.meta}.cache"
            local age=$(($(date +%s) - $(stat -c %Y "$cached_file")))

            if [[ $age -lt $CACHE_TTL ]]; then
                echo "✓ Similar match (${similarity}% similar, age: ${age}s)" >&2
                echo "  Cached query: $cached_query" >&2
                cat "$cached_file"
                return 0
            fi
        fi
    done

    echo "✗ No semantic cache hit" >&2
    return 1
}

# Save to semantic cache
set_semantic_cache() {
    local query="$1"
    local result="$2"

    init_cache

    local key=$(semantic_key "$query")
    local cache_file="$CACHE_DIR/${key}.cache"
    local meta_file="$CACHE_DIR/${key}.meta"

    echo "$result" > "$cache_file"
    echo "$query" > "$meta_file"

    echo "✓ Saved to semantic cache" >&2
}

# Clear old cache entries
clean_semantic_cache() {
    init_cache
    local now=$(date +%s)
    local count=0

    for cache in "$CACHE_DIR"/*.cache; do
        [[ -f "$cache" ]] || continue
        local age=$((now - $(stat -c %Y "$cache")))
        if [[ $age -gt $CACHE_TTL ]]; then
            rm -f "$cache" "${cache%.cache}.meta"
            ((count++))
        fi
    done

    echo "Cleaned $count expired cache entries"
}

# CLI interface
case "${1:-help}" in
    get)
        get_semantic_cache "$2" "${3:-70}"
        ;;
    set)
        set_semantic_cache "$2" "$3"
        ;;
    clean)
        clean_semantic_cache
        ;;
    test)
        # Test similarity calculation
        calc_similarity "$2" "$3"
        ;;
    *)
        echo "Usage: aria-semantic-cache.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  get <query> [threshold]  - Get cached result for similar query"
        echo "  set <query> <result>     - Save result to cache"
        echo "  clean                    - Remove expired cache entries"
        echo "  test <q1> <q2>          - Test similarity between queries"
        ;;
esac
