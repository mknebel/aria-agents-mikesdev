# Models Reference

## Model Stack (Quality-Ordered)

| Tier | Model | Access | Best For | Speed |
|------|-------|--------|----------|-------|
| **S** | Claude | Native | Planning, architecture, security, UI/UX | - |
| **S** | Codex CLI | `codex` | Complex implementation, autonomous | Fast |
| **A** | Gemini | `gemini` | Context extraction (1M tokens) | Fast |
| **A** | MiniMax M2 | OpenRouter | Logic-aware mods, tests, debugging | 119 tps |
| **A** | Grok Code Fast | OpenRouter | Rapid iteration, quick code | 160 tps |
| **A** | Morph V3 Fast | OpenRouter | Exact replacements (96% accuracy) | 10,500 tps |
| **B** | DeepSeek V3.2 | OpenRouter | Bulk generation fallback | ~80 tps |
| **C** | Qwen3 Coder | OpenRouter | Fallback only | ~50 tps |

## Quality Benchmarks

| Model | SWE-bench | Terminal-Bench | Notes |
|-------|-----------|----------------|-------|
| Claude | **80.9%** | - | Best reasoning |
| Codex | 74.9% | 43.8% | Best autonomous |
| MiniMax M2 | 69.4% | **46.3%** | Best agentic |
| Grok Fast | 70.8% | - | Fastest quality |
| DeepSeek V3.2 | 67.8% | 37.7% | Bulk work |

## Cost Reference

| Model | Input | Output | Notes |
|-------|-------|--------|-------|
| Claude | $5/M | $25/M | Use strategically |
| Codex | FREE | FREE | Your OpenAI sub |
| Gemini | FREE | FREE | Your Google sub |
| MiniMax M2 | $0.26/M | $1.02/M | Best value |
| Grok Fast | $0.20/M | $1.50/M | Speed + quality |
| Morph V3 | $0.80/M | $1.20/M | Mechanical edits |
| DeepSeek | $0.22/M | $0.33/M | Cheapest |
| Qwen3 | FREE | FREE | Fallback |

## Routing Rules

| Task Type | Model | Why |
|-----------|-------|-----|
| UX Strategy | Claude | Best design sense |
| Frontend Design | frontend-design plugin | Avoids generic AI |
| Security/Auth | Claude → Codex → Claude | Triple validation |
| New Features | Codex | Autonomous implementation |
| Logic-Aware Mods | MiniMax M2 | Best agentic quality |
| Exact Replacements | Morph V3 | 10,500 tps |
| Quick Iterations | Grok Fast | Speed + quality |
| Test Generation | MiniMax M2 | Better coverage |
| Bulk/Fallback | DeepSeek/Qwen3 | Cost only |

## Morph vs MiniMax Decision

```
Do you know EXACTLY what to replace?
├── YES → Morph V3 (10,500 tps)
│   • Rename function/variable
│   • Update import paths
│   • Replace deprecated calls
│   • Swap library calls
│
└── NO (needs understanding) → MiniMax M2
    • Add error handling
    • Refactor patterns
    • Fix bugs
    • Extend functionality
```
