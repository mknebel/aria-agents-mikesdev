# Global Rules - FOLLOW STRICTLY

## Response Format
Start every response with a brief mode indicator:
- Fast mode: `⚡ Fast |` then your response
- Aria mode: `🔄 Aria |` then your response

Example: `⚡ Fast | I'll search for that using gemini...`

## CRITICAL: Use External Tools First (Saves Claude Tokens)

Check `~/.claude/routing-mode` for current mode. Default is **fast** (external tools).

### ⛔ MANDATORY PRE-TOOL CHECK (Fast Mode)

**BEFORE using Read, Grep, or Task tools, STOP and ask yourself:**

1. Am I in fast mode? (`cat ~/.claude/routing-mode`)
2. Is there an external tool that does this cheaper?

| ❌ DON'T | ✅ DO INSTEAD |
|----------|---------------|
| `Read` on file >100 lines | `smart-read.sh file "what I need"` |
| `Grep` for exploration | `smart-search.sh "pattern"` or `gemini "find X" @path` |
| `Task` with Explore agent | `gemini "question about codebase" @src` |
| Multiple `Read` calls | `ctx src/path` then `gemini "analyze" @-` |
| Writing complex code | `codex "implement X"` or `cctx "implement X"` |

**VIOLATIONS (token waste):**
- Reading a 2000-line file when you only need one function
- Using Grep 5+ times to explore instead of one gemini query
- Using Claude agents in fast mode

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

| Task Type | Tool | Command | Cost |
|-----------|------|---------|------|
| **Pattern search** | smart-search.sh | `smart-search.sh "query"` | FREE (indexed) |
| **Symbol lookup** | /lookup | `/lookup ClassName` | FREE (indexed) |
| **File listing** | Claude Glob | Use directly | Included |
| Semantic analysis | Gemini | `gemini "query" @files` | FREE |
| Quick code gen | OpenRouter | `ai.sh fast "prompt"` | ~$0.001 |
| Tool-use tasks | OpenRouter | `ai.sh tools "task"` | ~$0.01 |
| Smart read | DeepSeek/Gemini | `smart-read.sh file "question"` | ~$0.01 |
| Complex code | Codex | `codex "implement..."` | FREE |
| Code review | Codex | `codex "review..."` | FREE |
| Write tests | Codex | `codex "write tests..."` | FREE |
| Browser/UI | Playwright | `browser-agent.sh "task"` | ~$0.02 |
| Screenshot | Playwright | `browser.sh screenshot <url>` | FREE |

**Claude search tools ARE efficient** - use Grep/Glob directly for pattern matching.

### OpenRouter Models (via ai.sh)
| Command | Model | Best For |
|---------|-------|----------|
| `ai.sh fast` | Grok-3-mini | Quick snippets, simple tasks |
| `ai.sh tools` | DeepSeek V3 | File ops, tool-use chains |
| `ai.sh agent` | Browser preset | UI testing, screenshots |

**Run these via Bash tool.** External LLMs = no Claude tokens.

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

### Variable Store
All session variables stored in `/tmp/claude_vars/` (cleared on restart).

| Variable | Contains | Auto-saved by |
|----------|----------|---------------|
| `$ctx_last` | Last context search | `ctx "query"` |
| `$grep_last` | Last Grep result | Claude Grep |
| `$read_last` | Last Read result | Claude Read |
| `$llm_response_last` | Last LLM response | `llm.sh` |
| `$smart_read_last` | Last smart read | `smart-read.sh` |

### Variable Manager (`var.sh`)
```bash
var save name "content"      # Save variable
var save name - "query"      # Save from stdin with metadata
var get name                 # Get content
var get name --head 10       # First 10 lines
var get name --meta          # Show metadata (age, size, query)
var path name                # Get file path
var fresh name 5             # Check if <5 min old (exit 0/1)
var list                     # List all variables
var clear                    # Clear all
```

### LLM Dispatcher (`llm.sh`)
Smart dispatcher that handles `@var:` references based on LLM capabilities:

```bash
llm codex "implement X based on @var:ctx_last"   # Codex reads file
llm gemini "analyze @var:grep_last"              # Gemini reads file
llm fast "summarize @var:ctx_last"               # OpenRouter: inlines content
```

| Provider | File Reading | Reference Handling |
|----------|--------------|-------------------|
| `codex` | ✅ Native | Passes file path |
| `gemini` | ✅ Native | Passes file path |
| `fast/tools/qa` | ❌ API | Inlines content (max 20KB) |

### Context Builder (`ctx`)
```bash
ctx "auth login"                     # Search → auto-saves to $ctx_last
llm codex "implement @var:ctx_last"  # Use saved context

# Deduplication: asks before re-running same query within 5 min
ctx "auth login"                     # "Same query run 2m ago. Use cached? [Y/n]"
ctx "auth login" --force             # Skip dedup check
```

### Example Workflow
```bash
# OLD: Data passed inline (expensive)
CONTEXT=$(ctx "auth")                    # 50KB output
ANALYSIS=$(echo "$CONTEXT" | ai.sh qa)   # 50KB input
codex "implement: $ANALYSIS"             # 10KB input
# Total: ~110KB tokens

# NEW: References passed (cheap)
ctx "auth"                               # Saves @var:ctx_last
llm qa "analyze @var:ctx_last"           # LLM reads file directly
llm codex "implement @var:llm_response_last"
# Total: ~200 bytes + LLMs read files
```

**Rule:** Never re-output large data. Use `@var:name` references.

## Tool Efficiency Rules

| Tool | Rule |
|------|------|
| Grep/Search | Combine patterns, max 3 calls |
| Read | Once per file, use offset/limit for large files |
| Edit | Use MultiEdit for same file |
| Bash | Chain with `&&`, absolute paths |
| Large outputs | Reference `$tool_last` instead of re-outputting |

## Project Shortcuts

Essential shortcuts for common tasks. Loaded via BASH_ENV for all sessions (including Claude).

Source: `~/.claude/scripts/shortcuts.sh`

| Shortcut | Full path | Purpose |
|----------|-----------|---------|
| `dbquery` | `~/.claude/scripts/dbquery.sh` | Database queries (credentials managed) |
| `lyksearch` | - | Search LYK logs (rg) |
| `veritysearch` | - | Search Verity logs (rg) |
| `cake` | `/mnt/c/Apache24/php74/php.exe bin/cake.php` | CakePHP commands |
| `php74` | `/mnt/c/Apache24/php74/php.exe` | PHP 7.4 |
| `php81` | `/mnt/c/Apache24/php81/php.exe` | PHP 8.1 |
| `ba` | `~/.claude/scripts/browser-agent.sh` | Browser agent (headless) |
| `bav` | `~/.claude/scripts/browser-agent.sh visible` | Browser agent (visible) |
| `cctx` | `~/.claude/scripts/codex-with-context.sh` | Codex with index context |
| `ctx` | `~/.claude/scripts/ctx.sh` | Context builder (auto-saves) |
| `var` | `~/.claude/scripts/var.sh` | Variable manager |
| `llm` | `~/.claude/scripts/llm.sh` | Smart LLM dispatcher |
| `recent-changes` | `~/.claude/scripts/recent-changes.sh` | List recent file changes |
| `cdlyk` | - | cd to LYK-Cake4-Admin |
| `cdverity` | - | cd to VerityCom |
| `cdwww` | - | cd to /mnt/d/MikesDev/www |

### Database (MANDATORY - never raw mysql)
```bash
dbquery lyk "SELECT * FROM users"     # Query LYK database
dbquery verity "SELECT..."            # Query Verity database
dbquery -l                            # List all aliases
dbquery <alias> -o json "SELECT..."   # JSON output
```

### Log Search (local rg - fast, free)
```bash
lyksearch "error"                     # Search LYK logs
veritysearch "pattern"                # Search Verity logs
```

### PHP (port 80 = php74, port 81 = php81)
```bash
cake migrations migrate               # CakePHP command
php74 script.php                      # PHP 7.4
php81 script.php                      # PHP 8.1
```

### Browser (include port in URL if needed)
```bash
ba "test http://localhost/app"        # Headless
bav "test http://localhost:81/app"    # Visible, port 81
```

## Browser Automation

Use `browser-agent.sh` for agentic browser testing (LLM-driven) or `browser.sh` for direct commands.

**OpenRouter Presets** (auto-routes to best model):
- Browser tasks: `@preset/browser-agent-tools-only` (MiniMax M2, DeepSeek V3.2, Qwen3)
- General tools: `@preset/general-non-browser-tools`

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
- Use Claude for UI designs and related HTML, CSS and front-end frameworks