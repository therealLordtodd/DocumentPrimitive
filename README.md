# DocumentPrimitive

DocumentPrimitive provides a word-processor document layer on top of `RichTextPrimitive`. It adds sections, pages, columns, first/odd/even headers and footers, footnotes, TOC/list/field services, page and continuous editing surfaces, document-level review and search navigation, export mapping, optional preview integration, and optional GridPrimitive table editing.

## Products
- `DocumentPrimitive`: Cross-platform core document model, services, layout, state, and views.
- `DocumentPrimitiveExport`: Markdown, HTML, and PDF exporters using `ExportKit`.
- `DocumentPrimitivePreview`: Attachment and gallery rendering built on `PreviewPrimitive`.
- `DocumentPrimitiveGrid`: Conditional advanced table editing integration for hosts that can import GridPrimitive.

## Quick Start

```swift
import DocumentPrimitive
import RichTextPrimitive
import SwiftUI

let section = DocumentSection(
    blocks: [
        Block(
            type: .heading,
            content: .heading(.plain("Quarterly Report"), level: 1)
        ),
        Block(
            type: .paragraph,
            content: .text(.plain("The opening paragraph."))
        ),
    ],
    pageSetup: .letter,
    headerFooter: HeaderFooterConfig(
        header: HeaderFooter(center: [TextRun(text: "{title}")]),
        footer: HeaderFooter(center: [TextRun(text: "{pageNumber}")])
    )
)

let document = Document(title: "Quarterly Report", sections: [section])
let state = DocumentEditorState(document: document)

struct DocumentHost: View {
    let state: DocumentEditorState

    var body: some View {
        DocumentEditor(state: state)
    }
}
```

## Key Types
- `Document`, `DocumentSettings`, and `DocumentSection`: Source-of-truth document model.
- `PageSetup`, `ColumnLayout`, `HeaderFooterConfig`, `HeaderFooter`, `FootnoteConfig`, and `TableOfContentsConfig`: Page and document configuration.
- `DocumentStyleLibrary`: Standard paragraph, character, list, and table styles.
- `DocumentEditorState`: Main editor state with layout, page navigation, data-source adapters, comments, bookmarks, and tracked changes.
- `PageLayoutEngine`, `ComputedPage`, `BlockRange`, and `BlockFragmentPlacement`: Section-to-page layout.
- `TOCGenerator`, `FootnoteManager`, `ListNumberingEngine`, and `FieldCodeResolver`: Document services.
- `DocumentEditor`, `PageView`, `PrintPreview`, `DocumentToolbar`, `DocumentSearchPopover`, and `ReviewNavigatorPopover`: SwiftUI views.
- `BlockToExportMapper`, `MarkdownExporter`, `HTMLExporter`, and `PDFExporter`: Export implementation surface.
- `DocumentPreviewAttachmentResolver`, `DocumentAttachmentPreview`, and `DocumentAttachmentGallery`: Optional preview-focused document attachment surface.
- `GridDocumentEditor`, `GridPrintPreview`, `GridTableAdapter`, and `GridTableEditor`: Optional grid table integration.

## Source Of Truth

`Document.sections[].blocks` is the authoritative store. The editor exposes rich text adapters for specific editing scopes:

- `SectionDataSource` edits a whole section.
- `PageScopedDataSource` edits a whole visible page surface when that page is a safe whole-block editor.
- `FragmentDataSource` edits a page fragment of a split block.
- `BlockDataSource` edits a single block.
- `HeaderFooterDataSource` edits a specific first, primary, or even header/footer slot.

Layout, TOC generation, export, and preview should read the document model directly rather than treating data sources as durable state.

## Page Mode Editing

Page mode prefers a single page-scoped `RichTextEditor` whenever the computed page is a single-column, whole-block editing surface. That keeps body editing on the same cross-block selection and keyboard path as the continuous editor.

When the page contains split placements or repeated placements for the same block, `PageView` falls back to `FragmentDataSource` and `BlockDataSource` editors so pagination stays faithful to the rendered layout. Headers and footers remain separate `RichTextEditor` instances and still support independent first-page, primary, and even-page slots.

## Header And Footer Variants

`HeaderFooterConfig` supports separate first-page, primary odd-page, and even-page headers and footers. `HeaderFooterSlot` exposes left, center, and right editable slots for each variant, including `evenHeaderLeft`, `evenHeaderCenter`, `evenHeaderRight`, `evenFooterLeft`, `evenFooterCenter`, and `evenFooterRight`.

## Ruler Integration

`DocumentEditor` derives its ruler from `RulerPrimitive` via `DocumentRulerSnapshot`. The snapshot reflects the active section's page width, margins, column guides, and focused-block indent markers; dragging the left or right margin marker writes a section-specific `PageSetup` and reflows the layout.

## Section Reordering

In continuous and canvas modes, `DocumentEditor` exposes a dedicated drag handle for each section. The handle uses `DragAndDropPrimitive` while `DocumentEditorState.moveSections(from:to:)` updates the authoritative `document.sections` array and reflows pagination.

## Review And Navigation

Document review and search surfaces are built on shared primitives instead of bespoke controls. `ReviewNavigatorPopover` uses `FilterPrimitive` for structured review filters, while page chrome and review markers use `BadgePrimitive` and `HoverBadgePrimitive`. `DocumentSearchPopover` uses `SearchPrimitive` for document-wide navigation across headings, comments, bookmarks, and tracked changes.

## Export

```swift
import DocumentPrimitiveExport
import ExportKit

let exportDocument = BlockToExportMapper().map(document: document)
let data = try await MarkdownExporter().export(exportDocument, options: ExportOptions())
```

Use `BlockToExportMapper` to convert a `Document` into `ExportableDocument`. The exporters preserve sections, page metrics, field codes, headers/footers, footnotes, tables, images, and inline text attributes supported by `ExportKit`.

## Preview Integration

```swift
import DocumentPrimitive
import DocumentPrimitivePreview

let attachments = DocumentPreviewAttachmentResolver().attachments(in: document)
let gallery = DocumentAttachmentGallery(attachments: attachments)
```

Use `DocumentPrimitivePreview` when a host wants preview-backed handling for image, file, and embed-style blocks without adding `PreviewPrimitive` directly to the core editor dependency surface. The resolver keeps inline data, local file URLs, and remote URLs intact so `PreviewPrimitive` can either render them or surface capability limitations instead of silently dropping attachments.

## Testing

Run:

```bash
swift test
```

For cross-platform package graph checks, run:

```bash
xcodebuild build -scheme DocumentPrimitive -destination 'generic/platform=iOS Simulator' -quiet
xcodebuild build -scheme DocumentPrimitiveExport -destination 'generic/platform=iOS Simulator' -quiet
xcodebuild build -scheme DocumentPrimitive-Package -destination 'generic/platform=iOS Simulator' -quiet
```

When changing page-mode behavior, add coverage for unified page editing versus fragment fallback. When changing preview resolution, cover inline, local, and remote attachment sources.
