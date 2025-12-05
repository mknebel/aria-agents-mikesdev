---
description: Smart context search (FREE via external tools)
argument-hint: <query>
---

# Context Search

Gather context using external tools (FREE):

```bash
ctx "$ARGUMENTS"
```

## Options

| Flag | Purpose |
|------|---------|
| -f | File search only |
| -s | Symbol/function search |
| -c | Content search |
| --force | Bypass cache |

## Output

Results saved to `/tmp/claude_vars/ctx_last`

## Example

```bash
ctx "user authentication flow"
ctx -s "validateEmail"
ctx -f "*.controller.php"
```
