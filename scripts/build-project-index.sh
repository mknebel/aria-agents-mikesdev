#!/bin/bash
# Build Project Index - Pre-scans project files for fast lookups
# Usage: build-project-index.sh /path/to/project
#
# Uses ripgrep (rg) which automatically respects .gitignore
# Excludes: .git, node_modules, vendor, images, PDFs, binaries

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

# Check for ripgrep
if ! command -v rg &> /dev/null; then
    echo "Error: ripgrep (rg) is required. Install with: apt install ripgrep"
    exit 1
fi

# Common rg options:
# --files: list files only
# --type: filter by file type
# --glob: include/exclude patterns
# Automatically respects .gitignore and excludes .git/
RG_EXCLUDE="--glob '!*.png' --glob '!*.jpg' --glob '!*.jpeg' --glob '!*.gif' --glob '!*.ico' --glob '!*.svg' --glob '!*.webp' --glob '!*.bmp' --glob '!*.pdf' --glob '!*.zip' --glob '!*.tar' --glob '!*.gz' --glob '!*.exe' --glob '!*.dll' --glob '!*.so' --glob '!*.dylib' --glob '!*.woff' --glob '!*.woff2' --glob '!*.ttf' --glob '!*.eot' --glob '!*.mp3' --glob '!*.mp4' --glob '!*.wav' --glob '!*.avi' --glob '!*.mov'"

# Start JSON
cat > "$OUTPUT_FILE" << EOF
{
  "project_root": "$PROJECT_ROOT",
  "generated_at": "$(date -Iseconds)",
EOF

# Count code files (rg respects .gitignore automatically)
FILE_COUNT=$(eval "rg --files $RG_EXCLUDE '$PROJECT_ROOT'" 2>/dev/null | grep -E '\.(php|js|ts|tsx|jsx|py|go|java|rb|rs|c|cpp|h|hpp|cs|swift|kt)$' | wc -l)
echo "  \"file_count\": $FILE_COUNT," >> "$OUTPUT_FILE"

# Build categories
echo '  "categories": {' >> "$OUTPUT_FILE"

# Controllers/Handlers
echo '    "controllers": [' >> "$OUTPUT_FILE"
eval "rg --files $RG_EXCLUDE '$PROJECT_ROOT'" 2>/dev/null | grep -iE '(controller|handler)\.(php|js|ts)$' | head -100 | while read -r f; do
    REL_PATH="${f#$PROJECT_ROOT/}"
    LINES=$(wc -l < "$f" 2>/dev/null || echo 0)
    FUNCS=$(grep -oE '(public |private |protected )?function [a-zA-Z_][a-zA-Z0-9_]*' "$f" 2>/dev/null | sed 's/.*function //' | head -20 | tr '\n' ',' | sed 's/,$//')
    echo "      {\"path\": \"$REL_PATH\", \"lines\": $LINES, \"functions\": \"$FUNCS\"},"
done >> "$OUTPUT_FILE"
sed -i '$ s/,$//' "$OUTPUT_FILE"
echo '    ],' >> "$OUTPUT_FILE"

# Models/Entities
echo '    "models": [' >> "$OUTPUT_FILE"
eval "rg --files $RG_EXCLUDE '$PROJECT_ROOT'" 2>/dev/null | grep -E '/(Model|Entity|models|entities)/' | grep -E '\.(php|js|ts|py)$' | head -100 | while read -r f; do
    REL_PATH="${f#$PROJECT_ROOT/}"
    LINES=$(wc -l < "$f" 2>/dev/null || echo 0)
    echo "      {\"path\": \"$REL_PATH\", \"lines\": $LINES},"
done >> "$OUTPUT_FILE"
sed -i '$ s/,$//' "$OUTPUT_FILE"
echo '    ],' >> "$OUTPUT_FILE"

# Views/Templates
echo '    "views": [' >> "$OUTPUT_FILE"
eval "rg --files $RG_EXCLUDE '$PROJECT_ROOT'" 2>/dev/null | grep -E '/(templates|views|View)/' | grep -E '\.(php|ctp|twig|blade\.php|html|jsx|tsx|vue)$' | head -100 | while read -r f; do
    REL_PATH="${f#$PROJECT_ROOT/}"
    LINES=$(wc -l < "$f" 2>/dev/null || echo 0)
    echo "      {\"path\": \"$REL_PATH\", \"lines\": $LINES},"
done >> "$OUTPUT_FILE"
sed -i '$ s/,$//' "$OUTPUT_FILE"
echo '    ],' >> "$OUTPUT_FILE"

# Config files
echo '    "config": [' >> "$OUTPUT_FILE"
eval "rg --files $RG_EXCLUDE '$PROJECT_ROOT'" 2>/dev/null | grep -E '(/config/|\.config\.|composer\.json|package\.json|tsconfig|webpack|\.env\.example)' | grep -E '\.(json|yml|yaml|php|js|ts)$' | head -50 | while read -r f; do
    REL_PATH="${f#$PROJECT_ROOT/}"
    echo "      {\"path\": \"$REL_PATH\"},"
done >> "$OUTPUT_FILE"
sed -i '$ s/,$//' "$OUTPUT_FILE"
echo '    ],' >> "$OUTPUT_FILE"

# Tests
echo '    "tests": [' >> "$OUTPUT_FILE"
eval "rg --files $RG_EXCLUDE '$PROJECT_ROOT'" 2>/dev/null | grep -E '(/tests/|/test/|/__tests__/|Test\.|\.test\.|\.spec\.)' | grep -E '\.(php|js|ts|py)$' | head -100 | while read -r f; do
    REL_PATH="${f#$PROJECT_ROOT/}"
    echo "      {\"path\": \"$REL_PATH\"},"
done >> "$OUTPUT_FILE"
sed -i '$ s/,$//' "$OUTPUT_FILE"
echo '    ]' >> "$OUTPUT_FILE"

echo '  },' >> "$OUTPUT_FILE"

# Build function index (PHP, JS, TS)
echo '  "function_index": {' >> "$OUTPUT_FILE"
eval "rg --files $RG_EXCLUDE '$PROJECT_ROOT'" 2>/dev/null | grep -E '\.(php|js|ts)$' | head -200 | while read -r f; do
    REL_PATH="${f#$PROJECT_ROOT/}"
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
eval "rg --files $RG_EXCLUDE '$PROJECT_ROOT'" 2>/dev/null | grep -E '\.(php|js|ts|py)$' | head -200 | while read -r f; do
    REL_PATH="${f#$PROJECT_ROOT/}"
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
