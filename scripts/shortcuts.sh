#!/bin/bash
# Shell functions for Claude Code shortcuts (docs in ~/.claude/CLAUDE.md)

# Database (local, fast, exact)
function dbquery { ~/.claude/scripts/dbquery.sh "$@"; }

# Log search (local rg, fast)
LYK_LOGS="/mnt/d/MikesDev/www/LaunchYourKid/LaunchYourKid-Cake4/register/logs"
VERITY_LOGS="/mnt/d/MikesDev/www/Whitlock/Verity/VerityCom/logs"
function lyksearch { rg -i "$1" "$LYK_LOGS"/*.log; }
function veritysearch { rg -i "$1" "$VERITY_LOGS"/*.log; }

# PHP/CakePHP (local, fast)
function cake { /mnt/c/Apache24/php74/php.exe bin/cake.php "$@"; }
function php74 { /mnt/c/Apache24/php74/php.exe "$@"; }
function php81 { /mnt/c/Apache24/php81/php.exe "$@"; }

# Browser (LLM-driven, for complex UI tasks)
function ba { ~/.claude/scripts/browser-agent.sh "$@"; }
function bav { ~/.claude/scripts/browser-agent.sh visible "$@"; }

# Codex with index context
function cctx { ~/.claude/scripts/codex-with-context.sh "$@"; }

# Context builder (no AI call) - for any agent
function ctx { ~/.claude/scripts/ctx.sh "$@"; }
function recent-changes { ~/.claude/scripts/recent-changes.sh "$@"; }

# Navigation (saves 50+ chars)
function cdlyk { cd /mnt/d/MikesDev/www/LaunchYourKid/LYK-Cake4-Admin; }
function cdverity { cd /mnt/d/MikesDev/www/Whitlock/Verity/VerityCom; }
function cdwww { cd /mnt/d/MikesDev/www; }

# Exports
export -f dbquery lyksearch veritysearch cake php74 php81 ba bav cctx ctx recent-changes cdlyk cdverity cdwww
export LYK_LOGS VERITY_LOGS
alias smart-review='~/.claude/scripts/smart-review.sh'
