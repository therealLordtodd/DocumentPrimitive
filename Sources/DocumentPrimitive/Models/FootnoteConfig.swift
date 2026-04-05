import Foundation
import RichTextPrimitive

public enum FootnotePlacement: String, Codable, Sendable {
    case pageBottom
    case sectionEnd
    case documentEnd
}

public struct Footnote: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var anchorBlockID: BlockID
    public var content: TextContent

    public init(
        id: UUID = UUID(),
        anchorBlockID: BlockID,
        content: TextContent
    ) {
        self.id = id
        self.anchorBlockID = anchorBlockID
        self.content = content
    }
}

public struct FootnoteConfig: Codable, Sendable, Equatable {
    public var placement: FootnotePlacement
    public var numberingStyle: NumberingStyle
    public var restartPerSection: Bool

    public init(
        placement: FootnotePlacement = .pageBottom,
        numberingStyle: NumberingStyle = .arabic,
        restartPerSection: Bool = true
    ) {
        self.placement = placement
        self.numberingStyle = numberingStyle
        self.restartPerSection = restartPerSection
    }
}
