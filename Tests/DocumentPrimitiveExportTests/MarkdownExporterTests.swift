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

    @Test func exportsRomanDocumentFootnotesToMarkdown() async throws {
        let document = Document(
            title: "Draft",
            sections: [
                DocumentSection(
                    blocks: [Block(id: "anchor-1", type: .paragraph, content: .text(.plain("Body")))],
                    footnotes: [Footnote(anchorBlockID: "anchor-1", content: .plain("First note"))]
                ),
                DocumentSection(
                    blocks: [Block(id: "anchor-2", type: .paragraph, content: .text(.plain("More body")))],
                    footnotes: [Footnote(anchorBlockID: "anchor-2", content: .plain("Second note"))]
                ),
            ],
            settings: DocumentSettings(
                footnoteConfig: FootnoteConfig(
                    placement: .documentEnd,
                    numberingStyle: .roman,
                    restartPerSection: false
                )
            )
        )

        let exportable = BlockToExportMapper().map(document: document)
        let data = try await MarkdownExporter().export(exportable, options: ExportOptions())
        let markdown = String(decoding: data, as: UTF8.self)

        #expect(markdown.contains("I. First note"))
        #expect(markdown.contains("II. Second note"))
    }

    @Test func exportsSeparateOddAndEvenChromeToMarkdown() async throws {
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
        let data = try await MarkdownExporter().export(exportable, options: ExportOptions())
        let markdown = String(decoding: data, as: UTF8.self)

        #expect(markdown.contains("_Odd Header:_ Odd header"))
        #expect(markdown.contains("_Even Header:_ Even header 6"))
        #expect(markdown.contains("_Odd Footer:_ Odd footer"))
        #expect(markdown.contains("_Even Footer:_ Even footer"))
    }

    @Test func exportsSeparateFirstPageChromeToMarkdown() async throws {
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
        let data = try await MarkdownExporter().export(exportable, options: ExportOptions())
        let markdown = String(decoding: data, as: UTF8.self)

        #expect(markdown.contains("_First Header:_ First header 3"))
        #expect(markdown.contains("_First Footer:_ First footer"))
        #expect(markdown.contains("_Header:_ Default header"))
    }

    @Test func resolvesRepresentativePageNumbersForFirstOddAndEvenChrome() async throws {
        let document = Document(
            title: "Draft",
            sections: [
                DocumentSection(
                    blocks: [
                        Block(type: .paragraph, content: .text(.plain("Body"))),
                    ],
                    headerFooter: HeaderFooterConfig(
                        firstHeader: HeaderFooter(center: [TextRun(text: "First {PAGE}")]),
                        header: HeaderFooter(center: [TextRun(text: "Odd {PAGE}")]),
                        evenHeader: HeaderFooter(center: [TextRun(text: "Even {PAGE}")]),
                        differentFirstPage: true,
                        differentOddEven: true
                    ),
                    startPageNumber: 10
                ),
            ]
        )

        let exportable = BlockToExportMapper().map(document: document)
        let data = try await MarkdownExporter().export(exportable, options: ExportOptions())
        let markdown = String(decoding: data, as: UTF8.self)

        #expect(markdown.contains("_First Header:_ First 10"))
        #expect(markdown.contains("_Odd Header:_ Odd 11"))
        #expect(markdown.contains("_Even Header:_ Even 12"))
    }

    @Test func laterSectionsUsePaginatedStartPagesInMarkdown() async throws {
        let longText = String(repeating: "Long body copy ", count: 2500)
        let document = Document(
            title: "Draft",
            sections: [
                DocumentSection(
                    blocks: [
                        Block(type: .paragraph, content: .text(.plain(longText))),
                    ]
                ),
                DocumentSection(
                    blocks: [
                        Block(type: .paragraph, content: .text(.plain("Tail section"))),
                    ],
                    headerFooter: HeaderFooterConfig(
                        header: HeaderFooter(center: [TextRun(text: "Hdr {PAGE}/{NUMPAGES}")])
                    )
                ),
            ]
        )

        let exportable = BlockToExportMapper().map(document: document)
        let metrics = await ExportPageMetricsResolver().resolve(document: exportable)
        let data = try await MarkdownExporter().export(exportable, options: ExportOptions())
        let markdown = String(decoding: data, as: UTF8.self)

        #expect(metrics.sectionStartPages.count == 2)
        #expect(metrics.sectionStartPages[1] > 2)
        #expect(markdown.contains("_Header:_ Hdr \(metrics.sectionStartPages[1])/\(metrics.totalPageCount)"))
        #expect(markdown.contains("<!-- section 2 start-page: \(metrics.sectionStartPages[1]) columns: 1 -->"))
    }
}
