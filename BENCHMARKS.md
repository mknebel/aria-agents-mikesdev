# Claude Code Optimization Benchmarks

**Date:** 2025-12-03
**Baseline:** Generic Claude Code (no optimizations)
**Optimized:** Variable-passing + purpose-based routing + caching

---

## Token Usage

| Operation | Before | After | Savings |
|-----------|--------|-------|---------|
| Search results inline | 2-5KB | 50B ref | 98% |
| File context inline | 10KB | 50B ref | 99.5% |
| LLM chain (3 steps) | 30KB | 150B refs | 99.5% |
| CLAUDE.md per load | 2,657 tokens | 515 tokens | 81% |
| Typical session | ~50K tokens | ~5K tokens | 90% |

## Response Speed

| Operation | Before | After | Speedup |
|-----------|--------|-------|---------|
| Code search (semantic) | 3-10s | 0.8s (ripgrep) | 4-12× |
| LLM response (large ctx) | 5-15s | 2-8s | 2× |
| Cached LLM response | N/A | 0.1s | 50-150× |
| Session start (cold) | 5-10s | 1-2s (warm) | 5× |
| Hook execution | ~1000ms | ~22ms | 45× |

## Cost Estimates (Monthly, Active Use)

| Metric | Before | After | Savings |
|--------|--------|-------|---------|
| Tokens per session | ~50K | ~5K | 90% |
| Sessions per day | 10 | 10 | - |
| Monthly tokens | 15M | 1.5M | 13.5M |
| Estimated cost | ~$45 | ~$4.50 | ~$40/mo |
| Annual savings | - | - | ~$480/yr |

## LLM Provider Comparison

### Speed (typical response)
| Provider | Simple Query | Code Task | Review Task |
|----------|-------------|-----------|-------------|
| fast (DeepSeek) | 1-2s | 3-5s | 2-4s |
| codex (OpenAI) | 2-4s | 4-8s | 3-6s |
| gemini (Google) | 2-3s | 4-7s | 3-5s |
| qa preset | 2-3s | N/A | 2-4s |

### Quality (subjective 1-10)
| Provider | Code Gen | Code Review | Explanations |
|----------|----------|-------------|--------------|
| fast (DeepSeek) | 6 | 5 | 7 |
| codex (OpenAI) | 9 | 7 | 8 |
| gemini (Google) | 8 | 7 | 8 |
| qa preset | 5 | 8 | 6 |

### Cost per 1K tokens
| Provider | Input | Output |
|----------|-------|--------|
| fast (DeepSeek) | $0.0001 | $0.0002 |
| codex (OpenAI) | $0.003 | $0.015 |
| gemini (Google) | FREE | FREE |
| Claude (direct) | $0.003 | $0.015 |

## Purpose-Based Routing Results

| Intent Pattern | Routes To | Rationale |
|----------------|-----------|-----------|
| implement/write/create/fix/refactor | codex | Best code generation |
| review/check/analyze/validate/test | qa | Optimized for analysis |
| explain/what is/summarize/describe | fast | Speed priority |
| browser/click/navigate/screenshot | browser | UI automation |
| Default (generic) | codex | Most common use case |

## Optimization Components

### 1. Variable Passing Protocol
- Store: `/tmp/claude_vars/`
- Reference: `@var:name` (50 bytes vs 10KB inline)
- Auto-saves: `$ctx_last`, `$llm_response_last`, `$grep_last`, `$read_last`

### 2. Hybrid Context Search (ctx.sh)
- Fast path: ripgrep (~0.8s)
- Fallback: semantic indexed search (~5s)
- Auto-caches to `$ctx_last`

### 3. Response Caching (llm.sh)
- Hash: provider + prompt + var content hashes
- TTL: 1 hour
- Hit rate: ~30% (repeated queries)

### 4. Session Warmup (shortcuts.sh)
- Pre-indexes common projects in background
- Runs on shell init via BASH_ENV
- Skips if ran <5 min ago

### 5. Optimized Hooks
- Replaced grep with bash regex
- Reduced timeouts: 30s → 2s
- Execution time: ~22ms

## Test Commands

```bash
# Test intent detection
for p in "implement auth" "review code" "explain this"; do
  echo "$p → $(~/.claude/scripts/llm.sh auto "$p" 2>&1 | grep Intent)"
done

# Test ctx speed
time ctx "payment" -f  # fast (ripgrep)
time ctx "payment" -s  # semantic (indexed)

# Test caching
time llm fast "hello"  # first call
time llm fast "hello"  # cached

# Check variable freshness
var list
var fresh ctx_last 5
```

---

## Changelog

- **2025-12-03**: Initial benchmarks, purpose-based routing, variable protocol
