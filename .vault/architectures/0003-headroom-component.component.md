---
type: component
c4_level: 2
system: headroom
title: "Headroom SDK — Components"
createdAt: "2026-06-30T14:30:00Z"
updatedAt: "2026-06-30T14:30:00Z"
tags: [architecture, c4, component, headroom, pipeline]
see_also:
  - "architectures/0002-headroom-container.container.md"
  - "concepts/0001-content-router-skips-user-messages.concept.md"
  - "concepts/0002-compression-pipeline-per-content-type.concept.md"
linked_elements:
  - Component: Compress API
  - Component: Transform Pipeline
  - Component: Content Router
  - Component: Per-Type Compressors
  - Component: Tokenizer Registry
  - Component: Compression Cache
  - Component: OTEL Metrics
  - Component: LiteLLM Backend
  - Component: LiteLLM Provider
---

# Headroom SDK — Components (C4 Level 2)

## Diagram

```mermaid
C4Component
    title Headroom SDK — Components

    System_Boundary(sdk, "Headroom SDK") {
        Component(compress_api, "Compress API", "compress.py", "Public API: compress(messages, model) → CompressResult")
        Component(pipeline, "Transform Pipeline", "transforms/pipeline.py", "Orchestrates transform stages, OTEL timing")
        Component(content_router, "Content Router", "transforms/content_router.py", "Routes content to appropriate compressor")
        Component(compressors, "Per-Type Compressors", "transforms/*.py", "SmartCrusher, CodeCompressor, LogCompressor, Kompress, etc.")
        Component(tokenizer_registry, "Tokenizer Registry", "tokenizers/registry.py", "Auto-selects tokenizer by model pattern (tiktoken, mistral, huggingface, estimator)")
        Component(cache, "Compression Cache", "cache/compression_cache.py", "Content-addressed LRU cache (SHA-256, avoids re-compression)")
        Component(otel, "OTEL Metrics", "observability/metrics.py", "DELTA temporality counters and histograms")
        Component(litellm_backend, "LiteLLM Backend", "backends/litellm.py", "100+ provider support via LiteLLM (Bedrock, Azure, OpenRouter)")
        Component(litellm_provider, "LiteLLM Provider", "providers/litellm.py", "Universal token counter and model cost via LiteLLM")
    }

    Rel(developer, compress_api, "compress(messages)")
    Rel(compress_api, pipeline, "Runs pipeline")
    Rel(compress_api, tokenizer_registry, "Token counts")
    Rel(pipeline, content_router, "Routes each message")
    Rel(content_router, compressors, "Dispatches to compressor")
    Rel(compressors, tokenizer_registry, "Token counts")
    Rel(cache, compress_api, "Caches results")
    Rel(otel, pipeline, "Records metrics")
    Rel(otel, compressors, "Records stage timing")
    Rel(litellm_backend, compress_api, "Provider-agnostic calls")
    Rel(litellm_provider, tokenizer_registry, "Fallback tokenizer")
```

## Elements

| ID | Name | Type | Technology | File | Description |
|----|------|------|------------|------|-------------|
| compress_api | Compress API | Component | Python | `compress.py` | Public entry point: `compress(messages, model) → CompressResult` |
| pipeline | Transform Pipeline | Component | Python | `transforms/pipeline.py` | Orchestrates transform stages with timing, waste-signal detection |
| content_router | Content Router | Component | Python | `transforms/content_router.py` | Routes each message to appropriate compressor by content type (3402 lines) |
| compressors | Per-Type Compressors | Component | Python | `transforms/*.py` | SmartCrusher (JSON), CodeCompressor (AST), LogCompressor, SearchCompressor, Kompress (ML), etc. |
| tokenizer_registry | Tokenizer Registry | Component | Python | `tokenizers/registry.py` | Auto-selects tokenizer by model pattern: tiktoken (OpenAI), mistral (Mistral), huggingface (Llama), estimator (fallback) |
| cache | Compression Cache | Component | Python | `cache/compression_cache.py` | Content-addressed LRU cache (SHA-256), avoids re-compression across turns |
| otel | OTEL Metrics | Component | Python | `observability/metrics.py` | DELTA temporality counters: runs, tokens.input, tokens.saved, duration (histogram) |
| litellm_backend | LiteLLM Backend | Component | Python | `backends/litellm.py` | 100+ provider support via LiteLLM — Bedrock, Azure, OpenRouter, Vertex (1216 lines) |
| litellm_provider | LiteLLM Provider | Component | Python | `providers/litellm.py` | Universal token counter and model cost via LiteLLM (308 lines) |

## Notes

- **compress_api** is the single public entry point — all compression goes through `compress()`
- **pipeline** orchestrates the transform stages with OTEL timing at each stage
- **content_router** is the largest component (3402 lines) — handles content detection, routing, and compression policy
- **compressors** are pluggable — each implements the `Transform` interface in `transforms/base.py`
- **tokenizer_registry** uses regex model patterns (order matters) — gpt-5.* → tiktoken, claude-* → estimator, mistral → mistral
- **Litellm_backend** snapshots `os.environ` around litellm import to prevent dotenv key leakage
