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

    @MainActor
    @Test func sectionAndPageDataSourcesBroadcastSharedMutations() {
        let document = Document(
            title: "Draft",
            sections: [
                DocumentSection(
                    id: "section",
                    blocks: [
                        Block(id: "b1", type: .paragraph, content: .text(.plain("Hello"))),
                    ]
                ),
            ]
        )

        let state = DocumentEditorState(document: document)
        let sectionDataSource = state.dataSource(for: "section")
        guard let firstPage = state.layoutEngine.pages.first else {
            Issue.record("Expected at least one laid out page")
            return
        }
        let pageDataSource = state.dataSource(for: firstPage)
        var observedMutations: [RichTextMutation] = []

        let observerID = sectionDataSource.addMutationObserver { mutation in
            observedMutations.append(mutation)
        }

        pageDataSource.updateTextContent(blockID: "b1", content: .plain("Updated"))

        #expect(sectionDataSource.blocks.first?.content.textContent?.plainText == "Updated")
        #expect(observedMutations.contains(.batchUpdate))
        sectionDataSource.removeMutationObserver(observerID)
    }

    @MainActor
    @Test func headerFooterDataSourcesBroadcastSharedMutations() {
        let document = Document(
            title: "Draft",
            sections: [
                DocumentSection(
                    id: "section",
                    blocks: [Block(id: "b1", type: .paragraph, content: .text(.plain("Hello")))],
                    headerFooter: HeaderFooterConfig(
                        header: HeaderFooter(left: [TextRun(text: "Left")], center: [TextRun(text: "Center")])
                    )
                ),
            ]
        )

        let state = DocumentEditorState(document: document)
        let leftDataSource = state.headerFooterDataSource(for: "section", slot: .headerLeft)
        let centerDataSource = state.headerFooterDataSource(for: "section", slot: .headerCenter)
        var observedMutations: [RichTextMutation] = []

        let observerID = leftDataSource.addMutationObserver { mutation in
            observedMutations.append(mutation)
        }

        guard let centerBlockID = centerDataSource.blocks.first?.id else {
            Issue.record("Expected center header/footer block")
            return
        }
        centerDataSource.updateTextContent(blockID: centerBlockID, content: .plain("Updated Center"))

        #expect(observedMutations.contains(.batchUpdate))
        #expect(state.document.section("section")?.headerFooter?.header?.center.first?.text == "Updated Center")
        leftDataSource.removeMutationObserver(observerID)
    }
}
