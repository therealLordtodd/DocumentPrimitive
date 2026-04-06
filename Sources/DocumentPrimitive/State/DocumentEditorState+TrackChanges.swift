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

    public func acceptChange(_ id: ChangeID) {
        trackedChangeContexts.removeValue(forKey: id)
        changeTracker.accept(id)
    }

    public func rejectChange(_ id: ChangeID) {
        guard let context = trackedChangeContexts.removeValue(forKey: id) else {
            changeTracker.reject(id)
            return
        }

        replaceBlock(context.before, in: context.sectionID)
        changeTracker.reject(id)
    }

    public func acceptAllChanges() {
        trackedChangeContexts.removeAll()
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
}
