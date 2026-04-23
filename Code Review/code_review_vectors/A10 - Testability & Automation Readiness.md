# A10 — Testability & Automation Readiness

**Pass:** Pass A
**Priority:** P13.5
**Focus:** Stable accessibility identifiers for automation, deterministic test mode, fixture seeding, semantic surface publication, UI automation path design, test-mode bypasses for system dialogs.

## Why This Vector Exists

AI agents and XCTest UI automation are real capabilities in the testing stack. They can launch apps, click buttons, type into fields, use shortcuts, navigate controls, and assert visible state — all without a human present.

But they can only interact with what the app exposes. A control without a stable accessibility identifier is invisible to automation. A view without a deterministic launch mode is untestable. A workflow that requires a human to dismiss a system dialog is not an automation test.

This vector catches the gap between "works for a human" and "works for an AI agent." That gap is design debt — cheap to prevent at creation time, expensive to retrofit.

A4 (UX & Accessibility) covers accessibility from the user's perspective: screen readers, keyboard navigation, VoiceOver. This vector covers accessibility from the testing infrastructure perspective: can an AI agent find, interact with, and assert on this code?

## What To Review

### Accessibility Identifiers For Automation

Every control that automation might need to find should have a stable accessibility identifier. This overlaps with A4's user-facing accessibility review, but the automation lens adds:

- **coverage completeness** — are there controls that work visually but are invisible to `XCUIApplication` queries?
- **identifier stability** — are identifiers stable strings that will not change when display text is localized or reworded?
- **naming convention** — do identifiers follow `[dataObject][property][ElementType]` in camelCase with canonical suffixes (TextField, Button, Toggle, Dropdown, etc.)?
- **named properties, not anonymous strings** — are identifiers computed properties in the view, not string literals scattered through the code?
- **creation-time coverage** — are new views adding identifiers when controls are created, not deferring until a test needs them?

### Deterministic Test Mode

The app should support a deterministic launch configuration that suppresses noisy side effects during testing:

- **quiet launch mode** — onboarding, update prompts, keychain dialogs, first-run wizards, global hotkey registration, and helper installation are suppressed
- **test mode detection** — the simplest stable switch is `ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil`
- **runtime profiles** — the app supports at least `normal` and `testing` profiles, with the testing profile producing deterministic behavior
- **debug-only startup bypasses where needed** — if startup authentication or similar human gates make development automation unusable, a debug-only bypass exists that removes the gate without faking downstream service truth
- **no ambient dependencies** — tests should not require network access, active user sessions, or specific desktop state to pass

### Fixture Seeding

Automation against an empty app proves less than automation against known content:

- **seed before launch** — the test mode should load a fixture before the first frame
- **named fixtures** — fixtures are deterministic and named, not random
- **fixture cleanup** — test fixtures do not persist into normal app usage
- **realistic content** — fixtures contain enough content to exercise real code paths, not just empty-state UI

### Semantic Surface Publication

For apps using Marple or similar probe infrastructure:

- **important surfaces publish semantic state** — every significant view should publish a semantic surface snapshot that AI can query
- **synthetic startup state** — if no real view is mounted yet during startup, a synthetic `startup` surface should be published
- **context items exist** — required context items (selection, mode, sub-state) are present in published surfaces
- **state transitions are observable** — workflow state changes produce updated semantic snapshots, not just visual changes

### UI Automation Path Design

When reviewing new views or workflows, check whether the automation path is well-designed:

- **short paths** — a good UI automation test navigates 1–4 interactions. If reaching a state requires more than 4 steps from a known entry point, the path is fragile
- **state assertions, not sequence assertions** — the test should assert on the target state, not replay an exact click sequence. Fewer intermediate steps means more resilient tests
- **test-mode bypasses for system barriers** — file pickers, permission dialogs, drag-and-drop, and multi-app orchestration are unreliable under automation. If a workflow requires these, expose a test-mode bypass (e.g., accept a path directly instead of presenting a file picker)
- **absent-human design** — the UI should work under automation without anyone watching. If it only works when a human is ready to dismiss a dialog or reposition a window, it is not automatable
- **transport honesty** — if XCUITest is flaky for the needed proof on macOS, a thinner accessibility-driven smoke lane is acceptable. Do not insist on XCTest when AX or a desktop harness is the more stable honest layer
- **no pixel dependencies** — assertions should check semantic state or visible text, not pixel positions, scroll offsets, or window geometry

### Injectable Dependencies

Core services should be injectable so tests can substitute controlled implementations:

- **dependency injection for services** — network, persistence, authentication, and external integrations should be injectable
- **no singletons that resist testing** — if a service is a singleton, it should still support a test-mode configuration
- **recoverable failure states** — missing or corrupt dependencies should produce a recoverable error state, not a crash

## Agent Prompt

> You are a testability and automation readiness reviewer. Review [FEATURE] in [PROJECT] ([TECH_STACK]).
>
> Check these areas in order:
>
> 1. **Accessibility identifiers for automation**: Do all interactive elements have stable accessibility identifiers following the `[dataObject][property][ElementType]` naming convention? Are identifiers named computed properties, not inline strings? Could an AI agent find and interact with every critical control using only accessibility identifiers? Are there controls that work visually but are invisible to `XCUIApplication` queries?
>
> 2. **Deterministic test mode**: Does the app support a quiet launch mode that suppresses onboarding, update prompts, and other noisy side effects? Is test mode detectable via `XCTestConfigurationFilePath` or equivalent? Does the app have at least `normal` and `testing` runtime profiles?
>
> 3. **Fixture seeding**: Can the app launch with seeded test content? Are fixtures named and deterministic? Do fixtures contain realistic content, not just empty state?
>
> 4. **Semantic surface publication**: Do important views publish semantic state that AI or probes can query? Is a synthetic startup surface published before real views mount? Are context items (selection, mode, sub-state) present?
>
> 5. **UI automation path design**: Can critical paths be reached in 1–4 interactions from a known entry point? Are there test-mode bypasses for system dialogs (file pickers, permissions)? Would the UI work under automation without a human present? Is the chosen smoke transport (XCTest vs AX/accessibility harness) the most stable honest layer for the proof needed?
>
> 6. **Injectable dependencies**: Are core services injectable? Can tests substitute controlled implementations for network, persistence, and authentication? Do failure states produce recoverable errors, not crashes?
>
> For each finding: Severity, File and line, Description, Suggested fix. Note what's been done well.

## Findings

| Severity | File:Line | Description | Suggested Fix | Estimated Reality (0–100%) |
|---|---|---|---|---|
| — | — | No findings. | — | — |

## Notes

-
