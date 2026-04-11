import CoreGraphics
import Foundation
import PaginationPrimitive
import RichTextPrimitive

public struct BlockRange: Sendable, Equatable {
    public var startIndex: Int
    public var endIndex: Int

    public init(startIndex: Int, endIndex: Int) {
        self.startIndex = startIndex
        self.endIndex = endIndex
    }
}

public struct BlockFragmentPlacement: Identifiable, Sendable, Equatable {
    public let id: UUID
    public var blockID: BlockID
    public var blockIndex: Int
    public var frame: CGRect
    public var isPartial: Bool
    public var partialRange: ClosedRange<CGFloat>?
    public var itemHeight: CGFloat

    public init(
        id: UUID,
        blockID: BlockID,
        blockIndex: Int,
        frame: CGRect,
        isPartial: Bool = false,
        partialRange: ClosedRange<CGFloat>? = nil,
        itemHeight: CGFloat
    ) {
        self.id = id
        self.blockID = blockID
        self.blockIndex = blockIndex
        self.frame = frame
        self.isPartial = isPartial
        self.partialRange = partialRange
        self.itemHeight = itemHeight
    }
}

public struct ComputedPage: Identifiable, Sendable, Equatable {
    public let id: UUID
    public var sectionID: SectionID
    public var pageNumber: Int
    public var template: PageTemplate
    public var blockRanges: [BlockRange]
    public var placements: [PagePlacement]
    public var blockPlacements: [BlockFragmentPlacement]
    public var footnotes: [Footnote]
    public var header: HeaderFooter?
    public var footer: HeaderFooter?

    public var contentFrame: CGRect {
        CGRect(
            x: template.margins.leading,
            y: template.margins.top + template.headerHeight,
            width: template.contentWidth,
            height: template.contentHeight
        )
    }

    var prefersUnifiedEditorSurface: Bool {
        guard !blockPlacements.isEmpty else { return true }
        guard template.columns == 1 else { return false }

        var seenBlockIDs: Set<BlockID> = []
        for placement in blockPlacements {
            guard !placement.isPartial else { return false }
            guard seenBlockIDs.insert(placement.blockID).inserted else { return false }
        }

        return true
    }

    public init(
        id: UUID = UUID(),
        sectionID: SectionID,
        pageNumber: Int,
        template: PageTemplate = .letter,
        blockRanges: [BlockRange],
        placements: [PagePlacement] = [],
        blockPlacements: [BlockFragmentPlacement] = [],
        footnotes: [Footnote] = [],
        header: HeaderFooter? = nil,
        footer: HeaderFooter? = nil
    ) {
        self.id = id
        self.sectionID = sectionID
        self.pageNumber = pageNumber
        self.template = template
        self.blockRanges = blockRanges
        self.placements = placements
        self.blockPlacements = blockPlacements
        self.footnotes = footnotes
        self.header = header
        self.footer = footer
    }
}
