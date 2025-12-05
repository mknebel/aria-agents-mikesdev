---
description: New design with 3 LLMs in parallel (Opus + Gemini + Codex)
argument-hint: <design description>
---

# Parallel Design Pipeline

Run 3-way parallel design planning:

```bash
~/.claude/scripts/design-pipeline.sh "$ARGUMENTS"
```

## Flow

```
┌─────────────────────────────────────────────────────┐
│              PARALLEL (simultaneously)              │
├─────────────────┬─────────────────┬─────────────────┤
│ Gemini          │ Codex           │ Claude Opus 4.5 │
│ (latest)        │ (latest)        │ (aria-ui-ux)    │
│ FREE            │ $               │ $$              │
└────────┬────────┴────────┬────────┴────────┬────────┘
         └────────────────┬┴─────────────────┘
                          ↓
              Claude compares all 3
                          ↓
              Pick best / combine
                          ↓
                   quality-gate.sh
```

## How It Works

1. **Gemini Pro** + **Codex Max** run in parallel (script)
2. **Claude Opus** (aria-ui-ux) runs after script completes
3. **Claude** compares all 3 designs
4. Pick winner or combine best elements
5. Implement and validate

## After Pipeline

Claude should:
1. Review `$gemini_design` and `$codex_design`
2. Run `Task(aria-ui-ux, opus)` for 3rd perspective
3. Compare all 3 outputs
4. Implement best design
5. Run `quality-gate.sh`

## Variables Created

| Variable | Contents |
|----------|----------|
| `$gemini_design` | Gemini (latest) design |
| `$codex_design` | Codex (latest) design |
| `$design_comparison` | Combined comparison |
