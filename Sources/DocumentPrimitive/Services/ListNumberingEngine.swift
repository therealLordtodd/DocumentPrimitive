import Foundation

public struct ResolvedListNumber: Sendable, Equatable {
    public var level: Int
    public var text: String

    public init(level: Int, text: String) {
        self.level = level
        self.text = text
    }
}

public struct ListNumberingEngine: Sendable {
    public init() {}

    public func render(
        definition: ListDefinition,
        level: Int,
        counters: [Int]
    ) -> String {
        definition.render(level: level, counters: counters)
    }
}
