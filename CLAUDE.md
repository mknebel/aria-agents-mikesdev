# Global Rules - FOLLOW STRICTLY

## Response Format
Start every response with a brief mode indicator:
- Fast mode: `⚡ Fast |` then your response
- Aria mode: `🔄 Aria |` then your response

Example: `⚡ Fast | I'll search for that using gemini...`

## CRITICAL: Use External Tools First (Saves Claude Tokens)

Check `~/.claude/routing-mode` for current mode. Default is **fast** (external tools).

### When to Use External Tools (ALWAYS in Fast Mode)

**BEFORE using Grep/Read directly, use these instead:**

| User asks... | Use this | Command |
|--------------|----------|---------|
| "find X", "where is X", "search for X" | Tools agent | `ai.sh tools "find X in codebase"` |
| "explain this code", "what does X do" | Smart read | `smart-read.sh file "question"` |
| "search for pattern" | Smart search | `smart-search.sh "pattern" path` |
| "test the UI", "check the page" | Browser agent | `browser-agent.sh "task"` |
| "take a screenshot" | Browser | `browser.sh screenshot <url>` |
| "implement X", "write code for" | Codex | `codex "implement X"` |
| "review this code" | Codex | `codex "review..."` |
| "write tests for" | Codex | `codex "write tests..."` |

### Fast Mode Tools Reference

| Task Type | Tool | Command |
|-----------|------|---------|
| Search/Analysis | Gemini (FREE) | `gemini "query" @files` |
| Code exploration | DeepSeek | `ai.sh tools "task"` |
| Smart search | DeepSeek/Gemini | `smart-search.sh "query" path` |
| Smart read | DeepSeek/Gemini | `smart-read.sh file "question"` |
| Simple code | OpenRouter | `ai.sh fast "prompt"` |
| Complex code | Codex (FREE) | `codex "implement..."` |
| Code review | Codex (FREE) | `codex "review..."` |
| Write tests | Codex (FREE) | `codex "write tests..."` |
| Browser/UI | Playwright | `browser-agent.sh "task"` |
| Screenshot | Playwright | `browser.sh screenshot <url>` |

**Run these via the Bash tool.** They use external LLMs - not Claude tokens.

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

## Browser Automation

Use `browser-agent.sh` for agentic browser testing (LLM-driven) or `browser.sh` for direct commands.

### Agentic Browser Testing (LLM decides steps)
```bash
browser-agent.sh "task description"              # Headless
browser-agent.sh visible "task description"      # Watch it run
ai.sh agent "task description"                   # Alias
```

Examples:
```bash
browser-agent.sh "go to http://localhost/app and get the title"
browser-agent.sh "login to site, take a screenshot, verify dashboard"
browser-agent.sh visible "test the signup form"
```

### Direct Browser Commands
```bash
browser.sh url <url>                    # Navigate, get HTML
browser.sh screenshot <url> [path]      # Take screenshot
browser.sh video <url> [dir]            # Record video
browser.sh visible                      # Set visible mode (persistent)
browser.sh headless                     # Set headless mode (persistent)
browser.sh status                       # Show current mode
```

### Output Locations
| Type | Location |
|------|----------|
| Screenshots | `~/.claude/browser-screenshots/` |
| Videos | `~/.claude/browser-videos/` |
| Agent logs | `/tmp/claude_vars/browser-agent.log` |
| HTML output | `/tmp/claude_vars/browser_last` |

### When to Use
- **browser-agent.sh**: Complex multi-step tasks, form testing, user flows
- **browser.sh**: Quick screenshots, simple navigation, video recording

## Commands
`/mode` `/menu` `/cost-report` `/fast` `/index-project`
