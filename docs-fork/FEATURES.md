# better-headroom Features

This document describes the features and fixes added by the `better-headroom` fork.

For an overview of the fork's purpose and installation, see [BETTER-HEADROOM.md](./BETTER-HEADROOM.md).

---

## 1. Provider Fallback Fix (spec/001)

📋 [Detailed Spec](./spec/001-provider-fallback-fix.md)

**Status:** ✅ Implemented

**Problem:** When `provider=None` is passed to metrics recording methods, the metrics are recorded without provider attribution. This makes it impossible to trace which source generated the metric — especially in multi-provider setups where "local" vs "remote" matters for troubleshooting.

**Solution:** Default `provider=None` to `"local"` in three key locations:

1. **`Metrics.create_metric()`** — Method signature defaults `provider` to `"local"` instead of `None`
2. **`Metrics.update_metric()`** — Method signature defaults `provider` to `"local"` instead of `None`
3. **`Metrics.create_pipeline_metric()`** — Method signature defaults `provider` to `"local"` instead of `None`
4. **`Pipeline`** — Pipeline fallback defaults `provider` to `"local"` when no provider is specified

**Before (upstream):**
```python
# headroom/observability/metrics.py
class Metrics:
    def create_metric(self, name: str, value: float, provider: str = None, ...):
        ...
```

**After (better-headroom):**
```python
# headroom/observability/metrics.py
class Metrics:
    def create_metric(self, name: str, value: float, provider: str = "local", ...):
        ...
```

**Impact:**
- Every metric now has a provider attribute — no orphaned metrics
- Existing code that explicitly passes a provider is unaffected
- The `"local"` default signals the metric came from the local runtime, not an external provider

**Test coverage:**
- `test_pipeline_passes_local_provider_fallback_when_no_provider` — Verifies the provider fallback in the pipeline

---

## References

- **Fork overview:** [BETTER-HEADROOM.md](./BETTER-HEADROOM.md)
- **Governance:** [GOVERNANCE.md](./GOVERNANCE.md)
