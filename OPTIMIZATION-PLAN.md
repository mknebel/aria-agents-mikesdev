# Claude Code Optimization Plan

## Overview
Implement 5 optimization techniques for maximum token savings, speed, and quality.

---

## 1. Prompt Compression Hook (PreToolUse)

**File**: `/home/mike/.claude/hooks/compress-prompt.sh`

**Logic**:
- Strip verbose prefixes ("Please read the file at...")
- Compress repeated file paths (use $vars)
- Remove redundant context from chained calls

**Implementation**:
```bash
#!/bin/bash
INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.tool_input // empty')

# Strip common verbose patterns
COMPRESSED=$(echo "$PROMPT" | sed \
  -e 's/Please read the file at //' \
  -e 's/I need you to //' \
  -e 's/Can you help me //' \
  -e 's/The file is located at //')

# Output modified input if changed
if [ "$COMPRESSED" != "$PROMPT" ]; then
  echo "$INPUT" | jq --arg p "$COMPRESSED" '.tool_input = $p'
fi
exit 0
```

**Savings**: 30-50% on verbose prompts

---

## 2. Incremental File Tracking (PreToolUse for Read)

**File**: `/home/mike/.claude/hooks/file-cache.sh`

**Logic**:
- Compute MD5 hash of file
- Store hash + content in /tmp/claude_files/
- On Read: check hash, return cached if unchanged
- Invalidate on Write/Edit

**Data Structure**:
```
/tmp/claude_files/
├── hashes.json       # {"/path/file.php": "abc123", ...}
├── content/
│   └── abc123        # cached file content
└── metadata.json     # timestamps, sizes
```

**Savings**: 50-70% on repeated reads

---

## 3. Semantic Deduplication (PreToolUse for Grep)

**File**: `/home/mike/.claude/hooks/semantic-cache.sh`

**Logic**:
- Normalize query (lowercase, strip punctuation)
- Generate semantic hash (simple keyword extraction)
- Check cache for similar queries (fuzzy match)
- Return cached result if match found

**Cache Key Generation**:
```bash
# Extract keywords, sort, hash
echo "$QUERY" | tr '[:upper:]' '[:lower:]' | \
  grep -oE '\b[a-z]{3,}\b' | sort -u | md5sum | cut -d' ' -f1
```

**Savings**: 20-40% on similar searches

---

## 4. Response Templating

**File**: `/home/mike/.claude/hooks/short-response.sh`

**Logic**:
- PostToolUse hook
- Replace verbose success messages with short ones
- Configurable via ~/.claude/response-mode (verbose|short)

**Templates**:
```
Edit success:  "✓ {file}:{line}"
Write success: "✓ Created {file}"
Grep results:  "{count} matches" (details in $grep_last)
Read success:  "{lines} lines" (content in $read_last)
```

**Savings**: 10-20% on response tokens

---

## 5. External Tool Integration for Subagents

**Update**: All aria agent .md files

**Changes**:
- Add explicit instructions to use Codex/Gemini for code generation
- Add fallback chain: Codex → Gemini → OpenRouter → Claude
- Add variable references support

**New Section for Each Agent**:
```markdown
## External Tools (Use First - Saves Tokens)

| Task | Tool | Command |
|------|------|---------|
| Code generation | Codex | `codex "implement..."` |
| Large file analysis | Gemini | `gemini "analyze" @file` |
| Quick generation | OpenRouter | `ai.sh fast "prompt"` |

## Variable References
- Use `$grep_last` instead of re-outputting search results
- Use `$read_last` instead of re-outputting file contents
- File paths: `/tmp/claude_vars/{tool}_last`
```

---

## Implementation Order

| # | Component | Priority | Dependencies |
|---|-----------|----------|--------------|
| 1 | Incremental file tracking | High | None |
| 2 | Prompt compression | High | None |
| 3 | Semantic deduplication | Medium | Search cache exists |
| 4 | Response templating | Medium | var-store exists |
| 5 | Update aria agents | High | All hooks ready |

---

## Testing Plan

1. Run `/cost-report` before/after
2. Execute same task with/without optimizations
3. Compare token usage via `~/.claude/usage/`
4. Verify quality unchanged

---

## Files to Create/Modify

**Create**:
- `/home/mike/.claude/hooks/compress-prompt.sh`
- `/home/mike/.claude/hooks/file-cache.sh`
- `/home/mike/.claude/hooks/semantic-cache.sh`
- `/home/mike/.claude/hooks/short-response.sh`

**Modify**:
- `/home/mike/.claude/settings.json` (add hooks)
- `/home/mike/.claude/agents/*.md` (add external tool instructions)
- `/home/mike/.claude/CLAUDE.md` (add variable reference docs)
