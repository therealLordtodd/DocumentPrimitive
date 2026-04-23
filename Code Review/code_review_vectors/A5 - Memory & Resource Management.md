# A5 — Memory & Resource Management

**Pass:** Pass A
**Priority:** P5
**Focus:** Memory leaks, retain cycles, unbounded caches, resource cleanup (file handles, network connections, timers), long-lived task management.

## Agent Prompt

> You are a code reviewer focused on memory and resource management. Review [FEATURE] in [PROJECT] ([TECH_STACK]). Focus on: memory leaks (retain cycles, captured self in closures, unbounded caches), resource cleanup (are file handles, network connections, and timers closed/cancelled when no longer needed?), lifetime management (dangling references, tasks that outlive their owners), shutdown behavior (does the feature clean up on view/component dismiss?). For each finding: Severity, File and line, Description, Suggested fix. Also note what's been done well.

## Findings

| Severity | File:Line | Description | Suggested Fix | Estimated Reality (0–100%) |
|---|---|---|---|---|
| — | — | No findings. | — | — |

## Notes

-
