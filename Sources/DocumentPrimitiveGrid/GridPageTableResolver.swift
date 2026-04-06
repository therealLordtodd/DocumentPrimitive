#if canImport(GridPrimitive)
import DocumentPrimitive
import Foundation
import RichTextPrimitive

struct GridPageTablePlacement: Identifiable, Equatable {
    let sectionID: SectionID
    let block: Block
    let placement: BlockFragmentPlacement?
    let placementCount: Int
    let fitsPageContent: Bool

    var id: BlockID { block.id }

    var supportsInlineEditing: Bool {
        guard let placement else { return false }
        return placementCount == 1 && !placement.isPartial && fitsPageContent
    }
}

struct GridPageTableResolver {
    func tablePlacements(
        on page: ComputedPage,
        in document: Document
    ) -> [GridPageTablePlacement] {
        guard let section = document.section(page.sectionID) else { return [] }

        if !page.blockPlacements.isEmpty {
            let placementCounts = page.blockPlacements.reduce(into: [BlockID: Int]()) { counts, placement in
                counts[placement.blockID, default: 0] += 1
            }
            var placementsByBlockID: [BlockID: BlockFragmentPlacement] = [:]
            for placement in page.blockPlacements where placementsByBlockID[placement.blockID] == nil {
                placementsByBlockID[placement.blockID] = placement
            }

            return page.blockPlacements.compactMap { placement in
                guard placementsByBlockID[placement.blockID]?.id == placement.id else { return nil }
                guard section.blocks.indices.contains(placement.blockIndex) else { return nil }

                let block = section.blocks[placement.blockIndex]
                guard case .table = block.content else { return nil }
                return GridPageTablePlacement(
                    sectionID: page.sectionID,
                    block: block,
                    placement: placement,
                    placementCount: placementCounts[placement.blockID, default: 1],
                    fitsPageContent: placement.frame.height <= page.template.contentHeight
                )
            }
        }

        var seen: Set<BlockID> = []
        return page.blockRanges.flatMap { range in
            Array(range.startIndex...range.endIndex).compactMap { index in
                guard section.blocks.indices.contains(index) else { return nil }
                let block = section.blocks[index]
                guard seen.insert(block.id).inserted else { return nil }
                guard case .table = block.content else { return nil }
                return GridPageTablePlacement(
                    sectionID: page.sectionID,
                    block: block,
                    placement: nil,
                    placementCount: 1,
                    fitsPageContent: false
                )
            }
        }
    }
}
#endif
