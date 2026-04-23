# A1 — Security & Input Validation

**Pass:** Pass A
**Priority:** P1
**Focus:** Input sanitization, injection attacks (SQL/XSS/command), SSRF when fetching user-provided URLs, untrusted content rendering, authentication bypass.

## Agent Prompt

> You are a security-focused code reviewer. Review [FEATURE] in [PROJECT] ([TECH_STACK]). Focus on: input sanitization (are user-provided values validated and escaped before use?), injection attacks (SQL injection, XSS, command injection — can user input reach dangerous sinks?), SSRF (can user-provided URLs cause requests to internal/private IPs?), untrusted content rendering (is externally-sourced content sanitized before display?), authentication bypass (can unauthenticated requests reach protected resources?). For each finding: Severity (Critical/High/Medium/Low), File and line number, Description, Suggested fix with code snippet. Also note what's been done well. Be thorough but precise — no false positives.
>
> For Apple platform specifics, see `Style Guide/platform-notes/Apple Apps.md`.

## Findings

| Severity | File:Line | Description | Suggested Fix | Estimated Reality (0–100%) |
|---|---|---|---|---|
| — | — | No findings. | — | — |

## Notes

-
