import Foundation
import Testing
@testable import DocumentPrimitive
@testable import RichTextPrimitive

@Suite("DocumentPrimitive Model Tests")
struct DocumentModelTests {
    @Test func pageSetupPresets() {
        #expect(PageSetup.letter.pageSize == .letter)
        #expect(PageSetup.a4.pageSize == .a4)
    }

    @Test func columnLayoutEqualWidthCalculation() {
        let layout = ColumnLayout(columns: 3, spacing: 18, equalWidth: true)
        let widths = layout.resolvedWidths(totalWidth: 300)
        #expect(widths.count == 3)
        #expect(widths[0] == widths[1])
    }

    @Test func listDefinitionFormatRendering() {
        let definition = ListDefinition(
            id: "legal",
            levels: [
                ListLevelFormat(style: .decimal, format: "%1."),
                ListLevelFormat(style: .lowerAlpha, format: "(%1.%2)"),
            ]
        )

        let rendered = definition.render(level: 1, counters: [2, 3])
        #expect(rendered == "(2.c)")
    }

    @Test func documentCodableRoundTrip() throws {
        let document = Document(
            id: "doc",
            title: "Draft",
            sections: [
                DocumentSection(
                    id: "section",
                    blocks: [Block(id: "b1", type: .paragraph, content: .text(.plain("Hello")))]
                ),
            ]
        )

        let data = try JSONEncoder().encode(document)
        let decoded = try JSONDecoder().decode(Document.self, from: data)
        #expect(decoded == document)
    }
}
