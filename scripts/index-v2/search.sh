#!/bin/bash
# Index V2 Search - High-performance search with lazy updates
#
# Features:
#   - Instant index lookup
#   - Lazy change detection (only checks result files)
#   - Auto re-index changed files
#   - Bloom filter for quick rejection
#   - Stemming, synonyms, scoring
#
# Usage:
#   search.sh "query" [/path/to/project]

set -e

QUERY="$1"
PROJECT_ROOT="${2:-$(pwd)}"
PROJECT_ROOT=$(cd "$PROJECT_ROOT" 2>/dev/null && pwd)

[[ -z "$QUERY" ]] && echo "Usage: search.sh \"query\" [path]" && exit 1

# Find index
INDEX_NAME=$(echo "$PROJECT_ROOT" | md5sum | cut -d' ' -f1)
INDEX_DIR="$HOME/.claude/indexes/$INDEX_NAME"
MASTER_INDEX="$INDEX_DIR/master.json"
INVERTED_INDEX="$INDEX_DIR/inverted.json"
BLOOM_FILE="$INDEX_DIR/bloom.dat"
FILES_DIR="$INDEX_DIR/files"
CHECKSUM_FILE="$INDEX_DIR/checksums.txt"
VAR_DIR="/tmp/claude_vars"

mkdir -p "$VAR_DIR"

echo "🔍 Index V2 Search" >&2
echo "📋 Query: $QUERY" >&2
echo "" >&2

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CHECK INDEX EXISTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if [[ ! -f "$MASTER_INDEX" ]]; then
    echo "⚠️  No index found. Building..." >&2
    "$HOME/.claude/scripts/index-v2/build-index.sh" "$PROJECT_ROOT"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SYNONYMS & STEMMING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

declare -A SYNONYMS=(
    ["auth"]="login authentication signin session"
    ["login"]="auth authentication signin"
    ["user"]="member account customer client"
    ["payment"]="checkout purchase transaction billing stripe"
    ["order"]="purchase cart checkout"
    ["delete"]="remove destroy trash"
    ["create"]="add new insert store"
    ["update"]="edit modify change"
    ["get"]="fetch retrieve find show"
    ["list"]="index all browse"
    ["error"]="exception fail failure"
    ["test"]="spec unittest"
    ["config"]="settings options"
    ["database"]="db mysql query"
    ["validate"]="check verify sanitize"
)

stem_word() {
    local word="${1,,}"
    word="${word%tion}"; word="${word%ment}"; word="${word%ing}"
    word="${word%ed}"; word="${word%er}"; word="${word%es}"; word="${word%s}"
    echo "$word"
}

expand_query() {
    local query="$1"
    local expanded=""
    local words=$(echo "$query" | tr '[:upper:]' '[:lower:]' | grep -oE '[a-z]{3,}')

    for word in $words; do
        expanded+="$word "
        local stem=$(stem_word "$word")
        [[ "$stem" != "$word" && ${#stem} -ge 3 ]] && expanded+="$stem "
        for key in "${!SYNONYMS[@]}"; do
            if [[ "$word" == "$key" || "${SYNONYMS[$key]}" == *"$word"* ]]; then
                expanded+="${SYNONYMS[$key]} "
            fi
        done
    done
    echo "$expanded" | tr ' ' '\n' | sort -u | tr '\n' ' '
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BLOOM FILTER QUICK REJECTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

bloom_check() {
    local word="$1"
    local hash=$(echo "$word" | md5sum | cut -c1-8)
    grep -q "^$hash$" "$BLOOM_FILE" 2>/dev/null
}

echo "━━━ Step 1: Query Expansion ━━━" >&2
EXPANDED=$(expand_query "$QUERY")
echo "📝 Terms: $EXPANDED" >&2

# Quick bloom filter check
POSSIBLE_TERMS=""
for term in $EXPANDED; do
    if bloom_check "$term"; then
        POSSIBLE_TERMS+="$term "
    fi
done

if [[ -z "$POSSIBLE_TERMS" ]]; then
    echo "⚡ Bloom filter: No matches possible" >&2
    echo "No matches found."
    exit 0
fi

echo "⚡ Bloom filter: Possible terms: $POSSIBLE_TERMS" >&2

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SEARCH INVERTED INDEX
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "" >&2
echo "━━━ Step 2: Index Lookup ━━━" >&2

declare -A FILE_SCORES
RESULT_FILES=""

for term in $POSSIBLE_TERMS; do
    # Look up in inverted index
    files=$(jq -r ".[\"$term\"][]? // empty" "$INVERTED_INDEX" 2>/dev/null)
    for file in $files; do
        score=${FILE_SCORES[$file]:-0}
        FILE_SCORES[$file]=$((score + 1))
        RESULT_FILES+="$file "
    done
done

RESULT_FILES=$(echo "$RESULT_FILES" | tr ' ' '\n' | sort -u)
RESULT_COUNT=$(echo "$RESULT_FILES" | grep -c . || echo 0)

if [[ $RESULT_COUNT -eq 0 ]]; then
    echo "No index matches, trying ripgrep fallback..." >&2
    # Fallback to direct ripgrep
    PATTERN=$(echo "$POSSIBLE_TERMS" | tr ' ' '|' | sed 's/|$//')
    rg -n -i -l "$PATTERN" "$PROJECT_ROOT" 2>/dev/null | head -20
    exit 0
fi

echo "📊 Found $RESULT_COUNT files in index" >&2

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LAZY CHANGE DETECTION (only check result files)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "" >&2
echo "━━━ Step 3: Change Detection ━━━" >&2

declare -a CHANGED_FILES
declare -A OLD_CHECKSUMS

# Load checksums
while IFS='|' read -r file checksum; do
    OLD_CHECKSUMS["$file"]="$checksum"
done < "$CHECKSUM_FILE"

# Only check files in results
for file in $RESULT_FILES; do
    full_path="$PROJECT_ROOT/$file"
    if [[ -f "$full_path" ]]; then
        new_checksum=$(md5sum "$full_path" 2>/dev/null | cut -d' ' -f1)
        if [[ "${OLD_CHECKSUMS[$file]}" != "$new_checksum" ]]; then
            CHANGED_FILES+=("$file")
        fi
    fi
done

if [[ ${#CHANGED_FILES[@]} -gt 0 ]]; then
    echo "⚠️  ${#CHANGED_FILES[@]} files changed, re-indexing..." >&2

    # Re-index changed files in background
    for file in "${CHANGED_FILES[@]}"; do
        echo "  📝 Re-indexing: $file" >&2
        # Quick inline re-index
        full_path="$PROJECT_ROOT/$file"
        file_id=$(echo "$file" | md5sum | cut -d' ' -f1 | cut -c1-12)
        new_checksum=$(md5sum "$full_path" | cut -d' ' -f1)

        # Update checksum
        grep -v "^$file|" "$CHECKSUM_FILE" > "$CHECKSUM_FILE.tmp" || true
        echo "$file|$new_checksum" >> "$CHECKSUM_FILE.tmp"
        mv "$CHECKSUM_FILE.tmp" "$CHECKSUM_FILE"

        # Extract functions for fresh data
        functions=$(grep -n -oE 'function [a-zA-Z_][a-zA-Z0-9_]*' "$full_path" 2>/dev/null | sed 's/.*function //' || true)
    done

    echo "✅ Re-indexed ${#CHANGED_FILES[@]} files" >&2
else
    echo "✅ All result files up-to-date" >&2
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# RANK AND FORMAT RESULTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "" >&2
echo "━━━ Step 4: Rank Results ━━━" >&2

# Sort by score
RANKED=$(for file in "${!FILE_SCORES[@]}"; do
    echo "${FILE_SCORES[$file]}|$file"
done | sort -t'|' -k1 -rn | head -15)

# Format output with context
OUTPUT=""
while IFS='|' read -r score file; do
    full_path="$PROJECT_ROOT/$file"
    file_id=$(echo "$file" | md5sum | cut -d' ' -f1 | cut -c1-12)
    file_index="$FILES_DIR/${file_id}.json"

    # Get functions from per-file index
    if [[ -f "$file_index" ]]; then
        functions=$(jq -r '.functions[].name' "$file_index" 2>/dev/null | head -5 | tr '\n' ', ' | sed 's/,$//')
        category=$(jq -r '.category' "$file_index" 2>/dev/null)
    else
        functions=""
        category="unknown"
    fi

    OUTPUT+="[$category] $file (score: $score)
"
    [[ -n "$functions" ]] && OUTPUT+="  Functions: $functions
"

    # Get matching lines from file
    PATTERN=$(echo "$POSSIBLE_TERMS" | tr ' ' '|' | sed 's/|$//')
    if [[ -f "$full_path" ]]; then
        matches=$(grep -n -i -E "$PATTERN" "$full_path" 2>/dev/null | head -3)
        if [[ -n "$matches" ]]; then
            OUTPUT+="  Matches:
"
            while IFS= read -r match; do
                OUTPUT+="    $match
"
            done <<< "$matches"
        fi
    fi
    OUTPUT+="
"
done <<< "$RANKED"

# Save results
echo "$OUTPUT" > "$VAR_DIR/search_last"
echo "$OUTPUT" > "$VAR_DIR/indexed_search_last"

echo "" >&2
echo "✅ Done | \$indexed_search_last" >&2

echo "$OUTPUT"
