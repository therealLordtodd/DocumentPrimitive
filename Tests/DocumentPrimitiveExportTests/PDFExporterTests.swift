import CoreGraphics
import ExportKit
import Foundation
import Testing
#if canImport(PDFKit)
import PDFKit
#endif
@testable import DocumentPrimitive
@testable import DocumentPrimitiveExport
@testable import RichTextPrimitive

@Suite("PDFExporter Tests")
struct PDFExporterTests {
    @Test func exportsRenderablePDFData() async throws {
        let longText = String(repeating: "Exportable paragraph ", count: 600)
        let document = Document(
            title: "PDF Draft",
            sections: [
                DocumentSection(
                    blocks: [
                        Block(type: .heading, content: .heading(.plain("Intro"), level: 1)),
                        Block(type: .paragraph, content: .text(.plain(longText))),
                        Block(type: .divider, content: .divider),
                    ]
                ),
            ]
        )

        let exportable = BlockToExportMapper().map(document: document)
        let data = try await PDFExporter().export(exportable, options: ExportOptions())

        #expect(data.starts(with: Data("%PDF".utf8)))
        #expect(data.count > 512)

        let provider = try #require(CGDataProvider(data: data as CFData))
        let pdf = try #require(CGPDFDocument(provider))
        #expect(pdf.numberOfPages >= 1)
    }

    #if canImport(PDFKit)
    @Test func exportsSectionHeadersAndResolvedFieldTokens() async throws {
        let document = Document(
            title: "PDF Draft",
            sections: [
                DocumentSection(
                    blocks: [
                        Block(type: .paragraph, content: .text(.plain(String(repeating: "Body ", count: 400)))),
                    ],
                    headerFooter: HeaderFooterConfig(
                        header: HeaderFooter(center: [TextRun(text: "Hdr {PAGE}")]),
                        footer: HeaderFooter(right: [TextRun(text: "{TITLE}")])
                    ),
                    startPageNumber: 3
                ),
            ]
        )

        let exportable = BlockToExportMapper().map(document: document)
        let data = try await PDFExporter().export(exportable, options: ExportOptions())
        let pdf = try #require(PDFDocument(data: data))
        let firstPage = try #require(pdf.page(at: 0)?.string)

        #expect(firstPage.contains("Hdr 3"))
        #expect(firstPage.contains("PDF Draft"))
    }

    @Test func exportsPageBottomFootnotes() async throws {
        let document = Document(
            title: "PDF Draft",
            sections: [
                DocumentSection(
                    blocks: [
                        Block(id: "anchor", type: .paragraph, content: .text(.plain(String(repeating: "Body ", count: 200)))),
                    ],
                    footnotes: [
                        Footnote(anchorBlockID: "anchor", content: .plain("Footnote body")),
                    ]
                ),
            ],
            settings: DocumentSettings(
                footnoteConfig: FootnoteConfig(placement: .pageBottom)
            )
        )

        let exportable = BlockToExportMapper().map(document: document)
        let data = try await PDFExporter().export(exportable, options: ExportOptions())
        let pdf = try #require(PDFDocument(data: data))
        let firstPage = try #require(pdf.page(at: 0)?.string)

        #expect(firstPage.contains("Footnote body"))
    }
    #endif
}
