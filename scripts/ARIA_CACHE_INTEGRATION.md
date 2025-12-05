# ARIA Cache Integration Guide

How to integrate the ARIA Cache System with other ARIA workflow scripts.

## Overview

The `aria-cache.sh` system provides three complementary caching strategies that integrate seamlessly with the ARIA workflow's cost hierarchy and efficiency metrics.

## Integration with aria-state.sh

The cache system automatically updates ARIA metrics:

```bash
#!/bin/bash
source /home/mike/.claude/scripts/aria-cache.sh
source /home/mike/.claude/scripts/aria-state.sh

# Cache operations automatically track:
aria_cache_file_set "/path/file"     # Updates cache_misses
aria_cache_file_get "/path/file"     # Updates cache_hits or cache_misses

# Check metrics
echo "Hits: $(aria_get cache_hits)"
echo "Misses: $(aria_get cache_misses)"
```

## Integration with aria-score.sh

Cache efficiency affects your ARIA score:

```bash
# High cache hit rate = Better ARIA score
# Formula: cache_rate = (hits * 100 / (hits + misses))
# Bonus: +10% score boost for high hit rates

# Check current score
aria_score=$(aria_score.sh)  # Includes cache efficiency
```

## Use Case: Context Search Caching

Cache expensive context searches:

```bash
#!/bin/bash
# Enhanced ctx wrapper with caching

source /home/mike/.claude/scripts/aria-cache.sh

query="$1"
path="${2:-.}"

# Try cache first
if results=$(aria_cache_search_get "$query" "$path"); then
    echo "Cache hit: $results"
    exit 0
fi

# Cache miss - run expensive search
echo "Running search: $query" >&2
results=$(rg "$query" --files "$path" -t rust | jq -Rs 'split("\n")[:-1]')

# Cache for next time
aria_cache_search_set "$query" "$path" "$results"

echo "$results"
```

## Use Case: Query Result Caching

Cache database queries:

```bash
#!/bin/bash
# Database wrapper with caching

source /home/mike/.claude/scripts/aria-cache.sh

query="$1"

# Check cache first
if results=$(aria_cache_query_get "$query"); then
    echo "Using cached query result"
    echo "$results"
    exit 0
fi

# Execute query
echo "Executing: $query" >&2
results=$(mysql -u user -p password database -e "$query" 2>/dev/null | jq -R 'split("\t")')

# Cache result
aria_cache_query_set "$query" "$results"

echo "$results"
```

## Use Case: Large File Caching

Avoid re-reading large files:

```bash
#!/bin/bash
# File processor with caching

source /home/mike/.claude/scripts/aria-cache.sh

file="$1"

# Try cache first (with mtime validation)
if content=$(aria_cache_file_get "$file" 2>/dev/null); then
    echo "Using cached content" >&2
    echo "$content"
    exit 0
fi

# Not cached or stale - read file
content=$(cat "$file")

# Cache for next read
aria_cache_file_set "$file"

echo "$content"
```

## ARIA Workflow Integration

### Phase 1: Context Gathering (ctx command)

```bash
#!/bin/bash
# Enhanced ctx wrapper

source /home/mike/.claude/scripts/aria-cache.sh

QUERY="$1"

# Try cache first (search cache: 30 min TTL)
if cached=$(aria_cache_search_get "$QUERY" "."); then
    echo "$cached"
    exit 0
fi

# Not cached - run context search
context=$(grep -r "$QUERY" . --include="*.md" --include="*.sh")

# Cache results
aria_cache_search_set "$QUERY" "." "$context"

echo "$context"
```

### Phase 2: Planning (codex-save.sh)

```bash
#!/bin/bash
# Preserve previously generated code in cache

source /home/mike/.claude/scripts/aria-cache.sh

# When storing generated code, also cache it
codex_hash=$(echo -n "$PROMPT" | md5sum | cut -d' ' -f1)
aria_cache_query_set "codex:$codex_hash" "$GENERATED_CODE"

# Later, check cache before regenerating
if cached=$(aria_cache_query_get "codex:$codex_hash"); then
    echo "Using cached code generation"
    echo "$cached"
fi
```

### Phase 3: Quality Gate (quality-gate.sh)

```bash
#!/bin/bash
# Cache test results

source /home/mike/.claude/scripts/aria-cache.sh

# Cache test results by content hash
test_hash=$(find tests/ -type f -newer /tmp/last_test | md5sum | cut -d' ' -f1)
cached_results=$(aria_cache_query_get "test:$test_hash")

if [ -z "$cached_results" ]; then
    # Run tests
    results=$(npm test 2>&1)
    aria_cache_query_set "test:$test_hash" "$results"
fi

# Use cached results
echo "$cached_results"
```

## Cost Hierarchy Optimization

Use caching to save on higher-cost models:

```bash
# Cost hierarchy (with caching)
# 1. Cache (FREE) - Check before anything else
# 2. External tools (ctx, gemini, codex-save.sh) - Use if cache miss
# 3. Haiku (CHEAP) - CLI operations via subagent
# 4. Opus (EXPENSIVE) - Only for final refinement

#!/bin/bash
source /home/mike/.claude/scripts/aria-cache.sh

ANALYSIS_QUERY="$1"

# Step 1: Check cache (FREE)
if cached=$(aria_cache_query_get "analysis:$ANALYSIS_QUERY"); then
    echo "$cached"
    exit 0
fi

# Step 2: Try external tool if cache miss (CHEAP)
if result=$(ctx "$ANALYSIS_QUERY"); then
    # Cache the result
    aria_cache_query_set "analysis:$ANALYSIS_QUERY" "$result"
    echo "$result"
    exit 0
fi

# Step 3: Fall back to Haiku subagent
result=$(Task aria-qa haiku "Analyze: $ANALYSIS_QUERY")

# Cache for next time
aria_cache_query_set "analysis:$ANALYSIS_QUERY" "$result"

echo "$result"
```

## Monitoring Cache Effectiveness

```bash
#!/bin/bash
# Monitor cache performance

source /home/mike/.claude/scripts/aria-cache.sh
source /home/mike/.claude/scripts/aria-state.sh

echo "=== Cache Performance ==="
hits=$(aria_get cache_hits)
misses=$(aria_get cache_misses)
total=$((hits + misses))

if [ $total -gt 0 ]; then
    hit_rate=$((hits * 100 / total))
    echo "Hit rate: ${hit_rate}%"
    echo "Hits: $hits, Misses: $misses"

    # Show cache stats
    stats=$(aria_cache_stats | jq .)
    echo "Cache size: $(echo "$stats" | jq -r '.total_size')"
fi

# Clean expired entries periodically
aria_cache_clean
```

## Debugging Cache Issues

### Check cache contents

```bash
# List all cached files
find ~/.claude/cache -name "*.json" -type f

# View specific cache entry
hash=$(echo -n "/path/to/file" | md5sum | cut -d' ' -f1)
jq . ~/.claude/cache/files/$hash.json

# Search cache statistics
aria_cache_stats | jq .

# Clean expired entries
aria_cache_clean
```

### Troubleshooting performance

```bash
#!/bin/bash
source /home/mike/.claude/scripts/aria-cache.sh

# Check if cache is actually being hit
echo "Before cache clear:"
hits1=$(aria_get cache_hits)

# Perform cached operation
result=$(aria_cache_file_get "/test/file" 2>/dev/null)

echo "After operation:"
hits2=$(aria_get cache_hits)

if [ $hits2 -gt $hits1 ]; then
    echo "Cache working: hits increased"
else
    echo "Cache miss: check if data was cached"
    aria_cache_stats | jq '.files.count'
fi
```

## Production Checklist

Before deploying cache integration:

- [ ] Cache location writable: `chmod 700 ~/.claude/cache`
- [ ] Periodic cleanup scheduled: `aria_cache_clean` in cron
- [ ] Monitoring active: Check `aria_get cache_hits` regularly
- [ ] TTL settings appropriate for use case
- [ ] Fallback logic if cache fails
- [ ] Documentation updated with cache info
- [ ] Tests cover cache and non-cache paths

## Example: Fully Integrated Command

```bash
#!/bin/bash
# Complete example: Cached AI analysis

source /home/mike/.claude/scripts/aria-cache.sh
source /home/mike/.claude/scripts/aria-state.sh

QUERY="$1"
CACHE_KEY="analysis:$(echo -n "$QUERY" | md5sum | cut -d' ' -f1)"

# Try cache first
if result=$(aria_cache_query_get "$CACHE_KEY" 2>/dev/null); then
    echo "CACHED: $result" >&2
    echo "$result"
    exit 0
fi

echo "CACHE MISS: $QUERY" >&2

# Try cheap external tool
if result=$(ctx "$QUERY" 2>/dev/null); then
    # Cache result for 1 hour
    aria_cache_query_set "$CACHE_KEY" "$result"
    echo "$result"
    exit 0
fi

# Fall back to Haiku agent
result=$(Task aria-coder haiku "Analyze: $QUERY")

# Cache result
aria_cache_query_set "$CACHE_KEY" "$result"

echo "$result"
```

## Performance Benchmarks

Expected performance with caching:

- **File cache hit**: <1ms (disk read + mtime check)
- **Search cache hit**: <2ms (JSON parsing)
- **Query cache hit**: <2ms (JSON parsing)
- **Cache miss overhead**: <10ms (minimal)
- **Storage efficiency**: ~4KB per entry average

## Best Practices

1. **Use appropriate cache type**: File for content, Search for patterns, Query for results
2. **Set reasonable TTLs**: Don't cache ephemeral data too long
3. **Monitor hit rate**: Aim for 60%+ hit rate
4. **Clean regularly**: Run `aria_cache_clean` in cron
5. **Handle failures gracefully**: Always have fallback logic
6. **Document assumptions**: Note what's cached and why
7. **Test cache invalidation**: Ensure data updates properly
8. **Profile before optimizing**: Use metrics to identify bottlenecks

## Troubleshooting Reference

| Issue | Solution |
|-------|----------|
| Cache not being used | Check `aria_get cache_hits` |
| High miss rate | Verify patterns match exactly |
| Stale data served | Check TTL settings |
| Disk space growing | Run `aria_cache_clean` |
| Permissions denied | Check `~/.claude/cache` permissions |
| Can't find cached entry | Use `aria_cache_stats` to verify |

---

For detailed documentation, see:
- `ARIA_CACHE_README.md` - Complete reference
- `ARIA_CACHE_QUICK_REF.md` - Quick lookup
- `aria-cache.sh` - Source code with comments
