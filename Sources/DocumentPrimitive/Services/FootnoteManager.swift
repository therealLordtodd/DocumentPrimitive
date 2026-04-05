import Foundation

public struct ResolvedFootnote: Sendable, Equatable {
    public var footnote: Footnote
    public var displayNumber: String

    public init(footnote: Footnote, displayNumber: String) {
        self.footnote = footnote
        self.displayNumber = displayNumber
    }
}

public struct FootnoteManager: Sendable {
    public init() {}

    public func resolve(
        sections: [DocumentSection],
        config: FootnoteConfig
    ) -> [SectionID: [ResolvedFootnote]] {
        var results: [SectionID: [ResolvedFootnote]] = [:]
        var nextNumber = 1

        for section in sections {
            if config.restartPerSection {
                nextNumber = 1
            }

            results[section.id] = section.footnotes.map { footnote in
                defer { nextNumber += 1 }
                return ResolvedFootnote(
                    footnote: footnote,
                    displayNumber: config.numberingStyle.render(number: nextNumber)
                )
            }
        }

        return results
    }
}
