import Foundation

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
    public var blockRanges: [BlockRange]
    public var footnotes: [Footnote]
    public var header: HeaderFooter?
    public var footer: HeaderFooter?

    public init(
        id: UUID = UUID(),
        sectionID: SectionID,
        pageNumber: Int,
        blockRanges: [BlockRange],
        footnotes: [Footnote] = [],
        header: HeaderFooter? = nil,
        footer: HeaderFooter? = nil
    ) {
        self.id = id
        self.sectionID = sectionID
        self.pageNumber = pageNumber
        self.blockRanges = blockRanges
        self.footnotes = footnotes
        self.header = header
        self.footer = footer
    }
}
