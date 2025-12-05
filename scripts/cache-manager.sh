#!/bin/bash
# cache-manager.sh - Unified cache management for Claude Code CLI
# Usage: cache-manager.sh <command> [args]
#   get <category> <key>       - Get cached value
#   set <category> <key> <ttl> - Set from stdin
#   check <category> <key>     - Check if valid (exit 0) or stale (exit 1)
#   invalidate <pattern>       - Remove matching caches
#   stats                      - Show cache statistics
#   clean                      - Remove expired entries

CACHE_ROOT="$HOME/.claude/cache"
mkdir -p "$CACHE_ROOT"/{context,results,patterns,indexes,meta}

CMD="$1"
shift

cache_path() {
    local category="$1" key="$2"
    local hash=$(echo "$key" | md5sum | cut -d' ' -f1)
    echo "$CACHE_ROOT/$category/$hash"
}

cache_get() {
    local path=$(cache_path "$1" "$2")
    if [ -f "$path" ] && [ -f "$path.meta" ]; then
        local created=$(jq -r '.created' "$path.meta" 2>/dev/null)
        local ttl=$(jq -r '.ttl' "$path.meta" 2>/dev/null)
        local now=$(date +%s)
        local age=$((now - created))
        if [ "$age" -lt "$ttl" ]; then
            cat "$path"
            return 0
        fi
    fi
    return 1
}

cache_set() {
    local category="$1" key="$2" ttl="${3:-3600}"
    local path=$(cache_path "$category" "$key")
    mkdir -p "$(dirname "$path")"
    cat > "$path"
    echo "{\"created\":$(date +%s),\"ttl\":$ttl,\"key\":\"$key\"}" > "$path.meta"
}

cache_check() {
    local path=$(cache_path "$1" "$2")
    if [ -f "$path" ] && [ -f "$path.meta" ]; then
        local created=$(jq -r '.created' "$path.meta" 2>/dev/null)
        local ttl=$(jq -r '.ttl' "$path.meta" 2>/dev/null)
        local now=$(date +%s)
        [ $((now - created)) -lt "$ttl" ] && return 0
    fi
    return 1
}

cache_invalidate() {
    local pattern="$1"
    find "$CACHE_ROOT" -name "*$pattern*" -type f -delete 2>/dev/null
    echo "Invalidated: $pattern"
}

cache_stats() {
    echo "=== Cache Statistics ==="
    echo "Location: $CACHE_ROOT"
    echo "Total size: $(du -sh "$CACHE_ROOT" 2>/dev/null | cut -f1)"
    echo ""
    for dir in context results patterns indexes; do
        local count=$(find "$CACHE_ROOT/$dir" -type f ! -name '*.meta' 2>/dev/null | wc -l)
        local size=$(du -sh "$CACHE_ROOT/$dir" 2>/dev/null | cut -f1)
        echo "$dir: $count entries, $size"
    done
}

cache_clean() {
    local now=$(date +%s)
    local cleaned=0
    for meta in $(find "$CACHE_ROOT" -name "*.meta" 2>/dev/null); do
        local created=$(jq -r '.created' "$meta" 2>/dev/null)
        local ttl=$(jq -r '.ttl' "$meta" 2>/dev/null)
        if [ $((now - created)) -ge "$ttl" ]; then
            rm -f "${meta%.meta}" "$meta"
            ((cleaned++))
        fi
    done
    echo "Cleaned $cleaned expired entries"
}

case "$CMD" in
    get) cache_get "$@" ;;
    set) cache_set "$@" ;;
    check) cache_check "$@" ;;
    invalidate) cache_invalidate "$@" ;;
    stats) cache_stats ;;
    clean) cache_clean ;;
    *) echo "Usage: cache-manager.sh <get|set|check|invalidate|stats|clean> [args]" ;;
esac
