---
type: adr
id: ADR-0001
title: "ASGI middleware is the only reliable LiteLLM proxy integration pattern"
status: accepted
createdAt: "2026-06-30T14:00:00Z"
updatedAt: "2026-06-30T14:00:00Z"
tags: [litellm, integration, middleware, callback, asgi]
supersedes: []
superseded_by: []
see_also:
  - "memories/0001-litellm-callback-silent-failure-proxy-mode.memory.md"
  - "memories/0006-asgi-reverse-order-size-limit-before-compression.memory.md"
deprecated:
  date: null
  reason: null
  superseded_by: null
---

# ADR-0001: ASGI middleware is the only reliable LiteLLM proxy integration pattern

## Context

Headroom ships two LiteLLM integration mechanisms:

1. **Callback** (`headroom.integrations.litellm_callback.HeadroomCallback`) — one-line config in LiteLLM's `config.yaml` callbacks list
2. **ASGI middleware** (`headroom.integrations.asgi.CompressionMiddleware`) — middleware registration in `proxy_server.py`

During the `260629-1644-headroom-compression-check` session, the callback was properly configured (visible in config.yaml, package installed, class importable) but **never executed during chat completions** — zero compression logs, zero tokens saved, no CPU/memory impact.

## Decision

**Always use ASGI middleware** for LiteLLM proxy integration. Never use the callback mechanism in proxy mode.

**Rationale:**

| Consideration | Callback | ASGI Middleware |
|---------------|----------|-----------------|
| **Reliability** | Fails silently — no error messages | Direct integration — visible in middleware stack |
| **Execution timing** | Post-request hook (pre_call) | Request-level (before LiteLLM processing) |
| **Dependency on callbacks** | Yes (problematic in proxy mode) | No — independent of callback system |
| **Testability** | Difficult (internal callback system) | Easy (HTTP endpoint tests) |
| **Monitoring** | OTEL metrics only | Response headers + OTEL |

**Root cause of callback failure (never fully diagnosed):**
- LiteLLM proxy mode may not load callbacks from config the same way as library mode
- Chat completions endpoint may bypass pre_call hook system
- Callback loading silently fails with no error messages

**Evidence:** Callback class was importable and instantiable, OTEL callback worked alongside, `HeadroomCallbackAdapter` appeared 172 times in 10000 log lines — but zero compression events.

## Consequences

- **Positive:** ASGI middleware is reliable, testable, feature-toggleable, and produces response headers for monitoring
- **Positive:** Headroom provides ready-to-use `CompressionMiddleware` (287 lines, well-tested)
- **Negative:** Requires code change in `proxy_server.py` (~25 lines)
- **Neutral:** Callback code remains available for library-mode use cases
