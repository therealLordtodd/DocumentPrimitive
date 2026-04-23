# App Style Guide

> **Note:** This is your app-specific style guide. Copy this file for each app if your project has multiple apps (e.g., Client and Admin). Fill in all placeholders.

---

## Design Philosophy

[Describe the visual personality of your app — tone, aesthetic, target feel. E.g., "Clean, focused, and professional. Minimal chrome, maximum content density."]

---

## Color Tokens

| Token | Definition | Usage |
|-------|-----------|-------|
| `[DS_PREFIX]Colors.primary` | `[hex or semantic value]` | Primary button tint, links, active states |
| `[DS_PREFIX]Colors.destructive` | `[hex or semantic value]` | Destructive button tints |
| `[DS_PREFIX]Colors.error` | `[hex or semantic value]` | Error text and icons |
| `[DS_PREFIX]Colors.warning` | `[hex or semantic value]` | Warning icons and accents |
| `[DS_PREFIX]Colors.connected` | `[hex or semantic value]` | Success / connected state |
| `[DS_PREFIX]Colors.textPrimary` | `[hex or semantic value]` | Primary text |
| `[DS_PREFIX]Colors.textSecondary` | `[hex or semantic value]` | Secondary / subdued text |
| `[DS_PREFIX]Colors.textTertiary` | `[hex or semantic value]` | Tertiary / placeholder text |
| `[DS_PREFIX]Colors.windowBackground` | `[hex or semantic value]` | Main window background |
| `[DS_PREFIX]Colors.controlBackground` | `[hex or semantic value]` | Control / card background |
| `[ADD MORE]` | `[value]` | `[usage]` |

---

## Typography Tokens

| Token | Definition | Usage |
|-------|-----------|-------|
| `[DS_PREFIX]Typography.pageTitle` | `[font, size, weight]` | Page and sheet titles |
| `[DS_PREFIX]Typography.sectionHeader` | `[font, size, weight]` | Section/group headers |
| `[DS_PREFIX]Typography.body` | `[font, size, weight]` | Body text |
| `[DS_PREFIX]Typography.caption` | `[font, size, weight]` | Captions, labels, helper text |
| `[DS_PREFIX]Typography.mono` | `[font, size, weight]` | Code, query text, IDs |
| `[ADD MORE]` | `[value]` | `[usage]` |

---

## Spacing Tokens

| Token | Value | Usage |
|-------|-------|-------|
| `[DS_PREFIX]Spacing.microGap` | 2pt | Micro gaps |
| `[DS_PREFIX]Spacing.tinyGap` | 4pt | Tight element grouping |
| `[DS_PREFIX]Spacing.compactGap` | 8pt | Within-group field spacing |
| `[DS_PREFIX]Spacing.innerGap` | 12pt | Internal component spacing |
| `[DS_PREFIX]Spacing.windowContentInset` | 12pt | Root window content inset on all edges (main + settings windows) |
| `[DS_PREFIX]Spacing.sectionGap` | 20pt | Between form groups/sections |
| `[DS_PREFIX]Spacing.pagePadding` | 24pt | Outer sheet/page padding |
| `[DS_PREFIX]Spacing.buttonRadius` | `[value]` | Button corner radius |
| `[ADD MORE]` | `[value]` | `[usage]` |

---

## Component Library

| Component | File | Purpose |
|-----------|------|---------|
| `LabeledField` | `[path]` | Caption label + text input pair |
| `InfoBanner` | `[path]` | Inline informational/error banner |
| `ErrorConsoleBar` | `[path]` | Persistent status/error console |
| `[ADD MORE]` | `[path]` | `[purpose]` |

---

## Layout Patterns

### Primary Layout
[Describe the main window/screen layout. E.g., "Three-panel: sidebar / content / detail"]

### Navigation
[Describe how users navigate between sections.]

### Modal / Sheet Sizing
- Simple forms: 420pt wide
- Complex forms: 520pt wide
- Large panels: 600pt wide
- Extra-large panels: 700pt wide

---

## Non-Conforming UI Summary

> Fill this in as the project matures and inconsistencies are discovered in code review.

| Location | What it does | Why it's different | Tracking |
|----------|-------------|-------------------|---------|
| `[file:line]` | `[description]` | `[reason]` | `[Plane issue or TODO]` |
