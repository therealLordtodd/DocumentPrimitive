import Foundation
import Observation
import RichTextPrimitive

@MainActor
@Observable
public final class DocumentEditorState {
    public var document: Document {
        didSet {
            layoutEngine.document = document
            layoutEngine.reflow()
            if currentSection == nil {
                currentSection = document.sections.first?.id
            }
        }
    }

    public var richTextState: RichTextState
    public var viewMode: DocumentViewMode
    public var showRuler: Bool
    public var showFormatting: Bool
    public var currentPage: Int
    public var currentSection: SectionID?
    public let layoutEngine: PageLayoutEngine

    private var sectionDataSources: [SectionID: SectionDataSource] = [:]

    public init(
        document: Document,
        richTextState: RichTextState = RichTextState(),
        viewMode: DocumentViewMode = .page,
        showRuler: Bool = true,
        showFormatting: Bool = true,
        currentPage: Int = 1,
        currentSection: SectionID? = nil
    ) {
        self.document = document
        self.richTextState = richTextState
        self.viewMode = viewMode
        self.showRuler = showRuler
        self.showFormatting = showFormatting
        self.currentPage = currentPage
        self.currentSection = currentSection ?? document.sections.first?.id
        self.layoutEngine = PageLayoutEngine(document: document)
        self.layoutEngine.reflow()
    }

    public func dataSource(for sectionID: SectionID) -> SectionDataSource {
        if let existing = sectionDataSources[sectionID] {
            return existing
        }

        let source = SectionDataSource(editorState: self, sectionID: sectionID)
        sectionDataSources[sectionID] = source
        return source
    }

    fileprivate func blocks(for sectionID: SectionID) -> [Block] {
        document.section(sectionID)?.blocks ?? []
    }

    fileprivate func updateSectionBlocks(_ blocks: [Block], for sectionID: SectionID) {
        guard let index = document.sectionIndex(sectionID) else { return }
        document.sections[index].blocks = blocks
    }
}

@MainActor
@Observable
public final class SectionDataSource: RichTextDataSource {
    private unowned let editorState: DocumentEditorState
    public let sectionID: SectionID

    private var observers: [UUID: @MainActor (RichTextMutation) -> Void] = [:]

    public init(editorState: DocumentEditorState, sectionID: SectionID) {
        self.editorState = editorState
        self.sectionID = sectionID
    }

    public var blocks: [Block] {
        editorState.blocks(for: sectionID)
    }

    public func block(at index: Int) -> Block {
        blocks[index]
    }

    public func insertBlocks(_ blocks: [Block], at index: Int) {
        var updated = self.blocks
        let insertionIndex = min(max(index, 0), updated.count)
        updated.insert(contentsOf: blocks, at: insertionIndex)
        editorState.updateSectionBlocks(updated, for: sectionID)
        notify(.blocksInserted(indices: IndexSet(insertionIndex..<(insertionIndex + blocks.count))))
    }

    public func deleteBlocks(at indices: IndexSet) {
        var updated = blocks
        for index in indices.sorted(by: >) where updated.indices.contains(index) {
            updated.remove(at: index)
        }
        editorState.updateSectionBlocks(updated, for: sectionID)
        notify(.blocksDeleted(indices: indices))
    }

    public func moveBlocks(from source: IndexSet, to destination: Int) {
        var updated = blocks
        let movingBlocks = source.sorted().compactMap { updated.indices.contains($0) ? updated[$0] : nil }
        for index in source.sorted(by: >) where updated.indices.contains(index) {
            updated.remove(at: index)
        }
        let insertionIndex = min(max(destination, 0), updated.count)
        updated.insert(contentsOf: movingBlocks, at: insertionIndex)
        editorState.updateSectionBlocks(updated, for: sectionID)
        notify(.blocksMoved(from: source, to: destination))
    }

    public func replaceBlock(at index: Int, with block: Block) {
        var updated = blocks
        guard updated.indices.contains(index) else { return }
        updated[index] = block
        editorState.updateSectionBlocks(updated, for: sectionID)
        notify(.blockReplaced(index: index))
    }

    public func updateTextContent(blockID: BlockID, content: TextContent) {
        var updated = blocks
        guard let index = updated.firstIndex(where: { $0.id == blockID }) else { return }
        switch updated[index].content {
        case .text:
            updated[index].content = .text(content)
        case let .heading(_, level):
            updated[index].content = .heading(content, level: level)
        case .blockQuote:
            updated[index].content = .blockQuote(content)
        case let .list(_, style, indentLevel):
            updated[index].content = .list(content, style: style, indentLevel: indentLevel)
        case let .codeBlock(_, language):
            updated[index].content = .codeBlock(code: content.plainText, language: language)
        case .table, .image, .divider, .embed:
            return
        }
        editorState.updateSectionBlocks(updated, for: sectionID)
        notify(.textUpdated(blockID: blockID))
    }

    public func updateBlockType(blockID: BlockID, type: BlockType, content: BlockContent) {
        var updated = blocks
        guard let index = updated.firstIndex(where: { $0.id == blockID }) else { return }
        updated[index].type = type
        updated[index].content = content
        editorState.updateSectionBlocks(updated, for: sectionID)
        notify(.typeChanged(blockID: blockID))
    }

    public func addMutationObserver(_ observer: @escaping @MainActor (RichTextMutation) -> Void) -> UUID {
        let id = UUID()
        observers[id] = observer
        return id
    }

    public func removeMutationObserver(_ id: UUID) {
        observers.removeValue(forKey: id)
    }

    private func notify(_ mutation: RichTextMutation) {
        for observer in observers.values {
            observer(mutation)
        }
    }
}
