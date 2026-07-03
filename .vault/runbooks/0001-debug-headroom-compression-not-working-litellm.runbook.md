---
type: runbook
title: "Debug Headroom compression not working with LiteLLM proxy"
createdAt: "2026-06-30T14:00:00Z"
updatedAt: "2026-06-30T14:00:00Z"
tags: [debugging, compression, litellm, proxy, runbook]
see_also:
  - "adrs/0001-asgi-middleware-only-reliable-litellm-integration.adr.md"
  - "memories/0001-litellm-callback-silent-failure-proxy-mode.memory.md"
  - "memories/0002-tiktoken-encoding-mismatch-gpt-5x.memory.md"
  - "memories/0003-kompress-ml-silent-failure-missing-transformers.memory.md"
deprecated:
  date: null
  reason: null
  superseded_by: null
---

# Runbook: Debug Headroom compression not working with LiteLLM proxy

## Symptom

Compression not working — zero tokens saved, no compression logs, no `x-headroom-*` headers.

## Quick Check

**1. Are you using the callback?** → Switch to ASGI middleware (ADR-0001). Callback fails silently in proxy mode.

```yaml
# WRONG (fails silently):
litellm_settings:
  callbacks: ["headroom.integrations.litellm_callback.HeadroomCallback"]

# RIGHT (use ASGI middleware in proxy_server.py):
# app.add_middleware(CompressionMiddleware)
```

**2. Are you testing with gpt-5.x models?** → Tiktoken doesn't recognize gpt-5.5, gpt-5.4-mini, codex-auto-review. Pipeline runs but records 0 tokens. Test with gpt-4o instead.

**3. Is the conversation first-turn only?** → User-only messages are never compressed (by design). Test with multi-turn conversation that includes assistant messages.

## Step-by-Step Debug

### Step 1: Confirm middleware is enabled

```bash
docker logs --tail 100 lite-llm 2>&1 | grep -i "headroom.*middleware.*enabled"
# Expected: Headroom compression middleware enabled
```

### Step 2: Verify Kompress is available

```bash
docker exec lite-llm python -c "from headroom.transforms.kompress_compressor import is_kompress_available; print(is_kompress_available())"
# Expected: True
# If False: transformers or onnxruntime missing — install them
```

### Step 3: Test multi-turn compression

```bash
curl -s -I -X POST http://localhost:8016/v1/chat/completions \
  -H "Authorization: Bearer sk-xxx" \
  -d '{"model": "gpt-4o", "messages": [
    {"role": "system", "content": "You are a helpful assistant. [500 words of system prompt]"},
    {"role": "user", "content": "Write a Python script"},
    {"role": "assistant", "content": "Here is a detailed implementation with extensive code and explanation."},
    {"role": "user", "content": "Can you optimize it?"}
  ]}' 2>&1 | grep -i x-headroom-
# Expected: x-headroom-compressed: true, x-headroom-tokens-saved: <N>
```

### Step 4: Check OTEL metrics in ClickHouse

```sql
SELECT MetricName, count(), max(Value)
FROM otel_metrics_sum
WHERE MetricName LIKE 'headroom.compression.%'
  AND TimeUnix >= now() - INTERVAL 1 HOUR
GROUP BY MetricName
```

**Expected results:**
- `headroom.compression.runs` > 0
- `headroom.compression.tokens.input` > 0
- `headroom.compression.tokens.saved` > 0

If `runs > 0` but `tokens.input = 0`: **tiktoken encoding mismatch** (gpt-5.x model).

### Step 5: Check detailed debug logs

```bash
# Enable --detailed_debug in docker-compose.yaml
docker compose up -d litellm
docker logs --tail 100 -f lite-llm 2>&1 | grep -i -E "(headroom|compress|callback|otel)"
```

## Common Issues and Fixes

| Symptom | Root Cause | Fix |
|---------|-----------|-----|
| Zero compression, no logs | Using callback in proxy mode | Switch to ASGI middleware (ADR-0001) |
| Runs > 0, tokens.input = 0 | Tiktoken doesn't recognize model | Test with recognized model (gpt-4o, claude-sonnet) |
| No x-headroom headers | First-turn conversation | Test with multi-turn (assistant messages) |
| No compression, `is_kompress_available() = False` | transformers/onnxruntime missing | Install: `pip install transformers onnxruntime` |
| Compression works but ratio low | Short messages below min_tokens | Lower `min_tokens` or test with longer content |

## Rollback

If compression causes issues, disable immediately:

```yaml
# docker-compose.yaml
environment:
  - HEADROOM_MIDDLEWARE_ENABLED=false  # or remove the line
```

Restart container.

## Escalation

If all steps fail:
1. Check `headroom/proxy/server.py` for error handling patterns
2. Verify `CompressionMiddleware.__call__` is being invoked (add debug print)
3. Check if request body is valid JSON with messages array
4. Verify model is recognized by tiktoken (`tiktoken.encoding_for_model(model)`)
