---
type: adr
id: ADR-0002
title: "OTEL metrics use DELTA temporality — dashboard must use per-series delta computation"
status: accepted
createdAt: "2026-06-30T14:00:00Z"
updatedAt: "2026-06-30T14:00:00Z"
tags: [opentelemetry, metrics, delta, cumulative, dashboard, clickhouse]
supersedes: []
superseded_by: []
see_also:
  - "memories/0004-otel-cumulative-counter-delta-computation.memory.md"
deprecated:
  date: null
  reason: null
  superseded_by: null
---

# ADR-0002: OTEL metrics use DELTA temporality — dashboard must use per-series delta computation

## Context

Headroom sends OTEL metrics with **DELTA temporality** — each export cycle sends incremental values since last export. The ClickHouse OTel receiver converts these to cumulative for storage.

**Evidence:**
- `AggregationTemporality = 2` (DELTA) in ClickHouse `otel_metrics_sum`
- 111,000 data points in 3 hours for `headroom.compression.tokens.input`
- `Value` column shows cumulative totals (after delta-to-cumulative conversion)

**Dashboard bug discovered:** Grafana "Avg Ratio" panel used `max(Value)` = 10.4% vs actual 14.2%. `max()` loses pre-restart data when counter resets.

## Decision

**All Grafana queries for Headroom OTEL metrics must use `sumIf(delta > 0)` per-series delta computation:**

```sql
WITH deltas AS (
  SELECT
    MetricName,
    Value - lag(Value) OVER (PARTITION BY MetricName, toString(Attributes) ORDER BY TimeUnix) AS delta
  FROM otel_metrics_sum
  WHERE MetricName IN ('headroom.compression.tokens.input', 'headroom.compression.tokens.saved')
    AND $__timeFilter(TimeUnix)
)
SELECT
  sumIf(delta, MetricName = 'headroom.compression.tokens.saved' AND delta > 0) AS total_saved,
  sumIf(delta, MetricName = 'headroom.compression.tokens.input' AND delta > 0) AS total_input
FROM deltas
```

**Key requirements:**
1. **Partition by `toString(Attributes)`** — each model/series accumulates independently
2. **Use `delta > 0` filter** — negative deltas indicate counter reset (service restart)
3. **Never use `max(Value)`** for cumulative counter aggregation over time windows

## Alternatives Considered

| Approach | Problem |
|----------|---------|
| `max(Value)` | Loses pre-restart data; only captures highest counter value in window |
| `sum(Value)` | Sums same cumulative value multiple times — grossly inflated |
| `sumIf(delta > 0)` per series | ✅ Correct — captures all increments, handles restarts |

## Consequences

- **Positive:** Correct aggregation across service restarts and counter rollovers
- **Positive:** Accurate per-model breakdowns (each series computed independently)
- **Negative:** More complex Grafana queries (requires `lag()` window function)
- **Negative:** All dashboards built with `max()` pattern are producing incorrect values
