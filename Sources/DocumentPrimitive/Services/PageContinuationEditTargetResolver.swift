import Foundation
import RichTextPrimitive

public struct PageContinuationEditTarget: Identifiable, Sendable, Equatable {
    public let sectionID: SectionID
    public let block: Block
    public let placements: [BlockFragmentPlacement]

    public var id: BlockID { block.id }

    public init(
        sectionID: SectionID,
        block: Block,
        placements: [BlockFragmentPlacement]
    ) {
        self.sectionID = sectionID
        self.block = block
        self.placements = placements
    }
}

public struct PageContinuationEditTargetResolver: Sendable {
    public init() {}

    public func targets(
        on page: ComputedPage,
        in document: Document
    ) -> [PageContinuationEditTarget] {
        guard
            !page.blockPlacements.isEmpty,
            let section = document.section(page.sectionID)
        else {
            return []
        }

        var orderedBlockIDs: [BlockID] = []
        var seenBlockIDs: Set<BlockID> = []
        for placement in page.blockPlacements where seenBlockIDs.insert(placement.blockID).inserted {
            orderedBlockIDs.append(placement.blockID)
        }

        let placementsByBlockID = Dictionary(grouping: page.blockPlacements, by: \.blockID)

        return orderedBlockIDs.compactMap { blockID in
            guard let placements = placementsByBlockID[blockID], placements.count > 1 else { return nil }
            guard let firstPlacement = placements.first, section.blocks.indices.contains(firstPlacement.blockIndex) else {
                return nil
            }

            let block = section.blocks[firstPlacement.blockIndex]
            guard isContinuationEditable(block) else { return nil }

            return PageContinuationEditTarget(
                sectionID: page.sectionID,
                block: block,
                placements: placements.sorted(by: placementSort)
            )
        }
    }

    private func isContinuationEditable(_ block: Block) -> Bool {
        switch block.content {
        case .text, .heading, .blockQuote, .codeBlock, .list:
            true
        case .table, .image, .divider, .embed:
            false
        }
    }

    private func placementSort(_ lhs: BlockFragmentPlacement, _ rhs: BlockFragmentPlacement) -> Bool {
        if lhs.frame.minY == rhs.frame.minY {
            return lhs.frame.minX < rhs.frame.minX
        }
        return lhs.frame.minY < rhs.frame.minY
    }
}
