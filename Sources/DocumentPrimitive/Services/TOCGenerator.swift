import Foundation
import RichTextPrimitive

public struct TableOfContentsEntry: Sendable, Equatable, Identifiable {
    public let id: UUID
    public var title: String
    public var level: Int
    public var pageNumber: Int?
    public var blockID: BlockID

    public init(
        id: UUID = UUID(),
        title: String,
        level: Int,
        pageNumber: Int?,
        blockID: BlockID
    ) {
        self.id = id
        self.title = title
        self.level = level
        self.pageNumber = pageNumber
        self.blockID = blockID
    }
}

public struct TOCGenerator: Sendable {
    public init() {}

    @MainActor
    public func generate(
        from document: Document,
        layoutEngine: PageLayoutEngine,
        config: TableOfContentsConfig
    ) -> [TableOfContentsEntry] {
        document.sections.flatMap { section in
            section.blocks.compactMap { block in
                guard case let .heading(content, level) = block.content else { return nil }
                guard config.includedHeadingLevels.contains(level) else { return nil }
                return TableOfContentsEntry(
                    title: content.plainText,
                    level: level,
                    pageNumber: config.showPageNumbers ? layoutEngine.pageNumber(for: block.id) : nil,
                    blockID: block.id
                )
            }
        }
    }
}
