---
type: memory
title: "Headroom LiteLLM callback configured correctly but never executes in proxy mode"
createdAt: "2026-06-30T14:00:00Z"
updatedAt: "2026-06-30T14:00:00Z"
tags: [litellm, callback, gotcha, proxy, silent-failure]
see_also:
  - "adrs/0001-asgi-middleware-only-reliable-litellm-integration.adr.md"
deprecated:
  date: null
  reason: null
  superseded_by: null
---

# Memory: Headroom LiteLLM callback fails silently in proxy mode

## Fact

The `headroom.integrations.litellm_callback.HeadroomCallback` configured in LiteLLM proxy config.yaml is **properly set up but never executes** during chat completions. Zero compression logs, zero tokens saved, no CPU/memory impact from compression.

## Context

**Configuration (verified correct):**
```yaml
# config.yaml
litellm_settings:
  callbacks: ["otel", "headroom.integrations.litellm_callback.HeadroomCallback"]
```

**Environment (verified correct):**
```yaml
# docker-compose.yaml
environment:
  - HEADROOM_OTEL_METRICS_ENABLED=true
  - HEADROOM_OTEL_METRICS_ENDPOINT=http://clickstack-otel-collector:4318/v1/metrics
```

**Evidence of correct setup:**
- `headroom-ai[proxy]` installed (v0.26.0) with all dependencies
- Callback class importable and instantiable
- OTEL callback works alongside (config system functional)
- `HeadroomCallbackAdapter` checked (not disabled) — 172 occurrences in 10000 log lines

**Evidence of failure:**
- No compression logs in container
- No tokens_saved events in OTEL
- No CPU/memory impact from compression activity
- `--detailed_debug` enabled — still no callback execution evidence

## Impact

- Headroom compression appears to work (package installed, no errors) but silently does nothing
- Debugging path blocked — callback failures provide no error messages
- **Solution:** ASGI middleware (ADR-0001) — independent of callback system

**File:** `headroom/integrations/litellm_callback.py` — implements `async_pre_call_hook` that calls `headroom.compress()`. The hook is never called in proxy mode.
