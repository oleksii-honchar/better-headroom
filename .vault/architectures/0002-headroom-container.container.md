---
type: container
c4_level: 1
system: headroom
title: "Headroom SDK — Containers"
createdAt: "2026-06-30T14:30:00Z"
updatedAt: "2026-06-30T14:30:00Z"
tags: [architecture, c4, container, headroom]
see_also:
  - "architectures/0001-headroom-system-context.container.md"
  - "architectures/0003-headroom-component.component.md"
linked_elements:
  - Container: Headroom SDK (Python)
  - Container: Headroom Proxy (FastAPI)
  - ContainerDb: HuggingFace Model Cache
  - ContainerQueue: OTEL Collector
---

# Headroom SDK — Containers (C4 Level 1)

## Diagram

```mermaid
C4Container
    title Headroom SDK — Containers

    Person(developer, "Developer", "Uses compress() API or proxy")

    System_Boundary(headroom, "Headroom") {
        Container(sdk, "Headroom SDK", "Python", "Core library: compress(), pipeline, content router, compressors")
        Container(proxy, "Headroom Proxy", "Python / FastAPI", "Standalone compression proxy server")
        ContainerDb(hf_cache, "HuggingFace Model Cache", "Local disk", "Kompress ONNX model (chopratejas/kompress-v2-base, ~261MB)")
    }

    System_Ext(llm_provider, "LLM Provider", "OpenAI, Anthropic, etc.")
    System_Ext(otel, "OTEL Collector", "OpenTelemetry metrics endpoint")

    Rel(developer, sdk, "compress(messages)", "Python API")
    Rel(developer, proxy, "HTTP POST", "REST API")
    Rel(proxy, sdk, "Uses compress()", "Internal")
    Rel(sdk, hf_cache, "Downloads model", "HTTP (first use)")
    Rel(sdk, llm_provider, "Forwards compressed", "REST / streaming")
    Rel(sdk, otel, "Exports metrics", "OTLP HTTP")
```

## Elements

| ID | Name | Type | Technology | Description |
|----|------|------|------------|-------------|
| sdk | Headroom SDK | Container | Python | Core library: `compress()`, pipeline, content router, per-type compressors |
| proxy | Headroom Proxy | Container | Python / FastAPI | Standalone HTTP compression proxy for integration without code changes |
| hf_cache | HuggingFace Model Cache | ContainerDb | Local disk | Kompress ONNX model cached after first download (~261MB INT8) |

## Notes

- **SDK is the primary artifact** — proxy is a convenience wrapper around the SDK
- **SDK has no hard dependency on LLM providers** — it compresses messages; the caller sends to any provider
- **HuggingFace model** is lazily loaded on first use, cached locally (no repeated downloads)
- **OTEL metrics** are optional — configured via `HEADROOM_OTEL_METRICS_ENABLED=true`
