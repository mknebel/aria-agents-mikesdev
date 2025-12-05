---
description: List or show pipeline variables
argument-hint: [variable_name]
---

# Pipeline Variables

Variables persist between agents in `/tmp/claude_vars/`.

## Usage

### List all variables:
```bash
ls -la /tmp/claude_vars/
```

### Show specific variable (if argument provided):
```bash
cat /tmp/claude_vars/$ARGUMENTS
```

## Common Variables

| Variable | Source | Purpose |
|----------|--------|---------|
| codex_last | codex-save.sh | Generated code |
| codex_plan | plan-pipeline.sh | Implementation plan |
| gemini_context | plan-pipeline.sh | Gathered context |
| ctx_last | ctx.sh | Search results |
| grep_last | Grep tool | Search matches |
