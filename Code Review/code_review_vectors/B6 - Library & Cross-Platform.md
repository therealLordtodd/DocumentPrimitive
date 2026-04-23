# B6 — Library & Cross-Platform

**Pass:** Pass B
**Priority:** P13
**Focus:** Platform-specific code not isolated behind abstractions, direct framework use in business logic, missing protocol boundaries for swappable implementations.

## Agent Prompt

> You are a code reviewer focused on library usage and platform isolation. Review [FEATURE] in [PROJECT] ([TECH_STACK]). Look for: platform-specific code not isolated behind a protocol or abstraction layer, direct use of platform frameworks in business logic (models, services, data processors), missing protocol abstractions that would allow platform implementations to be swapped, use of older concurrency patterns (callbacks, manual threading) that could be simplified with modern async/await. Do not plan future ports — report only current issues. For each finding: Severity, File and line, Description, Suggested fix.
>
> For Apple-specific isolation rules (AppKit, NSPasteboard, NSEvent, etc.), see `Style Guide/platform-notes/Apple Apps.md`.
> For Windows-specific notes, see `Style Guide/platform-notes/Windows Apps.md`.

## Findings

| Severity | File:Line | Description | Suggested Fix | Estimated Reality (0–100%) |
|---|---|---|---|---|
| — | — | No findings. | — | — |

## Notes

-
