import BookmarkPrimitive
import CommentPrimitive
import SwiftUI

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
        state.changeTracker.visibleChanges.count
    }

    private var changeCountLabel: String {
        if changeCount == 0 {
            return "No Changes"
        }
        if let currentTrackedChangeID = state.currentTrackedChangeID,
           let index = state.changeTracker.visibleChanges.firstIndex(where: { $0.id == currentTrackedChangeID }) {
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
}
