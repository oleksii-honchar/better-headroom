---
type: container
c4_level: 0
system: headroom
title: "Headroom System Context"
createdAt: "2026-06-30T14:30:00Z"
updatedAt: "2026-06-30T14:30:00Z"
tags: [architecture, c4, system-context, headroom]
see_also:
  - "architectures/0002-headroom-container.container.md"
  - "architectures/0003-headroom-component.component.md"
linked_elements:
  - Person: Developer (AI agent developer)
  - System: Headroom SDK
  - System_Ext: LLM Provider (OpenAI, Anthropic, Bedrock, etc.)
  - System_Ext: HuggingFace (model downloads)
  - System_Ext: OTEL Collector (metrics)
  - System_Ext: Headroom Cloud (optional compression API)
---

# Headroom System Context (C4 Level 0)

## Diagram

```mermaid
C4Context
    title Headroom — System Context

    Person(developer, "Developer / AI Agent", "Develops AI agents that send long conversations to LLMs")

    System_Boundary(headroom, "Headroom") {
        System(sdk, "Headroom SDK", "Python library: compress() API + proxy server + integrations")
    }

    System_Ext(llm_provider, "LLM Provider", "OpenAI, Anthropic, AWS Bedrock, etc.")
    System_Ext(huggingface, "HuggingFace Hub", "Model downloads (Kompress ONNX model)")
    System_Ext(otel, "OTEL Collector", "OpenTelemetry metrics endpoint (ClickHouse)")
    System_Ext(headroom_cloud, "Headroom Cloud", "Optional managed compression API (cloud mode)")

    Rel(developer, sdk, "Calls compress() or runs proxy", "Python / HTTP")
    Rel(sdk, llm_provider, "Forwards compressed messages", "REST / streaming")
    Rel(sdk, huggingface, "Downloads Kompress model", "HTTP, first use only")
    Rel(sdk, otel, "Exports OTEL metrics", "OTLP HTTP, DELTA temporality")
    Rel(sdk, headroom_cloud, "Cloud compression", "HTTP, cloud mode only")
```

## Elements

| ID | Name | Type | Description |
|----|------|------|-------------|
| developer | Developer / AI Agent | Person | Uses Headroom to compress LLM conversations before sending to providers |
| sdk | Headroom SDK | System | Core Python library with `compress()` API, proxy server, and integrations |
| llm_provider | LLM Provider | System_Ext | Upstream LLM APIs (OpenAI, Anthropic, Bedrock, etc.) |
| huggingface | HuggingFace Hub | System_Ext | Downloads Kompress ONNX model (chopratejas/kompress-v2-base) |
| otel | OTEL Collector | System_Ext | OpenTelemetry metrics receiver (ClickHouse via otel-collector) |
| headroom_cloud | Headroom Cloud | System_Ext | Optional managed compression API for cloud mode |

## Notes

- Headroom is primarily a **Python SDK** that can be used as a library (`compress()`) or as a proxy server
- Cloud mode is optional — local compression is the primary mode
- HuggingFace is only contacted once (first Kompress model download, ~261MB ONNX)
- OTEL metrics use DELTA temporality — ClickHouse converts to cumulative (see ADR-0002)
