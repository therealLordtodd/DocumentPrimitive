# DocumentPrimitive Working Guide

## Purpose
DocumentPrimitive is the first-class word processor layer built on `RichTextPrimitive`. It owns documents, sections, page setup, columns, headers/footers, footnotes, table-of-contents generation, list numbering, field codes, page layout, document editor state, print preview, export mapping, the optional preview integration target, and the optional grid table upgrade target.

## Key Directories
- `Sources/DocumentPrimitive`: Core document model, services, layout engine, editor state, data-source adapters, and SwiftUI views.
- `Sources/DocumentPrimitiveExport`: Markdown, HTML, PDF exporters and `BlockToExportMapper`.
- `Sources/DocumentPrimitivePreview`: PreviewPrimitive-backed attachment resolution, inline preview views, and galleries.
- `Sources/DocumentPrimitiveGrid`: Conditional GridPrimitive table integration.
- `Tests/DocumentPrimitiveTests`: Core model, layout, services, and editor-adapter tests.
- `Tests/DocumentPrimitiveExportTests`: Export mapping and format tests.
- `Tests/DocumentPrimitivePreviewTests`: Attachment resolver coverage for preview integration.
- `Tests/DocumentPrimitiveGridTests`: Grid adapter tests.

## Architecture Rules
- `Document.sections[].blocks` is the source of truth. Data-source adapters such as `SectionDataSource`, `PageScopedDataSource`, `FragmentDataSource`, `BlockDataSource`, and `HeaderFooterDataSource` are editing bridges only.
- `PageLayoutEngine`, TOC generation, export, preview, and read paths must consume `Document.sections` directly, not cached editor data sources.
- Page mode should use the page-scoped editor surface whenever the page is a single-column, whole-block editing surface. Reserve fragment and block editors for genuinely split or repeated placements.
- Core `DocumentPrimitive` must remain cross-platform for macOS 14 and iOS 15 and must not depend on `GridPrimitive`.
- Keep advanced grid editing in `DocumentPrimitiveGrid`. Grid source should stay conditional on GridPrimitive availability.
- Keep preview-backed attachment and gallery code in `DocumentPrimitivePreview` so the core target stays lighter and free of `PreviewPrimitive`.
- `DocumentPrimitivePreview` should preserve remote attachment URLs and let `PreviewPrimitive` surface capability limits instead of dropping assets during resolution.
- Preserve true first, primary odd, and even header/footer variants through `HeaderFooterConfig`, `HeaderFooterSlot`, layout, preview, and export.
- Reuse `SearchPrimitive`, `FilterPrimitive`, `BadgePrimitive`, and `HoverBadgePrimitive` for document navigation and review chrome instead of recreating bespoke controls.
- Keep `DocumentPrimitiveExport` dependent on `ExportKit` and `PaginationPrimitive`, not on UI-only code.

## Performance Posture

- **Hot paths.** `PageLayoutEngine.reflow` runs on every block mutation in the editor; `PageView` body re-evaluates per scroll frame; `BlockToExportMapper` runs once per export; `DocumentEditorState` mutations run per keystroke.
- **Concurrency model.** `PageLayoutEngine` and `DocumentEditorState` are `@MainActor @Observable`. Document value types (`Document`, `DocumentSection`, blocks) are `Sendable` and `Codable`. Export is synchronous on the calling actor.
- **Allocation discipline.** `reflow` allocates a fresh `[ComputedPage]` and a fresh `blockPageMap` dictionary per call; acceptable because reflow happens on edit, not per frame, and reuse would require diff-aware invalidation. The `descriptorByItemID` dictionary is per-section, not per-page.
- **Test speed.** `swift test` runs 118 tests in ~0.26s — every suite under 0.3s. PDF-export suite is the longest at 0.26s and represents real PDF rendering. Reviewed 2026-04-29 (Speed & Clarity audit round 1).

## Testing
- Run `swift test` before committing.
- Run iOS simulator builds for `DocumentPrimitive`, `DocumentPrimitiveExport`, and `DocumentPrimitive-Package` after package graph or cross-platform code changes.
- Add preview resolver coverage when changing image/file/embed attachment handling, including inline, local, and remote assets.
- Add page-mode coverage when changing unified page editing versus fragment/block fallback behavior.
- Add anchor-navigation coverage when changing comment, bookmark, or tracked-change focus flows.
- Add `PageLayoutEngineTests` for flow, section breaks, columns, footnotes, and header/footer variant behavior.
- Add export tests whenever mapper, Markdown, HTML, PDF, fields, footnotes, or header/footer rendering changes.

---

## Family Membership — Document Editor

This primitive is a member of the Document Editor primitive family. It participates in shared conventions and consumes or publishes cross-primitive types used by the rich-text / document / editor stack.

**Before modifying public API, shared conventions, or cross-primitive types, consult:**
- `../RichTextEditorKit/docs/plans/2026-04-19-document-editor-dependency-audit.md` — who depends on whom, who uses which conventions
- `/Users/todd/Building - Apple/Packages/CONVENTIONS/` — shared patterns this primitive participates in
- `./MEMBERSHIP.md` in this primitive's root — specific list of conventions, shared types, and sibling consumers

**Changes that alter public API, shared type definitions, or convention contracts MUST include a ripple-analysis section in the commit or PR description** identifying which siblings could be affected and how.

Standalone consumers (apps just importing this primitive) are unaffected by this discipline — it applies only to modifications to the primitive itself.
