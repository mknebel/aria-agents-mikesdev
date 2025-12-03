# Global Agent Toolkit

Standard tools for AI agents (Claude, Codex, GPT, etc.) to interact with projects.

These commands are **data providers** - they return context without calling any AI.
Use them as building blocks in any agent workflow.

## Quick Reference

| Command | Purpose | Output |
|---------|---------|--------|
| `ctx "query"` | Indexed search → context | compact/json/tsv |
| `search-v2 "query"` | Raw index search | text with scores |
| `index-v2 [path]` | Build/update index | status messages |
| `recent-changes` | Recently modified files | compact/json/tsv |

## Commands

### ctx - Context Builder

High-level context for any task. Uses Index V2 internally.

```bash
# Basic usage
ctx "auth login"                    # Find auth-related code

# Output formats
ctx "payment checkout" --json       # JSON for machine parsing
ctx "user model" --tsv              # TSV: path, category, score, functions

# Limit results
ctx "validation" -n 10              # Top 10 results only
```

**Output (compact):**
```
## Context for: auth login

[controller] src/Controller/UsersController.php (score: 3)
  Functions: login, logout, authenticate
  Matches:
    45:    public function login()
    67:    private function authenticate($user)

[service] src/Service/AuthService.php (score: 2)
  Functions: validateToken, createSession
```

**Output (JSON):**
```json
[
  {"path":"src/Controller/UsersController.php","category":"controller","score":3,"functions":["login","logout"]},
  {"path":"src/Service/AuthService.php","category":"service","score":2,"functions":["validateToken"]}
]
```

### search-v2 - Raw Index Search

Lower-level search with full scoring details.

```bash
~/.claude/scripts/index-v2/search.sh "query" [/path/to/project]
```

Features:
- Synonym expansion (auth → login, authentication, signin)
- Stemming (payment → pay, processing → process)
- Bloom filter for quick rejection
- Inverted index for instant lookup
- Lazy change detection (only checks result files)

### index-v2 - Build/Update Index

```bash
# Build index for current directory
~/.claude/scripts/index-v2/build-index.sh

# Build for specific path
~/.claude/scripts/index-v2/build-index.sh /path/to/project

# Force full rebuild
~/.claude/scripts/index-v2/build-index.sh /path/to/project --full
```

Index location: `~/.claude/indexes/<project-hash>/`

Index contents:
- `master.json` - Project metadata
- `inverted.json` - Keyword → files mapping
- `bloom.dat` - Quick rejection filter
- `files/*.json` - Per-file metadata
- `checksums.txt` - Change detection

### recent-changes - Recent Modifications

```bash
# Basic usage
recent-changes                      # Last 20 changed files

# Output formats
recent-changes --json               # JSON array
recent-changes --tsv                # TSV: path, status, time

# Filters
recent-changes -n 50                # Last 50 files
recent-changes --uncommitted        # Git: uncommitted only
recent-changes --since "1 hour ago" # Git: since time
```

**Output (compact):**
```
## Recent Changes

Source: git

  [modified] src/Controller/UsersController.php (2 hours ago)
  [modified] src/Model/User.php (3 hours ago)
  [added]    src/Service/AuthService.php (yesterday)
  [untracked] tests/AuthTest.php
```

## Integration Patterns

### For Codex/GPT Agents

1. **Get context before coding:**
   ```bash
   ctx "feature keyword" --json > /tmp/context.json
   # Then read relevant files based on paths in context
   ```

2. **Check what changed:**
   ```bash
   recent-changes --uncommitted --json
   # Review uncommitted changes before making more
   ```

3. **Search then explore:**
   ```bash
   # Get high-level hits
   ctx "auth" -n 5 --tsv
   # Then use rg for specific patterns in those files
   rg "function login" src/Controller/UsersController.php
   ```

### For Claude Code

1. **Use cctx for AI-assisted tasks:**
   ```bash
   cctx "auth" "add password reset flow"
   # ctx + codex call
   ```

2. **Use ctx for context-only:**
   ```bash
   ctx "payment" --json
   # Returns context, no AI call
   ```

### Workflow Example

```bash
# 1. Ensure index is fresh
~/.claude/scripts/index-v2/auto-index.sh "$(pwd)"

# 2. Get context for the task
ctx "user authentication" --json > /tmp/ctx.json

# 3. Check recent changes for conflicts
recent-changes --uncommitted

# 4. Work on the task using the context
# (Agent reads files listed in ctx.json)

# 5. After changes, verify
recent-changes --uncommitted
```

## Output Formats

All tools support three output formats:

| Format | Flag | Best For |
|--------|------|----------|
| compact | (default) | Human reading, AI context windows |
| json | `--json` | Machine parsing, structured data |
| tsv | `--tsv` | Shell pipelines, simple parsing |

## Locations

| Item | Path |
|------|------|
| Scripts | `~/.claude/scripts/` |
| Index V2 | `~/.claude/scripts/index-v2/` |
| Indexes | `~/.claude/indexes/<hash>/` |
| Shortcuts | `~/.claude/scripts/shortcuts.sh` |

## Shortcuts

Add to your shell:

```bash
source ~/.claude/scripts/shortcuts.sh
```

| Shortcut | Command |
|----------|---------|
| `ctx` | Context builder (no AI) |
| `cctx` | Context + Codex AI |
| `ba` | Browser agent (headless) |
| `bav` | Browser agent (visible) |
