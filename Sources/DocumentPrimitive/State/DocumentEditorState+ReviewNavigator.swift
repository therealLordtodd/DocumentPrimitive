import BookmarkPrimitive
import CommentPrimitive
import FilterPrimitive
import Foundation
import RichTextPrimitive
import TrackChangesPrimitive

enum ReviewNavigatorItemKind: String, CaseIterable, Sendable {
    case comment
    case change
    case bookmark

    var label: String {
        switch self {
        case .comment:
            "Comment"
        case .change:
            "Change"
        case .bookmark:
            "Bookmark"
        }
    }

    var systemImage: String {
        switch self {
        case .comment:
            "text.bubble"
        case .change:
            "arrow.triangle.branch"
        case .bookmark:
            "bookmark"
        }
    }

    var sortPriority: Int {
        switch self {
        case .comment:
            0
        case .change:
            1
        case .bookmark:
            2
        }
    }
}

struct ReviewNavigatorItem: Identifiable, Equatable, Sendable {
    let sourceID: String
    let kindRawValue: String
    let title: String
    let subtitle: String
    let searchText: String
    let author: String?
    let commentStatus: String?
    let bookmarkType: String?
    let changeType: String?
    let pageNumber: Int?
    let contentID: String?
    let blockOrder: Int
    let offset: Int
    let secondarySortKey: String

    var id: String {
        "\(kindRawValue):\(sourceID)"
    }

    var kind: ReviewNavigatorItemKind {
        ReviewNavigatorItemKind(rawValue: kindRawValue) ?? .comment
    }

    var kindLabel: String {
        kind.label
    }

    var statusLabel: String? {
        if let commentStatus {
            switch commentStatus {
            case CommentStatus.open.rawValue:
                return "Open"
            case CommentStatus.resolved.rawValue:
                return "Resolved"
            case CommentStatus.wontFix.rawValue:
                return "Won't Fix"
            default:
                return commentStatus.capitalized
            }
        }

        if let bookmarkType {
            switch bookmarkType {
            case "automatic":
                return "Automatic"
            case "manual":
                return "Manual"
            default:
                return bookmarkType.capitalized
            }
        }

        if let changeType {
            switch changeType {
            case "insertion":
                return "Insertion"
            case "deletion":
                return "Deletion"
            case "format":
                return "Formatting"
            default:
                return changeType.capitalized
            }
        }

        return nil
    }

    var systemImage: String {
        kind.systemImage
    }
}

@MainActor
extension DocumentEditorState {
    var reviewNavigatorItems: [ReviewNavigatorItem] {
        let blockOrderByID = reviewNavigatorBlockOrderByID()
        let summaryResolver = TrackedChangeSummaryResolver()

        let bookmarks = bookmarkStore.bookmarks.map { bookmark in
            reviewNavigatorItem(for: bookmark, blockOrderByID: blockOrderByID)
        }

        let comments = commentStore.comments.map { comment in
            reviewNavigatorItem(for: comment, blockOrderByID: blockOrderByID)
        }

        let changes = reviewableTrackedChanges.map { change in
            reviewNavigatorItem(
                for: change,
                blockOrderByID: blockOrderByID,
                summaryResolver: summaryResolver
            )
        }

        return (bookmarks + comments + changes).sorted(by: reviewNavigatorSort)
    }

    var filteredReviewNavigatorItems: [ReviewNavigatorItem] {
        FilterEngine.apply(
            configuration: reviewFilterConfiguration,
            to: reviewNavigatorItems,
            schema: reviewNavigatorSchema
        )
    }

    var reviewNavigatorFilterFields: [FilterFieldDefinition] {
        reviewNavigatorSchema.fields
    }

    var reviewNavigatorQuickFilters: [QuickFilter] {
        let schema = reviewNavigatorSchema

        return [
            QuickFilter(
                name: "Comments",
                icon: "text.bubble",
                filter: FilterGroup(predicates: [
                    schema.predicate(\.kindRawValue, .equals, .enumValue(ReviewNavigatorItemKind.comment.rawValue)),
                ])
            ),
            QuickFilter(
                name: "Open Comments",
                icon: "text.bubble.fill",
                filter: FilterGroup(predicates: [
                    schema.predicate(\.kindRawValue, .equals, .enumValue(ReviewNavigatorItemKind.comment.rawValue)),
                    schema.predicate(\.commentStatus, .equals, .enumValue(CommentStatus.open.rawValue)),
                ])
            ),
            QuickFilter(
                name: "Changes",
                icon: "arrow.triangle.branch",
                filter: FilterGroup(predicates: [
                    schema.predicate(\.kindRawValue, .equals, .enumValue(ReviewNavigatorItemKind.change.rawValue)),
                ])
            ),
            QuickFilter(
                name: "My Changes",
                icon: "person.crop.circle",
                filter: FilterGroup(predicates: [
                    schema.predicate(\.kindRawValue, .equals, .enumValue(ReviewNavigatorItemKind.change.rawValue)),
                    schema.predicate(\.author, .equals, .string(changeTracker.currentAuthor.rawValue)),
                ])
            ),
            QuickFilter(
                name: "Bookmarks",
                icon: "bookmark",
                filter: FilterGroup(predicates: [
                    schema.predicate(\.kindRawValue, .equals, .enumValue(ReviewNavigatorItemKind.bookmark.rawValue)),
                ])
            ),
            QuickFilter(
                name: "This Page",
                icon: "doc.text.magnifyingglass",
                filter: FilterGroup(predicates: [
                    schema.predicate(\.pageNumber, .equals, .int(currentPage)),
                ])
            ),
        ]
    }

    func focusReviewNavigatorItem(_ item: ReviewNavigatorItem) {
        switch item.kind {
        case .comment:
            focusComment(CommentID(rawValue: item.sourceID))
        case .change:
            focusChange(ChangeID(rawValue: item.sourceID))
        case .bookmark:
            focusBookmark(BookmarkID(rawValue: item.sourceID))
        }
    }

    func isReviewNavigatorItemFocused(_ item: ReviewNavigatorItem) -> Bool {
        switch item.kind {
        case .comment:
            currentComment?.id.rawValue == item.sourceID
        case .change:
            currentTrackedChangeID?.rawValue == item.sourceID
        case .bookmark:
            richTextState.focusedBlockID?.rawValue == item.contentID
        }
    }

    private var reviewNavigatorSchema: FilterSchema<ReviewNavigatorItem> {
        var schema = FilterSchema<ReviewNavigatorItem>()
        schema.register(
            \.kindRawValue,
            id: "kind",
            label: "Type",
            type: .enumeration,
            suggestions: ReviewNavigatorItemKind.allCases.map { .enumValue($0.rawValue) }
        )
        schema.register(
            \.commentStatus,
            id: "comment_status",
            label: "Comment Status",
            type: .enumeration,
            suggestions: [
                .enumValue(CommentStatus.open.rawValue),
                .enumValue(CommentStatus.resolved.rawValue),
                .enumValue(CommentStatus.wontFix.rawValue),
            ]
        )
        schema.register(
            \.bookmarkType,
            id: "bookmark_type",
            label: "Bookmark Type",
            type: .enumeration,
            suggestions: [.enumValue("manual"), .enumValue("automatic")]
        )
        schema.register(
            \.changeType,
            id: "change_type",
            label: "Change Type",
            type: .enumeration,
            suggestions: [.enumValue("insertion"), .enumValue("deletion"), .enumValue("format")]
        )
        schema.register(
            \.author,
            id: "author",
            label: "Author",
            type: .string
        )
        schema.register(
            \.pageNumber,
            id: "page",
            label: "Page",
            type: .number
        )
        schema.register(
            \.searchText,
            id: "text",
            label: "Text",
            type: .string
        )
        return schema
    }

    private func reviewNavigatorItem(
        for bookmark: Bookmark,
        blockOrderByID: [String: Int]
    ) -> ReviewNavigatorItem {
        let bookmarkType = bookmark.isAutoGenerated ? "automatic" : "manual"
        let pageNumber = reviewNavigatorPageNumber(for: bookmark.anchor.contentID)
            ?? bookmark.metadata["page"].flatMap(Int.init)
        let subtitle = bookmark.isAutoGenerated ? "Automatic bookmark" : "Manual bookmark"

        return ReviewNavigatorItem(
            sourceID: bookmark.id.rawValue,
            kindRawValue: ReviewNavigatorItemKind.bookmark.rawValue,
            title: bookmark.name,
            subtitle: subtitle,
            searchText: [bookmark.name, subtitle, bookmark.metadata.values.joined(separator: " ")]
                .filter { !$0.isEmpty }
                .joined(separator: "\n"),
            author: nil,
            commentStatus: nil,
            bookmarkType: bookmarkType,
            changeType: nil,
            pageNumber: pageNumber,
            contentID: bookmark.anchor.contentID,
            blockOrder: blockOrderByID[bookmark.anchor.contentID] ?? .max,
            offset: bookmark.anchor.offset ?? 0,
            secondarySortKey: bookmark.name.lowercased()
        )
    }

    private func reviewNavigatorItem(
        for comment: Comment,
        blockOrderByID: [String: Int]
    ) -> ReviewNavigatorItem {
        let contentID = anchoredContentID(for: comment)
        let preview = reviewNavigatorPreview(comment.body, fallback: "Untitled comment")
        let subtitle = "\(reviewNavigatorCommentStatusLabel(comment.status)) by \(comment.author.rawValue)"

        return ReviewNavigatorItem(
            sourceID: comment.id.rawValue,
            kindRawValue: ReviewNavigatorItemKind.comment.rawValue,
            title: preview,
            subtitle: subtitle,
            searchText: [comment.body, comment.author.rawValue, comment.status.rawValue]
                .filter { !$0.isEmpty }
                .joined(separator: "\n"),
            author: comment.author.rawValue,
            commentStatus: comment.status.rawValue,
            bookmarkType: nil,
            changeType: nil,
            pageNumber: reviewNavigatorPageNumber(for: contentID),
            contentID: contentID,
            blockOrder: contentID.flatMap { blockOrderByID[$0] } ?? .max,
            offset: reviewNavigatorCommentOffset(comment),
            secondarySortKey: preview.lowercased()
        )
    }

    private func reviewNavigatorItem(
        for change: TrackedChange,
        blockOrderByID: [String: Int],
        summaryResolver: TrackedChangeSummaryResolver
    ) -> ReviewNavigatorItem {
        let summary = summaryResolver.summary(for: change, context: trackedChangeContexts[change.id])
        let type = reviewNavigatorChangeType(change.type)
        let subtitle = "\(reviewNavigatorChangeTypeLabel(type)) by \(change.author.rawValue)"

        return ReviewNavigatorItem(
            sourceID: change.id.rawValue,
            kindRawValue: ReviewNavigatorItemKind.change.rawValue,
            title: summary,
            subtitle: subtitle,
            searchText: [summary, change.author.rawValue, type]
                .filter { !$0.isEmpty }
                .joined(separator: "\n"),
            author: change.author.rawValue,
            commentStatus: nil,
            bookmarkType: nil,
            changeType: type,
            pageNumber: reviewNavigatorPageNumber(for: change.anchor.blockID),
            contentID: change.anchor.blockID,
            blockOrder: blockOrderByID[change.anchor.blockID] ?? .max,
            offset: change.anchor.offset,
            secondarySortKey: summary.lowercased()
        )
    }

    private func reviewNavigatorSort(_ lhs: ReviewNavigatorItem, _ rhs: ReviewNavigatorItem) -> Bool {
        if lhs.blockOrder != rhs.blockOrder {
            return lhs.blockOrder < rhs.blockOrder
        }

        if lhs.offset != rhs.offset {
            return lhs.offset < rhs.offset
        }

        if lhs.kind.sortPriority != rhs.kind.sortPriority {
            return lhs.kind.sortPriority < rhs.kind.sortPriority
        }

        if lhs.secondarySortKey != rhs.secondarySortKey {
            return lhs.secondarySortKey < rhs.secondarySortKey
        }

        return lhs.id < rhs.id
    }

    private func reviewNavigatorBlockOrderByID() -> [String: Int] {
        document.sections
            .flatMap(\.blocks)
            .enumerated()
            .reduce(into: [String: Int]()) { partialResult, entry in
                partialResult[entry.element.id.rawValue] = entry.offset
            }
    }

    private func reviewNavigatorPageNumber(for contentID: String?) -> Int? {
        guard let contentID else { return nil }
        return layoutEngine.pageNumber(for: BlockID(contentID))
    }

    private func reviewNavigatorCommentOffset(_ comment: Comment) -> Int {
        switch comment.anchor.anchorType {
        case TextCommentAnchor.anchorType:
            return (try? comment.anchor.resolve(TextCommentAnchor.self).offset) ?? 0
        case ObjectCommentAnchor.anchorType:
            return 0
        default:
            return 0
        }
    }

    private func reviewNavigatorCommentStatusLabel(_ status: CommentStatus) -> String {
        switch status {
        case .open:
            "Open comment"
        case .resolved:
            "Resolved comment"
        case .wontFix:
            "Won't-fix comment"
        }
    }

    private func reviewNavigatorChangeType(_ type: ChangeType) -> String {
        switch type {
        case .insertion:
            "insertion"
        case .deletion:
            "deletion"
        case .formatChange:
            "format"
        }
    }

    private func reviewNavigatorChangeTypeLabel(_ type: String) -> String {
        switch type {
        case "insertion":
            "Insertion"
        case "deletion":
            "Deletion"
        case "format":
            "Formatting"
        default:
            type.capitalized
        }
    }

    private func reviewNavigatorPreview(_ text: String, fallback: String) -> String {
        let trimmed = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        guard !trimmed.isEmpty else { return fallback }
        return String(trimmed.prefix(72))
    }
}
