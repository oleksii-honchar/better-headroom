---
type: memory
title: "Tiktoken encoding mismatch — gpt-5.x models produce zero compression tokens"
createdAt: "2026-06-30T14:00:00Z"
updatedAt: "2026-06-30T14:00:00Z"
tags: [tiktoken, gpt-5, gotcha, encoding, zero-compression, metrics]
see_also:
  - "adrs/0001-asgi-middleware-only-reliable-litellm-integration.adr.md"
deprecated:
  date: null
  reason: null
  superseded_by: null
---

# Memory: Tiktoken encoding mismatch — gpt-5.x produce zero tokens

## Fact

Tiktoken does NOT recognize `gpt-5.5`, `gpt-5.4-mini`, `codex-auto-review` — it falls back to `cl100k_base` encoding. The pipeline runs but records ZERO input tokens and ZERO duration for these models.

## Context

**Verification:**
```python
import tiktoken
for model in ['gpt-5.5', 'gpt-5.4', 'gpt-5.4-mini', 'codex-auto-review', 'gpt-4o']:
    try:
        enc = tiktoken.encoding_for_model(model)
    except KeyError:
        print(f'{model}: NOT recognized')
# gpt-5.5: NOT recognized
# gpt-5.4: NOT recognized
# gpt-5.4-mini: NOT recognized
# codex-auto-review: NOT recognized
# gpt-4o: encoding=o200k_base (recognized)
```

**Evidence from ClickHouse OTEL data:**

| Model | Duration Count | Duration Sum | Max Duration | Runs |
|-------|---------------|-------------|--------------|------|
| gpt-5.5 | 2,269,718 | 0 | 0 | 297 |
| gpt-5.4-mini | 95,878 | 0 | 0 | 18 |
| codex-auto-review | 74,553 | 0 | 0 | 12 |

gpt-5.5: `runs=297, tokens.input.max=0, tokens.saved.max=0, failures=0`

**Root cause mechanism:**
1. `tiktoken.encoding_for_model("gpt-5.5")` raises `KeyError`
2. Falls back to `cl100k_base` encoding (gpt-3.5-turbo)
3. Headroom's `_count_tokens` returns 0 for unrecognized models
4. Pipeline runs 297 times but records 0 input tokens each time
5. Duration is exactly 0 — pipeline returns immediately with no work

**Two metrics recording paths can conflict:**
- Pipeline's `record_pipeline_run` (in `transforms/pipeline.py:498`) — uses pipeline's tokenizer
- Adapter's `record_pipeline_run` (in `litellm_callback.py`) — uses adapter's own `_count_tokens`
- Adapter overwrites pipeline metrics — adapter's count returns 0

## Impact

- Any gpt-5.x model will show "zero compression" in dashboards despite pipeline running
- OTEL metrics are completely wrong for these models (0 tokens, 0 duration, 0 saved)
- **Mitigation:** Claw Compactor avoids this entirely — uses own heuristic token estimation with optional tiktoken fallback
