---
description: Deploy files via WinSCP (Opus decides, Haiku executes)
argument-hint: <connection> [files...]
---

# Deploy Command (ARIA Optimized)

**Pattern:** Opus orchestrates, Haiku executes. Zero wasted tokens.

## Usage

```
/deploy <connection> [file1] [file2] ...
/deploy lyk-production                    # Deploy all changed files
/deploy lyk-production src/Controller/    # Deploy specific path
```

## Flow

```
┌─────────────────────────────────────────────────────────────┐
│  YOU (Opus) - Orchestrator                                  │
│  1. Parse arguments: connection = "$ARGUMENTS"              │
│  2. If no files specified, get changed files from git       │
│  3. Build explicit file list                                │
│  4. Hand off to Haiku with COMPLETE instructions            │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  Task(aria-devops, haiku) - Executor                        │
│  - Receives: connection, file list, paths                   │
│  - Generates WinSCP script                                  │
│  - Executes transfer                                        │
│  - Reports results                                          │
└─────────────────────────────────────────────────────────────┘
```

## Connections (Saved Sessions)

| Name | Server | Path |
|------|--------|------|
| lyk-production | launchyourkid.com | /home/lyklive/public_html/admin/ |
| lyk-staging | staging.launchyourkid.com | /home/lyklive/public_html/admin/ |

## Your Task (Opus)

1. **Parse the arguments:** `$ARGUMENTS`

2. **If no files specified, get changed files:**
   ```bash
   git diff --name-only HEAD~1
   # or
   git status --porcelain | awk '{print $2}'
   ```

3. **Build the file list and delegate to Haiku:**

```
Task(aria-devops, haiku, prompt: """
Deploy to production via WinSCP.

CONNECTION: [connection name from args]
LOCAL BASE: /mnt/d/MikesDev/www/LaunchYourKid/LYK-Cake4-Admin/
REMOTE BASE: /home/lyklive/public_html/admin/

FILES TO DEPLOY:
- [file1]
- [file2]
- [file3]

INSTRUCTIONS:
1. Create WinSCP script at /tmp/deploy-[timestamp].txt
2. Script content:
   open [connection]
   lcd "[local base]"
   cd "[remote base]"
   put "[file1]"
   put "[file2]"
   exit
3. Execute: ~/.claude/scripts/winscp-deploy.sh [connection] [local-base] [remote-base] [files...]
   OR directly: "/mnt/c/Program Files (x86)/WinSCP/WinSCP.com" /script=/tmp/deploy-[timestamp].txt
4. Report success/failure for each file
5. Clean up script file
""")
```

4. **Report results to user**

## Example

User: `/deploy lyk-production src/Controller/Admin/ItemsController.php`

You (Opus):
1. Connection: lyk-production
2. Files: src/Controller/Admin/ItemsController.php
3. Delegate to Haiku with explicit instructions
4. Report: "Deployed 1 file to production"

## Important

- **Opus:** Only decides WHAT and WHERE
- **Haiku:** Handles HOW (script generation, execution, error handling)
- **Never:** Have Opus generate/execute WinSCP scripts directly
