# DocumentPrimitive Working Guide

## Purpose
DocumentPrimitive is the first-class word processor layer built on `RichTextPrimitive`. It owns documents, sections, page setup, columns, headers/footers, footnotes, table-of-contents generation, list numbering, field codes, page layout, document editor state, print preview, export mapping, and the optional grid table upgrade target.

## Key Directories
- `Sources/DocumentPrimitive`: Core document model, services, layout engine, editor state, data-source adapters, and SwiftUI views.
- `Sources/DocumentPrimitiveExport`: Markdown, HTML, PDF exporters and `BlockToExportMapper`.
- `Sources/DocumentPrimitiveGrid`: Conditional GridPrimitive table integration.
- `Tests/DocumentPrimitiveTests`: Core model, layout, services, and editor-adapter tests.
- `Tests/DocumentPrimitiveExportTests`: Export mapping and format tests.
- `Tests/DocumentPrimitiveGridTests`: Grid adapter tests.

## Architecture Rules
- `Document.sections[].blocks` is the source of truth. Data-source adapters such as `SectionDataSource`, `PageScopedDataSource`, `FragmentDataSource`, `BlockDataSource`, and `HeaderFooterDataSource` are editing bridges only.
- `PageLayoutEngine`, TOC generation, export, preview, and read paths must consume `Document.sections` directly, not cached editor data sources.
- Core `DocumentPrimitive` must remain cross-platform for macOS 15 and iOS 17 and must not depend on `GridPrimitive`.
- Keep advanced grid editing in `DocumentPrimitiveGrid`. Grid source should stay conditional on GridPrimitive availability.
- Preserve true first, primary odd, and even header/footer variants through `HeaderFooterConfig`, `HeaderFooterSlot`, layout, preview, and export.
- Keep `DocumentPrimitiveExport` dependent on `ExportKit` and `PaginationPrimitive`, not on UI-only code.

## Testing
- Run `swift test` before committing.
- Run iOS simulator builds for `DocumentPrimitive`, `DocumentPrimitiveExport`, and `DocumentPrimitive-Package` after package graph or cross-platform code changes.
- Add `PageLayoutEngineTests` for flow, section breaks, columns, footnotes, and header/footer variant behavior.
- Add export tests whenever mapper, Markdown, HTML, PDF, fields, footnotes, or header/footer rendering changes.
