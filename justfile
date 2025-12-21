# Claude Config Repository Justfile
# Manages ~/.claude configuration git repo

# Show all commands
default:
    @just --list

# Git shortcuts (ultra-short aliases)
alias st := status
alias ci := commit
alias co := commit-push
alias lg := log
alias df := diff

# Git status
status:
    @git status

# Git log (pretty format)
log n="10":
    @git log --oneline --graph --decorate -n {{n}}

# Git diff
diff:
    @git diff

# Stage all changes
add:
    @git add -A

# Commit with message
commit message:
    @git add -A
    @git commit -m "{{message}}\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)\n\nCo-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

# Commit and push
commit-push message:
    @just commit "{{message}}"
    @git push

# Pull latest
pull:
    @git pull

# Show current branch
branch:
    @git branch --show-current

# Git sync (pull + push)
sync:
    @git pull --rebase
    @git push

# Show uncommitted changes
uncommitted:
    @git status --short

# Show what changed in last commit
last:
    @git show --stat

# ARIA commands

# Show ARIA models
models:
    @aria route models

# ARIA session status
session:
    @aria-session.sh show

# List ARIA sessions
sessions:
    @aria-session.sh list

# New ARIA session
new-session:
    @aria-session.sh new

# ARIA stats
aria-stats:
    @aria status 2>/dev/null || echo "ARIA status not available"

# Utility commands

# Backup configs
backup:
    @tar -czf ~/claude-config-backup-$(date +%Y%m%d-%H%M%S).tar.gz \
        CLAUDE.md scripts/*.sh *.md 2>/dev/null
    @echo "✓ Backup created: ~/claude-config-backup-*.tar.gz"

# Show disk usage
disk:
    @du -sh . 2>/dev/null

# Cleanup temp files
clean:
    @rm -f cache/*.tmp 2>/dev/null || true
    @echo "✓ Cleaned temporary files"

# Test ARIA routing
test-aria task="context" prompt="test":
    @echo "Testing: aria route {{task}} '{{prompt}}'"
    @aria route {{task}} "{{prompt}}"

# Show config summary
info:
    @echo "Claude Config Repository"
    @echo "════════════════════════════════════════"
    @echo "Location: $(pwd)"
    @echo "Branch:   $(git branch --show-current)"
    @echo "Commits:  $(git log --oneline | wc -l)"
    @echo "Status:   $(git status --short | wc -l) uncommitted changes"
    @echo ""
    @echo "ARIA Configuration:"
    @echo "  Models:   aria route models"
    @echo "  Session:  $(aria-session.sh current 2>/dev/null || echo 'none')"
    @echo ""
    @echo "Recent commits:"
    @git log --oneline -3

# Quick health check (parallel execution)
health:
    #!/usr/bin/env bash
    echo "=== System Health Check ===" &
    (command -v aria >/dev/null && echo "✓ aria: $(which aria)" || echo "✗ aria: not found") &
    (command -v gemini >/dev/null && echo "✓ gemini: available" || echo "✗ gemini: not found") &
    (command -v claude >/dev/null && echo "✓ claude: available" || echo "✗ claude: not found") &
    echo "✓ justfiles: $(just -g --list 2>/dev/null | grep -c '^[[:space:]]*[a-z]') global recipes" &
    (git status --short | wc -l | xargs -I {} echo "• Git: {} uncommitted changes") &
    wait

# Verify ARIA setup
verify-aria:
    #!/usr/bin/env bash
    echo "ARIA Setup Verification"
    echo "═══════════════════════════════════════"
    command -v aria >/dev/null && echo "✓ aria command: $(which aria)" || echo "✗ aria not in PATH"
    command -v gemini >/dev/null && echo "✓ gemini CLI: installed" || echo "✗ gemini CLI: missing"
    command -v claude >/dev/null && echo "✓ claude CLI: installed" || echo "✗ claude CLI: missing"
    [[ -f ~/.claude/scripts/aria-route.sh ]] && echo "✓ ARIA router: found" || echo "✗ ARIA router: missing"
    echo ""
    echo "Model Routing:"
    ~/.claude/scripts/aria route models 2>/dev/null || echo "✗ Cannot display models"

# Enhanced commit with type prefix
ci-feat msg: (commit "feat: {{msg}}")
ci-fix msg: (commit "fix: {{msg}}")
ci-docs msg: (commit "docs: {{msg}}")
ci-refactor msg: (commit "refactor: {{msg}}")
ci-perf msg: (commit "perf: {{msg}}")
ci-test msg: (commit "test: {{msg}}")

# Analyze session for optimization opportunities
analyze-session:
    @~/.claude/scripts/aria route context "Analyze current session for: 1) Repeated command sequences, 2) Manual operations that could be automated via justfile, 3) Opportunities for parallel execution, 4) Token-heavy operations. Provide top 3 specific recommendations."

# Conversation history search
conversations:
    @find ~/.claude -type f \( -name "*conversation*" -o -name "*session*" -o -name "*.log" \) 2>/dev/null | head -20

# ARIA ultra-short aliases (70% token savings)
alias ag := aria-gather
alias ap := aria-plan
alias ac := aria-code
alias at := aria-test
alias aw := aria-workflow

# ARIA workflow recipes
aria-gather query:
    @~/.claude/scripts/aria route context "{{query}}"

aria-plan task:
    @~/.claude/scripts/aria route plan "{{task}}"

aria-code task:
    @~/.claude/scripts/aria route code "{{task}}"

aria-test task:
    @~/.claude/scripts/aria route test "{{task}}"

aria-workflow task:
    #!/usr/bin/env bash
    echo "ARIA Workflow: {{task}}"
    echo "1. Gathering context (Gemini, FREE)..."
    ~/.claude/scripts/aria route context "gather context for: {{task}}"
    echo ""
    echo "2. Planning (Claude Opus)..."
    ~/.claude/scripts/aria route plan "design implementation for: {{task}}"
    echo ""
    echo "3. Implementing (Gemini, FREE)..."
    ~/.claude/scripts/aria route code "implement: {{task}}"
    echo ""
    echo "4. Testing (Gemini, FREE)..."
    ~/.claude/scripts/aria route test "verify: {{task}}"
