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
