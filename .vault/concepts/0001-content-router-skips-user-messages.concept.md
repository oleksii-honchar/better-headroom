---
type: concept
title: "Content Router — Skips User Messages, Compresses All Else"
createdAt: "2026-06-30T14:00:00Z"
updatedAt: "2026-06-30T14:00:00Z"
tags: [content-router, compression, user-messages, pipeline]
see_also:
  - "concepts/0002-compression-pipeline-per-content-type.concept.md"
  - "memories/0005-first-turn-conversations-zero-compression.memory.md"
deprecated:
  date: null
  reason: null
  superseded_by: null
---

# Concept: Content Router — Skips User Messages, Compresses All Else

## What

Headroom's content router selectively compresses messages based on role. **User messages are never compressed** — only system, assistant, and tool messages pass through the compression pipeline.

## Why

User messages contain the original intent/question. Compressing user input risks losing critical semantic information that the LLM needs to respond correctly.

## Key Details

**Compression scope by role:**

| Role | Compressed | Rationale |
|------|-----------|-----------|
| `system` | ✅ Yes | System prompts are long context — safe to compress |
| `assistant` | ✅ Yes | Assistant responses are verbose — safe to compress |
| `tool` | ✅ Yes | Tool outputs (JSON, search results) compress well |
| `user` | ❌ No | Original intent/question — must preserve semantics |

**First-turn conversations = ZERO compression:**

When a conversation contains only user messages (first turn, no assistant response yet), compression returns the original messages unchanged — zero tokens saved.

```python
messages = [{"role": "user", "content": "What is the capital of France?"}]
result = compress(messages, model="gpt-4")
# tokens_before == tokens_after
# tokens_saved == 0
# NO x-headroom-* response headers
```

**Multi-turn = compression on system/assistant/tool:**

```python
messages = [
    {"role": "system", "content": "[500 words system prompt]"},
    {"role": "user", "content": "Write a Python script"},
    {"role": "assistant", "content": "[detailed implementation]"},
    {"role": "user", "content": "Can you optimize it?"}
]
# System: compressed | Assistant: compressed | User messages: unchanged
```

**Compression headers only appear when tokens_saved > 0:**

The ASGI middleware only injects `x-headroom-*` headers when compression actually saved tokens. If no tokens were saved (first-turn, short messages below threshold), no headers are added.

**Source:** `headroom/transforms/content_router.py` — ContentRouterConfig with `enable_kompress=True` default, content-type detection per message.
