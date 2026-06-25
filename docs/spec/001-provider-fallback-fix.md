# 001 — Provider Fallback Fix

**Status:** Implemented  
**Date:** 2025-06-25  
**Author:** Oleksii Honchar

---

## Problem

When `provider=None` is passed to metrics recording methods, the metrics are recorded without provider attribution. This makes it impossible to trace which source generated the metric — especially in multi-provider setups where "local" vs "remote" matters for troubleshooting.

## Impact

- Metrics recorded without explicit provider have `None` as the provider attribute
- No way to distinguish local vs remote metrics in observability
- Orphaned metrics that can't be traced back to a source

## Solution

Default `provider=None` to `"local"` in three key locations:

### 1. `Metrics.create_metric()`

```python
# Before (upstream):
def create_metric(self, name: str, value: float, provider: str = None, ...):

# After (better-headroom):
def create_metric(self, name: str, value: float, provider: str = "local", ...):
```

### 2. `Metrics.update_metric()`

```python
# Before (upstream):
def update_metric(self, name: str, value: float, provider: str = None, ...):

# After (better-headroom):
def update_metric(self, name: str, value: float, provider: str = "local", ...):
```

### 3. `Metrics.create_pipeline_metric()`

```python
# Before (upstream):
def create_pipeline_metric(self, name: str, value: float, provider: str = None, ...):

# After (better-headroom):
def create_pipeline_metric(self, name: str, value: float, provider: str = "local", ...):
```

### 4. `Pipeline` provider fallback

```python
# Before (upstream):
# Pipeline does not set a default provider

# After (better-headroom):
# Pipeline defaults provider to "local" when no provider is specified
```

## Backward Compatibility

- **Fully backward-compatible** — existing code that explicitly passes a provider is unaffected
- The only behavioral change is when `provider` is not passed: it now defaults to `"local"` instead of `None`
- `"local"` is a meaningful default — it indicates the metric came from the local runtime

## Test Coverage

- `test_pipeline_passes_local_provider_fallback_when_no_provider` — Verifies the provider fallback in the pipeline

## Files Changed

- `headroom/observability/metrics.py` — 3 method signatures
- `headroom/transforms/pipeline.py` — provider fallback in pipeline
- `tests/test_observability_metrics.py` — new test
