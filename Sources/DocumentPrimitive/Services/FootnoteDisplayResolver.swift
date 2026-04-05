import Foundation
import RichTextPrimitive

public struct DisplayedFootnote: Identifiable, Sendable, Equatable {
    public let id: UUID
    public var marker: String
    public var content: TextContent

    public init(id: UUID, marker: String, content: TextContent) {
        self.id = id
        self.marker = marker
        self.content = content
    }
}

public struct DisplayedFootnoteGroup: Identifiable, Sendable, Equatable {
    public let id: UUID
    public var title: String?
    public var footnotes: [DisplayedFootnote]

    public init(
        id: UUID = UUID(),
        title: String? = nil,
        footnotes: [DisplayedFootnote]
    ) {
        self.id = id
        self.title = title
        self.footnotes = footnotes
    }
}

public struct FootnoteDisplayResolver: Sendable {
    private let footnoteManager = FootnoteManager()

    public init() {}

    public func groups(for page: ComputedPage, document: Document) -> [DisplayedFootnoteGroup] {
        guard !page.footnotes.isEmpty else { return [] }

        let config = document.settings.footnoteConfig
        let resolvedBySection = footnoteManager.resolve(sections: document.sections, config: config)

        if config.placement == .documentEnd, config.restartPerSection {
            let visibleIDs = Set(page.footnotes.map(\.id))
            return document.sections.enumerated().compactMap { entry in
                let (sectionIndex, section) = entry
                let displayed = (resolvedBySection[section.id] ?? []).compactMap { resolved -> DisplayedFootnote? in
                    guard visibleIDs.contains(resolved.footnote.id) else { return nil }
                    return DisplayedFootnote(
                        id: resolved.footnote.id,
                        marker: formattedMarker(
                            resolved.displayNumber,
                            style: config.numberingStyle
                        ),
                        content: resolved.footnote.content
                    )
                }

                guard !displayed.isEmpty else { return nil }
                let title = document.sections.count > 1 ? "Section \(sectionIndex + 1) Footnotes" : nil
                return DisplayedFootnoteGroup(title: title, footnotes: displayed)
            }
        }

        let resolvedLookup = Dictionary(
            uniqueKeysWithValues: document.sections
                .flatMap { resolvedBySection[$0.id] ?? [] }
                .map { ($0.footnote.id, $0) }
        )
        let displayed = page.footnotes.compactMap { footnote -> DisplayedFootnote? in
            guard let resolved = resolvedLookup[footnote.id] else { return nil }
            return DisplayedFootnote(
                id: footnote.id,
                marker: formattedMarker(resolved.displayNumber, style: config.numberingStyle),
                content: resolved.footnote.content
            )
        }

        guard !displayed.isEmpty else { return [] }
        return [DisplayedFootnoteGroup(footnotes: displayed)]
    }

    private func formattedMarker(
        _ marker: String,
        style: NumberingStyle
    ) -> String {
        if style == .symbol {
            return marker
        }
        return "\(marker)."
    }
}
