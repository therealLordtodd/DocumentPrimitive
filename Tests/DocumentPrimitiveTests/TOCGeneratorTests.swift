import Foundation
import Testing
@testable import DocumentPrimitive
@testable import RichTextPrimitive

@MainActor
@Suite("TOCGenerator Tests")
struct TOCGeneratorTests {
    @Test func headingsBecomeTocEntries() {
        let document = Document(
            title: "TOC",
            sections: [
                DocumentSection(
                    id: "s1",
                    blocks: [
                        Block(id: "h1", type: .heading, content: .heading(.plain("Intro"), level: 1)),
                        Block(id: "p1", type: .paragraph, content: .text(.plain("Body"))),
                    ]
                ),
            ]
        )

        let engine = PageLayoutEngine(document: document)
        engine.reflow()

        let toc = TOCGenerator().generate(
            from: document,
            layoutEngine: engine,
            config: TableOfContentsConfig(includedHeadingLevels: 1...2)
        )

        #expect(toc.count == 1)
        #expect(toc[0].title == "Intro")
        #expect(toc[0].pageNumber == 1)
    }
}
