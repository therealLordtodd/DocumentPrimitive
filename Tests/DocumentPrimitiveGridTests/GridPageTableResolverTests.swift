#if canImport(GridPrimitive)
import CoreGraphics
import Foundation
import Testing
@testable import DocumentPrimitive
@testable import DocumentPrimitiveGrid
@testable import RichTextPrimitive

@Suite("GridPageTableResolver Tests")
struct GridPageTableResolverTests {
    @Test func resolverReturnsVisibleTablesForPagePlacements() {
        let resolver = GridPageTableResolver()
        let document = Document(
            title: "Tables",
            sections: [
                DocumentSection(
                    id: "section",
                    blocks: [
                        Block(id: "intro", type: .paragraph, content: .text(.plain("Intro"))),
                        Block(
                            id: "table-1",
                            type: .table,
                            content: .table(TableContent(rows: [[.plain("A1")]], caption: .plain("Inventory")))
                        ),
                        Block(
                            id: "table-2",
                            type: .table,
                            content: .table(TableContent(rows: [[.plain("B1")]], caption: .plain("Photos")))
                        ),
                    ]
                ),
            ]
        )
        let page = ComputedPage(
            sectionID: "section",
            pageNumber: 1,
            blockRanges: [],
            blockPlacements: [
                BlockFragmentPlacement(id: UUID(), blockID: "table-1", blockIndex: 1, frame: CGRect(x: 0, y: 0, width: 200, height: 80), itemHeight: 80),
                BlockFragmentPlacement(id: UUID(), blockID: "table-1", blockIndex: 1, frame: CGRect(x: 0, y: 82, width: 200, height: 80), itemHeight: 80),
                BlockFragmentPlacement(id: UUID(), blockID: "table-2", blockIndex: 2, frame: CGRect(x: 0, y: 164, width: 200, height: 80), itemHeight: 80),
            ]
        )

        let placements = resolver.tablePlacements(on: page, in: document)

        #expect(placements.map(\.block.id) == ["table-1", "table-2"])
        #expect(placements.map(\.sectionID) == ["section", "section"])
    }

    @Test func resolverFallsBackToBlockRangesWhenNoPlacementsExist() {
        let resolver = GridPageTableResolver()
        let document = Document(
            title: "Tables",
            sections: [
                DocumentSection(
                    id: "section",
                    blocks: [
                        Block(id: "intro", type: .paragraph, content: .text(.plain("Intro"))),
                        Block(
                            id: "table-1",
                            type: .table,
                            content: .table(TableContent(rows: [[.plain("A1")]]))
                        ),
                    ]
                ),
            ]
        )
        let page = ComputedPage(
            sectionID: "section",
            pageNumber: 1,
            blockRanges: [BlockRange(startIndex: 0, endIndex: 1)]
        )

        let placements = resolver.tablePlacements(on: page, in: document)

        #expect(placements.count == 1)
        #expect(placements.first?.block.id == "table-1")
        #expect(placements.first?.placement == nil)
    }
}
#endif
