import CoreGraphics
import Foundation
import Testing
@testable import DocumentPrimitive
@testable import RichTextPrimitive

@Suite("PageContinuationEditTargetResolver Tests")
struct PageContinuationEditTargetResolverTests {
    @Test func resolverReturnsEditableMultiFragmentTextBlocks() {
        let resolver = PageContinuationEditTargetResolver()
        let document = Document(
            title: "Fragments",
            sections: [
                DocumentSection(
                    id: "section",
                    blocks: [
                        Block(id: "body", type: .paragraph, content: .text(.plain("Paragraph"))),
                        Block(id: "table", type: .table, content: .table(TableContent(rows: [[.plain("Cell")]]))),
                    ]
                ),
            ]
        )
        let page = ComputedPage(
            sectionID: "section",
            pageNumber: 1,
            blockRanges: [],
            blockPlacements: [
                BlockFragmentPlacement(
                    id: UUID(),
                    blockID: "body",
                    blockIndex: 0,
                    frame: CGRect(x: 0, y: 0, width: 200, height: 80),
                    isPartial: true,
                    partialRange: 0...40,
                    itemHeight: 120
                ),
                BlockFragmentPlacement(
                    id: UUID(),
                    blockID: "body",
                    blockIndex: 0,
                    frame: CGRect(x: 0, y: 84, width: 200, height: 40),
                    isPartial: true,
                    partialRange: 40...120,
                    itemHeight: 120
                ),
                BlockFragmentPlacement(
                    id: UUID(),
                    blockID: "table",
                    blockIndex: 1,
                    frame: CGRect(x: 0, y: 130, width: 200, height: 60),
                    itemHeight: 60
                ),
                BlockFragmentPlacement(
                    id: UUID(),
                    blockID: "table",
                    blockIndex: 1,
                    frame: CGRect(x: 0, y: 194, width: 200, height: 60),
                    itemHeight: 60
                ),
            ]
        )

        let targets = resolver.targets(on: page, in: document)

        #expect(targets.count == 1)
        #expect(targets.first?.block.id == "body")
        #expect(targets.first?.placements.count == 2)
    }

    @Test func resolverIgnoresSinglePlacementBlocks() {
        let resolver = PageContinuationEditTargetResolver()
        let document = Document(
            title: "Fragments",
            sections: [
                DocumentSection(
                    id: "section",
                    blocks: [
                        Block(id: "body", type: .paragraph, content: .text(.plain("Paragraph"))),
                    ]
                ),
            ]
        )
        let page = ComputedPage(
            sectionID: "section",
            pageNumber: 1,
            blockRanges: [],
            blockPlacements: [
                BlockFragmentPlacement(
                    id: UUID(),
                    blockID: "body",
                    blockIndex: 0,
                    frame: CGRect(x: 0, y: 0, width: 200, height: 80),
                    itemHeight: 80
                ),
            ]
        )

        let targets = resolver.targets(on: page, in: document)

        #expect(targets.isEmpty)
    }
}
