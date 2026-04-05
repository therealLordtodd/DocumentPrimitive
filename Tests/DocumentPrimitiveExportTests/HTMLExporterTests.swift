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
}
