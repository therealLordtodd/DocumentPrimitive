# DocumentPrimitive — Document Editor Family Membership

This primitive is a member of the Document Editor primitive family. It sits at the top of the word-processing stack, composing RichText blocks with pagination, sections, headers/footers, review annotations, and export.

## Conventions This Primitive Participates In

- [x] [shared-types](../CONVENTIONS/shared-types-convention.md) — consumes many family + shared-infra types; defines document-structural types
- [ ] [typed-static-constants](../CONVENTIONS/typed-static-constants-convention.md) — not directly
- [x] [document-editor-family-membership](../CONVENTIONS/document-editor-family-membership.md)

## Shared Types This Primitive Defines

- **Document-structural types** — sections, headers/footers, lists, footnotes, fields, print-oriented structure
- Consumed by: `RichTextEditorKit`, hosts

## Shared Types This Primitive Imports

- RichText block model from `RichTextPrimitive`
- Typography types from `TypographyPrimitive` (transitively via RichText)
- Pagination types from `PaginationPrimitive`
- Ruler types from `RulerPrimitive`
- Comment / TrackChanges / Bookmark anchor types (three parallel implementations) from `CommentPrimitive`, `TrackChangesPrimitive`, `BookmarkPrimitive`
- Exporter protocol from `ExportKit`
- Broader shared infra (not family): `GridPrimitive`, `DragAndDropPrimitive`, `FilterPrimitive`, `SearchPrimitive`, `BadgePrimitive`, `HoverBadgePrimitive`, `PreviewPrimitive`

## Siblings That Hard-Depend on This Primitive

- `RichTextEditorKit` — re-exports DocumentPrimitive surface

## Ripple-Analysis Checklist Before Modifying Public API

1. **DocumentPrimitive declares 14 dependencies** — changes here can cascade outward through RichTextEditorKit's re-exports.
2. Changes to document-structural types: affects RichTextEditorKit and hosts consuming the document data model.
3. Changes to how DocumentPrimitive composes siblings (pagination, rulers, anchors): can break rendering in every host.
4. Adding a new sub-dependency: widens the umbrella's ripple surface — coordinate with RichTextEditorKit's re-exports.
5. Consult [dependency audit](../docs/plans/2026-04-19-document-editor-dependency-audit.md) §2 (the full import list is in DocumentPrimitive's Package.swift).
6. Document ripple impact in the commit/PR.

## Scope of Membership

Applies to modifications of DocumentPrimitive's own code. Consumers just importing for their own app are unaffected.
