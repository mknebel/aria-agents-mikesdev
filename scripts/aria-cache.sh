#!/bin/bash
# ARIA Cache Management System
# Handles file content, search results, and index query caching with validation
# Usage: source aria-cache.sh for function library, or run directly for CLI commands

# Source state management for metrics (optional)
source ~/.claude/scripts/aria-state.sh 2>/dev/null || true

set -e

# Cache root directory
ARIA_CACHE_ROOT="${ARIA_CACHE_ROOT:=$HOME/.claude/cache}"
ARIA_CACHE_LOCK="$ARIA_CACHE_ROOT/.lock"

# TTL Settings (in seconds)
ARIA_CACHE_FILE_TTL=0          # Files: validate by mtime, no TTL
ARIA_CACHE_SEARCH_TTL=1800     # Search results: 30 minutes
ARIA_CACHE_QUERY_TTL=3600      # Index queries: 60 minutes

# Initialize cache directory structure
aria_cache_init() {
    mkdir -p "$ARIA_CACHE_ROOT"/{files,search,index-queries} 2>/dev/null || true
    touch "$ARIA_CACHE_LOCK"
    return 0
}

# Generate MD5 hash for cache key
aria_cache_hash() {
    local input="$1"
    echo -n "$input" | md5sum | cut -d' ' -f1
}

# Lock-protected file operation
aria_cache_lock() {
    local op="$1"
    shift

    (
        exec 200>"$ARIA_CACHE_LOCK"
        flock -x 200 2>/dev/null || true
        "$op" "$@"
    )
}

# =============================================================================
# FILE CACHING - Validate by mtime
# =============================================================================

# Get cached file content if valid (mtime match)
# Returns content on hit (exit 0), empty on miss (exit 1)
aria_cache_file_get() {
    local filepath="$1"
    [[ -z "$filepath" ]] && return 1

    local hash=$(aria_cache_hash "$filepath")
    local cache_file="$ARIA_CACHE_ROOT/files/$hash.json"

    if [[ ! -f "$cache_file" ]]; then
        aria_cache_lock aria_inc "cache_misses"
        return 1
    fi

    # Validate mtime
    local cached_mtime=$(jq -r '.mtime // 0' "$cache_file" 2>/dev/null || echo 0)
    local current_mtime=$(stat -c %Y "$filepath" 2>/dev/null || echo 0)

    if [[ "$current_mtime" == "0" ]]; then
        # File doesn't exist anymore
        rm -f "$cache_file"
        return 1
    fi

    if [[ "$cached_mtime" != "$current_mtime" ]]; then
        # File was modified
        rm -f "$cache_file"
        aria_cache_lock aria_inc "cache_misses"
        return 1
    fi

    # Cache hit - return content
    jq -r '.content // ""' "$cache_file" 2>/dev/null
    aria_cache_lock aria_inc "cache_hits"
    return 0
}

# Cache file content with metadata
# Returns 0 on success, 1 on failure
aria_cache_file_set() {
    local filepath="$1"
    [[ -z "$filepath" ]] && return 1
    [[ ! -f "$filepath" ]] && return 1

    local hash=$(aria_cache_hash "$filepath")
    local cache_file="$ARIA_CACHE_ROOT/files/$hash.json"
    local mtime=$(stat -c %Y "$filepath" 2>/dev/null || echo 0)
    local size=$(stat -c %s "$filepath" 2>/dev/null || echo 0)
    local content=$(cat "$filepath" 2>/dev/null || echo "")
    local content_hash=$(echo -n "$content" | md5sum | cut -d' ' -f1)
    local cached_at=$(date +%s)

    mkdir -p "$ARIA_CACHE_ROOT/files"

    jq -n \
      --arg path "$filepath" \
      --argjson mtime "$mtime" \
      --argjson size "$size" \
      --arg content_hash "$content_hash" \
      --argjson cached_at "$cached_at" \
      --arg content "$content" \
      '{path: $path, mtime: $mtime, size: $size, content_hash: $content_hash, cached_at: $cached_at, content: $content}' \
      > "$cache_file" 2>/dev/null || return 1

    return 0
}

# Check if cached file is valid (mtime match)
# Returns 0 if valid, 1 if invalid/missing
aria_cache_file_valid() {
    local filepath="$1"
    [[ -z "$filepath" ]] && return 1

    local hash=$(aria_cache_hash "$filepath")
    local cache_file="$ARIA_CACHE_ROOT/files/$hash.json"

    [[ ! -f "$cache_file" ]] && return 1

    local cached_mtime=$(jq -r '.mtime // 0' "$cache_file" 2>/dev/null || echo 0)
    local current_mtime=$(stat -c %Y "$filepath" 2>/dev/null || echo 0)

    [[ "$cached_mtime" != "$current_mtime" ]] && return 1
    return 0
}

# =============================================================================
# SEARCH CACHING - Pattern + Path based
# =============================================================================

# Get cached search results
# Returns JSON array of files on hit (exit 0), empty on miss (exit 1)
aria_cache_search_get() {
    local pattern="$1"
    local path="${2:-.}"
    [[ -z "$pattern" ]] && return 1

    local key="${pattern}|${path}"
    local hash=$(aria_cache_hash "$key")
    local cache_file="$ARIA_CACHE_ROOT/search/$hash.json"

    if [[ ! -f "$cache_file" ]]; then
        aria_cache_lock aria_inc "cache_misses"
        return 1
    fi

    # Check TTL
    local cached_at=$(jq -r '.cached_at // 0' "$cache_file" 2>/dev/null || echo 0)
    local now=$(date +%s)
    local age=$((now - cached_at))

    if [[ $age -gt $ARIA_CACHE_SEARCH_TTL ]]; then
        rm -f "$cache_file"
        return 2  # Expired
    fi

    # Return results
    jq -r '.files // []' "$cache_file" 2>/dev/null
    aria_cache_lock aria_inc "cache_hits"
    return 0
}

# Cache search results
# Input: JSON array of file paths
aria_cache_search_set() {
    local pattern="$1"
    local path="${2:-.}"
    local results="$3"

    [[ -z "$pattern" ]] && return 1
    [[ -z "$results" ]] && return 1

    local key="${pattern}|${path}"
    local hash=$(aria_cache_hash "$key")
    local cache_file="$ARIA_CACHE_ROOT/search/$hash.json"
    local cached_at=$(date +%s)

    mkdir -p "$ARIA_CACHE_ROOT/search"

    jq -n \
      --arg pattern "$pattern" \
      --arg path "$path" \
      --argjson files "$(echo "$results" | jq -c . 2>/dev/null || echo '[]')" \
      --argjson cached_at "$cached_at" \
      --argjson ttl "$ARIA_CACHE_SEARCH_TTL" \
      '{pattern: $pattern, path: $path, files: $files, cached_at: $cached_at, ttl: $ttl}' \
      > "$cache_file" 2>/dev/null || return 1

    return 0
}

# =============================================================================
# INDEX QUERY CACHING - SQL-style caching
# =============================================================================

# Get cached query results
# Returns JSON results on hit (exit 0), empty on miss (exit 1)
aria_cache_query_get() {
    local query="$1"
    [[ -z "$query" ]] && return 1

    local hash=$(aria_cache_hash "$query")
    local cache_file="$ARIA_CACHE_ROOT/index-queries/$hash.json"

    if [[ ! -f "$cache_file" ]]; then
        aria_cache_lock aria_inc "cache_misses"
        return 1
    fi

    # Check TTL
    local cached_at=$(jq -r '.cached_at // 0' "$cache_file" 2>/dev/null || echo 0)
    local now=$(date +%s)
    local age=$((now - cached_at))

    if [[ $age -gt $ARIA_CACHE_QUERY_TTL ]]; then
        rm -f "$cache_file"
        return 2  # Expired
    fi

    # Return results
    jq -r '.results // []' "$cache_file" 2>/dev/null
    aria_cache_lock aria_inc "cache_hits"
    return 0
}

# Cache query results
# Input: JSON results
aria_cache_query_set() {
    local query="$1"
    local results="$2"

    [[ -z "$query" ]] && return 1
    [[ -z "$results" ]] && return 1

    local hash=$(aria_cache_hash "$query")
    local cache_file="$ARIA_CACHE_ROOT/index-queries/$hash.json"
    local cached_at=$(date +%s)

    mkdir -p "$ARIA_CACHE_ROOT/index-queries"

    jq -n \
      --arg query "$query" \
      --argjson results "$(echo "$results" | jq -c . 2>/dev/null || echo '[]')" \
      --argjson cached_at "$cached_at" \
      --argjson ttl "$ARIA_CACHE_QUERY_TTL" \
      '{query: $query, results: $results, cached_at: $cached_at, ttl: $ttl}' \
      > "$cache_file" 2>/dev/null || return 1

    return 0
}

# =============================================================================
# INVALIDATION
# =============================================================================

# Invalidate specific file cache
aria_cache_invalidate() {
    local filepath="$1"
    [[ -z "$filepath" ]] && return 1

    local hash=$(aria_cache_hash "$filepath")
    local cache_file="$ARIA_CACHE_ROOT/files/$hash.json"

    rm -f "$cache_file" 2>/dev/null || true
    return 0
}

# Invalidate all search cache
aria_cache_invalidate_search() {
    rm -rf "$ARIA_CACHE_ROOT/search" 2>/dev/null || true
    mkdir -p "$ARIA_CACHE_ROOT/search"
    return 0
}

# Invalidate all query cache
aria_cache_invalidate_queries() {
    rm -rf "$ARIA_CACHE_ROOT/index-queries" 2>/dev/null || true
    mkdir -p "$ARIA_CACHE_ROOT/index-queries"
    return 0
}

# Invalidate everything
aria_cache_invalidate_all() {
    rm -rf "$ARIA_CACHE_ROOT" 2>/dev/null || true
    mkdir -p "$ARIA_CACHE_ROOT"/{files,search,index-queries}
    return 0
}

# =============================================================================
# STATISTICS & CLEANUP
# =============================================================================

# Get cache statistics (JSON output)
aria_cache_stats() {
    local total_size=$(du -sh "$ARIA_CACHE_ROOT" 2>/dev/null | cut -f1)
    local file_count=$(find "$ARIA_CACHE_ROOT/files" -type f -name "*.json" 2>/dev/null | wc -l)
    local search_count=$(find "$ARIA_CACHE_ROOT/search" -type f -name "*.json" 2>/dev/null | wc -l)
    local query_count=$(find "$ARIA_CACHE_ROOT/index-queries" -type f -name "*.json" 2>/dev/null | wc -l)

    local file_size=$(du -sh "$ARIA_CACHE_ROOT/files" 2>/dev/null | cut -f1)
    local search_size=$(du -sh "$ARIA_CACHE_ROOT/search" 2>/dev/null | cut -f1)
    local query_size=$(du -sh "$ARIA_CACHE_ROOT/index-queries" 2>/dev/null | cut -f1)

    jq -n \
      --arg total_size "$total_size" \
      --argjson file_count "$file_count" \
      --arg file_size "$file_size" \
      --argjson search_count "$search_count" \
      --arg search_size "$search_size" \
      --argjson query_count "$query_count" \
      --arg query_size "$query_size" \
      '{
        total_size: $total_size,
        files: {count: $file_count, size: $file_size},
        search: {count: $search_count, size: $search_size},
        queries: {count: $query_count, size: $query_size}
      }'
}

# Clean expired cache entries
aria_cache_clean() {
    local now=$(date +%s)
    local cleaned=0

    # Search cache - clean expired entries
    while IFS= read -r cache_file; do
        [[ -z "$cache_file" ]] && continue
        local cached_at=$(jq -r '.cached_at // 0' "$cache_file" 2>/dev/null || echo 0)
        local age=$((now - cached_at))
        if [[ $age -gt $ARIA_CACHE_SEARCH_TTL ]]; then
            rm -f "$cache_file"
            ((cleaned++))
        fi
    done < <(find "$ARIA_CACHE_ROOT/search" -maxdepth 1 -type f -name "*.json" 2>/dev/null)

    # Query cache - clean expired entries
    while IFS= read -r cache_file; do
        [[ -z "$cache_file" ]] && continue
        local cached_at=$(jq -r '.cached_at // 0' "$cache_file" 2>/dev/null || echo 0)
        local age=$((now - cached_at))
        if [[ $age -gt $ARIA_CACHE_QUERY_TTL ]]; then
            rm -f "$cache_file"
            ((cleaned++))
        fi
    done < <(find "$ARIA_CACHE_ROOT/index-queries" -maxdepth 1 -type f -name "*.json" 2>/dev/null)

    return 0
}

# =============================================================================
# CLI INTERFACE
# =============================================================================

aria_cache_cli() {
    local cmd="$1"
    shift

    case "$cmd" in
        init)
            aria_cache_init
            echo "Cache initialized at: $ARIA_CACHE_ROOT"
            ;;
        get-file)
            [[ -z "$1" ]] && { echo "Usage: aria-cache.sh get-file <filepath>"; return 1; }
            aria_cache_file_get "$1"
            ;;
        set-file)
            [[ -z "$1" ]] && { echo "Usage: aria-cache.sh set-file <filepath>"; return 1; }
            aria_cache_file_set "$1" && echo "Cached: $1"
            ;;
        valid-file)
            [[ -z "$1" ]] && { echo "Usage: aria-cache.sh valid-file <filepath>"; return 1; }
            if aria_cache_file_valid "$1"; then
                echo "VALID: $1"
                return 0
            else
                echo "INVALID: $1"
                return 1
            fi
            ;;
        get-search)
            [[ -z "$1" ]] && { echo "Usage: aria-cache.sh get-search <pattern> [path]"; return 1; }
            aria_cache_search_get "$1" "$2"
            ;;
        set-search)
            [[ -z "$1" ]] || [[ -z "$2" ]] && { echo "Usage: aria-cache.sh set-search <pattern> <path> <json_results>"; return 1; }
            aria_cache_search_set "$1" "$2" "$3" && echo "Cached search: $1 in $2"
            ;;
        get-query)
            [[ -z "$1" ]] && { echo "Usage: aria-cache.sh get-query <query>"; return 1; }
            aria_cache_query_get "$1"
            ;;
        set-query)
            [[ -z "$1" ]] || [[ -z "$2" ]] && { echo "Usage: aria-cache.sh set-query <query> <json_results>"; return 1; }
            aria_cache_query_set "$1" "$2" && echo "Cached query: $1"
            ;;
        invalidate)
            [[ -z "$1" ]] && { echo "Usage: aria-cache.sh invalidate <filepath>"; return 1; }
            aria_cache_invalidate "$1" && echo "Invalidated: $1"
            ;;
        invalidate-search)
            aria_cache_invalidate_search && echo "Search cache cleared"
            ;;
        invalidate-queries)
            aria_cache_invalidate_queries && echo "Query cache cleared"
            ;;
        invalidate-all|flush)
            aria_cache_invalidate_all && echo "All caches cleared"
            ;;
        stats)
            aria_cache_stats | jq .
            ;;
        clean)
            aria_cache_clean && echo "Cache cleanup complete"
            ;;
        *)
            cat << 'EOF'
ARIA Cache Management System

USAGE:
  aria-cache.sh <command> [args]

FILE CACHING (validate by mtime):
  get-file <filepath>               Get cached file content (exit 0=hit, 1=miss)
  set-file <filepath>               Cache file with mtime metadata
  valid-file <filepath>             Check if file cache is valid

SEARCH CACHING (30min TTL):
  get-search <pattern> [path]       Get cached search results
  set-search <pattern> <path> <json> Cache search results

QUERY CACHING (60min TTL):
  get-query <query>                 Get cached query results
  set-query <query> <json>          Cache query results

INVALIDATION:
  invalidate <filepath>             Invalidate specific file cache
  invalidate-search                 Clear all search cache
  invalidate-queries                Clear all query cache
  invalidate-all, flush             Clear everything

MANAGEMENT:
  init                              Initialize cache directories
  stats                             Show cache statistics (JSON)
  clean                             Remove expired cache entries

ENVIRONMENT:
  ARIA_CACHE_ROOT                   Cache directory (default: ~/.claude/cache)
  ARIA_CACHE_FILE_TTL               File cache TTL (default: 0, use mtime)
  ARIA_CACHE_SEARCH_TTL             Search cache TTL (default: 1800s)
  ARIA_CACHE_QUERY_TTL              Query cache TTL (default: 3600s)

EXIT CODES:
  0                                 Success / Cache hit
  1                                 Failure / Cache miss
  2                                 Cache expired

EXAMPLES:
  # Initialize cache
  aria-cache.sh init

  # Cache a file
  aria-cache.sh set-file /path/to/file.php

  # Retrieve cached file
  aria-cache.sh get-file /path/to/file.php

  # Cache search results
  aria-cache.sh set-search "pattern" "." '["file1.php","file2.php"]'

  # Get statistics
  aria-cache.sh stats

  # Clear expired entries
  aria-cache.sh clean
EOF
            ;;
    esac
}

# Main entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Called directly, not sourced
    aria_cache_init
    aria_cache_cli "$@"
else
    # Sourced as library, auto-init
    aria_cache_init 2>/dev/null || true
fi
