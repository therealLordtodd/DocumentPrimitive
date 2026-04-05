import ExportKit
import Foundation
import Testing
@testable import DocumentPrimitive
@testable import DocumentPrimitiveExport
@testable import RichTextPrimitive

@Suite("HTMLExporter Tests")
struct HTMLExporterTests {
    @Test func exportsCommonBlocksToHTML() async throws {
        let document = Document(
            title: "Draft",
            sections: [
                DocumentSection(
                    blocks: [
                        Block(type: .heading, content: .heading(.plain("Intro"), level: 2)),
                        Block(type: .paragraph, content: .text(TextContent(runs: [TextRun(text: "Hello", attributes: TextAttributes(italic: true))]))),
                    ]
                ),
            ]
        )

        let exportable = BlockToExportMapper().map(document: document)
        let data = try await HTMLExporter().export(exportable, options: ExportOptions())
        let html = String(decoding: data, as: UTF8.self)

        #expect(html.contains("<h2>Intro</h2>"))
        #expect(html.contains("<em>Hello</em>"))
    }

    @Test func exportsSectionChromeAndFootnotesToHTML() async throws {
        let document = Document(
            title: "Draft",
            sections: [
                DocumentSection(
                    blocks: [
                        Block(id: "anchor", type: .paragraph, content: .text(.plain("Body"))),
                    ],
                    headerFooter: HeaderFooterConfig(
                        header: HeaderFooter(center: [TextRun(text: "Hdr {PAGE}")]),
                        footer: HeaderFooter(right: [TextRun(text: "{TITLE}")])
                    ),
                    startPageNumber: 3,
                    footnotes: [
                        Footnote(anchorBlockID: "anchor", content: .plain("Footnote body")),
                    ]
                ),
            ]
        )

        let exportable = BlockToExportMapper().map(document: document)
        let data = try await HTMLExporter().export(exportable, options: ExportOptions())
        let html = String(decoding: data, as: UTF8.self)

        #expect(html.contains("document-section"))
        #expect(html.contains("Hdr 3"))
        #expect(html.contains(">Draft<"))
        #expect(html.contains("Footnote body"))
        #expect(html.contains("data-anchor-source=\"anchor\""))
    }

    @Test func exportsTableCaptionsToHTML() async throws {
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
        let data = try await HTMLExporter().export(exportable, options: ExportOptions())
        let html = String(decoding: data, as: UTF8.self)

        #expect(html.contains("<caption>Quarterly Results</caption>"))
        #expect(html.contains("<td>Q1</td>"))
    }
}
