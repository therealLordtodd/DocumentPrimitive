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
}
