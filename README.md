# DocumentPrimitive

`DocumentPrimitive` is the word-processor layer that sits above `RichTextPrimitive`.

It takes block-based editing and adds document structure:

- sections
- page setup
- columns
- headers and footers
- footnotes
- layout and page flow
- document-level review and navigation
- export and preview integration
- optional grid-backed table editing

Use it when your app is building a real document editor or print-oriented writing surface.

Do not use it when you only need rich text editing inside a single continuous surface. In that case, `RichTextPrimitive` is the better starting point.

## Products

`DocumentPrimitive` is split into four products:

### `DocumentPrimitive`

The core document model, state, layout engine, services, and editor views.

### `DocumentPrimitiveExport`

Exporters and mapping helpers built on `ExportKit`.

### `DocumentPrimitivePreview`

Attachment preview and gallery helpers built on `PreviewPrimitive`.

### `DocumentPrimitiveGrid`

Optional advanced table editing built on `GridPrimitive`, available only where the grid stack is available.

That split is important. Most hosts need the core product first and then opt into export, preview, or grid behavior only when they actually need it.

## Core model

### `Document`

The top-level value-type document.

It owns:

- title
- sections
- settings
- styles

### `DocumentSection`

Each section owns its own content and page-level configuration:

- blocks
- page setup
- header/footer config
- column layout
- footnotes

This is a useful boundary because real word-processor behavior often changes at the section level, not only at the document level.

### `DocumentEditorState`

`DocumentEditorState` is the main runtime state object.

It owns:

- the live `Document`
- the top-level `RichTextState`
- current page and section
- review and search state
- bookmark, comment, and change-tracking stores
- the `PageLayoutEngine`
- scoped data sources for section, page, fragment, block, and header/footer editing

If you only remember one type from this package, it should usually be `DocumentEditorState`.

### `PageLayoutEngine`

The layout engine turns document content into computed pages.

That is what powers:

- page mode
- print preview
- page navigation
- header/footer resolution
- fragment-aware editing fallbacks

## Quick start

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
    pageSetup: .letter
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

That gives you a real document host with layout-aware editing behavior, not just a rich-text surface.

## Concrete examples

### 1. Drive the full editor

```swift
DocumentEditor(state: state)
```

This is the standard entry point when your app wants the full document-editing experience.

### 2. Export to markdown

```swift
import DocumentPrimitiveExport

let exportDocument = BlockToExportMapper().map(document: state.document)
let data = try await MarkdownExporter().export(exportDocument, options: ExportOptions())
```

This keeps export concerns out of the core editor product while preserving the document model as the source of truth.

### 3. Resolve attachments for preview

```swift
import DocumentPrimitivePreview

let attachments = DocumentPreviewAttachmentResolver().attachments(in: state.document)
```

Use this when your app wants galleries or inline attachment browsing without hard-wiring preview logic into the editor core.

### 4. Use the attachment gallery

```swift
import DocumentPrimitivePreview

DocumentAttachmentGallery(
    attachments: DocumentPreviewAttachmentResolver().attachments(in: state.document)
)
```

### 5. Add advanced table editing on supporting hosts

```swift
import DocumentPrimitiveGrid

GridDocumentEditor(state: state)
```

This is the optional path for hosts that want heavier spreadsheet-style table editing inside documents.

### 6. Work with the document model directly

```swift
state.document.sections.append(
    DocumentSection(
        blocks: [
            Block(type: .paragraph, content: .text(.plain("Appendix notes.")))
        ],
        pageSetup: .a4
    )
)
```

That is a good reminder that the durable state is the document model, not the temporary editor view layer.

## How the editor is structured

One of the best parts of this package is that it does not force every editing scenario through a single giant data source.

`DocumentEditorState` creates scoped adapters depending on what is being edited:

- `SectionDataSource`
- `PageScopedDataSource`
- `FragmentDataSource`
- `BlockDataSource`
- `HeaderFooterDataSource`

That matters because page mode and continuous mode are not the same editing problem.

In broad terms:

- continuous and canvas views favor section-oriented editing
- page mode tries to edit whole page surfaces when that is safe
- fragment or block-level editors are used when pagination splits content in ways that make whole-page editing misleading

## How to wire it into your app

### Keep `Document` as the source of truth

Your host app should think in terms of:

- a value-type `Document`
- a long-lived `DocumentEditorState`
- optional product add-ons for export, preview, and grid editing

That is cleaner than letting page views or scoped data sources become accidental sources of truth.

### Let `DocumentEditorState` own layout and editing adapters

Do not try to manually assemble page-scoped or fragment-scoped editing unless you have a very specific reason.

The package already centralizes:

- page reflow
- current-page tracking
- section tracking
- derived rich-text states
- bookmark/comment/change synchronization

### Treat this as the document layer, not the persistence layer

`DocumentPrimitive` handles document structure and editor behavior.

Your app still owns:

- file formats
- autosave policy
- collaboration
- project/library management
- cloud sync
- app navigation and commands

### Add optional products deliberately

Good default progression:

1. `DocumentPrimitive`
2. `DocumentPrimitiveExport` if you need export
3. `DocumentPrimitivePreview` if you need attachment preview
4. `DocumentPrimitiveGrid` only if advanced table editing is truly needed

That keeps the package graph honest and avoids dragging every optional capability into every host.

## A strong host-app pattern

```swift
@MainActor
final class ReportEditorController {
    let state: DocumentEditorState

    init(document: Document) {
        self.state = DocumentEditorState(document: document)
    }

    func exportMarkdown() async throws -> Data {
        let exportDocument = BlockToExportMapper().map(document: state.document)
        return try await MarkdownExporter().export(exportDocument, options: ExportOptions())
    }
}
```

Then the SwiftUI layer can render `DocumentEditor(state:)` while the controller handles app-level orchestration.

## Constraints and caveats

- macOS 15+ and iOS 17+ for the main package
- `DocumentPrimitiveGrid` is effectively a heavier optional path tied to the grid stack
- the package is layout- and document-structure aware, so it is more opinionated than `RichTextPrimitive`
- the core product does not try to absorb export, preview, or advanced grid editing directly

## When it is the right fit

`DocumentPrimitive` is a strong fit for:

- word processors
- report editors
- print-oriented writing tools
- long-form structured document apps
- review and annotation workflows

It is less useful for:

- note editors with no page model
- simple blog post or markdown editors
- apps that do not need section/page/header/footer behavior
