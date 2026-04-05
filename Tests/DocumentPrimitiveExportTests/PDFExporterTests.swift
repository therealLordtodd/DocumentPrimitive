import CoreGraphics
import ExportKit
import Foundation
import Testing
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
}
