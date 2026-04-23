# B4 — Database & Persistence

**Pass:** Pass B
**Priority:** P4
**Focus:** Data model relationships and delete rules, query patterns that load too much data, missing saves after batch operations, key-value store usage patterns, credential storage patterns.

## Agent Prompt

> You are a code reviewer focused on data persistence. Review [FEATURE] in [PROJECT] ([TECH_STACK]). Look for: data model relationships with unclear or incorrect delete rules, query patterns that load entire object graphs when only a subset is needed, missing explicit saves after batch operations, key-value store keys not using a defined constants pattern, credential storage that is not minimal and at point of use, decode failures from serialized data that are not handled gracefully. For each finding: Severity, File and line, Description, Suggested fix.
>
> For Apple platform persistence specifics, see `Style Guide/platform-notes/Apple Apps.md`.

## Findings

| Severity | File:Line | Description | Suggested Fix | Estimated Reality (0–100%) |
|---|---|---|---|---|
| — | — | No findings. | — | — |

## Notes

-
