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
            pruneDerivedEditorStateCaches()
            if currentSection == nil {
                currentSection = document.sections.first?.id
            }
            syncCurrentLocationToSelection()
            ensureCurrentPageExists()
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
    private var pageDataSources: [String: PageScopedDataSource] = [:]
    private var headerFooterDataSources: [String: HeaderFooterDataSource] = [:]
    private var sectionRichTextStates: [SectionID: RichTextState] = [:]
    private var pageRichTextStates: [String: RichTextState] = [:]
    private var headerFooterRichTextStates: [String: RichTextState] = [:]
    private weak var activeEditorRichTextState: RichTextState?

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
        syncCurrentLocationToSelection()
        ensureCurrentPageExists()
    }

    public var canGoToPreviousPage: Bool {
        guard let index = currentPageIndex() else { return false }
        return index > 0
    }

    public var canGoToNextPage: Bool {
        guard let index = currentPageIndex() else { return false }
        return index < layoutEngine.pages.count - 1
    }

    public func dataSource(for sectionID: SectionID) -> SectionDataSource {
        if let existing = sectionDataSources[sectionID] {
            return existing
        }

        let source = SectionDataSource(editorState: self, sectionID: sectionID)
        sectionDataSources[sectionID] = source
        return source
    }

    public func dataSource(for page: ComputedPage) -> PageScopedDataSource {
        let key = pageDataSourceKey(for: page)
        if let existing = pageDataSources[key] {
            existing.page = page
            return existing
        }

        let source = PageScopedDataSource(editorState: self, page: page)
        pageDataSources[key] = source
        return source
    }

    public func headerFooterDataSource(
        for sectionID: SectionID,
        slot: HeaderFooterSlot
    ) -> HeaderFooterDataSource {
        let key = headerFooterDataSourceKey(for: sectionID, slot: slot)
        if let existing = headerFooterDataSources[key] {
            return existing
        }

        let source = HeaderFooterDataSource(editorState: self, sectionID: sectionID, slot: slot)
        headerFooterDataSources[key] = source
        return source
    }

    public func richTextState(forSection sectionID: SectionID) -> RichTextState {
        if let existing = sectionRichTextStates[sectionID] {
            return existing
        }

        let state = makeDerivedRichTextState(
            allowedBlockIDs: blocks(for: sectionID).map(\.id)
        )
        sectionRichTextStates[sectionID] = state
        return state
    }

    public func richTextState(forPage page: ComputedPage) -> RichTextState {
        let key = pageDataSourceKey(for: page)
        if let existing = pageRichTextStates[key] {
            return existing
        }

        let state = makeDerivedRichTextState(
            allowedBlockIDs: visibleBlockIDs(for: page)
        )
        pageRichTextStates[key] = state
        return state
    }

    public func headerFooterRichTextState(
        for sectionID: SectionID,
        slot: HeaderFooterSlot
    ) -> RichTextState {
        let key = headerFooterDataSourceKey(for: sectionID, slot: slot)
        if let existing = headerFooterRichTextStates[key] {
            return existing
        }

        let state = makeDerivedRichTextState(
            allowedBlockIDs: [headerFooterBlockID(for: sectionID, slot: slot)]
        )
        headerFooterRichTextStates[key] = state
        return state
    }

    fileprivate func blocks(for sectionID: SectionID) -> [Block] {
        document.section(sectionID)?.blocks ?? []
    }

    fileprivate func updateSectionBlocks(_ blocks: [Block], for sectionID: SectionID) {
        guard let index = document.sectionIndex(sectionID) else { return }
        document.sections[index].blocks = blocks
        layoutEngine.document = document
        layoutEngine.reflow()
        pruneDerivedEditorStateCaches()
        broadcastSectionMutation(for: sectionID)
        syncCurrentLocationToSelection()
        ensureCurrentPageExists()
    }

    fileprivate func headerFooterRuns(
        for sectionID: SectionID,
        slot: HeaderFooterSlot
    ) -> [TextRun] {
        guard let section = document.section(sectionID) else { return [] }
        let config = section.headerFooter ?? HeaderFooterConfig()
        let target: HeaderFooter
        switch (slot.variant, slot.isHeader) {
        case (.first, true):
            target = config.firstHeader ?? HeaderFooter()
        case (.first, false):
            target = config.firstFooter ?? HeaderFooter()
        case (.primary, true):
            target = config.header ?? HeaderFooter()
        case (.primary, false):
            target = config.footer ?? HeaderFooter()
        case (.even, true):
            target = config.evenHeader ?? HeaderFooter()
        case (.even, false):
            target = config.evenFooter ?? HeaderFooter()
        }

        switch slot.alignment {
        case .left:
            return target.left
        case .center:
            return target.center
        case .right:
            return target.right
        }
    }

    fileprivate func updateHeaderFooterRuns(
        _ runs: [TextRun],
        for sectionID: SectionID,
        slot: HeaderFooterSlot
    ) {
        guard let index = document.sectionIndex(sectionID) else { return }

        var config = document.sections[index].headerFooter ?? HeaderFooterConfig()
        if slot.variant == .first {
            config.differentFirstPage = true
        }
        if slot.variant == .even {
            config.differentOddEven = true
        }

        if slot.isHeader {
            var header: HeaderFooter
            switch slot.variant {
            case .first:
                header = config.firstHeader ?? HeaderFooter()
            case .primary:
                header = config.header ?? HeaderFooter()
            case .even:
                header = config.evenHeader ?? HeaderFooter()
            }

            switch slot.alignment {
            case .left:
                header.left = runs
            case .center:
                header.center = runs
            case .right:
                header.right = runs
            }

            switch slot.variant {
            case .first:
                config.firstHeader = header
            case .primary:
                config.header = header
            case .even:
                config.evenHeader = header
            }
        } else {
            var footer: HeaderFooter
            switch slot.variant {
            case .first:
                footer = config.firstFooter ?? HeaderFooter()
            case .primary:
                footer = config.footer ?? HeaderFooter()
            case .even:
                footer = config.evenFooter ?? HeaderFooter()
            }

            switch slot.alignment {
            case .left:
                footer.left = runs
            case .center:
                footer.center = runs
            case .right:
                footer.right = runs
            }

            switch slot.variant {
            case .first:
                config.firstFooter = footer
            case .primary:
                config.footer = footer
            case .even:
                config.evenFooter = footer
            }
        }

        document.sections[index].headerFooter = config
        layoutEngine.document = document
        layoutEngine.reflow()
        pruneDerivedEditorStateCaches()
        broadcastHeaderFooterMutation(for: sectionID)
        syncCurrentLocationToSelection()
        ensureCurrentPageExists()
    }

    public func goToPreviousPage() {
        guard let index = currentPageIndex(), index > 0 else { return }
        select(page: layoutEngine.pages[index - 1])
    }

    public func goToNextPage() {
        guard let index = currentPageIndex(), index + 1 < layoutEngine.pages.count else { return }
        select(page: layoutEngine.pages[index + 1])
    }

    func syncCurrentLocationToSelection() {
        syncCurrentLocation(using: activeEditorRichTextState ?? richTextState)
    }

    func syncCurrentLocation(using editorState: RichTextState) {
        activeEditorRichTextState = editorState

        guard let position = selectedPosition(in: editorState),
              let location = pageLocation(for: position)
        else {
            return
        }

        currentSection = location.sectionID
        currentPage = location.pageNumber
    }

    private func pageDataSourceKey(for page: ComputedPage) -> String {
        "\(page.sectionID.rawValue)#\(page.pageNumber)"
    }

    private func headerFooterDataSourceKey(for sectionID: SectionID, slot: HeaderFooterSlot) -> String {
        "\(sectionID.rawValue)#\(slot.rawValue)"
    }

    private func broadcastSectionMutation(for sectionID: SectionID) {
        sectionDataSources[sectionID]?.emitExternalMutation(.batchUpdate)

        for dataSource in pageDataSources.values where dataSource.page.sectionID == sectionID {
            if let refreshedPage = layoutEngine.pages.first(where: {
                $0.sectionID == dataSource.page.sectionID && $0.pageNumber == dataSource.page.pageNumber
            }) {
                dataSource.page = refreshedPage
            }
            dataSource.emitExternalMutation(.batchUpdate)
        }
    }

    private func broadcastHeaderFooterMutation(for sectionID: SectionID) {
        for dataSource in headerFooterDataSources.values where dataSource.sectionID == sectionID {
            dataSource.emitExternalMutation(.batchUpdate)
        }
    }

    private func pruneDerivedEditorStateCaches() {
        let validSectionIDs = Set(document.sections.map(\.id))
        sectionRichTextStates = sectionRichTextStates.filter { validSectionIDs.contains($0.key) }
        sectionDataSources = sectionDataSources.filter { validSectionIDs.contains($0.key) }

        let validPageKeys = Set(layoutEngine.pages.map(pageDataSourceKey(for:)))
        pageRichTextStates = pageRichTextStates.filter { validPageKeys.contains($0.key) }
        pageDataSources = pageDataSources.filter { validPageKeys.contains($0.key) }

        headerFooterRichTextStates = headerFooterRichTextStates.filter { key, _ in
            validSectionIDs.contains(sectionID(fromHeaderFooterKey: key))
        }
        headerFooterDataSources = headerFooterDataSources.filter { key, _ in
            validSectionIDs.contains(sectionID(fromHeaderFooterKey: key))
        }
    }

    func pageScrollKey(for page: ComputedPage) -> String {
        pageDataSourceKey(for: page)
    }

    var currentPageScrollKey: String? {
        resolvedCurrentPage().map(pageScrollKey(for:))
    }

    private func makeDerivedRichTextState(allowedBlockIDs: [BlockID]) -> RichTextState {
        RichTextState(
            selection: initialSelection(for: allowedBlockIDs),
            activeAttributes: richTextState.activeAttributes,
            findState: richTextState.findState,
            writingMode: richTextState.writingMode,
            focusedBlockID: initialFocusedBlockID(for: allowedBlockIDs),
            zoomLevel: richTextState.zoomLevel
        )
    }

    private func initialSelection(for allowedBlockIDs: [BlockID]) -> TextSelection {
        let allowed = Set(allowedBlockIDs)

        switch richTextState.selection {
        case let .caret(blockID, offset) where allowed.contains(blockID):
            return .caret(blockID, offset: offset)
        case let .range(start, end) where allowed.contains(start.blockID) && allowed.contains(end.blockID):
            return .range(start: start, end: end)
        case let .blockSelection(blockIDs) where !allowed.intersection(blockIDs).isEmpty:
            return .blockSelection(allowed.intersection(blockIDs))
        default:
            guard let firstBlockID = allowedBlockIDs.first else {
                return .blockSelection([])
            }
            return .caret(firstBlockID, offset: 0)
        }
    }

    private func initialFocusedBlockID(for allowedBlockIDs: [BlockID]) -> BlockID? {
        if let focusedBlockID = richTextState.focusedBlockID, allowedBlockIDs.contains(focusedBlockID) {
            return focusedBlockID
        }
        return allowedBlockIDs.first
    }

    private func visibleBlockIDs(for page: ComputedPage) -> [BlockID] {
        if !page.blockPlacements.isEmpty {
            var seen: Set<BlockID> = []
            return page.blockPlacements.compactMap { placement in
                if seen.insert(placement.blockID).inserted {
                    return placement.blockID
                }
                return nil
            }
        }

        guard let section = document.section(page.sectionID) else { return [] }
        return page.blockRanges.flatMap { range in
            Array(range.startIndex...range.endIndex).compactMap { index in
                section.blocks.indices.contains(index) ? section.blocks[index].id : nil
            }
        }
    }

    private func headerFooterBlockID(for sectionID: SectionID, slot: HeaderFooterSlot) -> BlockID {
        BlockID("\(sectionID.rawValue)-\(slot.rawValue)")
    }

    private func sectionID(fromHeaderFooterKey key: String) -> SectionID {
        SectionID(String(key.split(separator: "#", maxSplits: 1).first ?? ""))
    }

    private func selectedPosition(in editorState: RichTextState) -> TextPosition? {
        switch editorState.selection {
        case let .caret(blockID, offset):
            return TextPosition(blockID: blockID, offset: offset)
        case let .range(start, _):
            return start
        case let .blockSelection(blockIDs):
            if let focusedBlockID = editorState.focusedBlockID {
                return TextPosition(blockID: focusedBlockID, offset: 0)
            }
            guard let firstBlockID = blockIDs.sorted(by: { $0.rawValue < $1.rawValue }).first else {
                return nil
            }
            return TextPosition(blockID: firstBlockID, offset: 0)
        }
    }

    private func pageLocation(for position: TextPosition) -> (sectionID: SectionID, pageNumber: Int)? {
        guard let section = document.sections.first(where: { section in
            section.blocks.contains(where: { $0.id == position.blockID })
        }) else {
            return nil
        }

        let candidatePlacements = layoutEngine.pages.flatMap { page in
            page.blockPlacements
                .filter { $0.blockID == position.blockID }
                .map { placement in
                    (page: page, placement: placement)
                }
        }

        guard let firstCandidate = candidatePlacements.first else {
            guard let pageNumber = layoutEngine.pageNumber(for: position.blockID) else { return nil }
            return (section.id, pageNumber)
        }

        guard let block = section.blocks.first(where: { $0.id == position.blockID }) else {
            return (firstCandidate.page.sectionID, firstCandidate.page.pageNumber)
        }

        let targetHeight = selectionHeight(for: position.offset, in: block, itemHeight: firstCandidate.placement.itemHeight)
        if let exactCandidate = candidatePlacements.first(where: { candidate in
            contains(selectionHeight: targetHeight, in: candidate.placement)
        }) {
            return (exactCandidate.page.sectionID, exactCandidate.page.pageNumber)
        }

        if targetHeight <= (candidatePlacements.first?.placement.partialRange?.lowerBound ?? 0) {
            return (firstCandidate.page.sectionID, firstCandidate.page.pageNumber)
        }

        if let lastCandidate = candidatePlacements.last {
            return (lastCandidate.page.sectionID, lastCandidate.page.pageNumber)
        }

        return (firstCandidate.page.sectionID, firstCandidate.page.pageNumber)
    }

    private func selectionHeight(for offset: Int, in block: Block, itemHeight: CGFloat) -> CGFloat {
        let totalCharacters = max(editableCharacterCount(for: block), 1)
        let clampedOffset = min(max(offset, 0), totalCharacters)
        let ratio = CGFloat(clampedOffset) / CGFloat(totalCharacters)
        return min(max(itemHeight * ratio, 0), itemHeight)
    }

    private func contains(selectionHeight: CGFloat, in placement: BlockFragmentPlacement) -> Bool {
        guard let partialRange = placement.partialRange else { return true }

        if selectionHeight >= placement.itemHeight {
            return partialRange.upperBound >= placement.itemHeight
        }

        return selectionHeight >= partialRange.lowerBound && selectionHeight < partialRange.upperBound
    }

    private func editableCharacterCount(for block: Block) -> Int {
        switch block.content {
        case let .text(content),
             let .heading(content, _),
             let .blockQuote(content),
             let .list(content, _, _):
            return max(content.plainText.count, 1)
        case let .codeBlock(code, _):
            return max(code.count, 1)
        case let .table(table):
            if let caption = table.caption?.plainText, !caption.isEmpty {
                return max(caption.count, 1)
            }
            let flattened = table.rows.flatMap { $0 }.map(\.plainText).joined(separator: " ")
            return max(flattened.count, 1)
        case let .image(image):
            return max((image.altText ?? "[Image]").count, 1)
        case .divider:
            return 1
        case let .embed(embed):
            return max((embed.payload ?? "[\(embed.kind)]").count, 1)
        }
    }

    private func currentPageIndex() -> Int? {
        guard let page = resolvedCurrentPage() else { return nil }
        return layoutEngine.pages.firstIndex(where: { $0.id == page.id })
    }

    private func resolvedCurrentPage() -> ComputedPage? {
        if let currentSection {
            if let exact = layoutEngine.pages.first(where: {
                $0.sectionID == currentSection && $0.pageNumber == currentPage
            }) {
                return exact
            }

            if let sameSection = layoutEngine.pages.first(where: { $0.sectionID == currentSection }) {
                return sameSection
            }
        }

        return layoutEngine.pages.first(where: { $0.pageNumber == currentPage }) ?? layoutEngine.pages.first
    }

    private func select(page: ComputedPage) {
        currentSection = page.sectionID
        currentPage = page.pageNumber
    }

    private func ensureCurrentPageExists() {
        guard resolvedCurrentPage() == nil, let firstPage = layoutEngine.pages.first else { return }
        select(page: firstPage)
    }
}

public enum HeaderFooterAlignment: String, Sendable, Codable {
    case left
    case center
    case right
}

public enum HeaderFooterVariant: String, Sendable, Codable {
    case first
    case primary
    case even
}

public enum HeaderFooterSlot: String, Sendable, Codable {
    case firstHeaderLeft
    case firstHeaderCenter
    case firstHeaderRight
    case headerLeft
    case headerCenter
    case headerRight
    case firstFooterLeft
    case firstFooterCenter
    case firstFooterRight
    case footerLeft
    case footerCenter
    case footerRight
    case evenHeaderLeft
    case evenHeaderCenter
    case evenHeaderRight
    case evenFooterLeft
    case evenFooterCenter
    case evenFooterRight

    var isHeader: Bool {
        switch self {
        case .firstHeaderLeft, .firstHeaderCenter, .firstHeaderRight,
             .headerLeft, .headerCenter, .headerRight,
             .evenHeaderLeft, .evenHeaderCenter, .evenHeaderRight:
            true
        case .firstFooterLeft, .firstFooterCenter, .firstFooterRight,
             .footerLeft, .footerCenter, .footerRight,
             .evenFooterLeft, .evenFooterCenter, .evenFooterRight:
            false
        }
    }

    var alignment: HeaderFooterAlignment {
        switch self {
        case .firstHeaderLeft, .headerLeft, .firstFooterLeft, .footerLeft, .evenHeaderLeft, .evenFooterLeft:
            .left
        case .firstHeaderCenter, .headerCenter, .firstFooterCenter, .footerCenter, .evenHeaderCenter, .evenFooterCenter:
            .center
        case .firstHeaderRight, .headerRight, .firstFooterRight, .footerRight, .evenHeaderRight, .evenFooterRight:
            .right
        }
    }

    var variant: HeaderFooterVariant {
        switch self {
        case .firstHeaderLeft, .firstHeaderCenter, .firstHeaderRight,
             .firstFooterLeft, .firstFooterCenter, .firstFooterRight:
            .first
        case .headerLeft, .headerCenter, .headerRight, .footerLeft, .footerCenter, .footerRight:
            .primary
        case .evenHeaderLeft, .evenHeaderCenter, .evenHeaderRight,
             .evenFooterLeft, .evenFooterCenter, .evenFooterRight:
            .even
        }
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

    fileprivate func emitExternalMutation(_ mutation: RichTextMutation) {
        notify(mutation)
    }
}

@MainActor
@Observable
public final class PageScopedDataSource: RichTextDataSource {
    private unowned let editorState: DocumentEditorState
    public var page: ComputedPage

    private var observers: [UUID: @MainActor (RichTextMutation) -> Void] = [:]

    public init(editorState: DocumentEditorState, page: ComputedPage) {
        self.editorState = editorState
        self.page = page
    }

    public var blocks: [Block] {
        let sectionBlocks = editorState.blocks(for: page.sectionID)
        return visibleSectionIndices().compactMap { index in
            sectionBlocks.indices.contains(index) ? sectionBlocks[index] : nil
        }
    }

    public func block(at index: Int) -> Block {
        blocks[index]
    }

    public func insertBlocks(_ blocks: [Block], at index: Int) {
        var updated = editorState.blocks(for: page.sectionID)
        let insertionIndex = insertionSectionIndex(forLocalIndex: index, in: updated)
        updated.insert(contentsOf: blocks, at: insertionIndex)
        editorState.updateSectionBlocks(updated, for: page.sectionID)
        notify(.blocksInserted(indices: IndexSet(index..<(index + blocks.count))))
    }

    public func deleteBlocks(at indices: IndexSet) {
        var updated = editorState.blocks(for: page.sectionID)
        let sectionIndices = indices
            .compactMap { localIndex in sectionIndex(forLocalIndex: localIndex) }
            .sorted(by: >)

        for index in sectionIndices where updated.indices.contains(index) {
            updated.remove(at: index)
        }

        editorState.updateSectionBlocks(updated, for: page.sectionID)
        notify(.blocksDeleted(indices: indices))
    }

    public func moveBlocks(from source: IndexSet, to destination: Int) {
        let existingBlocks = blocks
        var reordered = existingBlocks
        let moving = source.sorted().compactMap { reordered.indices.contains($0) ? reordered[$0] : nil }
        for index in source.sorted(by: >) where reordered.indices.contains(index) {
            reordered.remove(at: index)
        }

        let insertionIndex = min(max(destination, 0), reordered.count)
        reordered.insert(contentsOf: moving, at: insertionIndex)
        replaceVisibleBlocks(with: reordered)
        notify(.blocksMoved(from: source, to: destination))
    }

    public func replaceBlock(at index: Int, with block: Block) {
        var updated = editorState.blocks(for: page.sectionID)
        guard let sectionIndex = sectionIndex(forLocalIndex: index), updated.indices.contains(sectionIndex) else { return }
        updated[sectionIndex] = block
        editorState.updateSectionBlocks(updated, for: page.sectionID)
        notify(.blockReplaced(index: index))
    }

    public func updateTextContent(blockID: BlockID, content: TextContent) {
        guard let index = blocks.firstIndex(where: { $0.id == blockID }) else { return }
        var updated = blocks
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
        replaceVisibleBlocks(with: updated)
        notify(.textUpdated(blockID: blockID))
    }

    public func updateBlockType(blockID: BlockID, type: BlockType, content: BlockContent) {
        guard let index = blocks.firstIndex(where: { $0.id == blockID }) else { return }
        var updated = blocks
        updated[index].type = type
        updated[index].content = content
        replaceVisibleBlocks(with: updated)
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

    private func visibleSectionIndices() -> [Int] {
        if !page.blockPlacements.isEmpty {
            var seen: Set<Int> = []
            return page.blockPlacements.compactMap { placement in
                if seen.insert(placement.blockIndex).inserted {
                    return placement.blockIndex
                }
                return nil
            }
        }

        return page.blockRanges.flatMap { range in
            Array(range.startIndex...range.endIndex)
        }
    }

    private func sectionIndex(forLocalIndex localIndex: Int) -> Int? {
        let visible = visibleSectionIndices()
        guard visible.indices.contains(localIndex) else { return nil }
        return visible[localIndex]
    }

    private func insertionSectionIndex(forLocalIndex localIndex: Int, in sectionBlocks: [Block]) -> Int {
        let visible = visibleSectionIndices()
        if let mapped = visible.indices.contains(localIndex) ? visible[localIndex] : nil {
            return mapped
        }

        if let first = visible.first, localIndex <= 0 {
            return first
        }

        if let last = visible.last {
            return min(last + 1, sectionBlocks.count)
        }

        return sectionBlocks.count
    }

    private func replaceVisibleBlocks(with newBlocks: [Block]) {
        var updated = editorState.blocks(for: page.sectionID)
        let visible = visibleSectionIndices().sorted(by: >)
        let insertionIndex = max(visible.last ?? updated.count, 0)

        for index in visible where updated.indices.contains(index) {
            updated.remove(at: index)
        }

        updated.insert(contentsOf: newBlocks, at: min(insertionIndex, updated.count))
        editorState.updateSectionBlocks(updated, for: page.sectionID)
    }

    private func notify(_ mutation: RichTextMutation) {
        for observer in observers.values {
            observer(mutation)
        }
    }

    fileprivate func emitExternalMutation(_ mutation: RichTextMutation) {
        notify(mutation)
    }
}

@MainActor
@Observable
public final class HeaderFooterDataSource: RichTextDataSource {
    private unowned let editorState: DocumentEditorState
    public let sectionID: SectionID
    public let slot: HeaderFooterSlot

    private var observers: [UUID: @MainActor (RichTextMutation) -> Void] = [:]

    public init(editorState: DocumentEditorState, sectionID: SectionID, slot: HeaderFooterSlot) {
        self.editorState = editorState
        self.sectionID = sectionID
        self.slot = slot
    }

    public var blocks: [Block] {
        [Block(id: blockID, type: .paragraph, content: .text(TextContent(runs: editorState.headerFooterRuns(for: sectionID, slot: slot))))]
    }

    public func block(at index: Int) -> Block {
        blocks[min(max(index, 0), blocks.count - 1)]
    }

    public func insertBlocks(_ blocks: [Block], at index: Int) {
        _ = index
        replaceContent(with: blocks)
        notify(.blocksInserted(indices: IndexSet(integersIn: 0..<blocks.count)))
    }

    public func deleteBlocks(at indices: IndexSet) {
        _ = indices
        editorState.updateHeaderFooterRuns([], for: sectionID, slot: slot)
        notify(.blocksDeleted(indices: IndexSet(integer: 0)))
    }

    public func moveBlocks(from source: IndexSet, to destination: Int) {
        _ = source
        _ = destination
        notify(.batchUpdate)
    }

    public func replaceBlock(at index: Int, with block: Block) {
        _ = index
        replaceContent(with: [block])
        notify(.blockReplaced(index: 0))
    }

    public func updateTextContent(blockID: BlockID, content: TextContent) {
        guard blockID == self.blockID else { return }
        editorState.updateHeaderFooterRuns(content.runs, for: sectionID, slot: slot)
        notify(.textUpdated(blockID: blockID))
    }

    public func updateBlockType(blockID: BlockID, type: BlockType, content: BlockContent) {
        guard blockID == self.blockID else { return }
        let runs: [TextRun]
        switch content {
        case let .text(textContent),
             let .heading(textContent, _),
             let .blockQuote(textContent),
             let .list(textContent, _, _):
            runs = textContent.runs
        case let .codeBlock(code, _):
            runs = [TextRun(text: code)]
        case let .table(table):
            runs = [TextRun(text: table.caption?.plainText ?? table.rows.flatMap { $0 }.map(\.plainText).joined(separator: " "))]
        case let .image(image):
            runs = [TextRun(text: image.altText ?? "")]
        case .divider:
            runs = []
        case let .embed(embed):
            runs = [TextRun(text: embed.payload ?? "")]
        }

        _ = type
        editorState.updateHeaderFooterRuns(runs, for: sectionID, slot: slot)
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

    private var blockID: BlockID {
        BlockID("\(sectionID.rawValue)-\(slot.rawValue)")
    }

    private func replaceContent(with blocks: [Block]) {
        let runs = blocks.compactMap { block -> [TextRun]? in
            switch block.content {
            case let .text(content),
                 let .heading(content, _),
                 let .blockQuote(content),
                 let .list(content, _, _):
                return content.runs
            case let .codeBlock(code, _):
                return [TextRun(text: code)]
            case let .table(table):
                return [TextRun(text: table.caption?.plainText ?? table.rows.flatMap { $0 }.map(\.plainText).joined(separator: " "))]
            case let .image(image):
                return [TextRun(text: image.altText ?? "")]
            case .divider:
                return []
            case let .embed(embed):
                return [TextRun(text: embed.payload ?? "")]
            }
        }
        .flatMap { $0 }

        editorState.updateHeaderFooterRuns(runs, for: sectionID, slot: slot)
    }

    private func notify(_ mutation: RichTextMutation) {
        for observer in observers.values {
            observer(mutation)
        }
    }

    fileprivate func emitExternalMutation(_ mutation: RichTextMutation) {
        notify(mutation)
    }
}
