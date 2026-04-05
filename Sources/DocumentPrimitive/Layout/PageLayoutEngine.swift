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

        for (sectionIndex, section) in document.sections.enumerated() {
            let descriptors = calculator.measuredBlocks(for: section, settings: document.settings)
            let templateProvider = calculator.templateProvider(for: section, settings: document.settings)
            let engine = PaginationEngine(templateProvider: templateProvider)
            engine.paginate(descriptors.map(\.item), section: sectionIndex)

            let sectionStartPage = section.startPageNumber ?? nextPageNumber
            let descriptorByItemID = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.item.id, $0) })

            for (pageIndex, rawPage) in engine.pages.enumerated() {
                let pageNumber = sectionStartPage + pageIndex
                let blockIndices = rawPage.placements.compactMap { placement in
                    descriptorByItemID[placement.itemID]?.blockIndex
                }
                let uniqueIndices = Array(Set(blockIndices)).sorted()
                let ranges = coalescedRanges(from: uniqueIndices)
                let visibleBlockIDs = uniqueIndices.compactMap { index in
                    section.blocks.indices.contains(index) ? section.blocks[index].id : nil
                }
                let footnotes = calculator.footnotes(
                    for: section,
                    visibleBlockIDs: visibleBlockIDs,
                    pageIndexInSection: pageIndex,
                    pageCountInSection: engine.pages.count,
                    isLastSection: sectionIndex == document.sections.count - 1,
                    settings: document.settings
                )
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
                        template: rawPage.template,
                        blockRanges: ranges,
                        placements: rawPage.placements,
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

    private func coalescedRanges(from indices: [Int]) -> [BlockRange] {
        guard let first = indices.first else { return [] }

        var ranges: [BlockRange] = []
        var start = first
        var previous = first

        for index in indices.dropFirst() {
            if index == previous + 1 {
                previous = index
                continue
            }

            ranges.append(BlockRange(startIndex: start, endIndex: previous))
            start = index
            previous = index
        }

        ranges.append(BlockRange(startIndex: start, endIndex: previous))
        return ranges
    }
}
