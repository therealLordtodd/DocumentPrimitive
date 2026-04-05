import Foundation
import RichTextPrimitive

public struct SectionID: Sendable, Codable, Hashable, RawRepresentable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public var description: String { rawValue }
}

public struct DocumentSection: Identifiable, Codable, Sendable, Equatable {
    public let id: SectionID
    public var blocks: [Block]
    public var pageSetup: PageSetup?
    public var headerFooter: HeaderFooterConfig?
    public var columnLayout: ColumnLayout?
    public var startPageNumber: Int?
    public var footnotes: [Footnote]

    public init(
        id: SectionID = SectionID(UUID().uuidString),
        blocks: [Block] = [],
        pageSetup: PageSetup? = nil,
        headerFooter: HeaderFooterConfig? = nil,
        columnLayout: ColumnLayout? = nil,
        startPageNumber: Int? = nil,
        footnotes: [Footnote] = []
    ) {
        self.id = id
        self.blocks = blocks
        self.pageSetup = pageSetup
        self.headerFooter = headerFooter
        self.columnLayout = columnLayout
        self.startPageNumber = startPageNumber
        self.footnotes = footnotes
    }
}
