#!/bin/bash

# Incremental File Tracking Hook for Read Tool
# Caches file content by MD5 hash to avoid re-reading unchanged files
# Usage: PreToolUse hook for Read tool

# Initialize cache directories
CACHE_DIR="/tmp/claude_files"
HASHES_FILE="$CACHE_DIR/hashes.json"
CONTENT_DIR="$CACHE_DIR/content"

# Create cache structure if needed
mkdir -p "$CONTENT_DIR" 2>/dev/null

# Read JSON input from stdin
input=$(cat)
if [ -z "$input" ]; then
    exit 0
fi

# Extract file path using jq
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)

# Only process Read tool calls
if [ "$tool_name" != "Read" ] || [ -z "$file_path" ]; then
    exit 0
fi

# Check if file exists
if [ ! -f "$file_path" ]; then
    exit 0
fi

# Compute MD5 hash of file
file_hash=$(md5sum "$file_path" 2>/dev/null | awk '{print $1}')
if [ -z "$file_hash" ]; then
    exit 0
fi

# Initialize hashes.json if it doesn't exist
if [ ! -f "$HASHES_FILE" ]; then
    echo '{}' > "$HASHES_FILE"
fi

# Check if we have a cached hash for this file
cached_hash=$(jq -r ".[\"$file_path\"] // empty" "$HASHES_FILE" 2>/dev/null)

# If hash matches and content exists, return cached content
if [ "$cached_hash" = "$file_hash" ] && [ -f "$CONTENT_DIR/$file_hash" ]; then
    cached_content=$(cat "$CONTENT_DIR/$file_hash" 2>/dev/null)
    if [ -n "$cached_content" ]; then
        # Output cache hit response
        jq -n \
            --arg reason "File unchanged - using cached content" \
            --arg content "$cached_content" \
            '{
                "decision": "block",
                "reason": $reason,
                "cached_content": $content
            }' 2>/dev/null
        exit 0
    fi
fi

# No cache hit - let read proceed normally
# But first, check if we need to update the cache after the read
# We'll store the hash now, and content will be stored in PostToolUse hook
# For now, just let it pass through (exit 0)
exit 0
