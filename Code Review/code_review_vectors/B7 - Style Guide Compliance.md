# B7 — Style Guide & Apple HIG Compliance

**Pass:** Pass B
**Priority:** P15
**Focus:** Full Apple Human Interface Guidelines conformance, design token discipline, SwiftUI pattern compliance, visual defaults, and accessibility standards. Every rule below applies unless the project's style guide explicitly documents a deviation with rationale.

## Agent Prompt

> You are a code reviewer performing a comprehensive Apple HIG and style guide compliance audit. Review [FEATURE] in [PROJECT] ([PLATFORM]: macOS / iOS / watchOS).
>
> **Before reviewing code**, read:
> 1. `Style Guide/Unified Standards.md` — cross-app design rules
> 2. `Style Guide/App Style Guide.md` — app-specific tokens and components
> 3. `Style Guide/platform-notes/Apple Apps.md` — Apple platform rules and visual defaults
> 4. `/Users/todd/Programming/Vantage/Style Guide/platform-notes/Apple Apps.md` — canonical Apple HIG reference (cross-project)
>
> If the project documents an intentional deviation from Apple defaults in its style guide, that deviation is allowed. Everything else must conform.

## Checklist

### A. Design Token Discipline

Check every view file touched by this feature for:

1. **Raw color values** — No `Color.red`, `Color.black.opacity(...)`, `.foregroundStyle(.primary)`, or hex literals. All colors must use the project's `[PREFIX]Colors` tokens. Flag every instance.
2. **Raw font values** — No `.font(.body)`, `.font(.system(size:))`, or `.font(.caption)` in view code. All typography must use the project's `[PREFIX]Typography` tokens. Exception: raw semantic fonts (`.body`, `.title`) are acceptable if the project's token system wraps them (check the token file).
3. **Raw spacing values** — No `.padding(12)`, `spacing: 8`, `cornerRadius: 6` in view code. All spacing must use `[PREFIX]Spacing` tokens. Exception: `.padding()` with no argument (system default) is fine.
4. **Raw numeric frame sizes** — No `.frame(width: 320)` without a named constant or token. Layout dimensions that appear in multiple places must be tokenized.

### B. SwiftUI Pattern Compliance

5. **`.task` for async loading** — No `.onAppear { Task { await ... } }`. Synchronous-only `.onAppear` is fine. Mixed sync+async must split: `.onAppear` for sync, `.task` for async.
6. **Sheet dismiss** — Sheets must use `@Environment(\.dismiss)`. No `@Binding var isPresented: Bool` passed to sheets for self-dismissal. Parent-owned presentation state (`@State var showSheet`) is correct.
7. **Button styles** — Every `Button` must have an explicit `.buttonStyle()`. Allowed: `.borderedProminent`, `.bordered`, `.plain`, `.borderless`. Exempt: buttons inside `.alert{}`, `.confirmationDialog{}`, `.contextMenu{}`, `Menu{}`.
8. **Destructive confirmations** — Destructive actions must use `.alert` with `role: .destructive`. No `.confirmationDialog` for destructive flows.
9. **Form grouping** — Use `GroupBox` for in-view form sections. `Form { Section {} }` is acceptable only in Settings/Preferences views (Apple's standard macOS pattern).
10. **Split views** — Resizable side-by-side panels must use `HSplitView` (macOS) or `NavigationSplitView` (iOS). No `HStack + Divider` for resizable layouts.
11. **Animations** — Every `withAnimation` must specify duration and curve. No bare `withAnimation { }`. Standard durations: 0.2s `.easeInOut` for micro-interactions, 0.3s `.easeInOut` for transitions.

### C. Concurrency & Architecture

12. **@MainActor on ViewModels** — Every `@Observable` class and `ObservableObject` class that publishes UI state must be `@MainActor`. Exception: projects with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` build setting (note this in findings).
13. **No print()** — All logging must use the project's log facade (`AppLog`, `SmartDocsLog`, etc.) or `os.Logger`. No `print()` in production code. Exception: CLI targets where `print()` is the correct output mechanism.

### D. Visual Defaults (Apple HIG Baseline)

Check design token definition files and any raw values in view code against these Apple defaults. Flag deviations that are not documented in the project's style guide.

14. **Content padding** — Standard content/page padding should be **20pt**. Flag if significantly different (< 16pt or > 24pt) without documented rationale.
15. **Corner radii** — Cards/panels: **10pt**. Buttons: **6pt**. Popovers/toasts: **12pt**. Flag deviations > 2pt from these values.
16. **Typography sizing** — Token definitions should use semantic system fonts (`.body`, `.title`, `.caption`, etc.) for Dynamic Type support. Flag raw `.system(size:)` in token definitions for standard text sizes. Raw sizes are acceptable for display elements (hero numbers, BPM readouts) where precise pixel control is needed.
17. **Touch targets** — iOS: minimum **44pt** height for tappable elements. watchOS: minimum **38pt**. macOS: minimum **21pt**. Flag any interactive element with a frame or hit area below these minimums.

### E. Accessibility

18. **Icon-only button tooltips** — On macOS: every icon-only button must have `.help("description")`. On iOS: every icon-only button must have `.accessibilityLabel("description")`. No exceptions.
19. **Screen reader support** — Interactive elements must have meaningful accessibility labels. Decorative images should use `.accessibilityHidden(true)`.

## Severity Guide

| Severity | When to use |
|----------|-------------|
| **Critical** | Token discipline violation in a shared/reusable component (multiplied impact) |
| **High** | Missing `@MainActor`, raw `.system(size:)` in token definitions (breaks Dynamic Type), touch target below minimum |
| **Medium** | Individual raw value in a view, missing `.buttonStyle`, missing `.help()`, bare `withAnimation` |
| **Low** | Minor spacing deviation (within 2pt), cosmetic inconsistency, `Form { Section {} }` in a borderline context |

## Findings

| Severity | File:Line | Description | Suggested Fix | Estimated Reality (0–100%) |
|---|---|---|---|---|
| — | — | No findings. | — | — |

## Notes

-
