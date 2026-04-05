import Foundation
import Testing
@testable import DocumentPrimitive
@testable import RichTextPrimitive

@Suite("FootnoteDisplayResolver Tests")
struct FootnoteDisplayResolverTests {
    @Test func documentEndFootnotesGroupBySectionWhenRestarting() {
        let sectionOneFootnote = Footnote(anchorBlockID: "anchor-1", content: .plain("First note"))
        let sectionTwoFootnote = Footnote(anchorBlockID: "anchor-2", content: .plain("Second note"))
        let document = Document(
            title: "Draft",
            sections: [
                DocumentSection(
                    blocks: [Block(id: "anchor-1", type: .paragraph, content: .text(.plain("Body one")))],
                    footnotes: [sectionOneFootnote]
                ),
                DocumentSection(
                    blocks: [Block(id: "anchor-2", type: .paragraph, content: .text(.plain("Body two")))],
                    footnotes: [sectionTwoFootnote]
                ),
            ],
            settings: DocumentSettings(
                footnoteConfig: FootnoteConfig(
                    placement: .documentEnd,
                    numberingStyle: .arabic,
                    restartPerSection: true
                )
            )
        )
        let page = ComputedPage(
            sectionID: document.sections[1].id,
            pageNumber: 2,
            blockRanges: [BlockRange(startIndex: 0, endIndex: 0)],
            footnotes: [sectionOneFootnote, sectionTwoFootnote]
        )

        let groups = FootnoteDisplayResolver().groups(for: page, document: document)

        #expect(groups.count == 2)
        #expect(groups[0].title == "Section 1 Footnotes")
        #expect(groups[0].footnotes.first?.marker == "1.")
        #expect(groups[1].title == "Section 2 Footnotes")
        #expect(groups[1].footnotes.first?.marker == "1.")
    }

    @Test func documentEndFootnotesStayContinuousAcrossSections() {
        let sectionOneFootnote = Footnote(anchorBlockID: "anchor-1", content: .plain("First note"))
        let sectionTwoFootnote = Footnote(anchorBlockID: "anchor-2", content: .plain("Second note"))
        let document = Document(
            title: "Draft",
            sections: [
                DocumentSection(
                    blocks: [Block(id: "anchor-1", type: .paragraph, content: .text(.plain("Body one")))],
                    footnotes: [sectionOneFootnote]
                ),
                DocumentSection(
                    blocks: [Block(id: "anchor-2", type: .paragraph, content: .text(.plain("Body two")))],
                    footnotes: [sectionTwoFootnote]
                ),
            ],
            settings: DocumentSettings(
                footnoteConfig: FootnoteConfig(
                    placement: .documentEnd,
                    numberingStyle: .roman,
                    restartPerSection: false
                )
            )
        )
        let page = ComputedPage(
            sectionID: document.sections[1].id,
            pageNumber: 2,
            blockRanges: [BlockRange(startIndex: 0, endIndex: 0)],
            footnotes: [sectionOneFootnote, sectionTwoFootnote]
        )

        let groups = FootnoteDisplayResolver().groups(for: page, document: document)

        #expect(groups.count == 1)
        #expect(groups[0].title == nil)
        #expect(groups[0].footnotes.map(\.marker) == ["I.", "II."])
    }
}
