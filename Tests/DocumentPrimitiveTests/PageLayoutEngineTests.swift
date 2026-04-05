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

    @Test func differentFirstPageTemplateDropsHeaderSpaceOnOpeningPage() {
        let longText = String(repeating: "Lorem ipsum dolor sit amet ", count: 1500)
        let document = Document(
            title: "Headers",
            sections: [
                DocumentSection(
                    id: "section-1",
                    blocks: [
                        Block(id: "intro", type: .heading, content: .heading(.plain("Intro"), level: 1)),
                        Block(id: "body", type: .paragraph, content: .text(.plain(longText))),
                    ],
                    headerFooter: HeaderFooterConfig(
                        header: HeaderFooter(center: [TextRun(text: "Document Header")]),
                        footer: HeaderFooter(center: [TextRun(text: "Footer")]),
                        differentFirstPage: true
                    )
                ),
            ]
        )

        let engine = PageLayoutEngine(document: document)
        engine.reflow()

        #expect(engine.pages.count > 1)
        #expect(engine.pages[0].template.headerHeight == 0)
        #expect(engine.pages[0].header == nil)
        #expect(engine.pages[1].template.headerHeight == 36)
        #expect(engine.pages[1].header != nil)
    }

    @Test func sectionEndFootnotesCollectOnFinalPage() {
        let longText = String(repeating: "Body copy ", count: 1500)
        let document = Document(
            title: "Footnotes",
            sections: [
                DocumentSection(
                    id: "section-1",
                    blocks: [
                        Block(id: "anchor", type: .paragraph, content: .text(.plain("Anchor paragraph"))),
                        Block(id: "body", type: .paragraph, content: .text(.plain(longText))),
                    ],
                    footnotes: [
                        Footnote(anchorBlockID: "anchor", content: .plain("Footnote body")),
                    ]
                ),
            ],
            settings: DocumentSettings(
                defaultPageSetup: .letter,
                footnoteConfig: FootnoteConfig(placement: .sectionEnd)
            )
        )

        let engine = PageLayoutEngine(document: document)
        engine.reflow()

        #expect(engine.pages.count > 1)
        #expect(engine.pages[0].footnotes.isEmpty)
        #expect(engine.pages.last?.footnotes.count == 1)
    }
}
