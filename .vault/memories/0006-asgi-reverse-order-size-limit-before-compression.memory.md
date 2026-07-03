---
type: memory
title: "ASGI middleware executes in reverse registration order — size limit checked on original body before compression"
createdAt: "2026-06-30T14:00:00Z"
updatedAt: "2026-06-30T14:00:00Z"
tags: [asgi, middleware, size-limit, execution-order, gotcha]
see_also:
  - "adrs/0001-asgi-middleware-only-reliable-litellm-integration.adr.md"
deprecated:
  date: null
  reason: null
  superseded_by: null
---

# Memory: ASGI executes in reverse registration order — size limit before compression

## Fact

ASGI middleware executes in **reverse of registration order**. This means RequestSizeLimitMiddleware (registered after CompressionMiddleware) runs FIRST — size check is enforced on the original, uncompressed body.

## Context

**Registration order in proxy_server.py:**
```python
# Registration order (bottom = last registered):
app.add_middleware(CompressionMiddleware)       # registered first
app.add_middleware(RequestSizeLimitMiddleware)   # registered second
```

**Execution order (reverse):**
```
Request → RequestSizeLimitMiddleware (checks ORIGINAL body size)
               ↓
          CompressionMiddleware (compresses body)
               ↓
          [App handlers]
```

## Impact

- **Positive:** Large requests rejected before compression — prevents "bypass" where oversized payloads could slip through after compression
- **Negative:** Size limit doesn't benefit from compression — requests that would pass after compression are rejected before compression runs
- This is intentional: prevents security bypass where large payloads could circumvent size limits after compression
- **Key insight:** When registering middleware, remember ASGI reverses the order
