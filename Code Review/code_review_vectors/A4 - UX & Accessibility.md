# A4 — UX & Accessibility

**Pass:** Pass A
**Priority:** P12
**Focus:** Accessibility identifiers as surface contract, screen reader labels, keyboard navigation, VoiceOver support, empty/loading/error state coverage, layout responsiveness.

## Why This Vector Matters More Than Its Priority Suggests

Accessibility is P12 in the priority stack because missing labels rarely block shipping the way a security hole or data corruption bug does. But accessibility identifiers serve a dual purpose:

1. **User-facing accessibility** — screen readers, keyboard navigation, assistive technology
2. **Testing infrastructure** — AI agents and XCTest UI automation depend on stable identifiers to find and interact with controls

A missing accessibility identifier on a critical control means VoiceOver users cannot interact with it. Treat accessibility identifiers as part of the app's **public surface contract**, not as test scaffolding added on demand.

The testing and automation side of this dual purpose is covered in depth by **A10 (Testability & Automation Readiness)**. This vector focuses on the user-facing accessibility side.

## What To Review

### Accessibility Identifiers

Every interactive element should have a stable accessibility identifier. Check for:

- **Buttons** — especially icon-only buttons, which are invisible to assistive tech without labels
- **Text fields and text editors** — inputs that automation needs to find and type into
- **Toggles, switches, steppers, sliders** — controls that automation needs to read and set
- **List rows and table rows** — items that need to be selectable by automation
- **Navigation controls** — sidebar items, tabs, segmented controls
- **Toolbar items** — buttons and controls in the toolbar area
- **Sheet and dialog controls** — confirm/cancel buttons, form fields within sheets

Identifiers should follow the project's naming convention (typically `[dataObject][property][ElementType]` in camelCase). Check that:

- identifiers are stable strings, not display labels or localized text
- identifiers use the canonical element suffix (TextField, Button, Toggle, Dropdown, etc.)
- identifiers are named computed properties in the view, not anonymous inline strings
- new views with critical controls add identifiers at creation time, not retroactively

### Screen Reader Labels And Hints

- every interactive element has a meaningful `accessibilityLabel`
- icon-only buttons have a `accessibilityLabel` describing their action, not their icon
- decorative images are hidden from accessibility (`accessibilityHidden(true)`)
- complex custom controls have appropriate `accessibilityValue` and `accessibilityHint`
- groups of related controls use `accessibilityElement(children:)` appropriately

### Keyboard Navigation

- the full UI can be operated without a pointing device
- tab order follows visual reading order
- keyboard shortcuts are documented and do not conflict with system shortcuts
- focus indicators are visible when navigating by keyboard
- modal sheets and dialogs trap focus appropriately and release it on dismiss

### Tooltip Coverage

- every icon-only button has a `.help()` tooltip
- tooltips describe the action, not the icon ("Export as PDF", not "Arrow icon")

### Empty, Loading, And Error States

- every data-driven view handles the empty state with appropriate UI (not a blank screen)
- loading states show a progress indicator or skeleton, not a frozen UI
- error states show a recoverable message, not a crash or blank
- error text uses the design system's error color token, not a raw color

### Layout Responsiveness

- the UI handles window resizing without clipping or overlapping content
- long text does not overflow containers or break layout
- split views resize proportionally
- minimum window sizes are set to prevent unusable layouts

### Testing Implications

See **A10 (Testability & Automation Readiness)** for the full automation-readiness review. When reviewing accessibility, the overlap is: every interactive element that needs a screen reader label also needs a stable accessibility identifier that automation can target.

## Agent Prompt

> You are a UX and accessibility reviewer. Review [FEATURE] in [PROJECT] ([TECH_STACK]).
>
> Check these areas in order:
>
> 1. **Accessibility identifiers**: Do all interactive elements (buttons, fields, toggles, list rows, navigation controls, toolbar items, sheet controls) have stable accessibility identifiers following the `[dataObject][property][ElementType]` naming convention? Are identifiers named computed properties, not anonymous inline strings? Are new views adding identifiers at creation time?
>
> 2. **Screen reader support**: Do all interactive elements have meaningful `accessibilityLabel` values? Do icon-only buttons describe their action? Are decorative images hidden? Do complex custom controls have appropriate value and hint properties?
>
> 3. **Keyboard navigation**: Can the full UI be operated without a mouse? Does tab order follow visual reading order? Do shortcuts conflict with system shortcuts? Are focus indicators visible? Do modals trap and release focus correctly?
>
> 4. **Tooltips**: Does every icon-only button have a `.help()` tooltip?
>
> 5. **Empty/loading/error states**: Does every data-driven view handle empty, loading, and error states with appropriate UI? Does error text use the design system's error color token?
>
> 6. **Layout responsiveness**: Does the UI handle window resizing? Does long text overflow? Do split views resize proportionally? Are minimum window sizes set?
>
> For each finding: Severity, File and line, Description, Suggested fix. Note what's been done well.

## Findings

| Severity | File:Line | Description | Suggested Fix | Estimated Reality (0–100%) |
|---|---|---|---|---|
| — | — | No findings. | — | — |

## Notes

-
