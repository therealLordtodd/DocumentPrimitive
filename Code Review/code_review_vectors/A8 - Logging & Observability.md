# A8 — Logging & Observability

**Pass:** Pass A
**Priority:** P14
**Focus:** Logging facade usage, category and level correctness, structured metadata, no sensitive data in logs, dual logging for user-visible errors, no raw logging API calls.

## Agent Prompt

> You are a code reviewer focused on logging and observability. Review [FEATURE] in [PROJECT] ([TECH_STACK]). The project uses a centralized logging facade (`[LOG_FACADE]`). Check against these rules:
>
> 1. **No raw `print` or bare logging API calls.** All output goes through `[LOG_FACADE]`.
> 2. **Correct category.** Each log call uses the appropriate logger category (db, auth, ui, network, app, ai).
> 3. **Correct severity.** `.info` for normal ops, `.warning` for recoverable issues, `.error` for failures, `.debug` for dev-only detail.
> 4. **Entry + outcome logging.** Operations that can fail log at entry AND at outcome. A catch block with no log call is a finding.
> 5. **Structured metadata.** Log calls attach context via metadata parameters — not string interpolation baked into the message.
> 6. **No sensitive data.** Never log passwords, tokens, API keys, or PII beyond what's needed for debugging.
> 7. **Dual logging for user-visible errors.** When an error is shown to the user, log to both the structured log AND the in-app error console. Missing either side is a finding.
> 8. **iOS debug logging controls.** If iOS has a debug panel, ensure it can toggle logging on/off, set minimum level, and optionally mirror to console.
> 9. **Build-gated debug logging.** Debug-only logging UI/infrastructure must be gated behind build configuration (`DEBUG` or explicit internal flag).
> 10. **watchOS scope control.** Do not require watch logging infrastructure unless the feature spec explicitly calls for it.
> 11. **Log maintenance controls.** If the app includes a log/settings pane, ensure `Clear Current Log`, `Reset Log History`, and `Clear Status Panel` exist and behave correctly (alerts for destructive actions, no broken file sink after clear/reset).
>
> For each finding: Severity, File and line, Description, Suggested fix. Be thorough but precise — no false positives.

## Findings

| Severity | File:Line | Description | Suggested Fix | Estimated Reality (0–100%) |
|---|---|---|---|---|
| — | — | No findings. | — | — |

## Notes

-
