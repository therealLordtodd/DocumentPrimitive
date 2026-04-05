import CoreGraphics
import ExportKit
import Foundation
import Testing
@testable import DocumentPrimitive
@testable import DocumentPrimitiveExport
@testable import RichTextPrimitive

@Suite("BlockToExportMapper Tests")
struct BlockToExportMapperTests {
    @Test func mapsSectionMetadataForExport() {
        let document = Document(
            title: "Draft",
            sections: [
                DocumentSection(
                    blocks: [
                        Block(type: .heading, content: .heading(.plain("Intro"), level: 1)),
                        Block(type: .paragraph, content: .text(.plain("Body"))),
                    ],
                    pageSetup: PageSetup(pageSize: .a4),
                    headerFooter: HeaderFooterConfig(
                        header: HeaderFooter(center: [TextRun(text: "Hdr {PAGE}")]),
                        footer: HeaderFooter(right: [TextRun(text: "{TITLE}")]),
                        differentFirstPage: true,
                        differentOddEven: true
                    ),
                    columnLayout: ColumnLayout(columns: 2, spacing: 24),
                    startPageNumber: 5,
                    footnotes: [
                        Footnote(anchorBlockID: "IntroAnchor", content: .plain("Footnote body")),
                    ]
                ),
            ]
        )

        var updatedDocument = document
        updatedDocument.sections[0].blocks[0] = Block(
            id: "IntroAnchor",
            type: .heading,
            content: .heading(.plain("Intro"), level: 1)
        )

        let exportable = BlockToExportMapper().map(document: updatedDocument)
        let section = try! #require(exportable.sections.first)

        #expect(exportable.blocks.count == 2)
        #expect(exportable.sections.count == 1)
        #expect(exportable.footnoteConfiguration?.placement == .pageBottom)
        #expect(section.blocks.count == 2)
        #expect(section.blocks.first?.sourceIdentifier == "IntroAnchor")
        #expect(section.pageTemplate.columns == 2)
        #expect(section.pageTemplate.columnSpacing == 24)
        #expect(section.startPageNumber == 5)
        #expect(section.headerFooter?.differentFirstPage == true)
        #expect(section.headerFooter?.differentOddEven == true)
        #expect(section.headerFooter?.header?.center.plainText == "Hdr {PAGE}")
        #expect(section.headerFooter?.footer?.right.plainText == "{TITLE}")
        #expect(section.footnotes.first?.anchorSourceIdentifier == "IntroAnchor")
        #expect(section.footnotes.first?.content.plainText == "Footnote body")
    }

    @Test func preservesTableAndImageMetadataForExport() {
        let imageSize = CGSize(width: 320, height: 180)
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
                                    columnWidths: [2, 1],
                                    caption: .plain("Quarterly Results")
                                )
                            )
                        ),
                        Block(
                            type: .image,
                            content: .image(
                                ImageContent(
                                    data: Data([0x89, 0x50, 0x4E, 0x47]),
                                    altText: "Revenue chart",
                                    size: imageSize
                                )
                            )
                        ),
                    ]
                ),
            ]
        )

        let exportable = BlockToExportMapper().map(document: document)
        #expect(exportable.blocks.count == 2)

        guard case let .table(rows, columnWidths, caption) = exportable.blocks[0].content else {
            Issue.record("Expected table export content")
            return
        }

        #expect(rows.count == 2)
        #expect(rows[0][0].plainText == "Quarter")
        #expect(columnWidths == [2, 1])
        #expect(caption?.plainText == "Quarterly Results")

        guard case let .image(data, _, altText, size) = exportable.blocks[1].content else {
            Issue.record("Expected image export content")
            return
        }

        #expect(data == Data([0x89, 0x50, 0x4E, 0x47]))
        #expect(altText == "Revenue chart")
        #expect(size == imageSize)
    }
}
