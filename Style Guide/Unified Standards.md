# Unified Cross-App Standards

> **Note:** Fill in `[DS_PREFIX]` with your design system prefix (e.g. `FZ` for Forever Zone 2, `DE` for Data Estate). Replace all `[COLOR_TOKEN]`, `[FONT_TOKEN]`, `[SPACING_TOKEN]` placeholders with your actual token names.
>
> These standards apply to **all** apps in the project. When building or modifying any app, follow these rules. Per-app style guides document app-specific layouts and components; this document covers shared patterns that must be identical across all apps.

---

## 1. Design System Parity

All apps MUST share the same design token definitions:

| Token File | Status |
|-----------|--------|
| `[DS_PREFIX]Colors` | Define once, use everywhere. All apps adopt the full color set. |
| `[DS_PREFIX]Spacing` | Define once, use everywhere. All apps adopt the full spacing token set. |
| `[DS_PREFIX]Typography` | Define once, use everywhere. All apps adopt the full typography enum. |

### Proposed Tokens to Add
When filling in your design system, consider including:
- `tinyGap` (4pt), `microGap` (2pt), `pagePadding` (24pt), `windowContentInset` (12pt) in spacing
- `caption2`, `monoSmall`, `headline` in typography

---

## 2. Color Standards

### Error Text: `[DS_PREFIX]Colors.error`
Error text (inline messages, validation errors, status text) uses the designated error color token. This applies to all apps.

### Destructive Actions: `[DS_PREFIX]Colors.destructive`
Button tints for destructive actions use the destructive color. This is for button chrome only, not text.

### Text Colors: Always use tokens
- `[DS_PREFIX]Colors.textPrimary` — never raw `.foregroundStyle(.primary)`
- `[DS_PREFIX]Colors.textSecondary` — never raw `.foregroundStyle(.secondary)`
- `[DS_PREFIX]Colors.textTertiary` — never raw `.foregroundStyle(.tertiary)`

### Status Colors: Always tokens
- `[DS_PREFIX]Colors.connected` for success/connected — never raw `.green`
- `[DS_PREFIX]Colors.warning` for warnings — never raw `.orange`
- `[DS_PREFIX]Colors.destructive` for destructive button tints — never raw `.red`
- `[DS_PREFIX]Colors.error` for error text — never raw `.red`

---

## 3. Button Standards

### Primary Action
```code
Button("Label") { action() }
    .buttonStyle(.borderedProminent)
    .tint([DS_PREFIX]Colors.primary)
    .controlSize(.regular)  // default for sheets and forms
    // .controlSize(.large) for full-page auth screens only
    // .controlSize(.small) for inline toolbar/rail buttons only
```

### Secondary Action
```code
Button("Cancel") { dismiss() }
    .buttonStyle(.bordered)
    // NO .tint — uses system default
```

### Destructive Button (severe)
```code
Button("Delete") { action() }
    .buttonStyle(.borderedProminent)
    .tint([DS_PREFIX]Colors.destructive)
```

### Destructive Button (moderate)
```code
Button("Clear") { action() }
    .buttonStyle(.bordered)
    .tint([DS_PREFIX]Colors.destructive)
```

### Plain Text Link
```code
Button("View all") { action() }
    .buttonStyle(.plain)
    .foregroundStyle([DS_PREFIX]Colors.link)
```

### Rules
1. **Every button MUST have an explicit button style** — no unstyled buttons.
2. **Size rules**: large for auth-screen CTAs, small for inline/toolbar, regular (or omitted) for form/sheet actions.
3. **Secondary buttons are never tinted** — tint is reserved for primary and destructive.

---

## 4. Sheet Standards

### Layout Pattern
```code
VStack(spacing: [DS_PREFIX]Spacing.innerGap) {
    // Title
    Text("Sheet Title")
        .font([DS_PREFIX]Typography.pageTitle)

    // Content
    // ...

    // Action buttons at BOTTOM
    HStack {
        Spacer()
        Button("Cancel") { dismiss() }
            .buttonStyle(.bordered)
        Button("Save") { save() }
            .buttonStyle(.borderedProminent)
            .tint([DS_PREFIX]Colors.primary)
    }
}
.padding([DS_PREFIX]Spacing.pagePadding)
.frame(width: 420)  // 420 simple | 520 complex | 600 large | 700 extra-large
```

### Rules
1. **Buttons always at the bottom** — never in a header bar.
2. **Title** uses the page title typography token.
3. **Padding** uses the page padding spacing token — same in all apps.
4. **Dismiss** via the environment dismiss mechanism — never set a boolean directly.

---

## 5. Form Standards

### Grouping
Use the platform's form grouping component (e.g., `GroupBox` on Apple platforms) for all form sections.

### Rules
1. **Always use the grouping component** for form sections.
2. **Labeled fields** (caption label above input) should be a shared design system component.
3. **Compact gap (8pt)** between fields within a group.
4. **Section gap (20pt)** between groups.

---

## 6. Confirmation Dialogs

### Destructive Confirmations: Always use alerts
```code
// Use platform alert mechanism for destructive confirmations
```

### Rules
1. **Always use alerts** for destructive confirmations — not inline dialogs or sheets.
2. **Complex confirmations** (e.g., typed confirmation) use a custom sheet.
3. **Button order**: destructive first, cancel second.

---

## 7. Error Display Standards

### Inline Error Text
```code
// Error text uses [DS_PREFIX]Colors.error + [DS_PREFIX]Typography.caption
```

### Rules
1. **Error text** is always `[DS_PREFIX]Colors.error` + the caption typography token.
2. **Warning icon** uses the warning color.
3. **Error icon** uses the destructive/error color.
4. **Never use raw red** for error text — always use the token.

---

## 8. Loading State Standards

### Pattern
```code
// Pair a progress indicator with a caption label
// Use appropriate size: large for auth, regular for centered panels, small for inline
```

### Rules
1. **Always pair a loading indicator with a separate text label** — don't use single-component string init.
2. **Size matches context**: large for auth, regular for panels, small for inline/toolbar.

---

## 9. Animation Standards

### Standard Durations
| Token | Duration | Curve | Usage |
|-------|----------|-------|-------|
| `micro` | 0.2s | ease-in-out | Sidebar toggle, filter expand/collapse, hover effects |
| `standard` | 0.3s | ease-in-out | Page transitions, sheet animations, auto-expand |

### Rules
1. **Two durations only**: 0.2s for micro-interactions, 0.3s for larger transitions.
2. **Default curve**: ease-in-out for state changes.
3. **Always specify duration and curve** — no bare animation calls without parameters.

---

## 10. Toolbar Standards

### Rules
1. **Consistent padding**: use the same horizontal and vertical toolbar padding across all apps.
2. **Background**: use the appropriate material/background for all toolbars.
3. **Always followed by a divider**.
4. **Page-level titles** use the page title token. Sub-pane titles use the section header token.

---

## 11. Accessibility Standards

### Tooltips
Every icon-only button MUST have a tooltip. No exceptions.

### Keyboard Shortcuts
Both apps should add standard platform shortcuts:
- Settings shortcut
- New item shortcut
- Search focus shortcut
- Primary action submission (auth screens)

---

## 12. Split View Standards

Use the platform's resizable split view component — never fake it with a stack + divider for panels that should be resizable.

---

## 13. Divider Standards

### Rules
1. **Toolbar dividers**: bare divider with no padding.
2. **Sidebar section dividers**: small horizontal padding on both sides.
3. **All other dividers**: bare divider.

---

## 14. Data Loading Standards

### Rules
1. **Use task-based loading** for all async data — not fire-and-forget on appear.
2. **Synchronous setup** (theme restoration, non-async configuration) can use appear events.

---

## 15. Sheet Dismiss Standards

### Rules
1. **Always use the environment dismiss mechanism** — never set a boolean directly.
2. **Call dismiss** after both cancel and successful save/action.

---

## 16. UI Element Naming Standards

### The Rule

Every interactive UI element that a user touches is a **named computed property** on the View. Anonymous inline controls are prohibited for any element that:
- Has a meaningful label or purpose
- May need to be discussed, debugged, or referenced
- Holds or displays state

### Pattern
```swift
// MARK: - Filters

private var clientNameSearchField: some View {
    TextField("Search clients...", text: $searchQuery)
        .textFieldStyle(.roundedBorder)
}

private var clientStatusDropdown: some View {
    Picker("Status", selection: $selectedStatus) {
        ForEach(ClientStatus.allCases) { Text($0.label).tag($0) }
    }
    .labelsHidden()
}
```

### Canonical Suffix List
`TextField` · `TextEditor` · `SearchField` · `Dropdown` · `Toggle` · `DatePicker` · `Stepper` · `Slider` · `Button` · `Table` · `List` · `Tab` · `Segment`

See `AGENTS.md` for the full naming rule set and the `uiElementContext` ViewModel pattern.

---

## 17. Pane Padding Standards

### Terminology

| Term | Meaning | Example |
|------|---------|---------|
| **Window** | Top-level container | Main window, Settings window |
| **Pane** | Content region within a window | Sidebar pane, detail pane, settings sub-panes |
| **Panel** | Floating auxiliary window | Colors panel, Inspector panel (`NSPanel`) |
| **Status bar** | Persistent strip showing state | Bottom bar showing errors/ready status |
| **Section** / **Group** | Grouped content within a pane | A `GroupBox` of related form fields |

### Rules

1. **Window root containers** (main shell, Settings window root, startup-recovery settings root) MUST apply `.padding([DS_PREFIX]Spacing.windowContentInset)` equally on all edges — 12pt all around. Do not split top/horizontal/bottom values at window level.
2. **Detail panes** (right column, settings tabs, any `ScrollView` content area) MUST apply `.padding([DS_PREFIX]Spacing.pagePadding)` on the outermost container — 24pt on all edges. No zero-inset edges.
3. **List panes** (middle column) — search/filter controls above the list get `.padding(.horizontal, [DS_PREFIX]Spacing.pagePadding)` and `.padding(.top, [DS_PREFIX]Spacing.pagePadding)`. The `List` itself uses its native insets.
4. **Never apply zero padding on any pane edge.** If content touches a pane boundary, padding is missing.
5. **Avoid per-child padding when outer padding is set.** Apply padding once at the pane level, not redundantly on each child.

### Detail Pane Pattern
```swift
var body: some View {
    ScrollView {
        VStack(alignment: .leading, spacing: [DS_PREFIX]Spacing.sectionGap) {
            // content sections
        }
        .padding([DS_PREFIX]Spacing.pagePadding)
    }
}
```

### List Pane Pattern
```swift
var body: some View {
    VStack(spacing: [DS_PREFIX]Spacing.compactGap) {
        searchField
            .padding(.horizontal, [DS_PREFIX]Spacing.pagePadding)
            .padding(.top, [DS_PREFIX]Spacing.pagePadding)

        resultsList  // List uses native insets
    }
}
```
