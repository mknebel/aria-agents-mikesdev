#!/bin/bash
# Incremental Index Add - Add files to existing index
# Usage: incremental-add.sh <project_root> <file1> [file2] ...

PROJECT_ROOT="$1"
shift
FILES="$@"

[[ -z "$PROJECT_ROOT" ]] && exit 1
[[ -z "$FILES" ]] && exit 0

INDEX_NAME=$(echo "$PROJECT_ROOT" | md5sum | cut -d' ' -f1)
INDEX_DIR="$HOME/.claude/indexes/$INDEX_NAME"
INVERTED_INDEX="$INDEX_DIR/inverted.json"
BLOOM_FILE="$INDEX_DIR/bloom.dat"

[[ ! -d "$INDEX_DIR" ]] && exit 0
[[ ! -f "$INVERTED_INDEX" ]] && exit 0

# Load existing inverted index
TEMP_INDEX=$(mktemp)
cp "$INVERTED_INDEX" "$TEMP_INDEX"

for file in $FILES; do
    [[ ! -f "$file" ]] && continue

    # Get relative path
    REL_PATH="${file#$PROJECT_ROOT/}"

    # Extract keywords from file
    KEYWORDS=$(grep -oE '\b[a-zA-Z_][a-zA-Z0-9_]{2,}\b' "$file" 2>/dev/null | \
        tr '[:upper:]' '[:lower:]' | \
        sort -u | \
        grep -vE '^(the|and|for|this|that|with|from|have|been|will|would|could|should|function|return|class|public|private|protected|static|const|var|let|echo|print|array|string|int|bool|null|true|false|if|else|while|foreach|switch|case|break|continue|try|catch|throw|new|use|namespace)$' | \
        head -100)

    # Add keywords to inverted index
    for kw in $KEYWORDS; do
        # Use jq to add file to keyword entry
        jq --arg kw "$kw" --arg file "$REL_PATH" \
            '.[$kw] = ((.[$kw] // []) + [$file] | unique)' \
            "$TEMP_INDEX" > "${TEMP_INDEX}.new" 2>/dev/null && \
            mv "${TEMP_INDEX}.new" "$TEMP_INDEX"
    done
done

# Update inverted index atomically
mv "$TEMP_INDEX" "$INVERTED_INDEX"

# Update bloom filter (append mode)
for file in $FILES; do
    [[ ! -f "$file" ]] && continue
    KEYWORDS=$(grep -oE '\b[a-zA-Z_][a-zA-Z0-9_]{2,}\b' "$file" 2>/dev/null | tr '[:upper:]' '[:lower:]' | sort -u)
    for kw in $KEYWORDS; do
        echo "$kw" >> "$BLOOM_FILE"
    done
done

# Dedupe bloom file
sort -u "$BLOOM_FILE" -o "$BLOOM_FILE" 2>/dev/null

exit 0
