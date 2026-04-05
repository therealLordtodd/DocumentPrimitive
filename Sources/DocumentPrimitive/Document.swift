import Foundation
import RichTextPrimitive

public struct DocumentID: Sendable, Codable, Hashable, RawRepresentable, ExpressibleByStringLiteral, CustomStringConvertible {
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

public struct DocumentSettings: Codable, Sendable, Equatable {
    public var defaultPageSetup: PageSetup
    public var footnoteConfig: FootnoteConfig
    public var tableOfContents: TableOfContentsConfig?
    public var author: String?
    public var createdAt: Date?
    public var modifiedAt: Date?

    public init(
        defaultPageSetup: PageSetup = .letter,
        footnoteConfig: FootnoteConfig = FootnoteConfig(),
        tableOfContents: TableOfContentsConfig? = nil,
        author: String? = nil,
        createdAt: Date? = nil,
        modifiedAt: Date? = nil
    ) {
        self.defaultPageSetup = defaultPageSetup
        self.footnoteConfig = footnoteConfig
        self.tableOfContents = tableOfContents
        self.author = author
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public struct Document: Identifiable, Codable, Sendable, Equatable {
    public let id: DocumentID
    public var title: String
    public var sections: [DocumentSection]
    public var settings: DocumentSettings
    public var styles: DocumentStyleLibrary

    public init(
        id: DocumentID = DocumentID(UUID().uuidString),
        title: String,
        sections: [DocumentSection] = [],
        settings: DocumentSettings = DocumentSettings(),
        styles: DocumentStyleLibrary = .standard
    ) {
        self.id = id
        self.title = title
        self.sections = sections
        self.settings = settings
        self.styles = styles
    }

    public func section(_ id: SectionID) -> DocumentSection? {
        sections.first { $0.id == id }
    }

    public func sectionIndex(_ id: SectionID) -> Int? {
        sections.firstIndex { $0.id == id }
    }
}
