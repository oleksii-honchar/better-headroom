---
type: concept
title: "Compression Pipeline — Per-Content-Type Compressors"
createdAt: "2026-06-30T14:00:00Z"
updatedAt: "2026-06-30T14:00:00Z"
tags: [compression, pipeline, kompress, content-type, ml]
see_also:
  - "concepts/0001-content-router-skips-user-messages.concept.md"
  - "memories/0003-kompress-ml-silent-failure-missing-transformers.memory.md"
deprecated:
  date: null
  reason: null
  superseded_by: null
---

# Concept: Compression Pipeline — Per-Content-Type Compressors

## What

Headroom uses **per-content-type compressors** selected by a content router. Each compressor targets a specific content type. Only plain text requires ML (Kompress); all others are pure Python.

## Why

Specialized compressors achieve better compression ratios than a single generic approach. Most content types don't need ML at all.

## Key Details

**Compressor matrix (from `headroom/transforms/`):**

| Compressor | Content Type | Requires ML | File |
|------------|-------------|-------------|------|
| SmartCrusher | JSON arrays | ❌ No | `smart_crusher.py` |
| CodeCompressor | Source code (AST) | ❌ No | `code_compressor.py` |
| SearchCompressor | grep/ripgrep results | ❌ No | `search_compressor.py` |
| LogCompressor | Build/test logs | ❌ No | `log_compressor.py` |
| Tabular compressor | CSV/TSV/markdown tables | ❌ No | `tabular_ingest.py` |
| HTML extractor | HTML content | ❌ No | `html_extractor.py` |
| DiffCompressor | Git diff output | ❌ No | `diff_compressor.py` |
| TextCrusher | General text | ❌ No | `text_crusher.py` |
| **Kompress** | **Plain text** | **✅ Yes** | **`kompress_compressor.py`** |

**Kompress (ML text compressor) — the only ML dependency:**

- ModernBERT token classification model (`chopratejas/kompress-v2-base`)
- ONNX Runtime inference (INT8, ~261MB) — no PyTorch required
- Requires `transformers` and `onnxruntime` packages
- **Silent failure if missing:** If `transformers` or `onnxruntime` not installed, Kompress is silently unavailable — all plain text falls through to non-ML compressors

**Content router config (from `headroom/transforms/content_router.py:620-629`):**

```python
@dataclass
class ContentRouterConfig:
    enable_code_aware: bool = False
    enable_kompress: bool = True
    enable_smart_crusher: bool = True
    enable_search_compressor: bool = True
    enable_log_compressor: bool = True
    enable_tabular_compressor: bool = True
    enable_html_extractor: bool = True
    enable_image_optimizer: bool = True
```

**Kompress can be disabled per-provider:**

```python
# Environment variables (from headroom/proxy/server.py:3869-3872):
HEADROOM_DISABLE_KOMPRESS=False         # Global disable
HEADROOM_DISABLE_KOMPRESS_ANTHROPIC     # Per-provider
HEADROOM_DISABLE_KOMPRESS_OPENAI        # Per-provider
HEADROOM_DISABLE_KOMPRESS_FALLBACK      # Fallback disable
```

**Request flow through ASGI middleware:**

```
POST /v1/chat/completions
         ↓
[Buffer request body]
         ↓
[Parse JSON, extract messages]
         ↓
[Content router selects compressor per message]
         ↓
[Kompress for plain text, others for structured content]
         ↓
[Replace messages in body]
         ↓
[Forward compressed request]
         ↓
[Inject x-headroom-* response headers]
```

**Response headers (monitoring):**

| Header | Description |
|--------|-------------|
| `x-headroom-compressed` | "true" if compression occurred |
| `x-headroom-tokens-before` | Original token count |
| `x-headroom-tokens-after` | Compressed token count |
| `x-headroom-tokens-saved` | Tokens removed |
