# B5 — Efficiency

**Pass:** Pass B
**Priority:** P8
**Focus:** Redundant computation, eager loading, main-thread blocking, unbounded accumulation, object churn, memory growth.

## Agent Prompt

> You are a code reviewer focused on efficiency. Review [FEATURE] in [PROJECT] ([TECH_STACK]). The goal is clean, efficient code that makes the app feel snappy. Look for: redundant work (same data loaded, parsed, or computed multiple times), eager loading (large objects loaded before needed), main-thread blocking (synchronous operations that should be async), unbounded accumulation (collections that grow without bounds), object churn (creating new instances when cached/shared would work), memory growth (unbounded collections, retained closures, missing cleanup). Measure before optimizing — don't guess bottlenecks. For each finding: Severity, File and line, Description, Suggested fix.

## Findings

| Severity | File:Line | Description | Suggested Fix | Estimated Reality (0–100%) |
|---|---|---|---|---|
| — | — | No findings. | — | — |

## Notes

-
