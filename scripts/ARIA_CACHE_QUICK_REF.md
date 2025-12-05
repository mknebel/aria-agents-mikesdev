# ARIA Cache Quick Reference

## Quick Start

```bash
# Initialize cache
aria-cache.sh init

# Cache a file
aria-cache.sh set-file /path/to/file.php

# Retrieve cached file
aria-cache.sh get-file /path/to/file.php

# Check if cache is valid
aria-cache.sh valid-file /path/to/file.php
```

## File Caching

**Validation**: mtime-based (automatic, no TTL)

```bash
# Set cache
aria-cache.sh set-file /path/to/file

# Get (hit=exit 0, miss=exit 1)
aria-cache.sh get-file /path/to/file

# Check validity
aria-cache.sh valid-file /path/to/file

# Library usage
source aria-cache.sh
aria_cache_file_set /path/to/file
content=$(aria_cache_file_get /path/to/file)
aria_cache_invalidate /path/to/file
```

## Search Caching

**Validation**: TTL-based (30 minutes by default)

```bash
# Set cache
aria-cache.sh set-search "pattern" "path" '["file1","file2"]'

# Get (hit=exit 0, miss=exit 1, expired=exit 2)
aria-cache.sh get-search "pattern" "path"

# Library usage
source aria-cache.sh
aria_cache_search_set "pattern" "/proj" '["a.js","b.js"]'
results=$(aria_cache_search_get "pattern" "/proj")
aria_cache_invalidate_search
```

## Query Caching

**Validation**: TTL-based (60 minutes by default)

```bash
# Set cache
aria-cache.sh set-query "SELECT * FROM users" '[{"id":1}]'

# Get (hit=exit 0, miss=exit 1, expired=exit 2)
aria-cache.sh get-query "SELECT * FROM users"

# Library usage
source aria-cache.sh
aria_cache_query_set "SELECT * FROM users" '[{"id":1}]'
results=$(aria_cache_query_get "SELECT * FROM users")
aria_cache_invalidate_queries
```

## Management

```bash
# View statistics (JSON)
aria-cache.sh stats

# Clean expired entries
aria-cache.sh clean

# Clear all search cache
aria-cache.sh invalidate-search

# Clear all query cache
aria-cache.sh invalidate-queries

# Clear everything
aria-cache.sh invalidate-all

# Alias for clear all
aria-cache.sh flush
```

## Configuration

```bash
# Custom cache location
export ARIA_CACHE_ROOT="/custom/path"

# File TTL (default: 0 = use mtime)
export ARIA_CACHE_FILE_TTL=0

# Search TTL (default: 1800 seconds = 30 min)
export ARIA_CACHE_SEARCH_TTL=3600

# Query TTL (default: 3600 seconds = 60 min)
export ARIA_CACHE_QUERY_TTL=7200
```

## Exit Codes

```bash
0  = Success / Cache hit
1  = Failure / Cache miss
2  = Cache expired
```

## Patterns

### Pattern: Cache with validation

```bash
source aria-cache.sh

# Try cache first
if output=$(aria_cache_file_get "/path/to/file"); then
    echo "Cache hit: $output"
else
    # Cache miss, generate fresh
    output=$(generate_output)
    aria_cache_file_set "/path/to/file"
    echo "$output"
fi
```

### Pattern: Search result caching

```bash
source aria-cache.sh

PATTERN="function.*auth"
PATH="/project/src"

# Check cache
if results=$(aria_cache_search_get "$PATTERN" "$PATH"); then
    echo "Using cached: $results"
else
    # Run search and cache
    results=$(rg "$PATTERN" "$PATH" | jq -Rs 'split("\n")[:-1]')
    aria_cache_search_set "$PATTERN" "$PATH" "$results"
    echo "Fresh search: $results"
fi
```

### Pattern: Metrics tracking

```bash
source aria-cache.sh
source aria-state.sh

# Metrics are automatically updated:
# - aria_inc "cache_hits" on hit
# - aria_inc "cache_misses" on miss

hits=$(aria_get cache_hits)
misses=$(aria_get cache_misses)
total=$((hits + misses))
rate=$((total > 0 ? hits * 100 / total : 0))
echo "Hit rate: ${rate}%"
```

## Workflow Integration

```bash
#!/bin/bash
# Example: ctx wrapper with caching

source /home/mike/.claude/scripts/aria-cache.sh

QUERY="$1"
HASH=$(echo -n "$QUERY" | md5sum | cut -d' ' -f1)

# Try cache first
if cached=$(aria_cache_query_get "$QUERY"); then
    echo "$cached"
    exit 0
fi

# Cache miss, run real search
results=$(perform_search "$QUERY")

# Cache for next time
aria_cache_query_set "$QUERY" "$results"

echo "$results"
```

## Common Issues

| Issue | Solution |
|-------|----------|
| File cache not updating | Check mtime: `stat -c %Y /path` |
| High miss rate | Check TTL settings or pattern variations |
| Permissions denied | `chmod 700 ~/.claude/cache` |
| Disk full | `aria-cache.sh flush && aria-cache.sh init` |

## File Locations

```
~/.claude/cache/files/         - File cache entries
~/.claude/cache/search/        - Search cache entries
~/.claude/cache/index-queries/ - Query cache entries
```

## Metrics

Automatically tracked in `~/.claude/.aria-state`:
- `cache_hits` - Number of cache hits
- `cache_misses` - Number of cache misses

Check with: `aria_get cache_hits`

## Size Limits

No hard limits, but monitor with:
```bash
du -sh ~/.claude/cache
aria-cache.sh stats
```

Clean periodically:
```bash
aria-cache.sh clean      # Remove expired entries
aria-cache.sh flush      # Clear everything
```

---

For detailed documentation, see `ARIA_CACHE_README.md`
