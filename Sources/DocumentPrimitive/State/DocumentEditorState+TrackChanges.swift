import Foundation
import RichTextPrimitive
import TrackChangesPrimitive

enum TrackedStructuralChangeOperation {
    case replace(before: Block, after: Block)
    case insert(blocks: [Block], index: Int)
    case delete(blocks: [Block], index: Int)
}

struct TrackedChangeContext {
    let sectionID: SectionID
    let operation: TrackedStructuralChangeOperation
}

@MainActor
extension DocumentEditorState {
    public func changes(on page: ComputedPage) -> [TrackedChange] {
        let visibleContentIDs = visibleContentIDsForTrackChanges(on: page)
        return changeTracker.visibleChanges.filter { visibleContentIDs.contains($0.anchor.blockID) }
    }

    public var currentTrackedChange: TrackedChange? {
        guard let currentTrackedChangeID else { return nil }
        return changeTracker.visibleChanges.first(where: { $0.id == currentTrackedChangeID })
    }

    public var currentTrackedChangeSummary: String? {
        guard let change = currentTrackedChange else { return nil }
        let context = trackedChangeContexts[change.id]

        switch change.type {
        case let .insertion(text):
            let preview = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if case let .insert(blocks, _) = context?.operation {
                return structuralChangeSummary(
                    count: blocks.count,
                    singular: "Inserted block",
                    plural: "Inserted blocks",
                    preview: preview
                )
            }
            return preview.isEmpty ? "Insertion" : "Insert: \(String(preview.prefix(24)))"
        case let .deletion(text):
            let preview = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if case let .delete(blocks, _) = context?.operation {
                return structuralChangeSummary(
                    count: blocks.count,
                    singular: "Deleted block",
                    plural: "Deleted blocks",
                    preview: preview
                )
            }
            return preview.isEmpty ? "Deletion" : "Delete: \(String(preview.prefix(24)))"
        case .formatChange:
            return "Formatting change"
        }
    }

    public func goToNextChange() {
        let visibleChanges = changeTracker.visibleChanges
        guard !visibleChanges.isEmpty else { return }

        guard let currentTrackedChangeID,
              let currentIndex = visibleChanges.firstIndex(where: { $0.id == currentTrackedChangeID }),
              currentIndex + 1 < visibleChanges.count
        else {
            focusChange(visibleChanges.first!.id)
            return
        }

        focusChange(visibleChanges[currentIndex + 1].id)
    }

    public func goToPreviousChange() {
        let visibleChanges = changeTracker.visibleChanges
        guard !visibleChanges.isEmpty else { return }

        guard let currentTrackedChangeID,
              let currentIndex = visibleChanges.firstIndex(where: { $0.id == currentTrackedChangeID }),
              currentIndex > 0
        else {
            focusChange(visibleChanges.last!.id)
            return
        }

        focusChange(visibleChanges[currentIndex - 1].id)
    }

    public func focusChange(_ id: ChangeID) {
        guard let change = changeTracker.visibleChanges.first(where: { $0.id == id })
            ?? changeTracker.changes.first(where: { $0.id == id })
        else {
            return
        }

        currentTrackedChangeID = change.id
        let selection = TextSelection.caret(
            BlockID(change.anchor.blockID),
            offset: change.anchor.offset
        )

        if position(for: selection).flatMap({ sectionID(forBlockID: $0.blockID) }) != nil {
            focusDocumentSelection(selection)
            return
        }

        if let context = trackedChangeContexts[id] {
            focusFallbackSelection(for: context)
        }
    }

    public func acceptCurrentChange() {
        let visibleChanges = changeTracker.visibleChanges
        guard !visibleChanges.isEmpty else { return }

        let target = currentTrackedChange ?? visibleChanges.first!
        let successor = successorChangeID(afterRemoving: target.id, from: visibleChanges)

        acceptChange(target.id)
        if let successor {
            focusChange(successor)
        }
    }

    public func rejectCurrentChange() {
        let visibleChanges = changeTracker.visibleChanges
        guard !visibleChanges.isEmpty else { return }

        let target = currentTrackedChange ?? visibleChanges.first!
        let successor = successorChangeID(afterRemoving: target.id, from: visibleChanges)

        rejectChange(target.id)
        if let successor {
            focusChange(successor)
        }
    }

    public func acceptChange(_ id: ChangeID) {
        trackedChangeContexts.removeValue(forKey: id)
        if currentTrackedChangeID == id {
            currentTrackedChangeID = nil
        }
        changeTracker.accept(id)
    }

    public func rejectChange(_ id: ChangeID) {
        guard let context = trackedChangeContexts.removeValue(forKey: id) else {
            if currentTrackedChangeID == id {
                currentTrackedChangeID = nil
            }
            changeTracker.reject(id)
            return
        }

        applyRejectedChange(context)
        if currentTrackedChangeID == id {
            currentTrackedChangeID = nil
        }
        changeTracker.reject(id)
    }

    public func acceptAllChanges() {
        trackedChangeContexts.removeAll()
        currentTrackedChangeID = nil
        changeTracker.acceptAll()
    }

    public func rejectAllChanges() {
        let contexts = changeTracker.changes.reversed().compactMap { change in
            trackedChangeContexts[change.id]
        }

        for context in contexts {
            applyRejectedChange(context)
        }

        trackedChangeContexts.removeAll()
        currentTrackedChangeID = nil
        changeTracker.rejectAll()
    }

    func recordTrackedChange(
        in sectionID: SectionID,
        before: Block,
        after: Block
    ) {
        guard changeTracker.isTracking, before != after else { return }
        guard let beforeContent = trackableTextContent(for: before),
              let afterContent = trackableTextContent(for: after)
        else {
            return
        }

        let change: TrackedChange?
        if beforeContent.plainText == afterContent.plainText {
            change = recordFormatChange(before: before, after: after, length: max(beforeContent.plainText.count, 1))
        } else if let delta = pureInsertionDelta(from: beforeContent.plainText, to: afterContent.plainText) {
            change = recordInsertion(for: before.id, offset: delta.offset, text: delta.text)
        } else if let delta = pureDeletionDelta(from: beforeContent.plainText, to: afterContent.plainText) {
            change = recordDeletion(for: before.id, offset: delta.offset, text: delta.text)
        } else {
            change = recordFormatChange(
                before: before,
                after: after,
                length: max(max(beforeContent.plainText.count, afterContent.plainText.count), 1)
            )
        }

        guard let change else { return }
        trackedChangeContexts[change.id] = TrackedChangeContext(
            sectionID: sectionID,
            operation: .replace(before: before, after: after)
        )
    }

    func recordStructuralTrackedChanges(
        in sectionID: SectionID,
        before beforeBlocks: [Block],
        after afterBlocks: [Block]
    ) {
        guard changeTracker.isTracking, beforeBlocks != afterBlocks else { return }

        let beforeByID = Dictionary(uniqueKeysWithValues: beforeBlocks.map { ($0.id, $0) })
        let afterByID = Dictionary(uniqueKeysWithValues: afterBlocks.map { ($0.id, $0) })
        let beforeIDs = Set(beforeByID.keys)
        let afterIDs = Set(afterByID.keys)

        for sharedID in beforeBlocks.map(\.id) where afterIDs.contains(sharedID) {
            guard let before = beforeByID[sharedID], let after = afterByID[sharedID], before != after else { continue }
            recordTrackedChange(in: sectionID, before: before, after: after)
        }

        let insertedIndices = afterBlocks.indices.filter { !beforeIDs.contains(afterBlocks[$0].id) }
        for group in contiguousIndexGroups(insertedIndices) {
            let insertedBlocks = group.map { afterBlocks[$0] }
            guard !insertedBlocks.isEmpty else { continue }
            recordBlockInsertionChange(
                in: sectionID,
                blocks: insertedBlocks,
                at: group.first ?? 0
            )
        }

        let deletedIndices = beforeBlocks.indices.filter { !afterIDs.contains(beforeBlocks[$0].id) }
        for group in contiguousIndexGroups(deletedIndices) {
            let deletedBlocks = group.map { beforeBlocks[$0] }
            guard !deletedBlocks.isEmpty else { continue }

            let anchorBlockID: BlockID? = {
                if let first = group.first, afterBlocks.indices.contains(first) {
                    return afterBlocks[first].id
                }
                if let first = group.first, first > 0, afterBlocks.indices.contains(first - 1) {
                    return afterBlocks[first - 1].id
                }
                return firstFocusableBlockID(afterReplacingSection: sectionID, with: afterBlocks)
            }()

            recordBlockDeletionChange(
                in: sectionID,
                blocks: deletedBlocks,
                at: group.first ?? 0,
                anchorBlockID: anchorBlockID
            )
        }
    }

    private func recordInsertion(for blockID: BlockID, offset: Int, text: String) -> TrackedChange? {
        guard !text.isEmpty else { return nil }

        changeTracker.recordInsertion(
            anchor: ChangeAnchor(blockID: blockID.rawValue, offset: offset, length: text.count),
            text: text
        )
        return changeTracker.changes.last
    }

    private func recordDeletion(for blockID: BlockID, offset: Int, text: String) -> TrackedChange? {
        guard !text.isEmpty else { return nil }

        changeTracker.recordDeletion(
            anchor: ChangeAnchor(blockID: blockID.rawValue, offset: offset, length: text.count),
            text: text
        )
        return changeTracker.changes.last
    }

    private func recordFormatChange(
        before: Block,
        after: Block,
        length: Int
    ) -> TrackedChange? {
        let encodedBefore = encodedBlockSnapshot(before)
        let encodedAfter = encodedBlockSnapshot(after)

        changeTracker.recordFormatChange(
            anchor: ChangeAnchor(blockID: before.id.rawValue, offset: 0, length: length),
            from: ["block": encodedBefore],
            to: ["block": encodedAfter]
        )
        return changeTracker.changes.last
    }

    private func recordBlockInsertionChange(
        in sectionID: SectionID,
        blocks: [Block],
        at index: Int
    ) {
        let preview = structuralPreview(for: blocks)
        let anchorBlockID = blocks.first?.id ?? firstFocusableBlockID(afterReplacingSection: sectionID, with: blocks)
        guard let anchorBlockID else { return }

        changeTracker.recordInsertion(
            anchor: ChangeAnchor(blockID: anchorBlockID.rawValue, offset: 0, length: max(preview.count, 1)),
            text: preview
        )

        guard let change = changeTracker.changes.last else { return }
        trackedChangeContexts[change.id] = TrackedChangeContext(
            sectionID: sectionID,
            operation: .insert(blocks: blocks, index: index)
        )
    }

    private func recordBlockDeletionChange(
        in sectionID: SectionID,
        blocks: [Block],
        at index: Int,
        anchorBlockID: BlockID?
    ) {
        let preview = structuralPreview(for: blocks)
        let anchorBlockID = anchorBlockID ?? blocks.first?.id ?? firstFocusableBlockID(afterReplacingSection: sectionID, with: [])
        guard let anchorBlockID else { return }

        changeTracker.recordDeletion(
            anchor: ChangeAnchor(blockID: anchorBlockID.rawValue, offset: 0, length: max(preview.count, 1)),
            text: preview
        )

        guard let change = changeTracker.changes.last else { return }
        trackedChangeContexts[change.id] = TrackedChangeContext(
            sectionID: sectionID,
            operation: .delete(blocks: blocks, index: index)
        )
    }

    private func encodedBlockSnapshot(_ block: Block) -> String {
        let data = (try? JSONEncoder().encode(block)) ?? Data()
        return data.base64EncodedString()
    }

    private func trackableTextContent(for block: Block) -> TextContent? {
        switch block.content {
        case let .text(content),
             let .heading(content, _),
             let .blockQuote(content),
             let .list(content, _, _):
            return content
        case let .codeBlock(code, _):
            return .plain(code)
        case .table, .image, .divider, .embed:
            return nil
        }
    }

    private func visibleContentIDsForTrackChanges(on page: ComputedPage) -> Set<String> {
        if !page.blockPlacements.isEmpty {
            return Set(page.blockPlacements.map { $0.blockID.rawValue })
        }

        guard let section = document.section(page.sectionID) else { return [] }
        return Set(
            page.blockRanges.flatMap { range in
                Array(range.startIndex...range.endIndex).compactMap { index in
                    section.blocks.indices.contains(index) ? section.blocks[index].id.rawValue : nil
                }
            }
        )
    }

    func focusDocumentSelection(_ selection: TextSelection) {
        guard let position = position(for: selection) else { return }
        guard let sectionID = sectionID(forBlockID: position.blockID) else { return }

        richTextState.selection = selection
        richTextState.focusedBlockID = position.blockID

        let sectionState = richTextState(forSection: sectionID)
        sectionState.selection = selection
        sectionState.focusedBlockID = position.blockID

        let blockState = richTextState(forBlock: position.blockID, in: sectionID)
        blockState.selection = selection
        blockState.focusedBlockID = position.blockID

        for page in layoutEngine.pages where page.sectionID == sectionID {
            guard visibleContentIDsForTrackChanges(on: page).contains(position.blockID.rawValue) else { continue }

            let pageState = richTextState(forPage: page)
            pageState.selection = selection
            pageState.focusedBlockID = position.blockID

            for placement in page.blockPlacements where placement.blockID == position.blockID {
                let fragmentState = richTextState(forFragment: placement, in: sectionID)
                fragmentState.selection = selection
                fragmentState.focusedBlockID = position.blockID
            }
        }

        syncCurrentLocationToSelection()
    }

    func position(for selection: TextSelection) -> TextPosition? {
        switch selection {
        case let .caret(blockID, offset):
            return TextPosition(blockID: blockID, offset: offset)
        case let .range(start, _):
            return start
        case let .blockSelection(ids):
            guard let first = ids.sorted(by: { $0.rawValue < $1.rawValue }).first else { return nil }
            return TextPosition(blockID: first, offset: 0)
        }
    }

    func sectionID(forBlockID blockID: BlockID) -> SectionID? {
        document.sections.first(where: { section in
            section.blocks.contains(where: { $0.id == blockID })
        })?.id
    }

    private func pureInsertionDelta(from oldText: String, to newText: String) -> (offset: Int, text: String)? {
        let oldCharacters = Array(oldText)
        let newCharacters = Array(newText)
        guard newCharacters.count > oldCharacters.count else { return nil }

        let prefix = commonPrefixLength(oldCharacters, newCharacters)
        let suffix = commonSuffixLength(oldCharacters, newCharacters, prefix: prefix)
        let oldMiddleCount = oldCharacters.count - prefix - suffix
        let newMiddleCount = newCharacters.count - prefix - suffix

        guard oldMiddleCount == 0, newMiddleCount > 0 else { return nil }
        let inserted = String(newCharacters[prefix..<(prefix + newMiddleCount)])
        return (prefix, inserted)
    }

    private func pureDeletionDelta(from oldText: String, to newText: String) -> (offset: Int, text: String)? {
        let oldCharacters = Array(oldText)
        let newCharacters = Array(newText)
        guard oldCharacters.count > newCharacters.count else { return nil }

        let prefix = commonPrefixLength(oldCharacters, newCharacters)
        let suffix = commonSuffixLength(oldCharacters, newCharacters, prefix: prefix)
        let oldMiddleCount = oldCharacters.count - prefix - suffix
        let newMiddleCount = newCharacters.count - prefix - suffix

        guard oldMiddleCount > 0, newMiddleCount == 0 else { return nil }
        let deleted = String(oldCharacters[prefix..<(prefix + oldMiddleCount)])
        return (prefix, deleted)
    }

    private func commonPrefixLength(_ lhs: [Character], _ rhs: [Character]) -> Int {
        var count = 0
        while count < min(lhs.count, rhs.count), lhs[count] == rhs[count] {
            count += 1
        }
        return count
    }

    private func commonSuffixLength(_ lhs: [Character], _ rhs: [Character], prefix: Int) -> Int {
        var count = 0
        while
            lhs.count - count - 1 >= prefix,
            rhs.count - count - 1 >= prefix,
            lhs[lhs.count - count - 1] == rhs[rhs.count - count - 1]
        {
            count += 1
        }
        return count
    }

    private func applyRejectedChange(_ context: TrackedChangeContext) {
        switch context.operation {
        case let .replace(before, _):
            replaceBlock(before, in: context.sectionID)
        case let .insert(blocks, index):
            removeTrackedBlocks(blocks.map(\.id), from: context.sectionID, preferredIndex: index)
        case let .delete(blocks, index):
            insertTrackedBlocks(blocks, into: context.sectionID, at: index)
        }
    }

    private func removeTrackedBlocks(
        _ blockIDs: [BlockID],
        from sectionID: SectionID,
        preferredIndex: Int
    ) {
        var updated = blocks(for: sectionID)

        for blockID in blockIDs.reversed() {
            if let index = updated.firstIndex(where: { $0.id == blockID }) {
                updated.remove(at: index)
            }
        }

        if updated.isEmpty {
            let fallbackID = blockIDs.first ?? BlockID(UUID().uuidString)
            updated = [Block(id: fallbackID, type: .paragraph, content: .text(.plain("")))]
        }

        updateSectionBlocks(updated, for: sectionID)

        let focusBlockID = updated.indices.contains(preferredIndex)
            ? updated[preferredIndex].id
            : updated.last?.id
        if let focusBlockID {
            focusDocumentSelection(.caret(focusBlockID, offset: 0))
        }
    }

    private func insertTrackedBlocks(
        _ blocks: [Block],
        into sectionID: SectionID,
        at index: Int
    ) {
        var updated = self.blocks(for: sectionID)

        if updated.count == 1,
           updated.first?.content.textContent?.plainText.isEmpty == true,
           blocks.count == 1,
           updated.first?.id == blocks.first?.id {
            updated = blocks
        } else {
            let insertionIndex = min(max(index, 0), updated.count)
            updated.insert(contentsOf: blocks, at: insertionIndex)
        }

        updateSectionBlocks(updated, for: sectionID)

        if let focusBlockID = blocks.first?.id {
            focusDocumentSelection(.caret(focusBlockID, offset: 0))
        }
    }

    private func focusFallbackSelection(for context: TrackedChangeContext) {
        guard let blockID = fallbackFocusBlockID(for: context) else { return }
        focusDocumentSelection(.caret(blockID, offset: 0))
    }

    private func fallbackFocusBlockID(for context: TrackedChangeContext) -> BlockID? {
        let sectionBlocks = blocks(for: context.sectionID)

        switch context.operation {
        case let .replace(before, after):
            if sectionBlocks.contains(where: { $0.id == after.id }) {
                return after.id
            }
            if sectionBlocks.contains(where: { $0.id == before.id }) {
                return before.id
            }
        case let .insert(blocks, index):
            if let existing = blocks.first(where: { inserted in
                sectionBlocks.contains(where: { $0.id == inserted.id })
            }) {
                return existing.id
            }
            if sectionBlocks.indices.contains(index) {
                return sectionBlocks[index].id
            }
            return sectionBlocks.last?.id
        case let .delete(_, index):
            if sectionBlocks.indices.contains(index) {
                return sectionBlocks[index].id
            }
            if index > 0, sectionBlocks.indices.contains(index - 1) {
                return sectionBlocks[index - 1].id
            }
            return sectionBlocks.last?.id
        }

        return document.sections.flatMap(\.blocks).first?.id
    }

    private func structuralPreview(for blocks: [Block]) -> String {
        let previews = blocks.map(blockPreviewText(for:))
        let joined = previews.joined(separator: "\n")
        return joined.isEmpty ? "[Block change]" : joined
    }

    private func blockPreviewText(for block: Block) -> String {
        switch block.content {
        case let .text(content),
             let .heading(content, _),
             let .blockQuote(content),
             let .list(content, _, _):
            return fallbackBlockPreview(content.plainText, block: block)
        case let .codeBlock(code, _):
            return fallbackBlockPreview(code, block: block)
        case let .table(table):
            let caption = table.caption?.plainText ?? ""
            let cells = table.rows.flatMap { $0 }.map(\.plainText).joined(separator: " ")
            return fallbackBlockPreview(caption.isEmpty ? cells : caption, block: block)
        case let .image(image):
            return fallbackBlockPreview(image.altText ?? "", block: block)
        case .divider:
            return "[Divider]"
        case let .embed(embed):
            return fallbackBlockPreview(embed.payload ?? embed.kind, block: block)
        }
    }

    private func fallbackBlockPreview(_ value: String, block: Block) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return String(trimmed.prefix(80))
        }
        return "[\(block.type.rawValue)]"
    }

    private func contiguousIndexGroups(_ indices: [Int]) -> [[Int]] {
        guard !indices.isEmpty else { return [] }

        var groups: [[Int]] = []
        var currentGroup: [Int] = [indices[0]]

        for index in indices.dropFirst() {
            if let last = currentGroup.last, index == last + 1 {
                currentGroup.append(index)
            } else {
                groups.append(currentGroup)
                currentGroup = [index]
            }
        }

        groups.append(currentGroup)
        return groups
    }

    private func firstFocusableBlockID(afterReplacingSection sectionID: SectionID, with blocks: [Block]) -> BlockID? {
        if let first = blocks.first?.id {
            return first
        }

        if let section = document.section(sectionID), let first = section.blocks.first?.id {
            return first
        }

        return document.sections.flatMap(\.blocks).first?.id
    }

    private func structuralChangeSummary(
        count: Int,
        singular: String,
        plural: String,
        preview: String
    ) -> String {
        let title = count == 1 ? singular : "\(count) \(plural.lowercased())"
        guard !preview.isEmpty else { return title }
        return "\(title): \(String(preview.prefix(24)))"
    }

    private func successorChangeID(
        afterRemoving id: ChangeID,
        from visibleChanges: [TrackedChange]
    ) -> ChangeID? {
        guard let index = visibleChanges.firstIndex(where: { $0.id == id }) else {
            return visibleChanges.first?.id
        }

        if index < visibleChanges.count - 1 {
            return visibleChanges[index + 1].id
        }
        if index > 0 {
            return visibleChanges[index - 1].id
        }
        return nil
    }
}
