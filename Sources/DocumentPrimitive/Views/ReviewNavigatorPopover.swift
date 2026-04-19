import FilterPrimitive
import SwiftUI

@MainActor
struct ReviewNavigatorPopover: View {
    @Bindable private var state: DocumentEditorState
    @State private var showsAdvancedFilters = false
    @Environment(\.documentTheme) private var theme

    init(state: DocumentEditorState) {
        self._state = Bindable(wrappedValue: state)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.popoverContentSpacing) {
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
                    LazyVStack(alignment: .leading, spacing: theme.spacing.navigatorRowSpacing) {
                        ForEach(state.filteredReviewNavigatorItems) { item in
                            reviewItemRow(item)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(theme.spacing.popoverPadding)
        .frame(width: theme.metrics.popoverWidth, height: theme.metrics.popoverHeight)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Review Navigator")
                    .font(theme.typography.headline)
                Text(summaryText)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondary)
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
        VStack(alignment: .leading, spacing: theme.spacing.navigatorRowSpacing) {
            Text("Current Comment")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.secondary)

            Text(summary)
                .font(.subheadline)
                .lineLimit(2)

            HStack(spacing: theme.spacing.navigatorRowSpacing) {
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
        .padding(theme.spacing.navigatorRowPadding)
        .background(
            RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius)
                .fill(theme.mutedFill)
        )
    }

    private func reviewItemRow(_ item: ReviewNavigatorItem) -> some View {
        let isFocused = state.isReviewNavigatorItemFocused(item)

        return Button {
            state.focusReviewNavigatorItem(item)
        } label: {
            HStack(alignment: .top, spacing: theme.spacing.navigatorRowIconGap) {
                Image(systemName: item.systemImage)
                    .foregroundStyle(isFocused ? theme.colors.accent : theme.colors.secondary)
                    .frame(width: theme.metrics.navigatorIconWidth)

                VStack(alignment: .leading, spacing: theme.spacing.annotationBadgeGap) {
                    HStack(alignment: .firstTextBaseline, spacing: theme.spacing.navigatorRowSpacing) {
                        Text(item.title)
                            .font(theme.typography.rowTitle)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        Spacer(minLength: 0)

                        if let pageNumber = item.pageNumber {
                            DocumentPageBadge(pageNumber: pageNumber)
                        }
                    }

                    Text(item.subtitle)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.secondary)
                        .lineLimit(2)

                    HStack(spacing: theme.spacing.annotationBadgeGap) {
                        DocumentMetadataBadge(text: item.kindLabel)
                        if let statusLabel = item.statusLabel {
                            DocumentMetadataBadge(text: statusLabel)
                        }
                        if let author = item.author, !author.isEmpty {
                            DocumentMetadataBadge(text: author)
                        }
                    }
                }

                if isFocused {
                    Image(systemName: "location.fill")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.accent)
                }
            }
            .padding(theme.spacing.navigatorRowPadding)
            .background(
                RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius)
                    .fill(isFocused ? theme.selectedFill : theme.subtleFill)
            )
        }
        .buttonStyle(.plain)
    }

    private func emptyState(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.annotationBadgeGap) {
            Text(title)
                .font(theme.typography.rowTitle)
            Text(message)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, theme.spacing.navigatorRowPadding)
    }

    private var commentCount: Int {
        state.commentStore.openComments.count
    }

    private var summaryText: String {
        "\(state.filteredReviewNavigatorItems.count) of \(state.reviewNavigatorItems.count) items"
    }
}
