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

    @Test func exportsSeparateOddAndEvenChromeToHTML() async throws {
        let document = Document(
            title: "Draft",
            sections: [
                DocumentSection(
                    blocks: [
                        Block(type: .paragraph, content: .text(.plain("Body"))),
                    ],
                    headerFooter: HeaderFooterConfig(
                        header: HeaderFooter(center: [TextRun(text: "Odd header")]),
                        footer: HeaderFooter(right: [TextRun(text: "Odd footer")]),
                        evenHeader: HeaderFooter(center: [TextRun(text: "Even header {PAGE}")]),
                        evenFooter: HeaderFooter(left: [TextRun(text: "Even footer")]),
                        differentOddEven: true
                    ),
                    startPageNumber: 5
                ),
            ]
        )

        let exportable = BlockToExportMapper().map(document: document)
        let data = try await HTMLExporter().export(exportable, options: ExportOptions())
        let html = String(decoding: data, as: UTF8.self)

        #expect(html.contains("data-page-variant=\"odd\""))
        #expect(html.contains("data-page-variant=\"even\""))
        #expect(html.contains("Odd header"))
        #expect(html.contains("Even header 6"))
        #expect(html.contains("Even footer"))
    }

    @Test func exportsSeparateFirstPageChromeToHTML() async throws {
        let document = Document(
            title: "Draft",
            sections: [
                DocumentSection(
                    blocks: [
                        Block(type: .paragraph, content: .text(.plain("Body"))),
                    ],
                    headerFooter: HeaderFooterConfig(
                        firstHeader: HeaderFooter(center: [TextRun(text: "First header {PAGE}")]),
                        firstFooter: HeaderFooter(center: [TextRun(text: "First footer")]),
                        header: HeaderFooter(center: [TextRun(text: "Default header")]),
                        footer: HeaderFooter(center: [TextRun(text: "Default footer")]),
                        differentFirstPage: true
                    ),
                    startPageNumber: 3
                ),
            ]
        )

        let exportable = BlockToExportMapper().map(document: document)
        let data = try await HTMLExporter().export(exportable, options: ExportOptions())
        let html = String(decoding: data, as: UTF8.self)

        #expect(html.contains("data-page-variant=\"first\""))
        #expect(html.contains("First header 3"))
        #expect(html.contains("First footer"))
        #expect(html.contains("Default header"))
    }
}
