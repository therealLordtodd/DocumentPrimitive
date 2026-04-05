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

    @Test func differentFirstPageUsesSeparateFirstChromeWhenProvided() {
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
                        firstHeader: HeaderFooter(center: [TextRun(text: "First Header")]),
                        firstFooter: HeaderFooter(center: [TextRun(text: "First Footer")]),
                        header: HeaderFooter(center: [TextRun(text: "Default Header")]),
                        footer: HeaderFooter(center: [TextRun(text: "Default Footer")]),
                        differentFirstPage: true
                    )
                ),
            ]
        )

        let engine = PageLayoutEngine(document: document)
        engine.reflow()

        #expect(engine.pages.count > 1)
        #expect(engine.pages[0].header?.center.first?.text == "First Header")
        #expect(engine.pages[0].footer?.center.first?.text == "First Footer")
        #expect(engine.pages[1].header?.center.first?.text == "Default Header")
        #expect(engine.pages[1].footer?.center.first?.text == "Default Footer")
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

    @Test func differentOddEvenUsesSeparateChromeForAbsolutePageNumbers() {
        let longText = String(repeating: "Body copy ", count: 2000)
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
                        header: HeaderFooter(center: [TextRun(text: "Odd Header")]),
                        footer: HeaderFooter(center: [TextRun(text: "Odd Footer")]),
                        evenHeader: HeaderFooter(center: [TextRun(text: "Even Header")]),
                        evenFooter: HeaderFooter(center: [TextRun(text: "Even Footer")]),
                        differentOddEven: true
                    ),
                    startPageNumber: 10
                ),
            ]
        )

        let engine = PageLayoutEngine(document: document)
        engine.reflow()

        #expect(engine.pages.count > 1)
        #expect(engine.pages[0].pageNumber == 10)
        #expect(engine.pages[0].header?.center.first?.text == "Even Header")
        #expect(engine.pages[0].footer?.center.first?.text == "Even Footer")
        #expect(engine.pages[1].pageNumber == 11)
        #expect(engine.pages[1].header?.center.first?.text == "Odd Header")
        #expect(engine.pages[1].footer?.center.first?.text == "Odd Footer")
    }

    @Test func documentEndFootnotesCollectAcrossSectionsOnFinalPage() {
        let longText = String(repeating: "Body copy ", count: 1500)
        let firstFootnote = Footnote(anchorBlockID: "anchor-1", content: .plain("First footnote"))
        let secondFootnote = Footnote(anchorBlockID: "anchor-2", content: .plain("Second footnote"))
        let document = Document(
            title: "Document Footnotes",
            sections: [
                DocumentSection(
                    id: "section-1",
                    blocks: [
                        Block(id: "anchor-1", type: .paragraph, content: .text(.plain("Anchor paragraph one"))),
                        Block(id: "body-1", type: .paragraph, content: .text(.plain(longText))),
                    ],
                    footnotes: [firstFootnote]
                ),
                DocumentSection(
                    id: "section-2",
                    blocks: [
                        Block(id: "anchor-2", type: .paragraph, content: .text(.plain("Anchor paragraph two"))),
                        Block(id: "body-2", type: .paragraph, content: .text(.plain(longText))),
                    ],
                    footnotes: [secondFootnote]
                ),
            ],
            settings: DocumentSettings(
                defaultPageSetup: .letter,
                footnoteConfig: FootnoteConfig(placement: .documentEnd)
            )
        )

        let engine = PageLayoutEngine(document: document)
        engine.reflow()

        #expect(engine.pages.count > 2)
        #expect(engine.pages.dropLast().allSatisfy { $0.footnotes.isEmpty })
        #expect(engine.pages.last?.footnotes == [firstFootnote, secondFootnote])
    }

    @Test func longParagraphProducesPartialBlockPlacementsAcrossPages() {
        let longText = String(repeating: "Split me across pages ", count: 2500)
        let document = Document(
            title: "Fragments",
            sections: [
                DocumentSection(
                    id: "section-1",
                    blocks: [
                        Block(id: "body", type: .paragraph, content: .text(.plain(longText))),
                    ]
                ),
            ]
        )

        let engine = PageLayoutEngine(document: document)
        engine.reflow()

        #expect(engine.pages.count > 1)
        #expect(engine.pages[0].blockPlacements.contains { $0.blockID == "body" && $0.isPartial })
        #expect(engine.pages[1].blockPlacements.contains { $0.blockID == "body" && $0.isPartial })
    }
}
