# RULES

## MODE
```
CHECK: cat ~/.claude/routing-mode → fast|aria
fast → external tools (below)
aria → Claude agents (aria-coder, Explore, aria-qa, aria-admin, aria-docs, aria-architect, code-review)
UI/CSS/design → Claude direct (skip external)
```

## RESPONSE: `⚡ Fast |` or `🔄 Aria |`

## TOOLS
```yaml
search:     ctx "query" | smart-search.sh "pattern"     # FREE, saves $ctx_last
lookup:     /lookup ClassName                           # FREE
read:       smart-read.sh file "question"               # $0.01
implement:  codex "task" | cctx "task"                  # FREE
review:     codex "review..."                           # FREE
tests:      codex "write tests..."                      # FREE
quick:      ai.sh fast "prompt"                         # $0.001
tools:      ai.sh tools "task"                          # $0.01
screenshot: browser.sh screenshot <url>                 # FREE
browser:    ba "task" | bav "task"                      # $0.02
database:   dbquery lyk|verity "SQL"                    # FREE
php:        cake <cmd> | php74 | php81                  # -
```

## VARS (MANDATORY)
```yaml
protocol: ctx → llm @var:name (never inline data)
store:    /tmp/claude_vars/ (cleared on restart)
```
```bash
ctx "query"                          # → $ctx_last
llm codex "do @var:ctx_last"         # → $llm_response_last
llm qa "review @var:llm_response_last"
var list | var fresh name 5
```
```yaml
$ctx_last:          ctx output
$llm_response_last: llm output
$grep_last:         Grep output
$read_last:         Read output
```
Codex/Gemini: read files (pass path). OpenRouter: inline (max 20KB).

## EFFICIENCY
```yaml
Grep:   combine patterns, max 3 calls
Read:   once per file, use limit for large
Edit:   MultiEdit for same file
Bash:   chain &&, absolute paths
Output: @var:name, never re-output
```

## BROWSER
```bash
browser.sh screenshot|visible|headless <url>
ba "task"   # headless
bav "task"  # visible
```
Output: ~/.claude/browser-screenshots/

## COMMANDS
/mode /fast /menu /cost-report /index-project /lookup
