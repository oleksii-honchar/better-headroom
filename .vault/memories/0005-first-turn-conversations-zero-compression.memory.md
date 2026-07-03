---
type: memory
title: "First-turn conversations produce zero compression — user-only messages are never compressed"
createdAt: "2026-06-30T14:00:00Z"
updatedAt: "2026-06-30T14:00:00Z"
tags: [compression, first-turn, user-messages, zero-compression]
see_also:
  - "concepts/0001-content-router-skips-user-messages.concept.md"
deprecated:
  date: null
  reason: null
  superseded_by: null
---

# Memory: First-turn conversations produce zero compression

## Fact

When a conversation contains only user messages (first turn, no assistant response yet), Headroom compression returns the original messages unchanged — zero tokens saved, no `x-headroom-*` response headers.

## Context

**First-turn example:**
```python
messages = [{"role": "user", "content": "What is the capital of France?"}]
result = compress(messages, model="gpt-4")
# tokens_before == tokens_after
# tokens_saved == 0
# NO x-headroom-* headers in response
```

**Why:** Headroom's content router skips user messages by design (see Concept-0001). If all messages are user messages, there's nothing to compress.

**Multi-turn = compression works:**
```python
messages = [
    {"role": "system", "content": "[long system prompt]"},
    {"role": "user", "content": "Write a Python script"},
    {"role": "assistant", "content": "[detailed implementation]"},
    {"role": "user", "content": "Can you optimize it?"}
]
# System: compressed | Assistant: compressed | User messages: unchanged
# x-headroom-compressed: true
```

**Production evidence:** 99.3% compression ratio (6268 → 44 tokens) on multi-turn assistant log messages, verified on puma.lan.

## Impact

- First-turn conversations will NOT save any tokens — this is by design
- Compression is most effective in multi-turn agent conversations (assistant/tool messages are verbose)
- Dashboard compression ratios will be lower if there are many first-turn conversations
- This is not a bug — user message compression would risk losing semantic intent
