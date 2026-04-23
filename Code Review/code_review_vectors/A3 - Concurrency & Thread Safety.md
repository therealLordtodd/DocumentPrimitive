# A3 — Concurrency & Thread Safety

**Pass:** Pass A
**Priority:** P2
**Focus:** Race conditions, shared mutable state, async/await correctness, task cancellation and cleanup, deadlocks.

## Agent Prompt

> You are a concurrency expert. Review [FEATURE] in [PROJECT] ([TECH_STACK]). Focus on: race conditions (can two concurrent operations corrupt shared state?), async/await pitfalls (fire-and-forget tasks that should be tracked, continuation leaks), task cancellation (are cancelled tasks properly cleaned up? Can stale results arrive?), deadlocks (can waiting on one resource while holding another cause a deadlock?), shared mutable state (is mutable state properly protected across threads/actors?). For each finding: Severity, File and line, Description, Suggested fix.
>
> For Apple platform concurrency specifics, see `Style Guide/platform-notes/Apple Apps.md`.

## Findings

| Severity | File:Line | Description | Suggested Fix | Estimated Reality (0–100%) |
|---|---|---|---|---|
| — | — | No findings. | — | — |

## Notes

-
