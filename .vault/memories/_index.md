---
type: index
title: "Memories"
createdAt: "2026-06-30T14:00:00Z"
updatedAt: "2026-06-30T14:30:00Z"
tags: []
---

# Memories

Atomic durable facts — incident learnings, API quirks, gotchas.

## Nodes

| ID | Slug | Title |
|----|------|-------|
| 0001 | [litellm-callback-silent-failure-proxy-mode](0001-litellm-callback-silent-failure-proxy-mode.memory.md) | Headroom LiteLLM callback configured correctly but never executes in proxy mode |
| 0002 | [tiktoken-encoding-mismatch-gpt-5x](0002-tiktoken-encoding-mismatch-gpt-5x.memory.md) | Tiktoken encoding mismatch — gpt-5.x models produce zero compression tokens |
| 0003 | [kompress-ml-silent-failure-missing-transformers](0003-kompress-ml-silent-failure-missing-transformers.memory.md) | Kompress ML compression fails silently when transformers/onnxruntime missing |
| 0004 | [otel-cumulative-counter-delta-computation](0004-otel-cumulative-counter-delta-computation.memory.md) | OTEL metrics DELTA temporality — ClickHouse cumulative conversion requires per-series delta computation |
| 0005 | [first-turn-conversations-zero-compression](0005-first-turn-conversations-zero-compression.memory.md) | First-turn conversations produce zero compression — user-only messages are never compressed |
| 0006 | [asgi-reverse-order-size-limit-before-compression](0006-asgi-reverse-order-size-limit-before-compression.memory.md) | ASGI middleware executes in reverse registration order — size limit checked on original body before compression |
| 0007 | [compound-build-docker-local-path-dependency](0007-compound-build-docker-local-path-dependency.memory.md) | Compound Docker build required for local path dependencies — --frozen ignores local paths |
