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
}
