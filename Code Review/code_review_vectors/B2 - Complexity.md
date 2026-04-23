# B2 — Complexity

**Pass:** Pass B
**Priority:** P10
**Focus:** Premature abstraction, code duplication, dead code, over-engineering, inconsistent patterns for the same problem.

## Agent Prompt

> You are a code reviewer focused on unnecessary complexity. Review [FEATURE] in [PROJECT] ([TECH_STACK]). Simple code is easy to read, maintain, and test. Look for: premature abstractions (helpers or wrappers used only once), code duplication (same logic repeated in multiple places), dead code (functions, types, or branches never called), over-engineering (configuration or flexibility that isn't used), inconsistent patterns (the same problem solved differently in different files). For each finding: Severity, File and line, Description, Suggested fix. Report only issues found in existing code.

## Findings

| Severity | File:Line | Description | Suggested Fix | Estimated Reality (0–100%) |
|---|---|---|---|---|
| — | — | No findings. | — | — |

## Notes

-
