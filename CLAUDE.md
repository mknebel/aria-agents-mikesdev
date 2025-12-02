# Global Rules - FOLLOW STRICTLY

## Response Format
Start every response with a brief mode indicator:
- Fast mode: `⚡ Fast |` then your response
- Aria mode: `🔄 Aria |` then your response

Example: `⚡ Fast | I'll search for that using gemini...`

## CRITICAL: Use External Tools First (Saves Claude Tokens)

Check `~/.claude/routing-mode` for current mode. Default is **fast** (external tools).

### Fast Mode (Default) - Use External Tools via Bash

| Task Type | Tool | Command |
|-----------|------|---------|
| Search/Analysis | Gemini (FREE) | `gemini "query" @files` |
| Simple code | OpenRouter | `ai.sh fast "prompt"` |
| Complex code | Codex (FREE) | `codex "implement..."` |
| Code review | Codex (FREE) | `codex "review..."` |
| Write tests | Codex (FREE) | `codex "write tests..."` |

**Run these via the Bash tool.** They use your existing subscriptions (Google, GPT) - not Claude tokens.

### Aria Mode (Fallback) - Use Claude Agents

Only if `/mode aria` is set, use Task tool with these agents:

| Task Type | Subagent |
|-----------|----------|
| Coding | `aria-coder` |
| Search | `Explore` |
| Testing | `aria-qa` |
| Git ops | `aria-admin` |
| Docs | `aria-docs` |
| Architecture | `aria-architect` |
| Security | `code-review` |

### Check Current Mode
```bash
cat ~/.claude/routing-mode   # "fast" or "aria"
```

### Switch Modes
- `/mode fast` - Use external tools (saves tokens)
- `/mode aria` - Use Claude agents (best quality)

## Variable References (Pass-by-Reference)

Large tool outputs are auto-saved as variables. **Use references instead of re-outputting data.**

| Variable | Contains |
|----------|----------|
| `$grep_last` | Last Grep result |
| `$read_last` | Last Read result |
| `/tmp/claude_vars/grep_last` | File path |

**Example:**
```
❌ Bad: "Here are the 500 matches: [... re-output everything ...]"
✅ Good: "Results stored in $grep_last, analyzing..."
```

This saves ~80% tokens on multi-step workflows.

## Tool Efficiency Rules

| Tool | Rule |
|------|------|
| Grep/Search | Combine patterns, max 3 calls |
| Read | Once per file, use offset/limit for large files |
| Edit | Use MultiEdit for same file |
| Bash | Chain with `&&`, absolute paths |
| Large outputs | Reference `$tool_last` instead of re-outputting |

## Commands
`/mode` `/menu` `/cost-report` `/fast` `/index-project`
