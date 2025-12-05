# RULES - MANDATORY FAST MODE ENFORCEMENT

## TASK TRACKING (MANDATORY - NEVER SKIP)

**On ANY multi-part request:**
1. STOP - Use TodoWrite BEFORE starting work
2. Each user task = separate todo item (number them)
3. Read back the list: "I see N tasks: 1)... 2)... 3)..."
4. Work through sequentially, marking in_progress → completed
5. NEVER mark complete until verified/tested

**Mid-task additions:**
- If user adds task while working: IMMEDIATELY add to todos
- Acknowledge: "Added to list: [task]"
- Continue current work, then handle new item

**Completion confirmation (ALWAYS):**
```
✅ 1. [task] - done
✅ 2. [task] - done
✅ 3. [task] - done
❌ Skipped: none (or explain why)
```

**If unsure about a task:** ASK, don't skip.

---

## CRITICAL: CHECK MODE FIRST
```bash
~/.claude/scripts/fast-mode-check.sh start
```

## ON EVERY TASK: Re-read Context
1. Re-read project CLAUDE.md (pitfalls, patterns)
2. Use `/lookup ClassName` before Grep (uses project index)
3. Use `ctx "query"` for semantic search

## FAST MODE = ALWAYS ON (Default)

**CLAUDE TOKEN BUDGET PER TASK:**
- Orchestration: ~200 tokens (route to tools)
- Final review: ~500 tokens (verify external output)
- UI/UX fixes: ~500 tokens (CSS/styling only)
- Apply edits: ~300 tokens (Edit tool)
- **TOTAL TARGET: ~1,500 tokens** (vs ~15,000 Claude-only)

## MANDATORY WORKFLOW

```
1. SEARCH → ctx "query" OR /lookup (NEVER Grep first)
2. GENERATE → llm codex "@var:ctx_last" (NEVER Claude generation)
3. REVIEW → llm gemini "check @var:codex_last" (cross-verify)
4. APPLY → Claude Edit tool (minimal review + precise changes)
```

## VIOLATIONS (Never Do These in Fast Mode)
- Writing >50 lines of code directly (use codex)
- Analyzing files without ctx first (use gemini)
- Searching without /lookup or ctx first
- Inlining large content (use @var: references)

## RESPONSE PREFIX: `⚡ Fast |` or `🔄 Aria |`

---

## FAST MODE - OPTIMIZED WORKFLOW

### Priority: FREE Models First
```yaml
codex:  FREE (your OpenAI subscription) - code generation
gemini: FREE (your Google subscription) - analysis/reasoning
fast:   ~$0.001 - quick checks only
qa:     ~$0.002 - reviews (if needed)
apply:  ~$0.001 - Relace code merging
```

### 1. SEARCH PRIORITY (Index First)
```yaml
ALWAYS:
  1. /lookup ClassName        # Instant from index (FREE)
  2. ctx "semantic query"     # Local search (FREE)
  3. Grep (ONLY if above fail)
```

### 2. VARIABLE PROTOCOL
```yaml
MANDATORY:
  ctx "query"                    # → $ctx_last
  llm auto "task @var:ctx_last"  # Routes to FREE model
  var summary name               # Read summary first (500 chars)
  var get name                   # Full content ONLY for edits

NEVER inline data - always use @var: references
```

### 3. GENERATION WORKFLOW (Adaptive)

**SIMPLE tasks** (single file, small changes):
```bash
llm codex "implement: $TASK based on @var:ctx_last"
# Claude reviews + applies
```

**MEDIUM tasks** (multi-step, new features):
```bash
# Parallel generation (both FREE)
llm codex "implement: $TASK" &
llm gemini "implement: $TASK" &
wait

# Cross-verify (FREE)
llm gemini "review @var:codex_last for bugs"
llm codex "review @var:gemini_last for bugs"

# Claude picks best + applies
```

**COMPLEX tasks** (auth, payment, security):
```bash
~/.claude/scripts/parallel-pipeline.sh "$TASK" ctx_last
# Full pipeline: parallel reasoning → generation → verification
# Claude reviews final result + applies
```

### 4. CLAUDE'S ROLE (Strategic)
```yaml
Claude does:
  - Final review (~500 tokens) - catches what others miss
  - UI/UX polish (~500 tokens) - best design quality
  - Apply edits (~300 tokens) - precise changes
  - Orchestration (~200 tokens) - minimal overhead

Claude does NOT:
  - Heavy code generation (use codex)
  - Bulk analysis (use gemini)
  - Quick checks (use fast preset)
```

### 5. UI/UX CARVE-OUT (Claude Direct)
```yaml
Claude handles directly (NO external):
  - CSS/styling decisions
  - Layout and responsive design
  - Accessibility (ARIA, focus)
  - Visual polish and animations
  - Fixing UI bugs from external code
  - Tailwind/CSS frameworks

Reason: External LLMs produce generic/broken UI
```

---

## TOOLS REFERENCE

```yaml
# FREE (your subscriptions)
codex:    llm codex "task"              # GPT-4+ code generation
gemini:   llm gemini "task"             # Analysis, reasoning

# Cheap (OpenRouter)
fast:     llm fast "quick question"     # ~$0.001, super-fast
qa:       llm qa "review code"          # ~$0.002, thorough
tools:    llm tools "implement"         # ~$0.001, code gen backup
apply:    llm apply "merge code"        # ~$0.001, Relace Apply

# Local (FREE)
search:   ctx "query"                   # → $ctx_last
lookup:   /lookup ClassName             # Instant from index

# Pipeline (FREE)
pipeline: parallel-pipeline.sh "task"   # Full parallel workflow
```

---

## LLM ROUTING (auto mode)

```yaml
llm auto "prompt"   # Smart routing:

  code/implement/write → codex (FREE)
  review/analyze → gemini (FREE)
  quick/explain → gemini or fast
  apply/merge → apply (Relace)
```

---

## COMMANDS

```
/smart "task"      - Adaptive quality workflow
/implement "spec"  - Spec → codex → review → apply
/fast "task"       - Direct fast mode
/lookup Name       - Instant index lookup
/mode fast|aria    - Switch routing mode
/cost-report       - Token usage summary
```

---

## TOKEN SAVINGS SUMMARY

| Task Type | Claude-Only | Fast Mode | Savings |
|-----------|-------------|-----------|---------|
| Simple | ~8,000 | ~800 | **90%** |
| Medium | ~12,000 | ~1,200 | **90%** |
| Complex | ~15,000 | ~1,500 | **90%** |

**Quality**: Equal or better (multiple perspectives + Claude final review)

---

## QUALITY SAFEGUARDS

```yaml
Before applying external code:
  1. Review for correctness
  2. Check for security issues
  3. Verify UI/styling (fix directly)
  4. Run relevant tests

Cross-verification catches:
  - Bugs that one model misses
  - Security issues
  - Edge cases
  - Style inconsistencies
```
