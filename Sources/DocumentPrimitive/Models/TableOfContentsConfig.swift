import Foundation

public enum TabLeader: String, Codable, Sendable {
    case none
    case dots
    case dashes
    case line
}

public struct TableOfContentsConfig: Codable, Sendable, Equatable {
    public var includedHeadingLevels: ClosedRange<Int>
    public var showPageNumbers: Bool
    public var useHyperlinks: Bool
    public var tabLeader: TabLeader

    public init(
        includedHeadingLevels: ClosedRange<Int> = 1...3,
        showPageNumbers: Bool = true,
        useHyperlinks: Bool = true,
        tabLeader: TabLeader = .dots
    ) {
        self.includedHeadingLevels = includedHeadingLevels
        self.showPageNumbers = showPageNumbers
        self.useHyperlinks = useHyperlinks
        self.tabLeader = tabLeader
    }
}
