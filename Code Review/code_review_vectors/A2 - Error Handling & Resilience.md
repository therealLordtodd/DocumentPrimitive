# A2 — Error Handling & Resilience

**Pass:** Pass A
**Priority:** P3
**Focus:** Silent error swallowing, missing user feedback on failures, network error recovery, partial operation state on crash, error propagation across layers.

## Agent Prompt

> You are a code reviewer focused on error handling and resilience. Review [FEATURE] in [PROJECT] ([TECH_STACK]). Focus on: silent error swallowing (are errors discarded where they should be logged or surfaced?), missing user feedback (do network errors, parse failures, or operation failures show UI feedback?), network error recovery (are timeouts, DNS failures, and offline states handled gracefully?), partial operation state (if the process crashes mid-operation, is data left inconsistent?), error propagation (are errors properly thrown/caught at each layer?). For each finding: Severity, File and line, Description, Suggested fix. Also note what's been done well.

## Findings

| Severity | File:Line | Description | Suggested Fix | Estimated Reality (0–100%) |
|---|---|---|---|---|
| — | — | No findings. | — | — |

## Notes

-
