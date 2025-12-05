#!/bin/bash
# cache-manager.sh - Enhanced caching with pattern matching and statistics
#
# Features:
# - Pattern normalization (similar prompts → same cache)
# - Tiered TTL (code gen: 2h, reviews: 1h, quick: 30m)
# - Cache statistics tracking
# - LRU eviction (keeps cache under 100MB)
#
# Usage:
#   cache-manager.sh get <provider> "prompt"
#   cache-manager.sh set <provider> "prompt" "response"
#   cache-manager.sh stats
#   cache-manager.sh clear [pattern]

set -e

CACHE_DIR="/tmp/claude_vars/cache"
STATS_FILE="/tmp/claude_vars/cache_stats.json"
MAX_CACHE_MB=100

mkdir -p "$CACHE_DIR"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Initialize stats if needed
init_stats() {
    if [[ ! -f "$STATS_FILE" ]]; then
        cat > "$STATS_FILE" <<'EOF'
{"hits":0,"misses":0,"saved_tokens":0,"saved_cost":0.0}
EOF
    fi
}

# Update stats
update_stats() {
    local field="$1"
    local increment="${2:-1}"
    init_stats

    local current=$(jq -r ".$field // 0" "$STATS_FILE")
    local new=$(echo "$current + $increment" | bc)

    local tmp=$(mktemp)
    jq ".$field = $new" "$STATS_FILE" > "$tmp" && mv "$tmp" "$STATS_FILE"
}

# Normalize prompt for pattern matching
# Removes specific values but keeps structure
normalize_prompt() {
    local prompt="$1"

    # Normalize common patterns:
    # - Line numbers → @NUM
    # - Specific function/class names → keep (important for cache)
    # Note: Keep file paths as-is (important for context matching)

    echo "$prompt" | \
        sed -E 's/:[0-9]+/:@NUM/g' | \
        sed -E 's/line [0-9]+/line @NUM/g' | \
        tr '[:upper:]' '[:lower:]'
}

# Get TTL based on intent
get_ttl() {
    local prompt="${1,,}"  # lowercase

    # Code generation - longer TTL (same spec = same code)
    if [[ "$prompt" =~ (implement|write|create|build|generate) ]]; then
        echo 7200  # 2 hours
        return
    fi

    # Reviews - medium TTL
    if [[ "$prompt" =~ (review|check|analyze|audit) ]]; then
        echo 3600  # 1 hour
        return
    fi

    # Quick questions - shorter TTL
    if [[ "$prompt" =~ (explain|what|how|why|summarize) ]]; then
        echo 1800  # 30 minutes
        return
    fi

    # Default
    echo 3600  # 1 hour
}

# Generate cache key with pattern normalization
get_cache_key() {
    local provider="$1"
    local prompt="$2"

    local normalized=$(normalize_prompt "$prompt")
    local var_hashes=""

    # Include var file hashes for content-dependent caching
    local vars=$(echo "$prompt" | grep -oE '@var:[a-zA-Z0-9_]+' || true)
    for ref in $vars; do
        local var_name="${ref#@var:}"
        local var_file="/tmp/claude_vars/${var_name}.txt"
        if [[ -f "$var_file" ]]; then
            var_hashes+="|$(md5sum "$var_file" | cut -d' ' -f1)"
        fi
    done

    echo "${provider}|${normalized}${var_hashes}" | md5sum | cut -d' ' -f1
}

# Check cache
cmd_get() {
    local provider="$1"
    local prompt="$2"

    local cache_key=$(get_cache_key "$provider" "$prompt")
    local cache_file="$CACHE_DIR/${cache_key}.txt"
    local meta_file="$CACHE_DIR/${cache_key}.meta"

    # Check if exists
    if [[ ! -f "$cache_file" ]] || [[ ! -f "$meta_file" ]]; then
        update_stats "misses"
        return 1
    fi

    # Check TTL
    local ttl=$(get_ttl "$prompt")
    local age=$(( $(date +%s) - $(stat -c %Y "$cache_file") ))

    if [[ $age -gt $ttl ]]; then
        update_stats "misses"
        return 1
    fi

    # Cache hit!
    update_stats "hits"

    # Estimate saved tokens (rough: response length / 4)
    local response_len=$(wc -c < "$cache_file")
    local saved_tokens=$((response_len / 4))
    update_stats "saved_tokens" "$saved_tokens"

    # Estimate saved cost (rough: $0.01 per 1000 tokens)
    local saved_cost=$(echo "scale=4; $saved_tokens * 0.00001" | bc)
    update_stats "saved_cost" "$saved_cost"

    echo -e "${GREEN}⚡ Cache hit (${age}s old, saved ~${saved_tokens} tokens)${NC}" >&2
    cat "$cache_file"
    return 0
}

# Set cache
cmd_set() {
    local provider="$1"
    local prompt="$2"
    local response="$3"

    # Don't cache errors
    if [[ "$response" =~ ^(Error|error:|ERROR|Failed) ]]; then
        return 0
    fi

    # Don't cache empty responses
    if [[ ${#response} -lt 20 ]]; then
        return 0
    fi

    local cache_key=$(get_cache_key "$provider" "$prompt")
    local cache_file="$CACHE_DIR/${cache_key}.txt"
    local meta_file="$CACHE_DIR/${cache_key}.meta"

    echo "$response" > "$cache_file"
    echo "${provider}|$(date +%s)|${prompt:0:100}" > "$meta_file"

    # Check cache size and evict if needed
    evict_if_needed
}

# LRU eviction
evict_if_needed() {
    local cache_size_kb=$(du -sk "$CACHE_DIR" 2>/dev/null | cut -f1)
    local max_kb=$((MAX_CACHE_MB * 1024))

    if [[ $cache_size_kb -gt $max_kb ]]; then
        echo -e "${YELLOW}Cache size ${cache_size_kb}KB > ${max_kb}KB, evicting old entries...${NC}" >&2

        # Delete oldest files until under limit
        while [[ $cache_size_kb -gt $max_kb ]]; do
            local oldest=$(find "$CACHE_DIR" -name "*.txt" -type f -printf '%T+ %p\n' 2>/dev/null | sort | head -1 | cut -d' ' -f2-)
            if [[ -n "$oldest" ]]; then
                rm -f "$oldest" "${oldest%.txt}.meta"
                cache_size_kb=$(du -sk "$CACHE_DIR" 2>/dev/null | cut -f1)
            else
                break
            fi
        done
    fi
}

# Show stats
cmd_stats() {
    init_stats

    local hits=$(jq -r '.hits // 0' "$STATS_FILE")
    local misses=$(jq -r '.misses // 0' "$STATS_FILE")
    local saved_tokens=$(jq -r '.saved_tokens // 0' "$STATS_FILE")
    local saved_cost=$(jq -r '.saved_cost // 0' "$STATS_FILE")
    local total=$((hits + misses))
    local hit_rate=0
    [[ $total -gt 0 ]] && hit_rate=$((hits * 100 / total))

    local cache_size=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)
    local cache_files=$(find "$CACHE_DIR" -name "*.txt" 2>/dev/null | wc -l)

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  CACHE STATISTICS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  Hits:         ${GREEN}${hits}${NC}"
    echo -e "  Misses:       ${misses}"
    echo -e "  Hit Rate:     ${GREEN}${hit_rate}%${NC}"
    echo -e "  Saved Tokens: ${GREEN}~${saved_tokens}${NC}"
    echo -e "  Saved Cost:   ${GREEN}~\$${saved_cost}${NC}"
    echo -e "  Cache Size:   ${cache_size} (${cache_files} entries)"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Clear cache
cmd_clear() {
    local pattern="${1:-*}"

    if [[ "$pattern" == "*" ]]; then
        rm -rf "$CACHE_DIR"/*
        rm -f "$STATS_FILE"
        echo -e "${GREEN}Cache cleared${NC}"
    else
        find "$CACHE_DIR" -name "*${pattern}*" -delete 2>/dev/null
        echo -e "${GREEN}Cleared entries matching: ${pattern}${NC}"
    fi
}

# Main dispatch
case "${1:-}" in
    get)
        shift
        cmd_get "$@"
        ;;
    set)
        shift
        cmd_set "$@"
        ;;
    stats)
        cmd_stats
        ;;
    clear)
        shift
        cmd_clear "$@"
        ;;
    *)
        cat <<'HELP'
cache-manager.sh - Enhanced LLM response caching

Usage:
  cache-manager.sh get <provider> "prompt"    # Check cache
  cache-manager.sh set <provider> "prompt" "response"  # Store in cache
  cache-manager.sh stats                      # Show statistics
  cache-manager.sh clear [pattern]            # Clear cache

Features:
  - Pattern normalization (similar prompts → same cache key)
  - Tiered TTL (code: 2h, review: 1h, quick: 30m)
  - Token savings tracking
  - LRU eviction (max 100MB)
HELP
        ;;
esac
