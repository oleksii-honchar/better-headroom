---
type: memory
title: "Kompress ML compression fails silently when transformers/onnxruntime missing"
createdAt: "2026-06-30T14:00:00Z"
updatedAt: "2026-06-30T14:00:00Z"
tags: [kompress, transformers, onnxruntime, ml, gotcha, silent-failure]
see_also:
  - "concepts/0002-compression-pipeline-per-content-type.concept.md"
deprecated:
  date: null
  reason: null
  superseded_by: null
---

# Memory: Kompress ML compression fails silently without transformers/onnxruntime

## Fact

If the `transformers` and `onnxruntime` packages are NOT installed, Kompress ML compression silently fails and all plain text messages pass through uncompressed — no exception, no crash, just a warning log.

## Context

**Failure chain:**
```
async_pre_call_hook → compress() → ContentRouter → _try_ml_compressor() → _get_kompress() → is_kompress_available() → import transformers → ImportError
```

**Verification:**
```python
from headroom.transforms.kompress_compressor import is_kompress_available
print(is_kompress_available())  # False when transformers/onnxruntime missing
```

**Source code (headroom/transforms/kompress_compressor.py:249-274):**
```python
def _is_onnx_available() -> bool:
    try:
        import onnxruntime  # noqa: F401
        import transformers  # noqa: F401
        return True
    except ImportError:
        return False

def is_kompress_available() -> bool:
    return _is_onnx_available() or _is_pytorch_available()
```

**Error is caught gracefully** at `headroom/compress.py:336-349` — returns original messages with warning log, no metric recorded for the failure.

**Package installation options:**
| Extra | Includes | Size |
|-------|----------|------|
| `headroom-ai` (core) | No ML | Baseline |
| `headroom-ai[proxy]` | onnxruntime + transformers (no torch) | ~60MB |
| `headroom-ai[ml]` | torch + transformers + onnxruntime | ~800MB+ |

## Impact

- If you install `headroom-ai` without `transformers` and `onnxruntime`, ML compression is completely non-functional
- The failure is silent — no exception, no crash; just a warning log
- Compression metrics never appear in ClickHouse for plain text
- Structured content (JSON, code, logs) still compressed — only plain text affected
- **Mitigation:** Claw Compactor requires zero ML dependencies — this issue is eliminated
