# Global Rules

## Response Format
Start responses with: `⚡ Fast |` or `🔄 Aria |`

## Routing Decision Tree

```
Is mode fast? (cat ~/.claude/routing-mode)
├─ YES → Use external tools (see table below)
└─ NO (aria) → Use Claude agents (aria-coder, Explore, aria-qa, etc.)

Is task UI/CSS/design?
└─ YES → Use Claude directly (skip external tools)
```

## Tools Reference (Fast Mode)

| Task | Command | Cost |
|------|---------|------|
| **Search code** | `ctx "query"` or `smart-search.sh "pattern"` | FREE |
| **Symbol lookup** | `/lookup ClassName` | FREE |
| **Read + analyze** | `smart-read.sh file "question"` | ~$0.01 |
| **Implement code** | `codex "implement..."` or `cctx "task"` | FREE |
| **Review code** | `codex "review..."` | FREE |
| **Write tests** | `codex "write tests..."` | FREE |
| **Quick generation** | `ai.sh fast "prompt"` | ~$0.001 |
| **Tool-use chains** | `ai.sh tools "task"` | ~$0.01 |
| **Screenshot** | `browser.sh screenshot <url>` | FREE |
| **Browser testing** | `ba "task"` (headless) / `bav "task"` (visible) | ~$0.02 |
| **Database** | `dbquery lyk "SELECT..."` | FREE |

**Claude tools OK**: Grep, Glob, Edit, Write (included in subscription)

## Variable Protocol (MANDATORY)

All outputs auto-save. Pass references, not data:

```bash
ctx "auth login"                              # → $ctx_last
llm codex "implement @var:ctx_last"           # → $llm_response_last
llm qa "review @var:llm_response_last"        # Chains automatically
```

| Variable | Source |
|----------|--------|
| `$ctx_last` | `ctx` |
| `$llm_response_last` | `llm` |
| `$grep_last` | Claude Grep |
| `$read_last` | Claude Read |

**LLM capabilities**: Codex/Gemini read files (pass path). OpenRouter inlines content (max 20KB).

```bash
var list          # Show all variables
var fresh name 5  # Check if <5 min old
```

## Efficiency Rules

| Tool | Rule |
|------|------|
| Grep | Combine patterns, max 3 calls |
| Read | Once per file, use limit for large files |
| Edit | Use MultiEdit for same file |
| Bash | Chain with `&&`, absolute paths |
| Output | Reference `@var:name`, never re-output data |

## Shortcuts

| Shortcut | Purpose |
|----------|---------|
| `ctx` | Context search (auto-saves) |
| `llm` | Smart LLM dispatcher |
| `var` | Variable manager |
| `cctx` | Codex with index context |
| `dbquery` | Database queries |
| `cake` | CakePHP CLI (php74) |
| `ba`/`bav` | Browser agent headless/visible |
| `lyksearch` | Search LYK logs |

## Browser

```bash
browser.sh screenshot <url>     # Quick screenshot
browser.sh visible/headless     # Set mode
ba "test the form"              # Agentic (headless)
bav "test the form"             # Agentic (visible)
```

Output: `~/.claude/browser-screenshots/`, `~/.claude/browser-videos/`

## Commands
`/mode` `/fast` `/menu` `/cost-report` `/index-project` `/lookup`

## Aria Mode Agents (when mode=aria)

| Task | Agent |
|------|-------|
| Coding | `aria-coder` |
| Search | `Explore` |
| Testing | `aria-qa` |
| Git | `aria-admin` |
| Docs | `aria-docs` |
| Architecture | `aria-architect` |
| Security | `code-review` |
