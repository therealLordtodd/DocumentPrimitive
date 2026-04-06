import BookmarkPrimitive
import CommentPrimitive
import SwiftUI
import TrackChangesPrimitive

public struct DocumentToolbar: View {
    @Bindable private var state: DocumentEditorState

    public init(state: DocumentEditorState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 12) {
            Picker("View", selection: $state.viewMode) {
                Text("Page").tag(DocumentViewMode.page)
                Text("Continuous").tag(DocumentViewMode.continuous)
                Text("Canvas").tag(DocumentViewMode.canvas)
            }
            .pickerStyle(.segmented)

            Toggle("Ruler", isOn: $state.showRuler)
            Toggle("Formatting", isOn: $state.showFormatting)
            Toggle(
                "Track",
                isOn: Binding(
                    get: { state.changeTracker.isTracking },
                    set: { state.changeTracker.isTracking = $0 }
                )
            )

            Menu {
                visibilityButton("All Changes", visibility: .showAll)
                visibilityButton("My Changes", visibility: .showOnlyMine)
                visibilityButton("Final View", visibility: .final)
                visibilityButton("Original View", visibility: .original)
            } label: {
                Label(changeVisibilityLabel, systemImage: "line.3.horizontal.decrease.circle")
            }
            .menuStyle(.borderlessButton)

            Menu {
                if let currentCommentSummary = state.currentCommentSummary {
                    Section("Current Comment") {
                        Text(currentCommentSummary)

                        Button("Previous Comment") {
                            state.goToPreviousComment()
                        }
                        .disabled(commentCount == 0)

                        Button("Next Comment") {
                            state.goToNextComment()
                        }
                        .disabled(commentCount == 0)

                        if state.currentComment?.status == .open {
                            Button("Resolve Comment") {
                                state.resolveCurrentComment()
                            }
                        } else {
                            Button("Reopen Comment") {
                                state.reopenCurrentComment()
                            }
                        }
                    }
                }

                if bookmarkEntries.isEmpty {
                    Text("No bookmarks")
                } else {
                    Section("Bookmarks") {
                        ForEach(bookmarkEntries, id: \.id) { entry in
                            Button(entry.label) {
                                state.focusBookmark(entry.id)
                            }
                        }
                    }
                }

                if openCommentEntries.isEmpty {
                    Text("No open comments")
                } else {
                    Section("Comments") {
                        ForEach(openCommentEntries, id: \.id) { entry in
                            Button(entry.label) {
                                state.focusComment(entry.id)
                            }
                        }
                    }
                }
            } label: {
                Label("Review", systemImage: "list.bullet.rectangle")
            }
            .menuStyle(.borderlessButton)

            Spacer()

            HStack(spacing: 8) {
                Button {
                    state.goToPreviousChange()
                } label: {
                    Image(systemName: "arrow.up.circle")
                }
                .buttonStyle(.borderless)
                .disabled(changeCount == 0)

                Text(changeCountLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 72, alignment: .center)

                Button {
                    state.goToNextChange()
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.borderless)
                .disabled(changeCount == 0)

                if let currentChangeSummary = state.currentTrackedChangeSummary {
                    Text(currentChangeSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(minWidth: 110, maxWidth: 180, alignment: .leading)
                }

                Button {
                    state.acceptCurrentChange()
                } label: {
                    Image(systemName: "checkmark.circle")
                }
                .buttonStyle(.borderless)
                .disabled(state.currentTrackedChange == nil)

                Button(role: .destructive) {
                    state.rejectCurrentChange()
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.borderless)
                .disabled(state.currentTrackedChange == nil)

                Menu {
                    Button("Accept Current Change") {
                        state.acceptCurrentChange()
                    }
                    .disabled(state.currentTrackedChange == nil)

                    Button("Reject Current Change", role: .destructive) {
                        state.rejectCurrentChange()
                    }
                    .disabled(state.currentTrackedChange == nil)

                    Divider()

                    Button("Accept All Changes") {
                        state.acceptAllChanges()
                    }
                    .disabled(changeCount == 0)

                    Button("Reject All Changes", role: .destructive) {
                        state.rejectAllChanges()
                    }
                    .disabled(changeCount == 0)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .disabled(changeCount == 0)
            }

            HStack(spacing: 8) {
                Button {
                    state.goToPreviousPage()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .disabled(!state.canGoToPreviousPage)

                Text("Page \(state.currentPage)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    state.goToNextPage()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .disabled(!state.canGoToNextPage)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var changeCount: Int {
        state.reviewableTrackedChanges.count
    }

    private var changeVisibilityLabel: String {
        switch state.changeTracker.showChanges {
        case .showAll:
            "All Changes"
        case .showOnlyMine:
            "My Changes"
        case .final_:
            "Final View"
        case .original:
            "Original View"
        }
    }

    private var changeCountLabel: String {
        if changeCount == 0 {
            return "No Changes"
        }
        if let currentTrackedChangeID = state.currentTrackedChangeID,
           let index = state.reviewableTrackedChanges.firstIndex(where: { $0.id == currentTrackedChangeID }) {
            return "Change \(index + 1)/\(changeCount)"
        }
        return changeCount == 1 ? "1 Change" : "\(changeCount) Changes"
    }

    private var bookmarkEntries: [(id: BookmarkID, label: String)] {
        state.bookmarkStore.bookmarks.map { bookmark in
            let pageNumber = state.bookmarkStore.positionResolver?.pageNumber(for: bookmark.anchor)
            let pageSuffix = pageNumber.map { " (p.\($0))" } ?? ""
            return (bookmark.id, "\(bookmark.name)\(pageSuffix)")
        }
    }

    private var openCommentEntries: [(id: CommentID, label: String)] {
        state.commentStore.openComments.map { comment in
            let body = comment.body.trimmingCharacters(in: .whitespacesAndNewlines)
            let preview = body.isEmpty ? "Untitled comment" : String(body.prefix(36))
            return (comment.id, preview)
        }
    }

    private var commentCount: Int {
        state.commentStore.openComments.count
    }

    @ViewBuilder
    private func visibilityButton(_ title: String, visibility: ChangeVisibility) -> some View {
        Button {
            state.changeTracker.showChanges = visibility
        } label: {
            HStack {
                Text(title)
                if state.changeTracker.showChanges == visibility {
                    Image(systemName: "checkmark")
                }
            }
        }
    }
}
