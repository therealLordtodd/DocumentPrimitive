import FilterPrimitive
import SwiftUI

@MainActor
struct ReviewNavigatorPopover: View {
    @Bindable private var state: DocumentEditorState
    @State private var showsAdvancedFilters = false

    init(state: DocumentEditorState) {
        self._state = Bindable(wrappedValue: state)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let currentCommentSummary = state.currentCommentSummary {
                currentCommentControls(summary: currentCommentSummary)
            }

            QuickFilterToggle(
                filters: state.reviewNavigatorQuickFilters,
                activeConfiguration: $state.reviewFilterConfiguration
            )

            FilterBar(
                configuration: $state.reviewFilterConfiguration,
                fields: state.reviewNavigatorFilterFields
            )

            DisclosureGroup("Advanced Filters", isExpanded: $showsAdvancedFilters) {
                FilterBuilder(
                    configuration: $state.reviewFilterConfiguration,
                    fields: state.reviewNavigatorFilterFields,
                    totalItemCount: state.reviewNavigatorItems.count,
                    matchingCount: state.filteredReviewNavigatorItems.count
                )
                .padding(.top, 8)
            }

            Divider()

            if state.reviewNavigatorItems.isEmpty {
                emptyState(
                    title: "No review items yet",
                    message: "Comments, tracked changes, and bookmarks will appear here."
                )
            } else if state.filteredReviewNavigatorItems.isEmpty {
                emptyState(
                    title: "No matching review items",
                    message: "Adjust the active filters to widen the navigator."
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(state.filteredReviewNavigatorItems) { item in
                            reviewItemRow(item)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .frame(width: 430, height: 520)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Review Navigator")
                    .font(.headline)
                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !state.reviewFilterConfiguration.isEmpty {
                Button("Reset") {
                    state.reviewFilterConfiguration = FilterConfiguration()
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func currentCommentControls(summary: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Comment")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(summary)
                .font(.subheadline)
                .lineLimit(2)

            HStack(spacing: 8) {
                Button("Previous") {
                    state.goToPreviousComment()
                }
                .disabled(commentCount == 0)

                Button("Next") {
                    state.goToNextComment()
                }
                .disabled(commentCount == 0)

                Spacer()

                if state.currentComment?.status == .open {
                    Button("Resolve") {
                        state.resolveCurrentComment()
                    }
                } else {
                    Button("Reopen") {
                        state.reopenCurrentComment()
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func reviewItemRow(_ item: ReviewNavigatorItem) -> some View {
        let isFocused = state.isReviewNavigatorItemFocused(item)

        return Button {
            state.focusReviewNavigatorItem(item)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.systemImage)
                    .foregroundStyle(isFocused ? Color.accentColor : .secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        Spacer(minLength: 0)

                        if let pageNumber = item.pageNumber {
                            pageBadge(pageNumber)
                        }
                    }

                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        metadataPill(item.kindLabel)
                        if let statusLabel = item.statusLabel {
                            metadataPill(statusLabel)
                        }
                        if let author = item.author, !author.isEmpty {
                            metadataPill(author)
                        }
                    }
                }

                if isFocused {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isFocused ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }

    private func metadataPill(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.12))
            )
    }

    private func pageBadge(_ pageNumber: Int) -> some View {
        Text("p.\(pageNumber)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.12))
            )
    }

    private func emptyState(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 12)
    }

    private var commentCount: Int {
        state.commentStore.openComments.count
    }

    private var summaryText: String {
        "\(state.filteredReviewNavigatorItems.count) of \(state.reviewNavigatorItems.count) items"
    }
}
