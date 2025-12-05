# ARIA Cache Management System

Comprehensive cache management for the ARIA workflow, with support for file content caching, search result caching, and index query caching.

## Overview

The `aria-cache.sh` script provides a unified caching system with three distinct cache types:

1. **File Cache** - Content-based with mtime validation
2. **Search Cache** - Pattern + path based with 30-minute TTL
3. **Query Cache** - Index query results with 60-minute TTL

All caches are:
- Thread-safe with file locking
- Integrated with aria-state metrics (hits/misses)
- Configurable via environment variables
- Capable of being sourced as a library or run via CLI

## Installation

The script is already installed at:
```bash
/home/mike/.claude/scripts/aria-cache.sh
```

Ensure it's executable:
```bash
chmod +x /home/mike/.claude/scripts/aria-cache.sh
```

## Usage

### As a CLI Tool

```bash
# Initialize cache directories
aria-cache.sh init

# File operations
aria-cache.sh set-file /path/to/file.php
aria-cache.sh get-file /path/to/file.php
aria-cache.sh valid-file /path/to/file.php
aria-cache.sh invalidate /path/to/file.php

# Search operations
aria-cache.sh set-search "pattern" "." '["file1.php","file2.php"]'
aria-cache.sh get-search "pattern" "."

# Query operations
aria-cache.sh set-query "SELECT * FROM users" '[{"id":1}]'
aria-cache.sh get-query "SELECT * FROM users"

# Cache management
aria-cache.sh stats          # Show cache statistics
aria-cache.sh clean          # Remove expired entries
aria-cache.sh invalidate-search  # Clear all search cache
aria-cache.sh invalidate-queries # Clear all query cache
aria-cache.sh invalidate-all     # Clear everything
aria-cache.sh flush              # Alias for invalidate-all
```

### As a Library

Source the script in your bash code:

```bash
source /home/mike/.claude/scripts/aria-cache.sh

# File caching
aria_cache_file_set "/path/to/file"
content=$(aria_cache_file_get "/path/to/file")
if aria_cache_file_valid "/path/to/file"; then
    echo "Cache is valid"
fi
aria_cache_invalidate "/path/to/file"

# Search caching
aria_cache_search_set "pattern" "/path" '["file1","file2"]'
results=$(aria_cache_search_get "pattern" "/path")
aria_cache_invalidate_search

# Query caching
aria_cache_query_set "SELECT * FROM table" '[{"id":1}]'
results=$(aria_cache_query_get "SELECT * FROM table")
aria_cache_invalidate_queries

# Management
aria_cache_stats
aria_cache_clean
aria_cache_invalidate_all
```

## Cache Structure

```
~/.claude/cache/
├── files/                          # File content cache
│   ├── {hash}.json                 # Metadata + content
│   └── ...
├── search/                         # Search result cache
│   ├── {hash}.json                 # Pattern, path, files
│   └── ...
└── index-queries/                  # Query result cache
    ├── {hash}.json                 # Query, results
    └── ...
```

### File Cache Entry Format

```json
{
  "path": "/full/path/to/file.php",
  "mtime": 1701801234,
  "size": 4521,
  "content_hash": "abc123...",
  "cached_at": 1701801240,
  "content": "file content here..."
}
```

### Search Cache Entry Format

```json
{
  "pattern": "function.*auth",
  "path": "/project/src",
  "files": [
    "file1.php",
    "file2.php"
  ],
  "cached_at": 1701801240,
  "ttl": 1800
}
```

### Query Cache Entry Format

```json
{
  "query": "SELECT * FROM users WHERE active=1",
  "results": [
    {"id": 1, "name": "Alice"},
    {"id": 2, "name": "Bob"}
  ],
  "cached_at": 1701801240,
  "ttl": 3600
}
```

## Validation and TTL

### File Cache
- **Validation**: By file modification time (mtime)
- **TTL**: None (always checked against actual file)
- **Hit**: mtime matches and file exists
- **Miss**: File not cached or mtime doesn't match
- **Auto-cleanup**: Invalid caches are deleted on retrieval

### Search Cache
- **Validation**: By TTL (30 minutes by default)
- **TTL**: 1800 seconds (configurable via `ARIA_CACHE_SEARCH_TTL`)
- **Hit**: Cached and within TTL
- **Miss**: Not cached
- **Expired**: Cached but TTL exceeded (returns exit code 2)

### Query Cache
- **Validation**: By TTL (60 minutes by default)
- **TTL**: 3600 seconds (configurable via `ARIA_CACHE_QUERY_TTL`)
- **Hit**: Cached and within TTL
- **Miss**: Not cached
- **Expired**: Cached but TTL exceeded (returns exit code 2)

## Exit Codes

| Code | Meaning | Use Case |
|------|---------|----------|
| 0 | Success / Cache hit | Data available |
| 1 | Failure / Cache miss | Data not available |
| 2 | Cache expired | Data was cached but is stale |

Example:
```bash
if aria_cache_file_get "/path/to/file"; then
    echo "Cache hit"
elif [ $? -eq 2 ]; then
    echo "Cache expired"
else
    echo "Cache miss"
fi
```

## Configuration

Set environment variables before sourcing or using the script:

```bash
# Cache root directory (default: ~/.claude/cache)
export ARIA_CACHE_ROOT="/custom/cache/path"

# File cache TTL (default: 0 = use mtime only)
export ARIA_CACHE_FILE_TTL=0

# Search cache TTL in seconds (default: 1800 = 30 minutes)
export ARIA_CACHE_SEARCH_TTL=3600

# Query cache TTL in seconds (default: 3600 = 60 minutes)
export ARIA_CACHE_QUERY_TTL=7200
```

## Metrics Integration

All cache operations are automatically tracked in `aria-state.sh`:

```bash
source ~/.claude/scripts/aria-state.sh

# Check cache statistics
hits=$(aria_get cache_hits)
misses=$(aria_get cache_misses)

# Calculate hit rate
total=$((hits + misses))
if [ $total -gt 0 ]; then
    rate=$((hits * 100 / total))
    echo "Cache hit rate: ${rate}%"
fi
```

## Examples

### Basic File Caching

```bash
source /home/mike/.claude/scripts/aria-cache.sh

# Cache a file
aria_cache_file_set "/path/to/large.php"

# Retrieve it later (or in another process)
content=$(aria_cache_file_get "/path/to/large.php")

# Use it
echo "$content" | wc -l
```

### Search Result Caching

```bash
source /home/mike/.claude/scripts/aria-cache.sh

# Run expensive search
files=$(rg "function.*middleware" --files /project/src)

# Cache the results
aria_cache_search_set "function.*middleware" "/project/src" "$files"

# Later, retrieve from cache
cached=$(aria_cache_search_get "function.*middleware" "/project/src")

if [ $? -eq 0 ]; then
    echo "Got cached search results: $cached"
fi
```

### Query Result Caching

```bash
source /home/mike/.claude/scripts/aria-cache.sh

# Cache expensive database query
query="SELECT id, name FROM users WHERE active=1 LIMIT 100"
results='[{"id":1,"name":"Alice"}]'
aria_cache_query_set "$query" "$results"

# Later, retrieve from cache
cached=$(aria_cache_query_get "$query")

if [ $? -eq 0 ]; then
    echo "Got cached query results: $cached"
fi
```

### Cache Maintenance

```bash
# Show statistics
aria-cache.sh stats

# Clean expired entries (search and query cache)
aria-cache.sh clean

# Clear specific cache types
aria-cache.sh invalidate-search
aria-cache.sh invalidate-queries

# Clear everything
aria-cache.sh flush
```

## Troubleshooting

### Cache not invalidating on file change

File caching is mtime-based. Ensure:
1. File is actually being modified (not just read)
2. mtime is updating (check with `stat -c %Y /path/to/file`)
3. System clock is correct

### High cache miss rate

Check:
1. TTL settings (queries/search cache may be expiring too quickly)
2. Patterns or queries changing slightly between calls
3. Cache directory location (ensure consistent across calls)

### Permissions issues

Cache directory must be writable:
```bash
# Ensure cache directory exists and is writable
mkdir -p ~/.claude/cache
chmod 700 ~/.claude/cache
```

### Out of disk space

Cache can grow large over time. Clean up:
```bash
# Remove all expired entries
aria-cache.sh clean

# Clear everything and restart
aria-cache.sh flush
aria-cache.sh init
```

## Performance Tips

1. **File caching** is best for frequently accessed files that change rarely
2. **Search caching** is best for expensive pattern searches
3. **Query caching** is best for database queries that don't change
4. Use `aria_cache_clean` periodically to remove expired entries
5. Monitor cache size with `aria_cache_stats`

## Integration with ARIA Workflow

The cache system is designed to integrate seamlessly with other ARIA scripts:

- `aria-state.sh` - Automatic metrics tracking
- `aria-score.sh` - Cache efficiency affects ARIA score
- `ctx` - Can cache context queries
- `ai.sh` - Can cache API responses

Example integration:
```bash
#!/bin/bash
source ~/.claude/scripts/aria-cache.sh
source ~/.claude/scripts/aria-state.sh

# Try to get cached context
if cached=$(aria_cache_search_get "function.*auth" "/project/src"); then
    echo "Cache hit: $cached"
    aria_inc "cache_hits"  # Already done by aria_cache_search_get
else
    echo "Cache miss, running search..."
    results=$(rg "function.*auth" --files /project/src | jq -Rs 'split("\n")[:-1]')
    aria_cache_search_set "function.*auth" "/project/src" "$results"
fi
```

## Advanced Usage

### Custom TTL Configuration

```bash
# Use longer TTL for search cache (2 hours)
export ARIA_CACHE_SEARCH_TTL=7200

source /home/mike/.claude/scripts/aria-cache.sh

aria_cache_search_set "pattern" "." '["file1","file2"]'
```

### Custom Cache Location

```bash
# Use different cache location
export ARIA_CACHE_ROOT="/tmp/my-cache"

source /home/mike/.claude/scripts/aria-cache.sh

# Cache will be stored in /tmp/my-cache instead of ~/.claude/cache
```

### Batch Operations

```bash
#!/bin/bash
source /home/mike/.claude/scripts/aria-cache.sh

# Cache multiple files
for file in src/**/*.php; do
    if [ -f "$file" ]; then
        aria_cache_file_set "$file"
    fi
done

# Check overall cache stats
aria_cache_stats | jq '.files.count'
```

## See Also

- `aria-state.sh` - Session state management
- `aria-score.sh` - Efficiency scoring
- `cache-manager.sh` - Legacy cache system
- `/home/mike/.claude/CLAUDE.md` - ARIA workflow documentation
