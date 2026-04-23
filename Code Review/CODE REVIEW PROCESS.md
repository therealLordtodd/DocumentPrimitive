# Code Review Process

## Overview

This project uses a two-pass code review system. **Pass A** reviews feature correctness — does the new code work safely and robustly? **Pass B** reviews code quality — is the code clear, simple, and well-documented?

Each pass dispatches review agents **sequentially** (one at a time) that read all relevant source files independently and produce structured findings with severity, file:line, description, suggested fix, and **Estimated Reality (0–100%)** — a confidence estimate of whether the issue is real. All vectors must report this estimate.

All findings must be posted to the **Code Review** module in Plane.

Documentation review issues are **automatic fixes**. No human approval required.

> **Why sequential, not parallel?** Running all vectors as parallel agents causes the orchestrating session to exceed its context window. Sequential execution keeps each vector's findings within budget.

Reviews report only problems found in current code. Missing features and future plans belong in tasks, not code reviews.

---

## Priority Hierarchy

**Correctness first, then robustness, then craft.**

### Tier 1: Correctness (Must Fix — blocks shipping)

| Priority | Vector | Pass | Rationale |
|----------|--------|------|-----------|
| P1 | Security & Input Validation | A | Vulnerabilities cannot ship. |
| P2 | Concurrency & Thread Safety | A | Data races cause crashes that are nearly impossible to reproduce. |
| P3 | Error Handling & Resilience | A | Silent failures lose user data or leave inconsistent state. |
| P4 | Database & Persistence | B | Wrong relationships or query patterns corrupt data. |

### Tier 2: Robustness (Should Fix — degrades over time)

| Priority | Vector | Pass | Rationale |
|----------|--------|------|-----------|
| P5 | Memory & Resource Management | A | Leaks compound. Harder to fix retroactively. |
| P6 | Integration & Compatibility | A | Format-specific bugs cause crashes when features interact. |
| P7 | Edge Cases & Boundary Conditions | A | Malformed input and boundary conditions cause isolated crashes. |
| P7.5 | Package & Library Health | A | Kit bugs found during integration propagate to all consumers if not caught early. |
| P7.6 | Primitive Adoption & Extraction | A | Reinvented primitives, missed extractions, and host-app band-aids permanently fragment the shared library. |
| P8 | Efficiency | B | Redundant work and main-thread blocking that users can feel. |
| P14 | Logging & Observability | A | Missing or noisy logs slow down diagnosis. |

### Tier 3: Craft (Nice to Fix — makes code excellent)

| Priority | Vector | Pass | Rationale |
|----------|--------|------|-----------|
| P9 | Clarity | B | Code a new developer can read and understand quickly. |
| P10 | Complexity | B | Simple code is easy to read, maintain, and test. |
| P11 | Documentation | B | Nearly free to write, enormously valuable to read. |
| P12 | UX & Accessibility | A | Important but doesn't block data integrity. |
| P13 | Library & Cross-Platform | B | Important long-term, not day-to-day. |
| P13.5 | Testability & Automation Readiness | A | Missing testability seams accumulate as expensive retrofit debt. |
| P15 | Style Guide & Apple HIG Compliance | B | Design token discipline, Apple HIG conformance, visual defaults, accessibility. |

### Conflict Resolution Rules

* Security fix makes code complex → do it anyway, document why
* Thread safety requires sacrificing performance → do it, performance can be reclaimed later
* Error handling creates UI complexity → handle the error, simplify the UI separately
* Memory optimization makes code harder to read → do it, add comments explaining the trade-off
* Clarity fix conflicts with efficiency → keep it clear unless performance impact is measurable
* Adding abstraction reduces duplication but increases complexity → keep it simple, tolerate the duplication
* Edge case fix conflicts with integration behavior → fix the edge case, file a follow-up for integration

**The general rule: correctness first, then robustness, then craft.**

---

## Pass A: Feature Correctness (11 Vectors)

Run as 11 **sequential** agents. Execute one vector at a time.

### A1. Security & Input Validation — P1
**Focus:** Input sanitization, injection attacks, SSRF, untrusted content rendering, authentication bypass.

### A2. Error Handling & Resilience — P3
**Focus:** Silent error swallowing, missing user feedback on failures, network error recovery, partial operation state on crash.

### A3. Concurrency & Thread Safety — P2
**Focus:** Race conditions, shared mutable state, async/await correctness, task cancellation, deadlocks.

### A4. UX & Accessibility — P12
**Focus:** Screen reader labels, keyboard navigation, VoiceOver support, empty/loading/error states, layout responsiveness. (Automation testability is in A10.)

### A5. Memory & Resource Management — P5
**Focus:** Memory leaks, retain cycles, unbounded caches, resource cleanup, long-lived task management.

### A6. Integration & Compatibility — P6
**Focus:** Feature interaction bugs, OS version compatibility, format-specific guards, migration surprises.

### A7. Edge Cases & Boundary Conditions — P7
**Focus:** Empty data, large data sets, malformed input, offline state, Unicode/encoding edge cases.

### A8. Logging & Observability — P14
**Focus:** Logging facade usage, category/level correctness, structured metadata, no sensitive data, dual logging for user-visible errors.

### A9. Package & Library Health — P7.5
**Focus:** Bugs, missing features, API misuse, and workarounds in shared libraries and kit packages being integrated into the app.

### A10. Testability & Automation Readiness — P13.5
**Focus:** Stable accessibility identifiers for automation, deterministic test mode, fixture seeding, semantic surface publication, UI automation path design, test-mode bypasses for system dialogs.

### A11. Primitive Adoption & Extraction — P7.6
**Focus:** Whether the project draws from the shared primitive/kit library when it should, contributes back when it can, and respects the host/library boundary in both directions.

**What to look for:**

**Adoption** — is the app reinventing existing primitives?

1. **Reinvented primitive** — walk `Packages/` and match against work the app is doing
2. **Wrapper bloat** — adapters that mirror primitive APIs ≥70% with no added value
3. **Reaching around seams** — subclassing internals, accessing private members, copying source
4. **Stale fork** — recognizable copy of primitive code, modified locally
5. **Cross-app fragmentation** — concept reinvented in 3+ sibling projects independently
6. **Performance escape hatch** — copying a primitive "for perf" instead of optimizing it
7. **Theming workaround** — overlays/swizzling to bend appearance instead of exposing customization

**Extraction** — should novel work move into the shared library?

8. **Primitive-shaped local code** — clean inputs/outputs, no app coupling, generally useful
9. **Composition pattern = kit candidate** — recurring combination of 2+ primitives
10. **Tests must migrate** — extracted code's tests move to the primitive too

**Boundary integrity** — fixes flow down, not absorbed up:

11. **Host-app band-aid** for a kit bug — push the fix into the primitive
12. **Workaround comments** — `HACK`, `WORKAROUND`, `TODO: remove when X fixes`
13. **Defensive version pin** — pinning to old version to avoid a regression
14. **Discoverability signal** — repeat "you reinvented X" findings mean X needs better surfacing

**When [PROJECT] is itself a primitive/kit, invert focus:**

15. **Reverse-coupling** — primitive imports/references specific host-app types or vocabulary (most insidious failure mode)
16. **Scope creep** — primitive grew responsibilities outside its name's promise
17. **Missing customization seams** — consumers reaching around because the seam doesn't exist

**Output format:** Findings should be tagged with direction:
- **Adopt** — use existing primitive X
- **Extract** — promote app code to new primitive/kit Y
- **Push down** — host band-aid moves into primitive Z
- **Primitive-side** — primitive has absorbed app concepts or grown beyond scope

**What to look for:**

1. **Kit API gaps** — Is the app working around a missing kit API instead of flagging it as a kit feature request?
2. **Kit bugs surfaced by integration** — Does the app's usage reveal incorrect behavior in a kit method?
3. **API contract mismatches** — Is the app calling a kit API with assumptions that don't match the kit's actual behavior or documentation?
4. **Workaround accumulation** — Are there `// HACK`, `// WORKAROUND`, or `// TODO: remove when kit fixes X` comments that indicate known kit issues?
5. **Version/dependency drift** — Is the app pinned to an older kit version to avoid a regression, or pulling a branch instead of a tagged release?
6. **Error surface gaps** — Does the kit surface errors in a way the app can meaningfully handle, or is the app forced to swallow/wrap them?
7. **Misplaced logic** — Is the app implementing logic that belongs in the kit? Validation, formatting, data transformation, or coordination patterns that multiple consumers would need should live in the shared library.

**Output format:** Findings should clearly distinguish:
- **App-side fix** — the app is misusing the kit API
- **Kit-side fix** — the kit has a bug or missing feature (file as a kit issue)
- **Both** — the app needs a workaround now AND the kit needs a fix

---

## Pass B: Code Quality (7 Vectors)

Run as 7 **sequential** agents. Execute one vector at a time.

### B1. Clarity — P9
**Focus:** Naming, readability, avoiding cleverness, consistent style.

### B2. Complexity — P10
**Focus:** Premature abstraction, code duplication, dead code, over-engineering, inconsistent patterns.

### B3. Documentation — P11
**Focus:** Missing doc comments, undocumented complex logic, large files without section markers, unexplained edge cases.

### B4. Database & Persistence — P4
**Focus:** Data model relationships and delete rules, query patterns, missing saves, credential storage patterns.

### B5. Efficiency — P8
**Focus:** Redundant computation, eager loading, main-thread blocking, memory churn, unbounded accumulation.

### B6. Library & Cross-Platform — P13
**Focus:** Platform-specific code not isolated, direct framework use in business logic, missing protocol abstractions.

### B7. Style Guide & Apple HIG Compliance — P15
**Focus:** Full Apple HIG conformance audit — design token discipline (colors, fonts, spacing), SwiftUI patterns (`.task`, sheet dismiss, button styles, animations), visual defaults (padding, radii, touch targets, Dynamic Type), and accessibility (tooltips, labels). Every rule applies unless the project's style guide documents a specific deviation with rationale. See `code_review_vectors/B7 - Style Guide Compliance.md` for the complete 19-point checklist.

---

## Execution Workflow

### When to Run

* **Pass A**: After implementing a new feature, before merging. Always run all 11 vectors.
* **Pass B**: After a coding session touching multiple files. At minimum run B1, B2, B3 every session.
* **Both passes**: Before any major release or after large refactors.

### How to Run

1. **Scope** — Identify all files modified or added for the feature
2. **Dispatch** — Run vectors **sequentially** (one at a time, never parallel)
3. **Collect** — Each agent returns structured findings
4. **Deduplicate** — Merge findings that appear in multiple vectors
5. **Prioritize** — Apply P1–P15 hierarchy
6. **Fix** — Implement fixes in priority order

### Priority: Correctness first, then robustness, then craft.
