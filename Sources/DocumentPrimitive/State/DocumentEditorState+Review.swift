import CommentPrimitive
import Foundation
import RichTextPrimitive
import TrackChangesPrimitive

@MainActor
extension DocumentEditorState {
    public func comments(
        for blockID: BlockID,
        includeResolved: Bool = false
    ) -> [Comment] {
        let comments = includeResolved ? commentStore.comments : commentStore.openComments
        return comments.filter { anchoredContentID(for: $0) == blockID.rawValue }
    }

    public func changes(for blockID: BlockID) -> [TrackedChange] {
        changeTracker.visibleChanges.filter { $0.anchor.blockID == blockID.rawValue }
    }

    public func isCurrentComment(on blockID: BlockID) -> Bool {
        guard let currentComment else { return false }
        return anchoredContentID(for: currentComment) == blockID.rawValue
    }

    public func isCurrentTrackedChange(on blockID: BlockID) -> Bool {
        currentTrackedChange?.anchor.blockID == blockID.rawValue
    }

    public func focusFirstBookmark(on page: ComputedPage) {
        guard let bookmark = bookmarks(on: page).first else { return }
        focusBookmark(bookmark.id)
    }

    public func focusFirstComment(on page: ComputedPage) {
        let pageComments = comments(on: page)
        guard !pageComments.isEmpty else { return }

        if let currentComment,
           pageComments.contains(where: { $0.id == currentComment.id }) {
            focusComment(currentComment.id)
            return
        }

        focusComment((pageComments.first { $0.status == .open } ?? pageComments.first!).id)
    }

    public func focusFirstChange(on page: ComputedPage) {
        let pageChanges = changes(on: page)
        guard !pageChanges.isEmpty else { return }

        if let currentTrackedChange,
           pageChanges.contains(where: { $0.id == currentTrackedChange.id }) {
            focusChange(currentTrackedChange.id)
            return
        }

        focusChange(pageChanges.first!.id)
    }
}
