import Foundation
import RichTextPrimitive
import TrackChangesPrimitive

struct TrackedChangeContext {
    let sectionID: SectionID
    let before: Block
    let after: Block
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
            ?? changeTracker.changes.first(where: { $0.id == currentTrackedChangeID })
    }

    public var currentTrackedChangeSummary: String? {
        guard let change = currentTrackedChange else { return nil }

        switch change.type {
        case let .insertion(text):
            let preview = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return preview.isEmpty ? "Insertion" : "Insert: \(String(preview.prefix(24)))"
        case let .deletion(text):
            let preview = text.trimmingCharacters(in: .whitespacesAndNewlines)
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
        focusDocumentSelection(
            TextSelection.caret(
                BlockID(change.anchor.blockID),
                offset: change.anchor.offset
            )
        )
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

        replaceBlock(context.before, in: context.sectionID)
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
            replaceBlock(context.before, in: context.sectionID)
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
        trackedChangeContexts[change.id] = TrackedChangeContext(sectionID: sectionID, before: before, after: after)
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
