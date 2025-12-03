#!/bin/bash
# Index V2 - High-performance search index
#
# Features:
#   - Per-file metadata cache
#   - Inverted index (keyword → files)
#   - Bloom filter for quick rejection
#   - Incremental updates
#   - Checksums for change detection
#
# Usage:
#   build-index.sh /path/to/project [--full] [--with-summaries]

set -e

PROJECT_ROOT="${1:-.}"
PROJECT_ROOT=$(cd "$PROJECT_ROOT" 2>/dev/null && pwd)
FORCE_FULL=0
WITH_SUMMARIES=0

for arg in "$@"; do
    case "$arg" in
        --full) FORCE_FULL=1 ;;
        --with-summaries) WITH_SUMMARIES=1 ;;
    esac
done

# Index directory structure
INDEX_NAME=$(echo "$PROJECT_ROOT" | md5sum | cut -d' ' -f1)
INDEX_DIR="$HOME/.claude/indexes/$INDEX_NAME"
FILES_DIR="$INDEX_DIR/files"
MASTER_INDEX="$INDEX_DIR/master.json"
INVERTED_INDEX="$INDEX_DIR/inverted.json"
BLOOM_FILE="$INDEX_DIR/bloom.dat"
CHECKSUM_FILE="$INDEX_DIR/checksums.txt"

mkdir -p "$INDEX_DIR" "$FILES_DIR"

echo "🔨 Building Index V2" >&2
echo "📁 Project: $PROJECT_ROOT" >&2
echo "📂 Index: $INDEX_DIR" >&2

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CHECK FOR CHANGES (incremental mode)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if [[ -f "$MASTER_INDEX" && $FORCE_FULL -eq 0 ]]; then
    # Check if any code files changed since last index
    CHANGED=$(find "$PROJECT_ROOT" -type f \( -name "*.php" -o -name "*.js" -o -name "*.ts" \) \
        ! -path "*/node_modules/*" ! -path "*/vendor/*" ! -path "*/.git/*" \
        -newer "$MASTER_INDEX" 2>/dev/null | head -1)

    if [[ -z "$CHANGED" ]]; then
        echo "✅ Index up-to-date" >&2
        exit 0
    fi
    echo "📝 Changes detected, rebuilding..." >&2
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BUILD INDEX
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "" >&2
echo "━━━ Building index ━━━" >&2

# Clear old data
rm -f "$FILES_DIR"/*.json 2>/dev/null || true
> "$CHECKSUM_FILE"
> "$INDEX_DIR/keywords.tmp"
> "$INDEX_DIR/bloom.tmp"

FILE_COUNT=0

# Find all code files
mapfile -t CODE_FILES < <(find "$PROJECT_ROOT" -type f \( -name "*.php" -o -name "*.js" -o -name "*.ts" \) \
    ! -path "*/node_modules/*" ! -path "*/vendor/*" ! -path "*/.git/*" 2>/dev/null | head -500)

for file in "${CODE_FILES[@]}"; do
    [[ ! -f "$file" ]] && continue

    rel_path="${file#$PROJECT_ROOT/}"
    file_id=$(echo "$rel_path" | md5sum | cut -d' ' -f1 | cut -c1-12)
    checksum=$(md5sum "$file" | cut -d' ' -f1)

    # Save checksum
    echo "$rel_path|$checksum" >> "$CHECKSUM_FILE"

    # Extract functions
    functions=$(grep -n -oE 'function [a-zA-Z_][a-zA-Z0-9_]*' "$file" 2>/dev/null | while read -r match; do
        line=$(echo "$match" | cut -d: -f1)
        func=$(echo "$match" | sed 's/.*function //')
        echo "{\"name\":\"$func\",\"line\":$line}"
    done | paste -sd, -)

    # Extract classes
    classes=$(grep -n -oE '(class|interface|trait) [A-Z][a-zA-Z0-9_]*' "$file" 2>/dev/null | while read -r match; do
        line=$(echo "$match" | cut -d: -f1)
        class=$(echo "$match" | awk '{print $2}')
        echo "{\"name\":\"$class\",\"line\":$line}"
    done | paste -sd, -)

    # Extract keywords from function/class names
    all_names=$(grep -oE 'function [a-zA-Z_][a-zA-Z0-9_]*' "$file" 2>/dev/null | sed 's/function //' || true)
    all_names+=" $(grep -oE '(class|interface|trait) [A-Z][a-zA-Z0-9_]*' "$file" 2>/dev/null | awk '{print $2}' || true)"

    keywords=""
    for name in $all_names; do
        # Split camelCase and snake_case
        words=$(echo "$name" | sed 's/\([a-z]\)\([A-Z]\)/\1 \2/g' | tr '_' ' ' | tr '[:upper:]' '[:lower:]')
        for word in $words; do
            if [[ ${#word} -ge 3 && ! "$word" =~ ^(get|set|the|and|for|has|add|new|all|this|that|with|from)$ ]]; then
                keywords+="\"$word\","
                echo "$word|$rel_path" >> "$INDEX_DIR/keywords.tmp"
                # Bloom filter entry
                hash=$(echo "$word" | md5sum | cut -c1-8)
                echo "$hash" >> "$INDEX_DIR/bloom.tmp"
            fi
        done
    done
    keywords="${keywords%,}"

    # Determine category
    category="other"
    [[ "$rel_path" =~ [Cc]ontroller ]] && category="controller"
    [[ "$rel_path" =~ [Mm]odel ]] && category="model"
    [[ "$rel_path" =~ [Ss]ervice ]] && category="service"
    [[ "$rel_path" =~ [Tt]est ]] && category="test"

    lines=$(wc -l < "$file" 2>/dev/null || echo 0)

    # Write per-file index
    cat > "$FILES_DIR/${file_id}.json" << EOF
{"path":"$rel_path","checksum":"$checksum","lines":$lines,"category":"$category","functions":[$functions],"classes":[$classes],"keywords":[$keywords]}
EOF

    FILE_COUNT=$((FILE_COUNT + 1))
    [[ $((FILE_COUNT % 50)) -eq 0 ]] && echo "  Indexed $FILE_COUNT files..." >&2
done

echo "📊 Indexed $FILE_COUNT files" >&2

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BUILD INVERTED INDEX
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "" >&2
echo "━━━ Building inverted index ━━━" >&2

# Aggregate keywords
echo '{' > "$INVERTED_INDEX"
sort "$INDEX_DIR/keywords.tmp" 2>/dev/null | uniq | awk -F'|' '
BEGIN { first=1 }
{
    if (kw != $1 && kw != "") {
        gsub(/,$/, "", files)
        if (!first) printf ",\n"
        printf "  \"%s\": [%s]", kw, files
        first=0
        files=""
    }
    kw = $1
    if (files != "") files = files ","
    files = files "\"" $2 "\""
}
END {
    if (kw != "") {
        gsub(/,$/, "", files)
        if (!first) printf ",\n"
        printf "  \"%s\": [%s]\n", kw, files
    }
}' >> "$INVERTED_INDEX"
echo '}' >> "$INVERTED_INDEX"

rm -f "$INDEX_DIR/keywords.tmp"

KEYWORD_COUNT=$(grep -c '"' "$INVERTED_INDEX" 2>/dev/null || echo 0)
echo "📊 $((KEYWORD_COUNT / 2)) keywords indexed" >&2

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BUILD BLOOM FILTER
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

sort -u "$INDEX_DIR/bloom.tmp" > "$BLOOM_FILE" 2>/dev/null || true
rm -f "$INDEX_DIR/bloom.tmp"
BLOOM_SIZE=$(wc -l < "$BLOOM_FILE" 2>/dev/null || echo 0)
echo "📊 Bloom filter: $BLOOM_SIZE entries" >&2

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BUILD MASTER INDEX
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

cat > "$MASTER_INDEX" << EOF
{
  "project_root": "$PROJECT_ROOT",
  "index_version": 2,
  "generated_at": "$(date -Iseconds)",
  "file_count": $FILE_COUNT,
  "keyword_count": $((KEYWORD_COUNT / 2)),
  "bloom_size": $BLOOM_SIZE
}
EOF

echo "" >&2
echo "✅ Index V2 built: $FILE_COUNT files, $((KEYWORD_COUNT / 2)) keywords" >&2
echo "📁 Location: $INDEX_DIR" >&2
