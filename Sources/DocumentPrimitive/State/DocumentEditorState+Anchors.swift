import BookmarkPrimitive
import CommentPrimitive
import Foundation
import RichTextPrimitive

struct DocumentBookmarkPositionResolver: BookmarkPositionResolver, Sendable {
    let pageNumbersByContentID: [String: Int]
    let orderByContentID: [String: Int]

    func pageNumber(for anchor: BookmarkAnchor) -> Int? {
        pageNumbersByContentID[anchor.contentID]
    }

    func isAbove(anchor: BookmarkAnchor, relativeTo currentAnchor: BookmarkAnchor) -> Bool {
        let leftOrder = orderByContentID[anchor.contentID] ?? .max
        let rightOrder = orderByContentID[currentAnchor.contentID] ?? .max

        if leftOrder != rightOrder {
            return leftOrder < rightOrder
        }

        return (anchor.offset ?? 0) < (currentAnchor.offset ?? 0)
    }
}

@MainActor
extension DocumentEditorState {
    public func addBookmark(
        named name: String,
        for blockID: BlockID,
        offset: Int? = nil,
        metadata: [String: String] = [:]
    ) {
        bookmarkStore.add(
            Bookmark(
                name: name,
                anchor: BookmarkAnchor(contentID: blockID.rawValue, offset: offset),
                metadata: metadata
            )
        )
    }

    public func bookmarkAnchor(for selection: TextSelection? = nil) -> BookmarkAnchor? {
        let selection = selection ?? richTextState.selection

        switch selection {
        case let .caret(blockID, offset):
            return BookmarkAnchor(contentID: blockID.rawValue, offset: offset)
        case let .range(start, end):
            let lowerOffset = min(start.offset, end.offset)
            return BookmarkAnchor(contentID: start.blockID.rawValue, offset: lowerOffset)
        case let .blockSelection(ids):
            guard let firstID = orderedBlockIDs(in: ids).first else { return nil }
            return BookmarkAnchor(contentID: firstID.rawValue)
        }
    }

    public func resolvedReference(
        _ reference: CrossReference,
        from currentAnchor: BookmarkAnchor? = nil
    ) -> ResolvedReference {
        bookmarkStore.resolve(reference, from: currentAnchor)
    }

    public func bookmarks(on page: ComputedPage) -> [Bookmark] {
        let visibleContentIDs = visibleContentIDs(on: page)
        return bookmarkStore.bookmarks.filter { visibleContentIDs.contains($0.anchor.contentID) }
    }

    @discardableResult
    public func addComment(
        body: String,
        authorID: String,
        selection: TextSelection? = nil
    ) -> Comment? {
        guard let anchor = commentAnchor(for: selection ?? richTextState.selection) else { return nil }

        let comment = Comment(
            anchor: anchor,
            author: CommentPrimitive.AuthorID(rawValue: authorID),
            body: body
        )
        commentStore.add(comment)
        commentStore.activeCommentID = comment.id
        return comment
    }

    public func comments(on page: ComputedPage) -> [Comment] {
        let visibleContentIDs = visibleContentIDs(on: page)
        return commentStore.comments.filter { comment in
            guard let contentID = anchoredContentID(for: comment) else { return false }
            return visibleContentIDs.contains(contentID)
        }
    }

    func refreshAnchoredStores() {
        bookmarkStore.positionResolver = bookmarkPositionResolver()
        bookmarkStore.regenerate(from: autoBookmarkItems())
    }

    private func bookmarkPositionResolver() -> some BookmarkPositionResolver {
        var pageNumbersByContentID: [String: Int] = [:]
        var orderByContentID: [String: Int] = [:]
        var nextOrder = 0

        for section in document.sections {
            for block in section.blocks {
                pageNumbersByContentID[block.id.rawValue] = layoutEngine.pageNumber(for: block.id)
                orderByContentID[block.id.rawValue] = nextOrder
                nextOrder += 1
            }
        }

        return DocumentBookmarkPositionResolver(
            pageNumbersByContentID: pageNumbersByContentID,
            orderByContentID: orderByContentID
        )
    }

    private func autoBookmarkItems() -> [(name: String, contentID: String, metadata: [String: String])] {
        var generatedNames: [String: Int] = [:]
        var items: [(name: String, contentID: String, metadata: [String: String])] = []

        for section in document.sections {
            for block in section.blocks {
                guard case let .heading(content, level) = block.content else { continue }

                let baseName = content.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !baseName.isEmpty else { continue }

                generatedNames[baseName, default: 0] += 1
                let count = generatedNames[baseName, default: 1]
                let resolvedName = count == 1 ? baseName : "\(baseName) (\(count))"

                var metadata = ["level": String(level)]
                if let pageNumber = layoutEngine.pageNumber(for: block.id) {
                    metadata["page"] = String(pageNumber)
                }

                items.append((resolvedName, block.id.rawValue, metadata))
            }
        }

        return items
    }

    private func commentAnchor(for selection: TextSelection) -> AnyCommentAnchor? {
        switch selection {
        case .caret:
            return nil
        case let .range(start, end):
            guard start.blockID == end.blockID else { return nil }

            let lower = min(start.offset, end.offset)
            let upper = max(start.offset, end.offset)
            guard upper > lower else { return nil }
            guard let content = textContent(for: start.blockID) else { return nil }
            guard let range = stringRange(in: content.plainText, lowerBound: lower, upperBound: upper) else { return nil }

            let selector = TextQuoteSelector.from(text: content.plainText, range: range)
            let anchor = TextCommentAnchor(
                blockID: start.blockID.rawValue,
                offset: lower,
                length: upper - lower,
                selector: selector
            )
            return try? AnyCommentAnchor(anchor)
        case let .blockSelection(ids):
            guard let firstID = orderedBlockIDs(in: ids).first else { return nil }
            return try? AnyCommentAnchor(ObjectCommentAnchor(objectID: firstID.rawValue))
        }
    }

    private func visibleContentIDs(on page: ComputedPage) -> Set<String> {
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

    private func anchoredContentID(for comment: Comment) -> String? {
        switch comment.anchor.anchorType {
        case TextCommentAnchor.anchorType:
            return try? comment.anchor.resolve(TextCommentAnchor.self).blockID
        case ObjectCommentAnchor.anchorType:
            return try? comment.anchor.resolve(ObjectCommentAnchor.self).objectID
        default:
            return nil
        }
    }

    private func orderedBlockIDs(in ids: Set<BlockID>) -> [BlockID] {
        let orderByID = document.sections
            .flatMap(\.blocks)
            .enumerated()
            .reduce(into: [BlockID: Int]()) { partialResult, entry in
                partialResult[entry.element.id] = entry.offset
            }

        return ids.sorted { left, right in
            (orderByID[left] ?? .max) < (orderByID[right] ?? .max)
        }
    }

    private func textContent(for blockID: BlockID) -> TextContent? {
        for section in document.sections {
            guard let block = section.blocks.first(where: { $0.id == blockID }) else { continue }

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

        return nil
    }

    private func stringRange(
        in text: String,
        lowerBound: Int,
        upperBound: Int
    ) -> Range<String.Index>? {
        let safeLower = min(max(lowerBound, 0), text.count)
        let safeUpper = min(max(upperBound, safeLower), text.count)
        guard safeUpper > safeLower else { return nil }

        guard
            let start = text.index(text.startIndex, offsetBy: safeLower, limitedBy: text.endIndex),
            let end = text.index(text.startIndex, offsetBy: safeUpper, limitedBy: text.endIndex)
        else {
            return nil
        }

        return start..<end
    }
}
