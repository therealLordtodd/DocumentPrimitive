import Foundation
import Observation
import PaginationPrimitive
import RichTextPrimitive

@MainActor
@Observable
public final class PageLayoutEngine {
    public var document: Document
    public private(set) var pages: [ComputedPage] = []

    private let calculator = PageFlowCalculator()
    private var blockPageMap: [BlockID: Int] = [:]

    public init(document: Document) {
        self.document = document
    }

    public func reflow() {
        pages = []
        blockPageMap = [:]

        var nextPageNumber = 1

        for section in document.sections {
            let descriptors = calculator.measuredBlocks(for: section, settings: document.settings)
            let template = calculator.template(for: section, settings: document.settings)
            let engine = PaginationEngine(template: template)
            engine.paginate(descriptors.map(\.item))

            let sectionStartPage = section.startPageNumber ?? nextPageNumber

            for (pageIndex, rawPage) in engine.pages.enumerated() {
                let pageNumber = sectionStartPage + pageIndex
                let blockIndices = rawPage.placements.compactMap { placement in
                    descriptors.first(where: { $0.item.id == placement.itemID })?.blockIndex
                }
                let uniqueIndices = Array(Set(blockIndices)).sorted()
                let ranges = uniqueIndices.map { BlockRange(startIndex: $0, endIndex: $0) }
                let visibleBlockIDs = uniqueIndices.compactMap { index in
                    section.blocks.indices.contains(index) ? section.blocks[index].id : nil
                }
                let footnotes = section.footnotes.filter { visibleBlockIDs.contains($0.anchorBlockID) }
                let headerFooter = calculator.headerFooter(
                    for: section.headerFooter,
                    pageNumber: pageNumber,
                    pageIndexInSection: pageIndex
                )

                for blockID in visibleBlockIDs where blockPageMap[blockID] == nil {
                    blockPageMap[blockID] = pageNumber
                }

                pages.append(
                    ComputedPage(
                        sectionID: section.id,
                        pageNumber: pageNumber,
                        blockRanges: ranges,
                        footnotes: footnotes,
                        header: headerFooter.header,
                        footer: headerFooter.footer
                    )
                )
            }

            nextPageNumber = (pages.last?.pageNumber ?? (sectionStartPage - 1)) + 1
        }
    }

    public func pageNumber(for blockID: BlockID) -> Int? {
        blockPageMap[blockID]
    }
}
