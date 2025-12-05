---
description: Commit changes (Opus decides, Haiku executes)
argument-hint: [commit message]
---

# Commit Command (ARIA Optimized)

**Pattern:** Opus thinks, Haiku types. Zero wasted tokens on git execution.

## Usage

```
/commit                           # Auto-generate message from changes
/commit fix: resolve login bug    # Use provided message
```

## Optimized Flow

```
┌─────────────────────────────────────────────────────────────┐
│  STEP 1: Bash (FREE) - Get raw data                         │
│  Run these commands to see what changed:                    │
│  - git status --porcelain                                   │
│  - git diff --cached --stat (if staged)                     │
│  - git diff --stat (if unstaged)                            │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  STEP 2: YOU (Opus) - Decide and compose                    │
│  - Review the changes                                       │
│  - Decide what to commit (all or specific files)            │
│  - Write commit message (or use provided: "$ARGUMENTS")     │
│  - Build EXPLICIT git commands                              │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  STEP 3: Task(aria-admin, haiku) - Execute                  │
│  Hand off with ZERO ambiguity:                              │
│  - Exact files to add                                       │
│  - Exact commit message                                     │
│  - Whether to push                                          │
└─────────────────────────────────────────────────────────────┘
```

## Your Task (Opus)

### Step 1: Get Status (Bash - no tokens)

Run these in parallel:
```bash
git status --porcelain
git diff --stat
git log --oneline -3
```

### Step 2: Decide (Your job)

- Review changes
- If `$ARGUMENTS` provided, use as commit message
- Otherwise, write a concise commit message
- Identify files to stage

### Step 3: Delegate to Haiku

```
Task(aria-admin, haiku, prompt: """
Execute git commit with these EXACT parameters:

FILES TO STAGE:
- path/to/file1.php
- path/to/file2.js

COMMIT MESSAGE:
feat: add user authentication

Include this footer:
🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

COMMANDS TO RUN:
1. git add [files]
2. git commit -m "[message]"
3. git status (verify)

DO NOT push unless explicitly requested.
Report: files committed, commit hash, any errors.
""")
```

### Step 4: Report to User

After Haiku completes, summarize:
- Commit hash
- Files committed
- Any issues

## Cost Comparison

| Step | Before (Opus all) | After (Optimized) |
|------|-------------------|-------------------|
| git status | Opus token | Bash (free) |
| git diff | Opus token | Bash (free) |
| Decide files | Opus | Opus |
| Write message | Opus | Opus |
| git add | Opus token | **Haiku** |
| git commit | Opus token | **Haiku** |
| Error handling | Opus token | **Haiku** |

**Savings:** ~40% fewer Opus tokens per commit

## Example

User: `/commit`

You (Opus):
1. Run `git status` and `git diff` via Bash
2. See: 3 files changed in scripts/
3. Compose message: "feat: add ARIA token optimizer"
4. Delegate to Haiku: "Stage scripts/aria*.sh, commit with message, report hash"
5. Tell user: "Committed abc1234: feat: add ARIA token optimizer (3 files)"

## Push Handling

If user says "commit and push" or `/commit --push`:
- Add `git push origin [branch]` to Haiku's instructions
- Haiku reports push result

## Important Rules

- **Opus:** Decides WHAT to commit and message
- **Haiku:** Executes git commands (add, commit, push)
- **Never:** Have Opus run git add/commit directly
- **Always:** Provide Haiku with explicit file list and exact message
