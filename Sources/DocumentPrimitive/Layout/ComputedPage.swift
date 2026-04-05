import CoreGraphics
import Foundation
import PaginationPrimitive

public struct BlockRange: Sendable, Equatable {
    public var startIndex: Int
    public var endIndex: Int

    public init(startIndex: Int, endIndex: Int) {
        self.startIndex = startIndex
        self.endIndex = endIndex
    }
}

public struct ComputedPage: Identifiable, Sendable, Equatable {
    public let id: UUID
    public var sectionID: SectionID
    public var pageNumber: Int
    public var template: PageTemplate
    public var blockRanges: [BlockRange]
    public var placements: [PagePlacement]
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

    public init(
        id: UUID = UUID(),
        sectionID: SectionID,
        pageNumber: Int,
        template: PageTemplate = .letter,
        blockRanges: [BlockRange],
        placements: [PagePlacement] = [],
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
        self.footnotes = footnotes
        self.header = header
        self.footer = footer
    }
}
