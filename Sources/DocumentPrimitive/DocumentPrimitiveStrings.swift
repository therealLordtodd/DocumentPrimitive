import Foundation

public enum DocumentPrimitiveStrings {
    static var viewPickerTitle: String { localized("document.toolbar.view", defaultValue: "View") }
    static var pageViewModeTitle: String { localized("document.toolbar.view.page", defaultValue: "Page") }
    static var continuousViewModeTitle: String { localized("document.toolbar.view.continuous", defaultValue: "Continuous") }
    static var canvasViewModeTitle: String { localized("document.toolbar.view.canvas", defaultValue: "Canvas") }
    static var rulerToggleTitle: String { localized("document.toolbar.ruler", defaultValue: "Ruler") }
    static var formattingToggleTitle: String { localized("document.toolbar.formatting", defaultValue: "Formatting") }
    static var trackToggleTitle: String { localized("document.toolbar.track", defaultValue: "Track") }
    static var allChangesTitle: String { localized("document.review.visibility.allChanges", defaultValue: "All Changes") }
    static var myChangesTitle: String { localized("document.review.visibility.myChanges", defaultValue: "My Changes") }
    static var finalViewTitle: String { localized("document.review.visibility.finalView", defaultValue: "Final View") }
    static var originalViewTitle: String { localized("document.review.visibility.originalView", defaultValue: "Original View") }
    static var headersTitle: String { localized("document.headers.title", defaultValue: "Headers") }
    static var headersFirstTitle: String { localized("document.headers.first", defaultValue: "Headers: First") }
    static var headersOddEvenTitle: String { localized("document.headers.oddEven", defaultValue: "Headers: Odd/Even") }
    static var headersFirstOddEvenTitle: String { localized("document.headers.firstOddEven", defaultValue: "Headers: First + Odd/Even") }
    static var differentFirstPageTitle: String { localized("document.headers.differentFirstPage", defaultValue: "Different First Page") }
    static var differentOddEvenTitle: String { localized("document.headers.differentOddEven", defaultValue: "Different Odd & Even") }
    static var searchTitle: String { localized("document.action.search", defaultValue: "Search") }
    static var reviewTitle: String { localized("document.action.review", defaultValue: "Review") }
    static var previousChangeAccessibilityLabel: String { localized("document.action.previousChange", defaultValue: "Previous change") }
    static var nextChangeAccessibilityLabel: String { localized("document.action.nextChange", defaultValue: "Next change") }
    static var acceptCurrentChangeTitle: String { localized("document.action.acceptCurrentChange", defaultValue: "Accept Current Change") }
    static var rejectCurrentChangeTitle: String { localized("document.action.rejectCurrentChange", defaultValue: "Reject Current Change") }
    static var acceptAllChangesTitle: String { localized("document.action.acceptAllChanges", defaultValue: "Accept All Changes") }
    static var rejectAllChangesTitle: String { localized("document.action.rejectAllChanges", defaultValue: "Reject All Changes") }
    static var reviewActionsAccessibilityLabel: String { localized("document.action.reviewActions", defaultValue: "Review actions") }
    static var previousPageAccessibilityLabel: String { localized("document.action.previousPage", defaultValue: "Previous page") }
    static var nextPageAccessibilityLabel: String { localized("document.action.nextPage", defaultValue: "Next page") }
    static var noChangesTitle: String { localized("document.changeCount.none", defaultValue: "No Changes") }

    static var searchPlaceholder: String {
        localized(
            "document.search.placeholder",
            defaultValue: "Search headings, comments, bookmarks, and changes"
        )
    }
    static var searchingDocumentTitle: String { localized("document.search.loading", defaultValue: "Searching document...") }
    static var searchDocumentTitle: String { localized("document.search.title", defaultValue: "Search Document") }
    static var resetActionTitle: String { localized("document.action.reset", defaultValue: "Reset") }
    static var allScopeTitle: String { localized("document.search.scope.all", defaultValue: "All") }
    static var noIndexedItemsTitle: String { localized("document.search.empty.noIndexedItems.title", defaultValue: "No indexed document items") }
    static var noMatchesFoundTitle: String { localized("document.search.empty.noMatches.title", defaultValue: "No matches found") }
    static var noIndexedItemsMessage: String {
        localized(
            "document.search.empty.noIndexedItems.message",
            defaultValue: "Headings, comments, bookmarks, and tracked changes will appear here."
        )
    }
    static var noMatchesFoundMessage: String {
        localized(
            "document.search.empty.noMatches.message",
            defaultValue: "Try a different term or widen the selected scope."
        )
    }

    static var reviewNavigatorTitle: String { localized("document.review.navigator.title", defaultValue: "Review Navigator") }
    static var advancedFiltersTitle: String { localized("document.review.advancedFilters", defaultValue: "Advanced Filters") }
    static var noReviewItemsTitle: String { localized("document.review.empty.noItems.title", defaultValue: "No review items yet") }
    static var noReviewItemsMessage: String {
        localized(
            "document.review.empty.noItems.message",
            defaultValue: "Comments, tracked changes, and bookmarks will appear here."
        )
    }
    static var noMatchingReviewItemsTitle: String { localized("document.review.empty.noMatches.title", defaultValue: "No matching review items") }
    static var noMatchingReviewItemsMessage: String {
        localized(
            "document.review.empty.noMatches.message",
            defaultValue: "Adjust the active filters to widen the navigator."
        )
    }
    static var currentCommentTitle: String { localized("document.review.currentComment", defaultValue: "Current Comment") }
    static var previousActionTitle: String { localized("document.action.previous", defaultValue: "Previous") }
    static var nextActionTitle: String { localized("document.action.next", defaultValue: "Next") }
    static var resolveActionTitle: String { localized("document.action.resolve", defaultValue: "Resolve") }
    static var reopenActionTitle: String { localized("document.action.reopen", defaultValue: "Reopen") }

    static var reorderSectionAccessibilityLabel: String { localized("document.section.reorder.accessibility", defaultValue: "Reorder section") }
    static var reorderSectionAccessibilityHint: String {
        localized(
            "document.section.reorder.hint",
            defaultValue: "Drag to move this section within the document"
        )
    }
    static var sectionPreviewLabel: String { localized("document.section.preview", defaultValue: "Section") }
    static var leftMarginAccessibilityLabel: String { localized("document.ruler.leftMargin", defaultValue: "Left margin") }
    static var rightMarginAccessibilityLabel: String { localized("document.ruler.rightMargin", defaultValue: "Right margin") }
    static var firstLineIndentAccessibilityLabel: String { localized("document.ruler.firstLineIndent", defaultValue: "First line indent") }
    static var hangingIndentAccessibilityLabel: String { localized("document.ruler.hangingIndent", defaultValue: "Hanging indent") }
    static var columnGuideAccessibilityLabel: String { localized("document.ruler.columnGuide", defaultValue: "Column guide") }

    static var commentTitle: String { localized("document.comment.title", defaultValue: "Comment") }
    static var resolvedCommentTitle: String { localized("document.comment.resolvedTitle", defaultValue: "Resolved Comment") }
    static var focusedTitle: String { localized("document.review.focused", defaultValue: "Focused") }
    static var editCommentPlaceholder: String { localized("document.comment.edit.placeholder", defaultValue: "Edit comment") }
    static var saveActionTitle: String { localized("document.action.save", defaultValue: "Save") }
    static var replyPlaceholder: String { localized("document.comment.reply.placeholder", defaultValue: "Reply") }
    static var replyActionTitle: String { localized("document.comment.reply.action", defaultValue: "Reply") }
    static var openActionTitle: String { localized("document.action.open", defaultValue: "Open") }
    static var previousShortActionTitle: String { localized("document.action.previous.short", defaultValue: "Prev") }
    static var trackedChangeTitle: String { localized("document.trackedChange.title", defaultValue: "Tracked Change") }
    static var acceptActionTitle: String { localized("document.action.accept", defaultValue: "Accept") }
    static var rejectActionTitle: String { localized("document.action.reject", defaultValue: "Reject") }
    static var untitledCommentTitle: String { localized("document.comment.untitled", defaultValue: "Untitled comment") }
    static var untitledHeadingTitle: String { localized("document.heading.untitled", defaultValue: "Untitled heading") }

    static var headingsScopeTitle: String { localized("document.search.scope.headings", defaultValue: "Headings") }
    static var commentsScopeTitle: String { localized("document.search.scope.comments", defaultValue: "Comments") }
    static var bookmarksScopeTitle: String { localized("document.search.scope.bookmarks", defaultValue: "Bookmarks") }
    static var changesScopeTitle: String { localized("document.search.scope.changes", defaultValue: "Changes") }
    static var headingStatusTitle: String { localized("document.search.status.heading", defaultValue: "Heading") }
    static var bookmarkStatusTitle: String { localized("document.search.status.bookmark", defaultValue: "Bookmark") }
    static var changeStatusTitle: String { localized("document.search.status.change", defaultValue: "Change") }
    static var automaticBookmarkTitle: String { localized("document.bookmark.automatic", defaultValue: "Automatic bookmark") }
    static var manualBookmarkTitle: String { localized("document.bookmark.manual", defaultValue: "Manual bookmark") }
    static var openCommentStatusTitle: String { localized("document.comment.status.open", defaultValue: "Open") }
    static var resolvedCommentStatusTitle: String { localized("document.comment.status.resolved", defaultValue: "Resolved") }
    static var wontFixCommentStatusTitle: String { localized("document.comment.status.wontFix", defaultValue: "Won't Fix") }
    static var openCommentStatusDescription: String { localized("document.comment.status.open.description", defaultValue: "Open comment") }
    static var resolvedCommentStatusDescription: String { localized("document.comment.status.resolved.description", defaultValue: "Resolved comment") }
    static var wontFixCommentStatusDescription: String { localized("document.comment.status.wontFix.description", defaultValue: "Won't-fix comment") }
    static var automaticStatusTitle: String { localized("document.bookmark.status.automatic", defaultValue: "Automatic") }
    static var manualStatusTitle: String { localized("document.bookmark.status.manual", defaultValue: "Manual") }
    static var insertionTitle: String { localized("document.change.insertion", defaultValue: "Insertion") }
    static var deletionTitle: String { localized("document.change.deletion", defaultValue: "Deletion") }
    static var formattingTitle: String { localized("document.change.formatting", defaultValue: "Formatting") }
    static var formattingChangeTitle: String { localized("document.change.formattingChange", defaultValue: "Formatting change") }

    static var quickFilterCommentsTitle: String { localized("document.review.quickFilter.comments", defaultValue: "Comments") }
    static var quickFilterOpenCommentsTitle: String { localized("document.review.quickFilter.openComments", defaultValue: "Open Comments") }
    static var quickFilterChangesTitle: String { localized("document.review.quickFilter.changes", defaultValue: "Changes") }
    static var quickFilterMyChangesTitle: String { localized("document.review.quickFilter.myChanges", defaultValue: "My Changes") }
    static var quickFilterBookmarksTitle: String { localized("document.review.quickFilter.bookmarks", defaultValue: "Bookmarks") }
    static var quickFilterThisPageTitle: String { localized("document.review.quickFilter.thisPage", defaultValue: "This Page") }
    static var filterTypeTitle: String { localized("document.review.filter.type", defaultValue: "Type") }
    static var filterCommentStatusTitle: String { localized("document.review.filter.commentStatus", defaultValue: "Comment Status") }
    static var filterBookmarkTypeTitle: String { localized("document.review.filter.bookmarkType", defaultValue: "Bookmark Type") }
    static var filterChangeTypeTitle: String { localized("document.review.filter.changeType", defaultValue: "Change Type") }
    static var filterAuthorTitle: String { localized("document.review.filter.author", defaultValue: "Author") }
    static var filterPageTitle: String { localized("document.review.filter.page", defaultValue: "Page") }
    static var filterTextTitle: String { localized("document.review.filter.text", defaultValue: "Text") }

    public static var gridTableEditorRequiresTableBlock: String {
        localized("document.grid.requiresTableBlock", defaultValue: "Grid table editor requires a table block.")
    }
    public static var tableBlockNotFound: String { localized("document.grid.tableBlockNotFound", defaultValue: "Table block not found.") }

    static func pageLabel(_ page: Int) -> String {
        String.localizedStringWithFormat(localized("document.page.label", defaultValue: "Page %d"), page)
    }

    static func pageBadgeLabel(_ page: Int) -> String {
        String.localizedStringWithFormat(localized("document.page.badge", defaultValue: "p.%d"), page)
    }

    static func changeCountPosition(current: Int, total: Int) -> String {
        String.localizedStringWithFormat(localized("document.changeCount.position", defaultValue: "Change %d/%d"), current, total)
    }

    static func changeCount(_ count: Int) -> String {
        String.localizedStringWithFormat(localized("document.changeCount.total", defaultValue: "%d Changes"), count)
    }

    static func scoreLabel(_ score: String) -> String {
        String.localizedStringWithFormat(localized("document.search.score", defaultValue: "Score %@"), score)
    }

    static func browsingIndexedItems(_ count: Int) -> String {
        String.localizedStringWithFormat(localized("document.search.summary.browsing", defaultValue: "Browsing %d indexed items"), count)
    }

    static func searchMatches(visible: Int, total: Int) -> String {
        String.localizedStringWithFormat(localized("document.search.summary.matches", defaultValue: "%d of %d matches"), visible, total)
    }

    static func reviewItemsSummary(visible: Int, total: Int) -> String {
        String.localizedStringWithFormat(localized("document.review.summary.items", defaultValue: "%d of %d items"), visible, total)
    }

    static func headingLevel(_ level: Int) -> String {
        String.localizedStringWithFormat(localized("document.heading.level", defaultValue: "Heading %d"), level)
    }

    static func statusByAuthor(status: String, author: String) -> String {
        String.localizedStringWithFormat(localized("document.status.byAuthor", defaultValue: "%@ by %@"), status, author)
    }

    static func tabStopAccessibilityLabel(_ alignment: String) -> String {
        String.localizedStringWithFormat(localized("document.ruler.tabStop", defaultValue: "%@ tab stop"), alignment)
    }

    static func insertionCount(_ count: Int) -> String {
        String.localizedStringWithFormat(localized("document.annotation.insertionCount", defaultValue: "%d insertions"), count)
    }

    static func deletionCount(_ count: Int) -> String {
        String.localizedStringWithFormat(localized("document.annotation.deletionCount", defaultValue: "%d deletions"), count)
    }

    static func formatChangeCount(_ count: Int) -> String {
        String.localizedStringWithFormat(localized("document.annotation.formatChangeCount", defaultValue: "%d format changes"), count)
    }

    static func commentHoverText(count: Int, preview: String) -> String {
        String.localizedStringWithFormat(localized("document.hover.comment", defaultValue: "%@: %@"), commentHoverPrefix(count), preview)
    }

    static func changeHoverText(count: Int, summary: String) -> String {
        String.localizedStringWithFormat(localized("document.hover.change", defaultValue: "%@: %@"), changeHoverPrefix(count), summary)
    }

    private static func commentHoverPrefix(_ count: Int) -> String {
        String.localizedStringWithFormat(localized("document.hover.commentPrefix", defaultValue: "%d comments"), count)
    }

    private static func changeHoverPrefix(_ count: Int) -> String {
        String.localizedStringWithFormat(localized("document.hover.changePrefix", defaultValue: "%d changes"), count)
    }

    private static func localized(_ key: String, defaultValue: String) -> String {
        NSLocalizedString(key, bundle: .module, value: defaultValue, comment: "")
    }
}
