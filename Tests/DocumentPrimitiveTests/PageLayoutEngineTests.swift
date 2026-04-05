import Foundation
import Testing
@testable import DocumentPrimitive
@testable import RichTextPrimitive

@MainActor
@Suite("PageLayoutEngine Tests")
struct PageLayoutEngineTests {
    @Test func singleSectionProducesPages() {
        let longText = String(repeating: "Lorem ipsum ", count: 200)
        let document = Document(
            title: "Layout",
            sections: [
                DocumentSection(
                    id: "section-1",
                    blocks: [
                        Block(id: "heading", type: .heading, content: .heading(.plain("Title"), level: 1)),
                        Block(id: "body", type: .paragraph, content: .text(.plain(longText))),
                    ]
                ),
            ]
        )

        let engine = PageLayoutEngine(document: document)
        engine.reflow()

        #expect(!engine.pages.isEmpty)
        #expect(engine.pageNumber(for: "heading") == 1)
    }

    @Test func sectionPageNumberRestartIsHonored() {
        let document = Document(
            title: "Sections",
            sections: [
                DocumentSection(id: "one", blocks: [Block(id: "a", type: .paragraph, content: .text(.plain("A")))]),
                DocumentSection(id: "two", blocks: [Block(id: "b", type: .paragraph, content: .text(.plain("B")))], startPageNumber: 10),
            ]
        )

        let engine = PageLayoutEngine(document: document)
        engine.reflow()

        #expect(engine.pageNumber(for: "b") == 10)
    }
}
