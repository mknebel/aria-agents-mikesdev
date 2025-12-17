---
description: Index project for fast search (builds Index V2)
argument-hint: [path] [--full]
---

Build or update the project index for fast, accurate searches.

```bash
~/.claude/scripts/index-v2/build-index.sh "${ARGUMENTS:-.}"
```

## Usage

```
# Index current project (incremental - only changed files)
/index-project

# Index specific path
/index-project /path/to/project

# Full rebuild (ignore existing index)
/index-project --full
```

## What Gets Indexed

- **Functions/Methods** - Name, file, line number
- **Classes** - Name, file, line number
- **Keywords** - Extracted from code (auth, payment, user, etc.)
- **Inverted Index** - Keyword → files mapping
- **Bloom Filter** - Fast rejection of non-matches

## Index Location

```
~/.claude/indexes/{MD5_HASH}/
├── master.json      # Metadata
├── inverted.json    # Keyword → files
├── bloom.dat        # Fast filter
├── checksums.txt    # Change detection
└── files/           # Per-file indexes
```

## Benefits

| Search Type | Without Index | With Index |
|-------------|---------------|------------|
| Symbol lookup | 2-5s | <100ms |
| Keyword search | 1-3s | <50ms |
| Quality | 75-80% | 88-92% |

## Auto-Indexing

Index automatically updates in background when:
- Files change (mtime-based detection)
- New files found during search (incremental learning)

## Integration

After indexing, these tools use the index:
- `indexed-search.sh` - High-accuracy search
- `smart-search.sh` - Hybrid search with fallback
- `ctx` - Context builder
