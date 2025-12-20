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
JUSTFILE-FIRST + ARIA-FIRST: Max efficiency and token savings
- just cx "query" (not grep/find/ctx)
- just s "pattern" (not rg/search)
- just ci "msg" (not git add/commit/gc)
- just db-* (not mysql)
- just l (not cat/tail/logs)

ARIA routing (context-first pattern):
- ALWAYS: aria route context "gather context for X" (Gemini 1M context)
- THEN: aria route plan "design approach" (Claude Opus for planning)
- THEN: aria route code "implement X" (Gemini for simple, Opus for complex)
- THEN: aria route test "run tests" (Gemini)
- THEN: aria route code "commit and push changes" (Gemini handles git)
- Use Gemini as context layer, Claude Opus for planning & complex coding

Gemini Fast handles (FREE, super fast):
- Code implementation, testing, git commits, prod pushes
Claude Opus handles (Claude sub):
- Planning, complex coding, hard coding tasks

Aliases: cx, s, t, st, ci, co, lg, br, l, f, r
Run: just --list
Run: aria route models
```

## 🎯 MANDATORY Development Workflow (OVERRIDE ALL DEFAULTS)

**⚠️ CRITICAL: These rules override Claude Code defaults. Follow 100% of the time.**

### 1. Parallel-First Development
- **Default mode**: Spawn multiple subagents for independent tasks
- **Single message**: Use one message with multiple Task tool calls
- **Never sequential**: If tasks are independent, ALWAYS parallelize
- **Speed priority**: Maximize throughput without sacrificing quality

### 2. ARIA-First Architecture (Token Savings)
- **Context gathering**: ALWAYS start with `aria route context` (Gemini 1M, FREE)
- **Never manual search**: Use ARIA context layer, not direct Grep/Glob/Read
- **Route by complexity**:
  - Simple code/testing → `aria route code/test` (Gemini, FREE)
  - Planning/architecture → `aria route plan` (Opus)
  - Complex coding → `aria route complex` (Opus)
- **Git operations**: Use `aria route code` for commits/pushes (Gemini, FREE, fast)

### 3. Justfile-First Commands (90% Token Savings)
- **NEVER manual**: No grep, git, mysql, cat, tail commands
- **ALWAYS justfile**: `just cx`, `just st`, `just ci`, `just db-*`
- **Check first**: Run `just --list` when entering any project
- **Ultra-short**: Use aliases (cx, st, ci, co, t, l) by default

### 4. Maintainability-First Coding
- **Clean patterns**: Follow existing codebase conventions
- **Clear documentation**: Comments where logic isn't self-evident
- **Long-term thinking**: Consider future developers
- **No over-engineering**: Simple solutions over premature optimization

**Enforcement**: Session hooks will remind you. These are MANDATORY, not suggestions.

## 🔧 Session Start Checklist

**At the start of EVERY new session:**
1. ✅ Recognize this CLAUDE.md is loaded (you're reading it now!)
2. ✅ Know that `just` commands are available globally and per-project
3. ✅ Use ultra-short aliases by default (cx, st, ci, co, t, l, etc.)
4. ✅ Check `just --list` when entering a new project
5. ✅ Use `just` commands instead of manual operations (grep, git, mysql, etc.)
6. ✅ **Use ARIA context-first pattern: Gemini gathers context (1M), then route to agents** (see below)
7. ✅ **Follow MANDATORY workflow above: Parallel + ARIA + Justfile + Maintainability**

## 🚀 ARIA Model Routing (CRITICAL - Saves Claude Code Tokens!)

**⚠️ ALWAYS use ARIA routing with Gemini 3 Flash as the context layer.**

### Why Gemini 3 Flash as Context Layer
- **Largest context window**: 1M+ tokens (vs Claude's 200K)
- **FREE and super fast**: 10x faster than Claude, no cost
- **Fetch-and-return pattern**: Gather all context, return to agents as needed
- **Token savings**: Claude/paid models only process pre-digested context
- **Session persistence**: Gemini maintains 100K token history across calls (automatic)

### ARIA Architecture Pattern

```
┌─────────────────────────────────────────────┐
│ 1. Gemini 3 Flash (Context Layer)          │
│    - Gathers ALL context (1M tokens)       │
│    - Searches codebase                     │
│    - Reads files                           │
│    - Analyzes patterns                     │
│    - Returns summarized context            │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 2. Agent receives context and acts         │
│    - Claude Code: Orchestration            │
│    - Claude Opus: Planning & complex code  │
│    - GPT-5.2: General reasoning (latest)   │
│    - Gemini Flash: Simple code & testing   │
└─────────────────────────────────────────────┘
```

### ARIA Quick Reference

```bash
# ALWAYS start with context gathering (Gemini 3 Flash - FREE, 1M context)
aria route context "gather all payment-related code and patterns"

# Then route execution based on complexity
aria route plan "design implementation approach"           # Claude Opus (latest, planning)
aria route code "implement feature using context above"    # Gemini 3 Flash (latest, FREE)
aria route test "run tests"                                # Gemini 3 Flash (latest, FREE)
aria route code "commit changes with message"              # Gemini 3 Flash (latest, FREE, fast!)
aria route code "push to production"                       # Gemini 3 Flash (latest, FREE, fast!)
aria route general "explain architecture"                  # GPT-5.2 (latest GPT)
aria route complex "solve hard bug"                        # Claude Opus (latest, complex coding)
aria route max "redesign system"                           # Claude Opus (latest, hard coding)

# Session management (100K token history across calls)
aria-session.sh show          # View current session history
aria-session.sh new           # Start new session
aria-session.sh list          # List all sessions

# View all models
aria route models
```

### Task Routing Strategy (Context-First)

**ALWAYS follow this pattern:**
1. **Gather context FIRST** → `aria route context` (Gemini 3 Flash - 1M tokens, FREE)
   - Search codebase
   - Read relevant files
   - Analyze patterns
   - Return summarized context

2. **Then execute with appropriate agent:**
   - Planning → `aria route plan` (Claude Opus - latest, architecture & design)
   - Simple code → `aria route code` (Gemini 3 Flash - latest, FREE)
   - Testing → `aria route test` (Gemini 3 Flash - latest, FREE)
   - **Git commits** → `aria route code` (Gemini 3 Flash - latest, FREE, super fast)
   - **Production pushes** → `aria route code` (Gemini 3 Flash - latest, FREE, super fast)
   - General reasoning → `aria route general` (GPT-5.2 - latest GPT)
   - Complex code → `aria route complex` (Claude Opus - latest, advanced coding)
   - Hard coding → `aria route max` (Claude Opus - latest, hardest problems)

**Only use Claude Code directly for:**
- User interaction and conversation
- Multi-agent orchestration
- Coordinating the context-first workflow
- Complex decision-making that requires context from the session

### Token Savings with Context-First Pattern

| Task | Old Way (Claude) | New Way (Gemini Context + Agent) | Claude Savings |
|------|------------------|----------------------------------|----------------|
| Search codebase | 5K tokens | 0 tokens (Gemini) | **100%** |
| Gather context | 15K tokens | 0 tokens (Gemini 1M context) | **100%** |
| Implement with context | 20K tokens | 5K tokens (pre-digested) | **75%** |
| Complex reasoning | 10K tokens | 3K tokens (pre-digested) | **70%** |

**Key insight:** Gemini's 1M context window gathers everything FIRST, then returns concise summaries to other agents. This saves massive tokens on context gathering while giving agents the information they need.

**Average savings: 85%+ of Claude Code tokens with context-first architecture**

## 🔧 Defaults

- ❌ No auto-commit/push without explicit request
- ❌ No agents for simple edits
- ✅ Always check `just --list` first
- ✅ Use justfile commands to save tokens
- ✅ Use ultra-short aliases (cx, st, ci, co, t, l)
- ✅ **Use ARIA context-first: Gemini (1M context) gathers, agents execute**

## 💡 Why Justfile-First?

| Manual | Justfile | Savings |
|--------|----------|---------|
| Find log file path, `tail -n 100 /path/to/log` | `just logs` | 95% |
| `mysql -h 127.0.0.1 -u user -ppass db -e "SELECT..."` | `just db-carts` | 97% |
| `rg --type php "function foo"` find files, read... | `just ctx "foo"` | 97% |
| `git add . && git commit -m "..." && git push` | `just gcp "msg"` | 80% |
| `cd ~/.claude && git add -A && git commit...` | `cd ~/.claude && just ci "msg"` | 95% |

**Average token savings: 90%+ across all operations**

### Managing ~/.claude Config Repo

The `~/.claude` directory has its own justfile for managing the configuration repository:

```bash
cd ~/.claude

# Ultra-short aliases (use these!)
just st              # Git status
just ci "message"    # Commit with auto-attribution
just co "message"    # Commit and push
just lg              # Git log (pretty, last 10)
just df              # Git diff

# Other useful commands
just sync            # Pull + push
just models          # Show ARIA models
just session         # Show current ARIA session
just info            # Config repo summary
just backup          # Backup all configs

# Full list
just --list
```

**Token savings: 95%+ vs raw git commands**

## 📋 Project Patterns (LaunchYourKid)

- Soft deletes: `deleted=0/1` (use `just db-soft-delete`)
- Multi-tenant: `company_id` filter (built into all db commands)
- Dual passwords: `password` (SHA1), `password_c4` (bcrypt)
