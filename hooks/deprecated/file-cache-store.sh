#!/bin/bash

# File Cache Store Hook - PostToolUse for Read Tool
# Stores file content and hash after successful reads
# Companion hook to file-cache.sh

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

# Extract tool info
tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Only process Read tool calls
if [ "$tool_name" != "Read" ] || [ -z "$file_path" ]; then
    exit 0
fi

# Check if file exists
if [ ! -f "$file_path" ]; then
    exit 0
fi

# Check if the read was successful (tool_output exists and has content)
tool_output=$(echo "$input" | jq -r '.tool_output // empty' 2>/dev/null)
if [ -z "$tool_output" ]; then
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

# Store the file content
echo "$tool_output" > "$CONTENT_DIR/$file_hash" 2>/dev/null

# Update the hashes index with file path -> hash mapping
temp_hashes=$(mktemp)
jq --arg filepath "$file_path" --arg hash "$file_hash" \
    '.[$filepath] = $hash' "$HASHES_FILE" > "$temp_hashes" 2>/dev/null

if [ -f "$temp_hashes" ]; then
    mv "$temp_hashes" "$HASHES_FILE"
else
    rm -f "$temp_hashes"
fi

# Let the normal response pass through
exit 0
