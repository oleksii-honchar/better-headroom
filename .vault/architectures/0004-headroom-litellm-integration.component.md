---
type: component
c4_level: 2
system: headroom
title: "Headroom LiteLLM Integration — Dual Integration Points"
createdAt: "2026-06-30T14:30:00Z"
updatedAt: "2026-06-30T14:30:00Z"
tags: [architecture, c4, component, litellm, integration]
see_also:
  - "architectures/0003-headroom-component.component.md"
  - "adrs/0001-asgi-middleware-only-reliable-litellm-integration.adr.md"
  - "memories/0001-litellm-callback-silent-failure-proxy-mode.memory.md"
linked_elements:
  - Component: ASGI Middleware
  - Component: LiteLLM Callback
  - Component: LiteLLM Backend
  - Component: LiteLLM Provider
---

# Headroom LiteLLM Integration — Dual Integration Points (C4 Level 2)

## Diagram

```mermaid
C4Component
    title Headroom LiteLLM Integration

    System_Boundary(headroom, "Headroom SDK") {
        Component(asgi_mw, "ASGI Middleware", "integrations/asgi.py", "CompressionMiddleware — buffers body, compresses, injects headers (287 lines)")
        Component(callback, "LiteLLM Callback", "integrations/litellm_callback.py", "HeadroomCallback — async_pre_call_hook (187 lines)")
        Component(litellm_backend, "LiteLLM Backend", "backends/litellm.py", "100+ provider support via LiteLLM (1216 lines)")
        Component(litellm_provider, "LiteLLM Provider", "providers/litellm.py", "Universal token counter via LiteLLM (308 lines)")
    }

    System_Ext(litellm_proxy, "LiteLLM Proxy", "better-litellm fork")
    System_Ext(litellm_lib, "LiteLLM Library", "litellm.completion()")

    Rel(litellm_proxy, asgi_mw, "app.add_middleware()", "ASGI registration")
    Rel(litellm_proxy, callback, "callbacks: [HeadroomCallback]", "config.yaml — FAILS SILENTLY ⚠️")
    Rel(litellm_lib, callback, "litellm.callbacks = [HeadroomCallback()]", "Library mode — works")
    Rel(asgi_mw, compress_api, "compress(messages)")
    Rel(callback, compress_api, "compress(messages)")
    Rel(litellm_backend, litellm_lib, "acompletion()", "Provider abstraction")
    Rel(litellm_provider, litellm_lib, "token_counter()", "Token counting")

    UpdateRelStyle(litellm_proxy, callback, $strokeDasharray="5 5", $stroke="#ff0000")
    UpdateRelStyle(litellm_proxy, asgi_mw, $stroke="#00cc00", $strokeWidth="2")
```

## Elements

| ID | Name | Type | Technology | File | Description |
|----|------|------|------------|------|-------------|
| asgi_mw | ASGI Middleware | Component | Python / Starlette | `integrations/asgi.py` | CompressionMiddleware — buffers body, compresses, injects x-headroom-* headers. **Proven reliable in proxy mode.** |
| callback | LiteLLM Callback | Component | Python | `integrations/litellm_callback.py` | HeadroomCallback — implements `async_pre_call_hook`. **FAILS SILENTLY in LiteLLM proxy mode** (see Memory-0001). Works in library mode. |
| litellm_backend | LiteLLM Backend | Component | Python | `backends/litellm.py` | Internal: uses LiteLLM to call 100+ providers (Bedrock, Azure, OpenRouter). Not the LiteLLM proxy integration — this is headroom's own LiteLLM usage. |
| litellm_provider | LiteLLM Provider | Component | Python | `providers/litellm.py` | Internal: uses LiteLLM for universal token counting and model cost lookup. |

## Notes

- **Two LiteLLM integration paths** — ASGI middleware (reliable) and callback (fails in proxy mode)
- **ASGI middleware** (green) is the only reliable pattern for LiteLLM proxy — see ADR-0001
- **Callback** (red dashed) fails silently in proxy mode — zero compression, zero logs — see Memory-0001
- **litellm_backend** and **litellm_provider** are INTERNAL to headroom — they use LiteLLM as a library, not as an integration target. They are NOT the LiteLLM proxy integration.
- ASGI middleware intercepts 4 paths: `/v1/messages`, `/v1/chat/completions`, `/v1/responses`, `/chat/completions`
- ASGI middleware also handles Responses API `input` field normalization
