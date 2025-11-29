---
description: Quick project structure overview
allowed-tools: Bash, Glob
---

Show project structure for: $ARGUMENTS

Execute ONE command:
```bash
find ${ARGUMENTS:-.} -type f -name "*.php" -o -name "*.js" -o -name "*.ts" | head -100 | sort
```

Or use Glob with pattern "**/*.{php,js,ts}" and head_limit:100.

Return organized summary by directory. Do NOT read file contents.
