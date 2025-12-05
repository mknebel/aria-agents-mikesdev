---
description: New design - 3 LLM drafts → Claude Opus final refinement
argument-hint: <design description>
---

# Parallel Design Pipeline

**Claude Opus is the BEST, LAST LINE of UI/UX improvement.**

```bash
~/.claude/scripts/design-pipeline.sh "$ARGUMENTS"
```

## Flow

```
┌───────────────────────────────────────────────────────┐
│           PHASE 1: PARALLEL DRAFTS                    │
├───────────────┬───────────────┬───────────────────────┤
│ Gemini        │ ChatGPT       │ Codex                 │
│ (latest)      │ gpt-5.1       │ codex-max             │
│ FREE          │ Pro sub       │ Pro sub               │
└───────┬───────┴───────┬───────┴───────────┬───────────┘
        └───────────────┴───────────────────┘
                        ↓
┌───────────────────────────────────────────────────────┐
│     PHASE 2: CLAUDE OPUS - FINAL REFINEMENT           │
│  • Reviews all 3 drafts as INPUT                      │
│  • Extracts best elements from each                   │
│  • Applies superior UI/UX expertise                   │
│  • Creates FINAL, POLISHED design                     │
│  • Result is BETTER than any single draft             │
└───────────────────────────────────────────────────────┘
                        ↓
                 quality-gate.sh
```

## How It Works

1. **Gemini** + **ChatGPT** + **Codex** generate 3 drafts in parallel
2. **Claude Opus** receives ALL drafts as input material
3. Claude identifies best elements from each draft
4. **Claude creates the FINAL refined design** (not just picking one)
5. Implement Claude's superior design
6. Validate with quality-gate.sh

## Claude's Role

**Claude Opus is NOT just another option - it is the FINAL ARBITER:**
- Reviews drafts for inspiration and best practices
- Applies expert UI/UX judgment
- Creates a design BETTER than any individual draft
- Ensures accessibility, responsiveness, code quality
- Produces production-ready implementation

## Variables Created

| Variable | Contents |
|----------|----------|
| `$gemini_design` | Gemini draft (FREE) |
| `$chatgpt_design` | ChatGPT gpt-5.1 draft (fast) |
| `$codex_design` | Codex codex-max draft (agentic) |
| `$design_comparison` | All drafts for Claude to refine |
