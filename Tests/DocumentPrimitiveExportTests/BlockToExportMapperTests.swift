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
}
