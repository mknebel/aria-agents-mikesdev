#!/bin/bash
# Build Project Index - Pre-scans project files for fast lookups
# Usage: build-project-index.sh /path/to/project

set -e

PROJECT_ROOT="${1:-.}"
PROJECT_ROOT=$(cd "$PROJECT_ROOT" && pwd)  # Absolute path

# Generate index name from path
INDEX_NAME=$(echo "$PROJECT_ROOT" | tr '/' '-' | sed 's/^-//')
OUTPUT_DIR="$HOME/.claude/project-indexes"
OUTPUT_FILE="$OUTPUT_DIR/${INDEX_NAME}.json"

mkdir -p "$OUTPUT_DIR"

echo "Building index for: $PROJECT_ROOT"
echo "Output: $OUTPUT_FILE"

# Start JSON
cat > "$OUTPUT_FILE" << EOF
{
  "project_root": "$PROJECT_ROOT",
  "generated_at": "$(date -Iseconds)",
EOF

# Count files
FILE_COUNT=$(find "$PROJECT_ROOT" -type f \( -name "*.php" -o -name "*.js" -o -name "*.ts" -o -name "*.py" -o -name "*.go" -o -name "*.java" -o -name "*.rb" \) 2>/dev/null | grep -v node_modules | grep -v vendor | grep -v ".git" | wc -l)
echo "  \"file_count\": $FILE_COUNT," >> "$OUTPUT_FILE"

# Build categories
echo '  "categories": {' >> "$OUTPUT_FILE"

# Controllers/Handlers
echo '    "controllers": [' >> "$OUTPUT_FILE"
find "$PROJECT_ROOT" -type f \( -name "*Controller*.php" -o -name "*Handler*.php" -o -name "*controller*.js" -o -name "*handler*.ts" \) 2>/dev/null | grep -v node_modules | grep -v vendor | head -100 | while read -r f; do
    REL_PATH="${f#$PROJECT_ROOT/}"
    LINES=$(wc -l < "$f" 2>/dev/null || echo 0)
    # Extract function names (PHP/JS style)
    FUNCS=$(grep -oE '(public |private |protected )?function [a-zA-Z_][a-zA-Z0-9_]*' "$f" 2>/dev/null | sed 's/.*function //' | head -20 | tr '\n' ',' | sed 's/,$//')
    echo "      {\"path\": \"$REL_PATH\", \"lines\": $LINES, \"functions\": \"$FUNCS\"},"
done >> "$OUTPUT_FILE"
# Remove trailing comma and close array
sed -i '$ s/,$//' "$OUTPUT_FILE"
echo '    ],' >> "$OUTPUT_FILE"

# Models/Entities
echo '    "models": [' >> "$OUTPUT_FILE"
find "$PROJECT_ROOT" -type f \( -path "*/Model/*" -o -path "*/Entity/*" -o -path "*/models/*" \) \( -name "*.php" -o -name "*.js" -o -name "*.ts" -o -name "*.py" \) 2>/dev/null | grep -v node_modules | grep -v vendor | head -100 | while read -r f; do
    REL_PATH="${f#$PROJECT_ROOT/}"
    LINES=$(wc -l < "$f" 2>/dev/null || echo 0)
    echo "      {\"path\": \"$REL_PATH\", \"lines\": $LINES},"
done >> "$OUTPUT_FILE"
sed -i '$ s/,$//' "$OUTPUT_FILE"
echo '    ],' >> "$OUTPUT_FILE"

# Views/Templates
echo '    "views": [' >> "$OUTPUT_FILE"
find "$PROJECT_ROOT" -type f \( -path "*/templates/*" -o -path "*/views/*" -o -path "*/View/*" \) \( -name "*.php" -o -name "*.ctp" -o -name "*.twig" -o -name "*.blade.php" -o -name "*.html" -o -name "*.jsx" -o -name "*.tsx" \) 2>/dev/null | grep -v node_modules | head -100 | while read -r f; do
    REL_PATH="${f#$PROJECT_ROOT/}"
    LINES=$(wc -l < "$f" 2>/dev/null || echo 0)
    echo "      {\"path\": \"$REL_PATH\", \"lines\": $LINES},"
done >> "$OUTPUT_FILE"
sed -i '$ s/,$//' "$OUTPUT_FILE"
echo '    ],' >> "$OUTPUT_FILE"

# Config files
echo '    "config": [' >> "$OUTPUT_FILE"
find "$PROJECT_ROOT" -type f \( -path "*/config/*" -o -name "*.config.*" -o -name "*.json" -o -name "*.yml" -o -name "*.yaml" \) 2>/dev/null | grep -v node_modules | grep -v vendor | grep -v ".git" | head -50 | while read -r f; do
    REL_PATH="${f#$PROJECT_ROOT/}"
    echo "      {\"path\": \"$REL_PATH\"},"
done >> "$OUTPUT_FILE"
sed -i '$ s/,$//' "$OUTPUT_FILE"
echo '    ],' >> "$OUTPUT_FILE"

# Tests
echo '    "tests": [' >> "$OUTPUT_FILE"
find "$PROJECT_ROOT" -type f \( -path "*/tests/*" -o -path "*/test/*" -o -path "*/__tests__/*" -o -name "*Test.php" -o -name "*.test.js" -o -name "*.spec.ts" \) 2>/dev/null | grep -v node_modules | head -100 | while read -r f; do
    REL_PATH="${f#$PROJECT_ROOT/}"
    echo "      {\"path\": \"$REL_PATH\"},"
done >> "$OUTPUT_FILE"
sed -i '$ s/,$//' "$OUTPUT_FILE"
echo '    ]' >> "$OUTPUT_FILE"

echo '  },' >> "$OUTPUT_FILE"

# Build function index (PHP and JS)
echo '  "function_index": {' >> "$OUTPUT_FILE"
find "$PROJECT_ROOT" -type f \( -name "*.php" -o -name "*.js" -o -name "*.ts" \) 2>/dev/null | grep -v node_modules | grep -v vendor | head -200 | while read -r f; do
    REL_PATH="${f#$PROJECT_ROOT/}"
    # Extract functions with line numbers
    grep -n -oE '(public |private |protected )?function [a-zA-Z_][a-zA-Z0-9_]*' "$f" 2>/dev/null | while read -r match; do
        LINE=$(echo "$match" | cut -d: -f1)
        FUNC=$(echo "$match" | sed 's/.*function //')
        echo "    \"$FUNC\": \"$REL_PATH:$LINE\","
    done
done >> "$OUTPUT_FILE"
sed -i '$ s/,$//' "$OUTPUT_FILE"
echo '  },' >> "$OUTPUT_FILE"

# Build class index
echo '  "class_index": {' >> "$OUTPUT_FILE"
find "$PROJECT_ROOT" -type f \( -name "*.php" -o -name "*.js" -o -name "*.ts" -o -name "*.py" \) 2>/dev/null | grep -v node_modules | grep -v vendor | head -200 | while read -r f; do
    REL_PATH="${f#$PROJECT_ROOT/}"
    # Extract class names with line numbers
    grep -n -oE '(class|interface|trait) [A-Z][a-zA-Z0-9_]*' "$f" 2>/dev/null | while read -r match; do
        LINE=$(echo "$match" | cut -d: -f1)
        CLASS=$(echo "$match" | sed 's/.*(class|interface|trait) //' | awk '{print $2}')
        echo "    \"$CLASS\": \"$REL_PATH:$LINE\","
    done
done >> "$OUTPUT_FILE"
sed -i '$ s/,$//' "$OUTPUT_FILE"
echo '  }' >> "$OUTPUT_FILE"

# Close JSON
echo '}' >> "$OUTPUT_FILE"

# Validate JSON
if command -v jq &> /dev/null; then
    if jq empty "$OUTPUT_FILE" 2>/dev/null; then
        echo "Index built successfully: $(jq '.file_count' "$OUTPUT_FILE") files indexed"
    else
        echo "Warning: JSON validation failed, but index was created"
    fi
else
    echo "Index built (jq not available for validation)"
fi

echo "Done: $OUTPUT_FILE"
