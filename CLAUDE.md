# Claude Code Global Settings

**⚠️ CRITICAL: This file is loaded at every session start. Use these commands 100% of the time.**

## 🎯 Quick Reference (Ultra-Short Aliases)

**First action in ANY new session: Run `just --list` or `just -g --list` to see available commands.**

| Task | Long | Short | Tokens Saved |
|------|------|-------|--------------|
| Search code | `just ctx "query"` | `just cx "query"` | AI search (FREE, 2s) |
| Find TODOs | `just todos` | `just t` | 70% shorter |
| Git status | `just gs` | `just st` | Familiar to git users |
| Commit | `just gc "msg"` | `just ci "msg"` | Auto-attribution |
| Commit+push | `just gcp "msg"` | `just co "msg"` | 1 command |
| View logs | `just logs` | `just l` | 75% shorter |
| DB access | `just db-lyk` | N/A | Zero-context |
| All commands | `just --list` | N/A | See everything |

**Use short aliases (1-2 chars) for 50-75% token savings on common commands.**

## ⚡ Global Commands (from ANY directory)

```bash
# Most used (memorize these 5 aliases!)
just -g cx "query"       # Search code (alias: cx → ctx)
just -g st               # Git status (alias: st → gs)
just -g ci "msg"         # Commit (alias: ci → gc)
just -g u                # Uncommitted (alias: u → uncommitted)
just -g p                # Projects (alias: p → projects)

# All aliases: cx, st, ci, co, lg, br, sw, u, sa, p, m, a, c, f, r, t, s
# Full list: just -g --list
```

## 🔥 Ultra-Short Aliases (All Projects)

| Alias | Command | Global | Project |
|-------|---------|--------|---------|
| `cx` | ctx | ✅ | ✅ |
| `s` | search/search-all | ✅ | ✅ |
| `t` | todos/grep-todos | ✅ | ✅ |
| `st` | gs (status) | ✅ | ✅ |
| `ci` | gc (commit) | ✅ | ✅ |
| `co` | gcp (commit+push) | ✅ | ✅ |
| `lg` | gl (log) | ✅ | ✅ |
| `br` | branch | ✅ | ✅ |
| `l` | logs | ❌ | ✅ |
| `f` | find-large | ✅ | ✅ |
| `r` | find-recent | ✅ | ✅ |
| `u` | uncommitted | ✅ | ❌ |
| `p` | projects | ✅ | ❌ |

**Use `just -g <alias>` globally or `just <alias>` in projects.**

## 📁 Project Commands (inside project directory)

**Every project has 80+ commands. Always check `just --list` first.**

### Standard commands in ALL projects:
- **Search**: `ctx`, `search`, `todos`, `grep-function`
- **Git**: `gs`, `gc`, `gcp`, `gl`, `branch`, `stash`
- **Logs**: `logs`, `logs-follow`, `logs-clear`
- **DB**: `db-*` commands (read/update/delete)
- **Quality**: `q`, `test`, `lint`

### Project-specific:
- **LYK-Cake4-Admin**: `test-page`, `db-migrate-user-password`
- **LaunchYourKid-Cake4**: `db-carts`, `db-cart-issues`, `db-authnet`, `deploy-prod`
- **BuyUSAFirst**: `db-shops`, `db-orders`, `db-stripe`
- **VerityCom**: `db-mark-matched`, `db-recon-stats`

## 🤖 Subagent Instructions

**When spawning subagents, prepend this to prompts:**

```
JUSTFILE-FIRST: Use short aliases for max efficiency
- just cx "query" (not grep/find/ctx)
- just s "pattern" (not rg/search)
- just ci "msg" (not git add/commit/gc)
- just db-* (not mysql)
- just l (not cat/tail/logs)

Aliases: cx, s, t, st, ci, co, lg, br, l, f, r
Run: just --list
```

## 🔧 Session Start Checklist

**At the start of EVERY new session:**
1. ✅ Recognize this CLAUDE.md is loaded (you're reading it now!)
2. ✅ Know that `just` commands are available globally and per-project
3. ✅ Use ultra-short aliases by default (cx, st, ci, co, t, l, etc.)
4. ✅ Check `just --list` when entering a new project
5. ✅ Use `just` commands instead of manual operations (grep, git, mysql, etc.)

## 🔧 Defaults

- ❌ No auto-commit/push without explicit request
- ❌ No agents for simple edits
- ✅ Always check `just --list` first
- ✅ Use justfile commands to save tokens
- ✅ Use ultra-short aliases (cx, st, ci, co, t, l)

## 💡 Why Justfile-First?

| Manual | Justfile | Savings |
|--------|----------|---------|
| Find log file path, `tail -n 100 /path/to/log` | `just logs` | 95% |
| `mysql -h 127.0.0.1 -u user -ppass db -e "SELECT..."` | `just db-carts` | 97% |
| `rg --type php "function foo"` find files, read... | `just ctx "foo"` | 97% |
| `git add . && git commit -m "..." && git push` | `just gcp "msg"` | 80% |

**Average token savings: 90%+ across all operations**

## 📋 Project Patterns (LaunchYourKid)

- Soft deletes: `deleted=0/1` (use `just db-soft-delete`)
- Multi-tenant: `company_id` filter (built into all db commands)
- Dual passwords: `password` (SHA1), `password_c4` (bcrypt)
