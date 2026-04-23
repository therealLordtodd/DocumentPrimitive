# DocumentPrimitive — Project Constitution

**Created:** 2026-04-16
**Authors:** Todd Cowing + Claude (Opus 4.7)

This document records the *why* behind foundational decisions. It is written for future collaborators — human and AI — who weren't in the room when these choices were made. The development plan tells you what we're building. AGENTS.md tells you how to build it. This document tells you why we made the decisions we made, and where we believe this is going.

Fill in the project-specific sections as decisions are made. The **Founding Principles** apply to every project in the portfolio without exception — they are the intent behind the work. The **Portfolio-Wide Decisions** are pre-filled conventional choices that follow from those principles; they apply unless explicitly overridden here with a documented reason.

---

## What DocumentPrimitive Is Trying to Be

DocumentPrimitive is the word-processor layer that sits above `RichTextPrimitive` in the editor stack. It adds document structure — sections, page setup, columns, headers and footers, footnotes, layout and page flow, document-level review and navigation, export and preview integration, and optional grid-backed table editing. It is for apps building real document editors or print-oriented writing surfaces, not for apps that only need rich text inside a single continuous surface. The central insight is that durable document behavior (pagination, section breaks, header/footer variants) belongs on its own layer separate from the block-editor engine, so host apps can scale from block editing up to full word-processor workflows without replumbing.

---

## Foundational Decisions

### Shared Portfolio Doctrine

The shared founding principles and portfolio-wide defaults now live in the Foundation Libraries wiki:

- `/Users/todd/Library/CloudStorage/GoogleDrive-todd@cowingfamily.com/My Drive/The Commons/Libraries/Foundation Libraries/operations/portfolio-doctrine.md`

Use this local constitution for project-specific decisions, not copied portfolio boilerplate.

---

### Project-Specific Decisions

*Add an entry here for every significant architectural, tooling, or directional decision made for this project. Write it at decision time, not retroactively. Future collaborators need to understand the reasoning, not just the outcome.*

*Initial decisions summarized from CLAUDE.md:*

#### `Document.sections[].blocks` Is the Source of Truth

**Decision:** The durable document model is `Document.sections[].blocks`. Data-source adapters (`SectionDataSource`, `PageScopedDataSource`, `FragmentDataSource`, `BlockDataSource`, `HeaderFooterDataSource`) are editing bridges only. Layout, TOC, export, preview, and read paths consume `Document.sections` directly, not cached editor data sources.

**Why:** Multiple scoped data sources are needed so page mode, continuous mode, and fragment-level editing can each present the right editing shape, but allowing those caches to become accidental sources of truth would fork the model and corrupt reads. One durable model keeps export, preview, and layout consistent.

**Trade-offs accepted:** Scoped adapters add surface area that must stay synchronized with the model. Contributors must know which adapter to pick and must not write back through caches.

---

#### Optional Capabilities Live in Separate Products

**Decision:** Export, preview-backed attachments, and advanced grid table editing each live in their own product (`DocumentPrimitiveExport`, `DocumentPrimitivePreview`, `DocumentPrimitiveGrid`) rather than being absorbed into the core `DocumentPrimitive` target.

**Why:** Not every host wants `ExportKit`, `PreviewPrimitive`, or `GridPrimitive` in its dependency graph. Splitting these keeps the core target lighter, keeps macOS-only grid editing off iOS hosts, and lets hosts opt into heavier capabilities deliberately. The core target also stays cross-platform (macOS 15+, iOS 17+) without pulling in dependencies that aren't available everywhere.

**Trade-offs accepted:** Hosts that want the whole stack have to adopt multiple products. Contributors must resist the temptation to add export, preview, or grid code directly to the core target.

---

#### Reuse Portfolio Primitives for Navigation and Review Chrome

**Decision:** Document navigation and review chrome reuse `SearchPrimitive`, `FilterPrimitive`, `BadgePrimitive`, and `HoverBadgePrimitive` rather than reimplementing bespoke controls.

**Why:** This is a direct expression of the Layered Architecture principle — these primitives already solve search, filter, and badge behavior for the portfolio and benefit from being exercised inside a real document editor.

**Trade-offs accepted:** We accept any friction of wiring in primitives with their own conventions rather than building one-off controls tuned exactly for this package.

---

*Add more entries as decisions are made.*

---

## Tech Stack and Platform Choices

**Platform:** macOS 15+ and iOS 17+ (cross-platform Swift package). `DocumentPrimitiveGrid` is conditionally macOS-only.
**Primary language:** Swift 6.0
**UI framework:** SwiftUI (with internal platform bridges)
**Data layer:** Value-type `Document` model; persistence is owned by the host app

**Why this stack:** DocumentPrimitive is a foundation package for Apple-platform editor stacks. Swift 6 with SwiftUI keeps the package consistent with the rest of the portfolio's editor layer. The value-type `Document` model is portable, testable, and serialization-friendly, which is what a document layer needs if it is going to be embedded in many different host apps.

---

## Who This Is Built For

*Who are the primary users or operators of this software? Humans, AI agents, or both? This shapes everything from UI density to conductorship defaults.*

[ ] Primarily humans
[ ] Primarily AI agents
[ ] Both, roughly equally
[ ] Both — humans build it, AIs operate it
[X] Both — AIs build it, humans operate it

**Notes:** This is a foundation package consumed by host apps. Humans write in the document editors built on top of it; AIs build and maintain the package itself, and operate the editors that host it through AISeamsKit seams in those host apps.

---

## Where This Is Going

[To be filled in as project direction crystallizes.]

---

## Open Questions

*None recorded yet.*

---

## Amendment Process

Use this process whenever a foundational decision changes or a new decision is added.

1. Update the relevant section in this constitution in the same change as the code/docs that motivated the update.
2. For each new or changed decision entry, include:
   - **Decision**
   - **Why**
   - **Trade-offs accepted**
   - **Revisit trigger** (what condition should cause reconsideration)
3. Add a matching row in the **Decision Log** with date and a concise summary.
4. If the amendment changes implementation rules, update `AGENTS.md` and any affected style guide files in the same change.
5. Record who approved the amendment (human + AI collaborator when applicable).

Minor wording clarifications that do not change meaning do not require a new decision entry, but should still be noted in the Decision Log.

---

## Decision Log

*Brief chronological record of significant decisions. Add an entry whenever a non-trivial decision is made that isn't already captured in the sections above.*

| Date | Decision | Decided by |
|------|----------|------------|
| 2026-04-16 | Constitution created and Founding Principles established | Both |
