---
type: memory
title: "OTEL metrics DELTA temporality — ClickHouse cumulative conversion requires per-series delta computation"
createdAt: "2026-06-30T14:00:00Z"
updatedAt: "2026-06-30T14:00:00Z"
tags: [opentelemetry, metrics, delta, cumulative, clickhouse, gotcha]
see_also:
  - "adrs/0002-otel-delta-temporality-metrics.adr.md"
deprecated:
  date: null
  reason: null
  superseded_by: null
---

# Memory: OTEL metrics DELTA temporality requires delta computation in queries

## Fact

Headroom sends DELTA temporality metrics. ClickHouse OTel receiver converts to cumulative. Dashboard queries using `max(Value)` lose data across container restarts — must use `sumIf(delta > 0)` per-series delta computation.

## Context

**Headroom sends DELTA temporality:**
- `AggregationTemporality = 2` (DELTA) in `otel_metrics_sum`
- 111,000 data points in 3 hours for `headroom.compression.tokens.input`
- Each `.add()` call increments counter by current batch; OTEL exporter sends these as DELTA

**ClickHouse converts to cumulative:**
- `Value` column shows cumulative totals (after delta-to-cumulative conversion)
- Despite `AggregationTemporality = 2` (DELTA), `Value` is cumulative

**Wrong approach — `max(Value)`:**
```sql
SELECT max(CASE WHEN MetricName = 'headroom.compression.tokens.saved' THEN Value END)
FROM otel_metrics_sum WHERE MetricName = 'headroom.compression.tokens.saved'
```
Problem: If container restarts, counter resets to 0. `max()` only captures post-restart value, losing all pre-restart data.

**Verified difference:**

| Metric | `max(Value)` | `sumIf(delta > 0)` |
|--------|-------------|-------------------|
| Tokens Input | 61.8M | **276M** |
| Tokens Saved | 6.4M | **39.3M** |
| Compression Ratio | 10.4% | **14.2%** |
| Runs | 1.2K | **6,803** |

**Correct approach — per-series delta:**
```sql
WITH deltas AS (
  SELECT
    MetricName,
    Attributes['model'] AS model,
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

## Impact

- All Grafana dashboards using `max(Value)` for Headroom metrics are producing incorrect values
- Container restarts cause data loss in `max()` queries (counter resets)
- Each model has independent series — must partition by `toString(Attributes)`
- Negative delta indicates counter reset — `delta > 0` filter handles this
