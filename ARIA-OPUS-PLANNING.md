# ARIA with Claude Opus Planning

## ✅ Complete Architecture (Updated 2025-12-20)

```
USER Request
    ↓
┌─────────────────────────────────────────────┐
│ SONNET (Claude Code) - Orchestrator         │
│ - Receives user request                     │
│ - Delegates to ARIA for execution           │
│ - Reviews results                           │
│ - Interacts with user                       │
└─────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────┐
│ Step 1: CONTEXT (Gemini 3 Flash - FREE)    │
│ aria route context "gather cart code"       │
│ - 1M token context window                  │
│ - Searches using justfiles                 │
│ - Returns summarized context               │
└─────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────┐
│ Step 2: PLANNING (Claude Opus)              │
│ aria route plan "design validation system"  │
│ - Receives context from Step 1             │
│ - Creates implementation plan              │
│ - Returns plan to Sonnet                   │
└─────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────┐
│ SONNET reviews plan, delegates execution    │
└─────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────┐
│ Step 3: EXECUTION (Gemini 3 Flash - FREE)  │
│ aria route code "implement based on plan"   │
│ - Receives plan from Step 2                │
│ - Implements using justfiles               │
│ - Returns results                          │
└─────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────┐
│ Step 4: TESTING (Gemini 3 Flash - FREE)    │
│ aria route test "verify implementation"     │
│ - Runs tests using justfiles               │
│ - Returns test results                     │
└─────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────┐
│ SONNET reviews, presents to USER            │
└─────────────────────────────────────────────┘
```

---

## 🚀 Available Models

```bash
aria models
```

| Type | Model | CLI | Best For | Cost |
|------|-------|-----|----------|------|
| `context` | gemini-3-flash | gemini | Context gathering (1M tokens) | FREE |
| `plan` | claude-opus | claude | Architecture & planning | Claude sub |
| `code` | gemini-3-flash | gemini | Implementation | FREE |
| `test` | gemini-3-flash | gemini | Testing | FREE |
| `general` | gpt-5.1 | codex | General reasoning | ChatGPT Pro |
| `complex` | gpt-5.1-codex-max | codex | Hard code problems | ChatGPT Pro |
| `max` | gpt-5.2 | codex | Hardest problems | ChatGPT Pro |

---

## 💡 Justfile-First Context (Automatic)

**ARIA now automatically prepends justfile instructions for:**
- `context` routes
- `plan` routes
- `code` routes
- `test` routes

Every prompt gets:
```
JUSTFILE-FIRST + ARIA-FIRST: Max efficiency and token savings
- just cx "query" (not grep/find/ctx) - AI-powered code search
- just s "pattern" (not rg/search) - Pattern search
- just t (not grep TODO) - Find all TODOs
- just st (not git status) - Git status
- just ci "msg" (not git commit) - Commit with auto-attribution
- just co "msg" (not git commit + push) - Commit and push
- just db-* (not mysql) - Database commands
- just l (not tail logs) - View logs
- just --list - See all available commands

Working directory: /current/working/directory

Task: [your actual prompt]
```

**To disable for a single call:**
```bash
ARIA_NO_JUSTFILE=1 aria route code "your prompt"
```

---

## 📋 Complete Example Workflow

```bash
# Step 1: Gather context (Gemini - FREE)
aria route context "find all cart validation code and related patterns"
# → Gemini searches using 'just cx cart', reads files, returns summary

# Step 2: Plan implementation (Opus)
aria route plan "design a cart validation system to prevent cross-company items"
# → Opus receives context, creates detailed implementation plan

# Step 3: Implement (Gemini - FREE)
aria route code "implement the validation system from the plan"
# → Gemini follows plan, uses 'just' commands, implements code

# Step 4: Test (Gemini - FREE)
aria route test "verify cart validation prevents cross-company items"
# → Gemini runs tests using 'just test', verifies implementation

# Optional: Complex debugging (ChatGPT Codex Max)
aria route complex "debug why validation fails in edge case X"
# → Escalates to more powerful model for hard problems
```

---

## 🎯 Token Economics

| Stage | Without ARIA | With ARIA | Savings |
|-------|--------------|-----------|---------|
| **Context Gathering** | 15K Sonnet tokens | 0 tokens (Gemini FREE) | **100%** |
| **Planning** | 10K Sonnet tokens | 10K Opus tokens | 0% (but better quality) |
| **Sonnet Orchestration** | 5K Sonnet tokens | 5K Sonnet tokens | 0% |
| **Implementation** | 20K Sonnet tokens | 0 tokens (Gemini FREE) | **100%** |
| **Testing** | 10K Sonnet tokens | 0 tokens (Gemini FREE) | **100%** |
| **TOTAL** | **60K tokens** | **15K tokens** | **75%** |

**Additional savings from justfile-first:**
- Using justfiles vs manual commands: **90%+ token reduction**

**Combined savings: ~90%+ of original token usage!**

---

## 🔧 Session Persistence

Context persists across all ARIA calls:

```bash
# Turn 1
aria route context "find payment code"

# Turn 2 - Opus remembers payment code from Turn 1!
aria route plan "design new payment validation"

# Turn 3 - Gemini remembers both context AND plan!
aria route code "implement the payment validation"
```

Sessions maintain up to 100K tokens of conversation history.

**Manage sessions:**
```bash
aria session              # Show current session
aria session show         # View full history
aria session new          # Start fresh
aria session clear        # Clear history
```

---

## 🎭 Role Clarity

### **Sonnet (Claude Code)** = Orchestrator
- Understands user requirements
- Breaks down tasks
- Delegates to ARIA
- Reviews results
- Makes final decisions
- Interacts with user

### **Opus (via ARIA)** = Architect & Planner
- Receives context from Gemini
- Designs implementation strategy
- Creates detailed plans
- Returns plan to Sonnet

### **Gemini (via ARIA)** = Worker & Tester
- Gathers context (1M tokens, FREE)
- Implements code (following Opus's plan)
- Runs tests
- Uses justfile commands
- Returns results

### **ChatGPT (via ARIA)** = Power Solver
- Complex reasoning (GPT-5.1)
- Hard code problems (Codex Max)
- Maximum capability tasks (GPT-5.2)

---

## ⚙️ Configuration

**Enable/disable features:**
```bash
export ARIA_SESSION_ENABLED=1     # Session persistence (default: 1)
export ARIA_NO_JUSTFILE=1         # Disable justfile context (default: 0)
```

**CLI tools used:**
- `gemini` - Google Gemini CLI (FREE)
- `claude` - Claude CLI (Sonnet/Opus/Haiku)
- `codex` - OpenAI Codex CLI (ChatGPT models)

All three CLIs are installed and configured:
- `/home/mike/.npm-global/bin/gemini`
- `/home/mike/.npm-global/bin/claude`
- `/home/mike/.npm-global/bin/codex`

---

## 📝 Best Practices

1. **Always start with context** - Gemini's 1M window is FREE
2. **Use Opus for planning** - Better architecture than implementing blind
3. **Let Gemini execute** - Fast, FREE, good enough for 90% of tasks
4. **Escalate when needed** - Use ChatGPT models for genuinely hard problems
5. **Review Opus's plans** - Sonnet should validate before delegating execution
6. **Trust justfile automation** - 90%+ token savings vs manual commands

---

## 🆘 Troubleshooting

**"claude CLI not found"**
- Run: `which claude`
- Should be: `/home/mike/.npm-global/bin/claude`

**"Opus planning seems off"**
- Check if context was provided first
- Opus plans better with context from Gemini

**"Gemini using grep instead of justfiles"**
- Justfile context should auto-prepend
- Check: `ARIA_NO_JUSTFILE` is not set to 1
- Verify justfile exists in working directory

**"Session not persisting"**
- Check: `ARIA_SESSION_ENABLED=1`
- View: `aria session show`

---

**Last Updated:** 2025-12-20
**Architecture:** Context (Gemini) → Planning (Opus) → Orchestration (Sonnet) → Execution (Gemini/ChatGPT)
**Key Innovation:** Automatic justfile-first context for 90%+ token savings
