import ExportKit
import Foundation
import Testing
@testable import DocumentPrimitive
@testable import DocumentPrimitiveExport
@testable import RichTextPrimitive

@Suite("MarkdownExporter Tests")
struct MarkdownExporterTests {
    @Test func exportsCommonBlocksToMarkdown() async throws {
        let document = Document(
            title: "Draft",
            sections: [
                DocumentSection(
                    blocks: [
                        Block(type: .heading, content: .heading(.plain("Intro"), level: 1)),
                        Block(type: .paragraph, content: .text(TextContent(runs: [TextRun(text: "Hello", attributes: TextAttributes(bold: true))]))),
                        Block(type: .list, content: .list(.plain("Item"), style: .bullet, indentLevel: 0)),
                    ]
                ),
            ]
        )

        let exportable = BlockToExportMapper().map(document: document)
        let data = try await MarkdownExporter().export(exportable, options: ExportOptions())
        let markdown = String(decoding: data, as: UTF8.self)

        #expect(markdown.contains("# Intro"))
        #expect(markdown.contains("**Hello**"))
        #expect(markdown.contains("- Item"))
    }

    @Test func exportsDocumentEndFootnotesAndResolvedChromeToMarkdown() async throws {
        let document = Document(
            title: "Draft",
            sections: [
                DocumentSection(
                    blocks: [
                        Block(id: "anchor-1", type: .paragraph, content: .text(.plain("Body"))),
                    ],
                    headerFooter: HeaderFooterConfig(
                        header: HeaderFooter(center: [TextRun(text: "Hdr {PAGE}")])
                    ),
                    startPageNumber: 4,
                    footnotes: [
                        Footnote(anchorBlockID: "anchor-1", content: .plain("First note")),
                    ]
                ),
                DocumentSection(
                    blocks: [
                        Block(id: "anchor-2", type: .paragraph, content: .text(.plain("More body"))),
                    ],
                    footnotes: [
                        Footnote(anchorBlockID: "anchor-2", content: .plain("Second note")),
                    ]
                ),
            ],
            settings: DocumentSettings(
                footnoteConfig: FootnoteConfig(placement: .documentEnd, restartPerSection: false)
            )
        )

        let exportable = BlockToExportMapper().map(document: document)
        let data = try await MarkdownExporter().export(exportable, options: ExportOptions())
        let markdown = String(decoding: data, as: UTF8.self)

        #expect(markdown.contains("_Header:_ Hdr 4"))
        #expect(markdown.contains("## Document Footnotes"))
        #expect(markdown.contains("1. First note"))
        #expect(markdown.contains("2. Second note"))
        #expect(markdown.contains("<!-- section 1 start-page: 4 columns: 1 -->"))
    }

    @Test func exportsTableCaptionsToMarkdown() async throws {
        let document = Document(
            title: "Draft",
            sections: [
                DocumentSection(
                    blocks: [
                        Block(
                            type: .table,
                            content: .table(
                                TableContent(
                                    rows: [
                                        [.plain("Quarter"), .plain("Revenue")],
                                        [.plain("Q1"), .plain("$120k")],
                                    ],
                                    caption: .plain("Quarterly Results")
                                )
                            )
                        ),
                    ]
                ),
            ]
        )

        let exportable = BlockToExportMapper().map(document: document)
        let data = try await MarkdownExporter().export(exportable, options: ExportOptions())
        let markdown = String(decoding: data, as: UTF8.self)

        #expect(markdown.contains("_Quarterly Results_"))
        #expect(markdown.contains("| Quarter | Revenue |"))
        #expect(markdown.contains("| --- | --- |"))
    }
}
